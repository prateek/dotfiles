"""Exercise installed clients against disposable local and Git releases."""
from __future__ import annotations

from contextlib import contextmanager
import http.server
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import threading
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[3]
SCRIPTS = ROOT / '.agents/skills/agent-skill-management/scripts'
sys.path.insert(0, str(SCRIPTS))
sys.path.insert(0, str(ROOT / 'agent-marketplace/scripts'))
from artifact import tree_files, validate_artifact
from codex_rpc import enabled_edit, requests

DEFAULTS = {'core', 'mattpocock', 'review', 'utils-agent'}


@contextmanager
def git_server(root: Path, environment: dict):
    class Handler(http.server.BaseHTTPRequestHandler):
        def serve(self):
            url = urlsplit(self.path)
            body = self.rfile.read(int(self.headers.get('Content-Length', '0')))
            result = subprocess.run(['git', 'http-backend'], input=body, capture_output=True, timeout=30,
                env=environment | {'GIT_PROJECT_ROOT': str(root), 'GIT_HTTP_EXPORT_ALL': '1',
                    'PATH_INFO': url.path, 'QUERY_STRING': url.query, 'REQUEST_METHOD': self.command,
                    'CONTENT_TYPE': self.headers.get('Content-Type', ''), 'CONTENT_LENGTH': str(len(body))})
            headers, content = result.stdout.split(b'\r\n\r\n', 1)
            parsed = dict(line.decode().split(': ', 1) for line in headers.split(b'\r\n'))
            self.send_response(int(parsed.pop('Status', '200').split()[0]))
            for key, value in parsed.items():
                self.send_header(key, value)
            self.send_header('Content-Length', str(len(content)))
            self.end_headers()
            self.wfile.write(content)

        do_GET = do_POST = serve

        def log_message(self, *_):
            pass

    server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        yield f'http://127.0.0.1:{server.server_port}/distribution.git'
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=2)


def main():
    claude, codex, scratch_arg = sys.argv[1:]
    scratch = Path(scratch_arg).absolute()
    scratch.mkdir(parents=True)
    home = scratch / 'home'
    for sub in ('.codex', '.claude', '.config'):
        (home / sub).mkdir(parents=True)
    environment = {key: value for key, value in os.environ.items() if not key.startswith('GIT_')}
    environment.update(HOME=str(home), ZDOTDIR=str(home), CODEX_HOME=str(home / '.codex'),
        CLAUDE_CONFIG_DIR=str(home / '.claude'), XDG_CONFIG_HOME=str(home / '.config'),
        GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_NOSYSTEM='1', GIT_TERMINAL_PROMPT='0',
        CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC='1')
    executables = scratch / 'bin'
    executables.mkdir()
    for name, path in (('claude', claude), ('codex', codex)):
        (executables / name).symlink_to(path)
    environment['PATH'] = os.pathsep.join([str(executables), *[
        part for part in environment['PATH'].split(os.pathsep) if '/mise/shims' not in part]])

    def run(*argv, cwd=home):
        result = subprocess.run(list(map(str, argv)), cwd=cwd, env=environment,
                                capture_output=True, text=True, timeout=180)
        with (scratch / 'commands.log').open('a') as log:
            log.write(f'{argv}\n{result.stdout}\n{result.stderr}\n')
        assert result.returncode == 0, f'{argv}: {result.stdout}\n{result.stderr}'
        return json.loads(result.stdout) if '--json' in argv else result.stdout

    def rpc(messages):
        return requests(messages, cli=codex, env=environment, cwd=home)

    def seal(artifact):
        path = artifact / 'release.json'
        receipt = json.loads(path.read_text())
        receipt['files'] = tree_files(artifact, skip={'release.json'})
        path.write_text(json.dumps(receipt))
        validate_artifact(artifact)

    original = scratch / 'original'
    shutil.copytree(ROOT / 'agent-marketplace/build/marketplace', original)
    names = sorted(path.name for path in (original / 'plugins').iterdir())
    assert set(names) == DEFAULTS | {'design', 'experimental', 'ios', 'obsidian-wiki', 'superpowers', 'utils-human'}
    for name in names:
        plugin = original / 'plugins' / name
        (plugin / 'release-probe.txt').write_text('original\n')
        (plugin / 'stale-probe.txt').write_text('old\n')
    seal(original)
    updated = scratch / 'updated'
    shutil.copytree(original, updated)
    for name in names:
        plugin = updated / 'plugins' / name
        (plugin / 'release-probe.txt').write_text('updated\n')
        (plugin / 'stale-probe.txt').unlink()
        for relative in ('.claude-plugin/plugin.json', '.codex-plugin/plugin.json'):
            path = plugin / relative
            data = json.loads(path.read_text())
            major, minor, patch = data['version'].split('.')
            data['version'] = f'{major}.{minor}.{int(patch) + 1}'
            path.write_text(json.dumps(data))
    catalog = updated / '.claude-plugin/marketplace.json'
    data = json.loads(catalog.read_text())
    for entry in data['plugins']:
        entry['version'] = json.loads((updated / 'plugins' / entry['name'] / '.claude-plugin/plugin.json').read_text())['version']
    catalog.write_text(json.dumps(data))
    seal(updated)

    foreign = scratch / 'unrelated'
    for relative in ('.claude-plugin', '.agents/plugins', 'plugins/other/.claude-plugin',
                     'plugins/other/.codex-plugin', 'plugins/other/skills/other'):
        (foreign / relative).mkdir(parents=True)
    (foreign / 'plugins/other/skills/other/SKILL.md').write_text('---\nname: other\ndescription: Unrelated fixture.\n---\n')
    for client, relative in (('claude', '.claude-plugin'), ('codex', '.agents/plugins')):
        data = json.loads((original / relative / 'marketplace.json').read_text())
        data['name'] = 'unrelated'
        entry = data['plugins'][0] | {'name': 'other', 'version': '9.0.0'}
        entry['source'] = './plugins/other' if client == 'claude' else {'source': 'local', 'path': './plugins/other'}
        data['plugins'] = [entry]
        (foreign / relative / 'marketplace.json').write_text(json.dumps(data))
        (foreign / f'plugins/other/.{client}-plugin/plugin.json').write_text(json.dumps(
            {'name': 'other', 'version': '9.0.0', 'skills': './skills/'}))
        run(client, 'plugin', 'marketplace', 'add', str(foreign))
        run(client, 'plugin', 'install' if client == 'claude' else 'add', 'other@unrelated')
    rpc([enabled_edit('other@unrelated', False)])

    live = scratch / 'live'
    policy = ROOT / 'home/.chezmoidata/agent_plugins.toml'

    def materialize(artifact, target):
        run(sys.executable, SCRIPTS / 'materialize-agent-plugins', '--artifact-root', artifact, '--plugins-root', target)

    def reconcile(target):
        run(sys.executable, SCRIPTS / 'reconcile-agent-plugins', '--apply', '--agent', 'claude', '--agent', 'codex',
            '--plugins-root', target, '--policy', policy,
            *[part for name in names if name not in DEFAULTS for part in ('--refresh-disabled', name)])

    def verify(artifact, marker):
        installed = {'claude': run('claude', 'plugin', 'list', '--json'),
                     'codex': run('codex', 'plugin', 'list', '--json')['installed']}
        for client, entries in installed.items():
            assert len(entries) == len(names) + 1, (client, entries)
            for entry in entries:
                identity = entry['id' if client == 'claude' else 'pluginId']
                name, marketplace = identity.split('@')
                if marketplace == 'unrelated':
                    assert entry['version'] == '9.0.0' and entry['enabled'] == (client == 'claude'), entry
                    continue
                assert marketplace == 'prateek-local' and name in names, entry
                plugin = artifact / 'plugins' / name
                expected = json.loads((plugin / f'.{client}-plugin/plugin.json').read_text())['version']
                assert entry['version'] == expected and entry['enabled'] == (name in DEFAULTS), entry
                cache = Path(entry['installPath']) if client == 'claude' else home / '.codex/plugins/cache/prateek-local' / name / expected
                assert (cache / 'release-probe.txt').read_text() == marker + '\n', (client, name, cache)
                assert (cache / 'stale-probe.txt').exists() == (marker == 'original'), (client, name)
        discovered = rpc([('plugin/read', {'marketplacePath': str(artifact / '.agents/plugins/marketplace.json'),
                                           'pluginName': name}) for name in names])
        counts = {}
        for name, response in zip(names, discovered):
            plugin = response['plugin']
            expected = {re.search(r'^name:\s*(.+)$', path.read_text(), re.M)[1].strip('\"\'')
                        for path in (artifact / 'plugins' / name / 'skills').rglob('SKILL.md')}
            assert {skill['name'] for skill in plugin['skills']} == {f'{name}:{skill}' for skill in expected}, (name, plugin)
            assert not plugin['hooks'], (name, plugin['hooks'])
            counts[name] = len(plugin['skills'])
        return counts

    materialize(original, live)
    run('codex', 'plugin', 'marketplace', 'add', str(live))
    for name in names:
        if name not in DEFAULTS:
            run('codex', 'plugin', 'add', f'{name}@prateek-local')
    reconcile(live)
    print('install and discovery:', verify(live, 'original'), flush=True)
    run('claude', 'plugin', 'validate', str(live))
    materialize(updated, live)
    reconcile(live)
    verify(live, 'updated')
    materialize(updated, live)
    assert (live.with_name('live.previous') / 'plugins/core/release-probe.txt').read_text() == 'original\n'
    print('versioned update, stale removal, retry recovery passed', flush=True)
    relocated = scratch / 'relocated'
    materialize(updated, relocated)
    reconcile(relocated)
    verify(relocated, 'updated')
    materialize(live.with_name('live.previous'), relocated)
    reconcile(relocated)
    verify(relocated, 'original')
    print('relocation and native rollback passed', flush=True)

    distribution = scratch / 'distribution'
    shutil.copytree(original, distribution)
    for args in (('init', '-q'), ('add', '--force', '--all'),
                 ('-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid', 'commit', '-qm', 'Artifact release')):
        run('git', *args, cwd=distribution)
    run('git', 'clone', '--bare', str(distribution), str(scratch / 'distribution.git'))
    with git_server(scratch, environment) as url:
        for client in ('claude', 'codex'):
            run(client, 'plugin', 'marketplace', 'remove', 'prateek-local')
            run(client, 'plugin', 'marketplace', 'add', url)
            for name in names:
                if client == 'claude':
                    run(client, 'plugin', 'install', f'{name}@prateek-local', '--scope', 'user')
                    if name not in DEFAULTS:
                        run(client, 'plugin', 'disable', f'{name}@prateek-local', '--scope', 'user')
                else:
                    run(client, 'plugin', 'add', f'{name}@prateek-local')
        rpc([enabled_edit(f'{name}@prateek-local', False) for name in names if name not in DEFAULTS])
        verify(original, 'original')
    print('artifact-root Git distribution passed over local smart HTTP', flush=True)
    print(run('claude', '--version').strip(), run('codex', '--version').strip(), flush=True)


if __name__ == '__main__':
    main()
