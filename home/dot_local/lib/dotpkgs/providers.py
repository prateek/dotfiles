"""Native inventories normalized to a single package record."""
from pathlib import Path
import hashlib
import json
import plistlib
import re
import tomllib

from core import Problem, apm_identity, record, version

MANAGERS = {
    'brew': ('brew', 'Homebrew formulae, casks and fork builds'),
    'mise': ('mise', 'Machine runtimes and npm/pipx/GitHub CLI backends'),
    'claude': ('claude', 'Claude Code native installation'),
    'codex': ('codex', 'Codex standalone installation'),
    'cursor': ('cursor-agent', 'Cursor agent native installation'),
    'gh': ('gh', 'GitHub CLI extensions'),
    'zinit': ('zsh', 'Shell plugins'),
    'apm': ('apm', 'Agent marketplace dependencies'),
    'mas': ('mas', 'Mac App Store apps'),
    'setapp': ('open', 'Setapp subscription apps'),
    'xcode': ('xcodes', 'Xcode toolchains'),
    'raycast': ('npm', 'Local Raycast extension builds'),
    'externals': ('git', 'Chezmoi Git externals'),
    'swift': ('swiftc', 'Local Swift helpers'),
}


LIMITS = {
    'brew': 'Latest means the Homebrew formula/cask catalog; versioned formula names keep their release line. Cask receipts may differ from self-updated app versions.',
    'mise': 'Managed source edits; host-local zz-local.toml pins remain host-local. Removing overrides requires manual review of underlying declarations. Required agent adapters cannot be removed independently.',
    'claude': 'Native update/install/remove. Durable pinning requires native auto-updater configuration; no integrated pin/unpin.',
    'codex': 'Standalone versions support durable pins. Account state and running sessions survive launcher removal.',
    'cursor': 'Native update/install/remove. No supported durable CLI pin control is integrated.',
    'gh': 'Pins are native gh installation state; fresh machines install the declared extension at latest.',
    'zinit': 'Simple zinit light declarations support install/remove and ver pins. Complex custom ice declarations require source edits.',
    'apm': 'Updates acquire the entire shared graph, then require source/patch/version review before materialization.',
    'mas': 'App Store compatible releases; no version pin API. App Store authentication may be required.',
    'setapp': 'Install/remove are integrated; updates use the signed Setapp client. No version pin API.',
    'xcode': 'Pin/install/select via xcodes. Latest may need a newer macOS. Runtime/device policy requires review after a version change.',
    'raycast': 'Install/rebuild declared extension sources; latest bumps dependency declarations. Removal requires explicit source changes and removal of the imported bundle in Raycast.',
    'externals': 'Refresh/update declared Git checkouts. Add/remove/ref changes belong to the owning chezmoi external declaration.',
    'swift': 'Build/remove the declared helpers. Versions are source/binary digests; no independent release pin.',
}


def brew(ctx, check):
    info = ctx.json(['brew', 'info', '--json=v2', '--installed'])
    changes = ctx.json(['brew', 'outdated', '--json=v2']) if check else {}
    outdated = {p['name']: p for kind in ('formulae', 'casks') for p in changes.get(kind, [])}
    rows = []
    for kind in ('formulae', 'casks'):
        for item in info[kind]:
            name = item.get('full_name') or item.get('full_token') or item.get('token') or item['name']
            short = item.get('name') if kind == 'formulae' else item['token']
            change = outdated.get(name) or outdated.get(short)
            installed = item.get('installed')
            if isinstance(installed, list):
                installed = ','.join(str(v['version']) for v in installed)
            latest = (item.get('versions', {}).get('stable') if kind == 'formulae' else item.get('version'))
            if kind == 'formulae' and item.get('revision'):
                latest = f'{latest}_{item["revision"]}'
            pinned = bool(item.get('pinned'))
            self_managed = kind == 'casks' and (item.get('auto_updates') or item.get('version') == 'latest')
            status = 'unknown' if not check else ('pinned_outdated' if pinned else 'update_available') if change else 'current'
            rows.append(record('brew', name, installed, 'hold' if pinned else 'latest',
                               latest if check else None, installed if pinned or self_managed else latest,
                               pinned=pinned, status=status, kind='formula' if kind == 'formulae' else 'cask',
                               auto_updates=bool(item.get('auto_updates')),
                               version_latest=item.get('version') == 'latest',
                               installed_on_request=any(v.get('installed_on_request', False) for v in item.get('installed', [])) if kind == 'formulae' else False,
                               note='Homebrew receipt/catalog versions; an app may self-update separately.' if kind == 'casks' else None))
    return rows


def mise(ctx, check):
    inventory = ctx.json(['mise', 'ls', '--global', '--json'])
    allowed = ctx.json(['mise', 'outdated', '--json']) if check else {}
    latest = ctx.json(['mise', 'outdated', '--bump', '--json']) if check else {}
    rows = []
    for name, versions in inventory.items():
        for item in versions:
            requested = item.get('requested_version', 'unknown')
            installed = item['version'] if item.get('installed') else None
            constrained = requested not in ('latest', 'stable', 'lts', 'unknown')
            permitted = allowed.get(name, {}).get('latest', installed) if check else None
            upstream = latest.get(name, {}).get('latest', installed) if check else None
            status = 'unknown' if installed and not re.search(r'\d', installed) else None
            if installed and re.fullmatch(r'\d+\.\d+\.\d+(?:[-+].+)?', requested) and installed != requested:
                status = 'policy_mismatch'
            rows.append(record('mise', name, installed, requested, upstream, permitted,
                               pinned=constrained, status=status,
                               source=item.get('source', {}).get('path')))
    return rows


def native(ctx, check, manager):
    binary = MANAGERS[manager][0]
    installed = version(ctx.run([binary, '--version'])) if ctx.available(binary) else None
    latest = None
    requested = 'latest'
    note = None
    if manager == 'claude':
        path = ctx.home / '.claude/settings.json'
        if path.exists():
            requested = json.loads(path.read_text()).get('autoUpdatesChannel', 'latest')
        if check:
            latest = ctx.run(['curl', '-fsSL', '--max-time', str(ctx.timeout),
                              'https://downloads.claude.ai/claude-code-releases/latest']).strip()
            allowed = latest if requested == 'latest' else ctx.run(
                ['curl', '-fsSL', '--max-time', str(ctx.timeout),
                 f'https://downloads.claude.ai/claude-code-releases/{requested}']).strip()
        else:
            allowed = None
    elif manager == 'codex':
        marker = ctx.home / '.codex/packages/standalone/auto-update-version'
        if installed and not marker.exists():
            requested = installed
        if check:
            data = ctx.fetch('https://releases.openai.com/codex/channels/latest')
            latest = data.get('version') or data.get('release_version') or data.get('tag_name', '').removeprefix('rust-v') or None
            if latest is None:
                raise Problem('Codex channel metadata has no version')
        allowed = latest
    else:
        if check:
            script = ctx.run(['curl', '-fsSL', '--max-time', str(ctx.timeout), 'https://cursor.com/install'])
            match = re.search(r'https://downloads\.cursor\.com/lab/([^/]+)/', script)
            if match:
                latest = match.group(1)
            else:
                raise Problem('Cursor installer no longer exposes a release version')
        allowed = latest
    pinned = requested not in ('latest', 'stable')
    return [record(manager, binary, installed, requested, latest, installed if pinned else allowed, pinned=pinned, note=note)]


def gh(ctx, check):
    import yaml
    rows = []
    for line in ctx.run(['gh', 'extension', 'list']).splitlines():
        parts = line.split('\t')
        if len(parts) < 3:
            raise Problem('gh extension list returned an unrecognized row')
        _, name, installed, *_ = parts
        root = ctx.data / 'gh/extensions' / name.rsplit('/', 1)[-1]
        manifest = root / 'manifest.yml'
        script = (root / '.git').exists() and not manifest.exists()
        pinned = False
        if manifest.is_file():
            pinned = (yaml.safe_load(manifest.read_text()) or {}).get('ispinned') is True
        elif script:
            installed = ctx.run(['git', '-C', root, 'rev-parse', 'HEAD']).strip()
            pinned = (root / f'.pin-{installed}').exists()
        latest = None
        if check:
            if script:
                latest = remote_head(ctx, root)
            else:
                latest = ctx.json(['gh', 'api', f'repos/{name}/releases/latest'])['tag_name']
        rows.append(record('gh', name, installed, installed if pinned else 'latest', latest,
                           installed if pinned else latest, pinned=pinned))
    return rows


def remote_head(ctx, path, ref='HEAD'):
    out = ctx.run(['git', '-C', path, 'ls-remote', 'origin', ref]).splitlines()
    if not out:
        raise Problem(f'no upstream ref {ref}')
    return out[0].split()[0]


def git_row(ctx, manager, name, path, check):
    if not (path / '.git').exists():
        return record(manager, name, requested='HEAD', path=str(path))
    installed = ctx.run(['git', '-C', path, 'rev-parse', 'HEAD']).strip()
    branch = ctx.run(['git', '-C', path, 'rev-parse', '--abbrev-ref', 'HEAD']).strip()
    detached = branch == 'HEAD'
    latest = remote_head(ctx, path, 'HEAD' if detached else f'refs/heads/{branch}') if check else None
    dirty = bool(ctx.run(['git', '-C', path, 'status', '--porcelain', '--untracked-files=no']).strip())
    return record(manager, name, installed, installed if detached else branch, latest,
                  installed if detached else latest, pinned=detached,
                  note='Tracked local changes present; update will refuse to overwrite them.' if dirty else None,
                  path=str(path), dirty=dirty)


def zinit(ctx, check):
    root = ctx.data / 'zinit/plugins'
    return [git_row(ctx, 'zinit', path.name.replace('---', '/'), path, check)
            for path in sorted(root.iterdir()) if path.is_dir() and not path.name.startswith('_local') and (path / '.git').exists()] if root.exists() else []


def externals(ctx, check):
    data = tomllib.loads(ctx.render('{{ includeTemplate ".chezmoiexternal.toml.tmpl" . }}'))
    return [git_row(ctx, 'externals', name, ctx.home / name, check)
            for name, item in data.items() if item.get('type') == 'git-repo']


def apm(ctx, check):
    import yaml
    root = ctx.repo / 'agent-marketplace'
    manifest = yaml.safe_load((root / 'apm.yml').read_text())
    declarations = {apm_identity(d): d for d in manifest.get('devDependencies', {}).get('apm', [])}
    lock = yaml.safe_load((root / 'apm.lock.yaml').read_text())
    refs = {}
    rows = []
    for item in lock.get('dependencies', []):
        repo = apm_identity(item['repo_url'])
        identity = repo + ('/' + item['virtual_path'] if item.get('virtual_path') else '')
        declaration = declarations.get(identity, identity)
        requested = declaration.partition('#')[2] or 'HEAD'
        latest = None
        allowed = None
        if check:
            if repo not in refs:
                out = ctx.run(['git', 'ls-remote', 'https://github.com/' + repo + '.git', 'HEAD'])
                if not out.strip():
                    raise Problem(f'cannot resolve {repo}')
                refs[repo] = out.split()[0]
            latest = refs[repo]
            allowed = item['resolved_commit'] if requested != 'HEAD' else latest
        rows.append(record('apm', identity, item['resolved_commit'], requested, latest, allowed,
                           pinned=requested != 'HEAD', direct=identity in declarations,
                           note='Upstream default-branch commit; lock is the accepted source revision.'))
    return rows


def mas(ctx, check):
    inventory = ctx.run(['mas', 'list'])
    changes = ctx.run(['mas', 'outdated']) if check else ''
    updates = {}
    for line in changes.splitlines():
        match = re.match(r'\s*(\d+)\s+(.+)\s+\((.+?)\s*->\s*(.+?)\)', line)
        if match:
            updates[match[1]] = match[4]
        elif line.strip():
            raise Problem('mas outdated returned an unrecognized row')
    rows = []
    for line in inventory.splitlines():
        match = re.match(r'\s*(\d+)\s+(.+)\s+\(([^)]+)\)', line)
        if not match:
            if line.strip():
                raise Problem('mas list returned an unrecognized row')
            continue
        name, title, installed = match.groups()
        latest = updates.get(name, installed) if check else None
        rows.append(record('mas', name, installed, 'latest compatible', latest, latest, title=title.strip(),
                           note='App Store compatible release, not necessarily newest on a newer macOS.'))
    return rows


def setapp(ctx, check):
    catalog = {}
    if check:
        data = ctx.fetch('https://store.setapp.com/store/api/v8/en')
        for vendor in data['data']['relationships']['vendors']['data']:
            for app in vendor.get('relationships', {}).get('applications', {}).get('data', []):
                versions = app.get('relationships', {}).get('versions', {}).get('data', [])
                if versions:
                    attrs = versions[0].get('attributes', {})
                    catalog[app['attributes']['name']] = attrs.get('marketing_version')
    rows = []
    roots = (Path('/Applications/Setapp'), ctx.home / 'Applications/Setapp')
    names = set(ctx.declared('setapp_apps')) | {p.stem for root in roots for p in root.glob('*.app')}
    for name in sorted(names):
        if '/' in name or name in ('.', '..'):
            raise Problem('invalid Setapp app name')
        path = next((p for p in (Path('/Applications/Setapp') / f'{name}.app',
                                ctx.home / 'Applications/Setapp' / f'{name}.app') if p.exists()), None)
        installed = None
        if path:
            with (path / 'Contents/Info.plist').open('rb') as handle:
                installed = plistlib.load(handle).get('CFBundleShortVersionString')
        latest = catalog.get(name)
        rows.append(record('setapp', name, installed, 'vendor', latest, latest,
                           path=str(path) if path else None,
                           note='Setapp owns app updates and licensing.'))
    return rows


def xcode(ctx, check):
    pin = json.loads((ctx.source / 'dot_agents/state/ios-triple.json').read_text())['xcode_version']
    installed = ctx.run(['xcodes', 'installed']).strip()
    selected = None
    if installed and ctx.available('xcodebuild'):
        try:
            output = ctx.run(['xcodebuild', '-version'])
        except Problem:
            output = ''
        match = re.search(r'^Xcode (.+)$', output, re.M)
        selected = match[1] if match else None
    latest = None
    if check:
        candidates = re.findall(r'^\s*(\d+(?:\.\d+)+)\s+\(', ctx.run(['xcodes', 'list', '--no-color']), re.M)
        if candidates:
            latest = max(candidates, key=lambda v: tuple(map(int, v.split('.'))))
    return [record('xcode', 'Xcode', selected if installed else None, pin, latest, pin,
                   pinned=True, status='unknown' if installed and not selected else 'policy_mismatch' if selected and selected != pin else None,
                   note='Xcode bundles are installed, but the active selection could not be determined.' if installed and not selected
                   else 'Latest stable in xcodes catalog; OS compatibility is checked by the installer.')]


def tree_digest(path):
    result = hashlib.sha256()
    for item in sorted(path.rglob('*')):
        relative = item.relative_to(path)
        if any(part in ('node_modules', '.git', 'dist') for part in relative.parts) or not item.is_file():
            continue
        result.update(str(relative).encode())
        result.update(item.read_bytes())
    return result.hexdigest()


def raycast(ctx, check):
    root = ctx.data / 'raycast-extensions'
    source = ctx.source / 'dot_local/share/raycast-extensions'
    names = {p.parent.name for directory in (source, root) for p in directory.glob('*/package.json')}
    rows = []
    for name in sorted(names):
        path = root / name
        deployed = (path / 'package.json').is_file()
        manifest = (path if deployed else source / name) / 'package.json'
        data = json.loads(manifest.read_text())
        desired = tree_digest(manifest.parent)
        stamp = ctx.state / 'builds' / f'raycast-{path.name}.json'
        built = json.loads(stamp.read_text()).get('digest') if deployed and stamp.exists() else None
        dependencies = []
        if check and deployed:
            outdated = ctx.json(['npm', 'outdated', '--json'], cwd=path, allowed_exit=(0, 1))
            if 'error' in outdated:
                raise Problem('npm dependency check failed')
            for dependency, info in outdated.items():
                requested = next((data.get(section, {}).get(dependency) for section in ('dependencies', 'devDependencies', 'optionalDependencies') if dependency in data.get(section, {})), None)
                dependencies.append(dict(name=dependency, installed=info.get('current'), requested=requested, latest_allowed=info.get('wanted'), latest=info.get('latest')))
        build_status = 'missing' if not deployed else 'unknown' if built is None else 'current' if built == desired else 'update_available'
        rows.append(record('raycast', path.name, built, 'package-lock.json', desired if check else None,
                           desired if check else None, pinned=True, path=str(path), dependencies=dependencies, build_status=build_status,
                           status='pinned_outdated' if dependencies else build_status,
                           note='Build source digest; dependency updates use npm and require rebuilding.'))
    return rows


def swift(ctx, check):
    rows = []
    policy_path = ctx.source / '.chezmoidata/package_policy.toml'
    policy = tomllib.loads(policy_path.read_text()).get('package_policy', {}).get('swift', {}) if policy_path.exists() else {}
    for name in ('mic', 'keymap-overlay'):
        source = ctx.source / f'.chezmoiassets/{name}.swift'
        desired = hashlib.sha256(source.read_bytes()).hexdigest()
        target = ctx.home / '.local/bin' / name
        stamp = ctx.state / 'builds' / f'swift-{name}.json'
        receipt = json.loads(stamp.read_text()) if stamp.exists() else {}
        built = receipt.get('digest') if target.exists() and receipt.get('binary') == hashlib.sha256(target.read_bytes()).hexdigest() else None
        rows.append(record('swift', name, built, 'dotfiles source', desired if check else None,
                           desired if check else None, path=str(target), enabled=policy.get(name, True),
                           status='missing' if not target.exists() else 'unknown' if built is None else 'current' if built == desired else 'update_available',
                           note='Source/binary receipt; pre-existing binaries without a receipt are unknown.'))
    return rows


def inventory(ctx, manager, check=True):
    if manager in ('claude', 'codex', 'cursor'):
        return native(ctx, check, manager)
    providers = {'brew': brew, 'mise': mise, 'gh': gh, 'zinit': zinit, 'externals': externals,
                 'apm': apm, 'mas': mas, 'setapp': setapp, 'xcode': xcode, 'raycast': raycast, 'swift': swift}
    return providers[manager](ctx, check)
