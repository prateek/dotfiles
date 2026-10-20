"""Native inventories normalized to a single package record."""
from pathlib import Path
import hashlib
import json
import plistlib
import re
import tomllib

from core import APM_CLI, Problem, apm_identity, record, version

MANAGERS = {
    'brew': ('brew', 'Homebrew formulae, casks and fork builds'),
    'mise': ('mise', 'Machine runtimes and npm/pipx/GitHub CLI backends'),
    'claude': ('claude', 'Claude Code native installation'),
    'codex': ('codex', 'Codex standalone installation'),
    'cursor': ('cursor-agent', 'Cursor agent native installation'),
    'gh': ('gh', 'GitHub CLI extensions'),
    'pi': ('pi', 'Pi agent packages'),
    'zinit': ('zsh', 'Shell plugins'),
    'apm': ('uv', 'Agent marketplace dependencies and its locked apm-cli'),
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
    'pi': 'Declarations are the pi entry in agents.toml; pins are source @version/@ref suffixes. Local-path packages have no comparable version.',
    'zinit': 'Simple zinit light declarations support install/remove and ver pins. Complex custom ice declarations require source edits.',
    'apm': 'Updates acquire the entire shared graph, then require source/patch/version review before materialization. apm:apm-cli follows agent-marketplace/uv.lock and updates on its own.',
    'mas': 'App Store compatible releases; no version pin API. App Store authentication may be required.',
    'setapp': 'Install/remove are integrated; updates use the signed Setapp client. No version pin API.',
    'xcode': 'Pin/install/select via xcodes. Latest may need a newer macOS. Runtime/device policy requires review after a version change.',
    'raycast': 'Install/rebuild declared extension sources; latest bumps dependency declarations. Removal requires explicit source changes and removal of the imported bundle in Raycast.',
    'externals': 'Refresh/update declared Git checkouts. Add/remove/ref changes belong to the owning chezmoi external declaration.',
    'swift': 'Build/remove the declared helpers. Versions are source/binary digests; no independent release pin.',
}


def add_declarations(rows, declarations, manager, **extra):
    by_name = {row['name']: row for row in rows}
    for name, item in declarations.items():
        lookup = name.removeprefix('homebrew/core/').removeprefix('homebrew/cask/') if manager == 'brew' else name
        row = by_name.get(lookup)
        if row is not None and extra.get('kind') and row.get('kind') != extra['kind']:
            row = None
        if row is None:
            matches = [candidate for candidate in rows if candidate['name'].split('/')[-1] == lookup
                       and (not extra.get('kind') or candidate.get('kind') == extra['kind'])]
            row = matches[0] if len(matches) == 1 else None
        if row is not None:
            row['declared'] = True
        else:
            rows.append(record(manager, lookup, requested='latest', declared=True,
                               note='Declared for this machine but not installed.', **extra))


def brew(ctx, check, names=None, include_declared=True):
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
    if include_declared:
        for section, kind in (('brews', 'formula'), ('casks', 'cask')):
            declared = ctx.brew_declarations()[section]
            add_declarations(rows, declared, 'brew', kind=kind, installed_on_request=True,
                             auto_updates=False, version_latest=False)
    return rows


def mise(ctx, check, names=None, include_declared=True):
    inventory = ctx.json(['mise', 'ls', '--global', '--json'])
    allowed = ctx.json(['mise', 'outdated', '--json']) if check else {}
    latest = ctx.json(['mise', 'outdated', '--bump', '--json']) if check else {}
    rows = []
    for name, versions in inventory.items():
        if names is not None and name not in names:
            continue
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


def native(ctx, check, manager, names=None, include_declared=True):
    binary = MANAGERS[manager][0]
    installed = version(ctx.run([binary, '--version'])) if ctx.available(binary) else None
    enabled = binary in ctx.features()['agent_clis']
    if not installed and not enabled:
        return [record(manager, binary, requested=None, status='disabled', enabled=False, declared=False,
                       note='Not selected for this machine.')]
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
    return [record(manager, binary, installed, requested, latest, installed if pinned else allowed, pinned=pinned, note=note,
                   enabled=enabled or bool(installed), declared=enabled)]


def gh(ctx, check, names=None, include_declared=True):
    import yaml
    rows = []
    for line in ctx.run(['gh', 'extension', 'list']).splitlines():
        parts = line.split('\t')
        if len(parts) < 3:
            raise Problem('gh extension list returned an unrecognized row')
        _, name, installed, *_ = parts
        if names is not None and name not in names:
            continue
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
    if include_declared:
        add_declarations(rows, ctx.declared('gh_extensions'), 'gh')
    return rows


def pi_source(entry):
    """Split a pi package source into pi's identity (npm name or git URL) and its pin."""
    source = entry.get('source', '') if isinstance(entry, dict) else str(entry)
    if source.startswith('npm:'):
        name = source[4:]
        at = name.find('@', 1)
        return ('npm:' + name[:at], name[at + 1:]) if at > 0 else (source, None)
    if source.startswith(('git:', 'http://', 'https://', 'ssh://', 'git@')):
        head, slash, tail = source.rpartition('/')
        repo, _, ref = tail.partition('@')
        return head + slash + repo, ref or None
    return source, None


def pi_declared(ctx):
    catalogue = tomllib.loads((ctx.source / '.chezmoidata/agents.toml').read_text())['agents']
    return list(catalogue.get('pi', {}).get('packages', []))


def pi(ctx, check, names=None, include_declared=True):
    settings_path = ctx.home / '.pi/agent/settings.json'
    configured = json.loads(settings_path.read_text()).get('packages', []) if settings_path.exists() else []
    declared = pi_declared(ctx) if include_declared else []
    enabled = 'pi' in ctx.features()['agent_clis']
    entries = {}
    for entry in [*declared, *configured]:
        identity, pin = pi_source(entry)
        entries.setdefault(identity, pin)
    declared_ids = {pi_source(entry)[0] for entry in declared}
    rows = []
    for identity, pin in entries.items():
        if names is not None and identity not in names:
            continue
        installed = latest = None
        note = None
        if identity.startswith('npm:'):
            manifest = ctx.home / '.pi/agent/npm/node_modules' / identity[4:] / 'package.json'
            installed = json.loads(manifest.read_text()).get('version') if manifest.is_file() else None
            if check:
                latest = ctx.json(['npm', 'view', identity[4:], 'version', '--json'], cwd=ctx.home)
        elif identity.startswith(('git:', 'http://', 'https://', 'ssh://', 'git@')):
            host_path = re.sub(r'^(git:|https?://|ssh://)(git@)?', '', identity).replace(':', '/').removesuffix('.git')
            checkout = ctx.home / '.pi/agent/git' / host_path
            if (checkout / '.git').exists():
                installed = ctx.run(['git', '-C', checkout, 'rev-parse', 'HEAD']).strip()
                latest = remote_head(ctx, checkout) if check else None
        else:
            installed = identity
            note = 'Local path package; pi loads it in place, so there is no comparable version.'
        status = 'unknown' if note else None
        if identity.startswith('npm:') and pin and installed and re.fullmatch(r'\d+\.\d+\.\d+\S*', pin) and installed != pin:
            status = 'policy_mismatch'
        if not enabled and not installed:
            status = 'disabled'
        rows.append(record('pi', identity, installed, pin or 'latest', latest, installed if pin else latest,
                           pinned=bool(pin), status=status, note=note, declared=identity in declared_ids,
                           enabled=enabled, source=identity + ('@' + pin if pin else '')))
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


def zinit(ctx, check, names=None, include_declared=True):
    root = ctx.data / 'zinit/plugins'
    paths = {path.name.replace('---', '/'): path for path in root.iterdir()
             if path.is_dir() and not path.name.startswith('_local') and (path / '.git').exists()} if root.exists() else {}
    declarations = set()
    if include_declared:
        source = ctx.source / 'dot_config/zsh/zinit-init.zsh'
        if source.exists():
            declarations = set(re.findall(r'^zinit light ([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)\s*$', source.read_text(), re.M))
        for name in declarations:
            paths.setdefault(name, root / name.replace('/', '---'))
    rows = []
    for name, path in sorted(paths.items()):
        if names is not None and name not in names:
            continue
        try:
            rows.append(git_row(ctx, 'zinit', name, path, check) | {'declared': name in declarations})
        except Problem as exc:
            raise Problem(f'zinit:{name}: {exc}') from exc
    return rows


def externals(ctx, check, names=None, include_declared=True):
    data = tomllib.loads(ctx.render('{{ includeTemplate ".chezmoiexternal.toml.tmpl" . }}'))
    rows = []
    for name, item in data.items():
        if item.get('type') != 'git-repo' or (names is not None and name not in names):
            continue
        try:
            rows.append(git_row(ctx, 'externals', name, ctx.home / name, check) | {'declared': True})
        except Problem as exc:
            raise Problem(f'externals:{name}: {exc}') from exc
    return rows


def apm(ctx, check, names=None, include_declared=True):
    import yaml
    root = ctx.repo / 'agent-marketplace'
    manifest = yaml.safe_load((root / 'vendor/apm.yml').read_text())
    declarations = {apm_identity(d): d for d in manifest.get('devDependencies', {}).get('apm', [])}
    lock = yaml.safe_load((root / 'vendor/apm.lock.yaml').read_text())
    refs = {}
    rows = []
    for item in lock.get('dependencies', []):
        repo = apm_identity(item['repo_url'])
        identity = repo + ('/' + item['virtual_path'] if item.get('virtual_path') else '')
        if names is not None and identity not in names:
            continue
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
    if names is None or APM_CLI in names:
        rows.extend(apm_cli(ctx, root, check))
    return rows


APM_CLI_REQUIREMENT = re.compile(r'\s*(?P<name>[A-Za-z0-9][A-Za-z0-9._-]*)\s*(?P<extras>\[[^\]]*\])?'
                                 r'\s*(?P<specifier>[^;]*?)\s*(?P<marker>;.*)?$')


def apm_cli_requirement(root):
    """The apm-cli entry in the marketplace's project dependencies, split into PEP 508 parts."""
    project = tomllib.loads((root / 'pyproject.toml').read_text())['project']
    for index, dependency in enumerate(project.get('dependencies', [])):
        parts = APM_CLI_REQUIREMENT.match(dependency)
        if parts and parts['name'].lower().replace('_', '-') == APM_CLI:
            return dict(parts.groupdict(), index=index, requirement=dependency,
                        requires_python=project.get('requires-python', ''))
    return None


def apm_cli_resolve(ctx, root, requirement, requires_python):
    """Newest release satisfying a requirement, resolved for the build's interpreter."""
    floor = re.search(r'(?:>=|~=|==)\s*(\d+\.\d+)', requires_python)
    argv = ['uv', 'pip', 'compile', '-', '--no-deps', '--no-header', '--no-annotate', '--quiet']
    out = ctx.run(argv + (['--python-version', floor.group(1)] if floor else []), cwd=root, input=requirement)
    match = re.search(rf'^{APM_CLI}(?:\[[^\]]*\])?==([^\s;]+)', out, re.M)
    if not match:
        raise Problem(f'cannot resolve {requirement}')
    return match.group(1)


def apm_cli_bounded(specifier):
    return bool(re.search(r'==|<|~=|!=', specifier))


def apm_cli(ctx, root, check):
    if not (root / 'pyproject.toml').exists():
        return []
    parts = apm_cli_requirement(root)
    if parts is None:
        return []
    specifier = parts['specifier']
    lock = root / 'uv.lock'
    packages = tomllib.loads(lock.read_text()).get('package', []) if lock.exists() else []
    installed = next((p['version'] for p in packages if p.get('name') == APM_CLI), None)
    latest = allowed = None
    if check:
        latest = apm_cli_resolve(ctx, root, APM_CLI, parts['requires_python'])
        allowed = apm_cli_resolve(ctx, root, parts['requirement'], parts['requires_python']) if apm_cli_bounded(specifier) else latest
    return [record('apm', APM_CLI, installed, specifier or 'any', latest, allowed,
                   pinned=apm_cli_bounded(specifier), direct=True,
                   note='Marketplace build tool; uv.lock is the accepted version.')]


def mas(ctx, check, names=None, include_declared=True):
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
    if include_declared:
        declarations = ctx.brew_declarations()['mas']
        add_declarations(rows, declarations, 'mas')
        for row in rows:
            row.setdefault('title', declarations.get(row['name'], {}).get('name', row['name']))
    return rows


def setapp(ctx, check, names=None, include_declared=True):
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
    app_names = set(ctx.declared('setapp_apps')) | {p.stem for root in roots for p in root.glob('*.app')}
    for name in sorted(app_names):
        if names is not None and name not in names:
            continue
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


def xcode(ctx, check, names=None, include_declared=True):
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
                   pinned=True, present=bool(installed), status='unknown' if installed and not selected else 'policy_mismatch' if selected and selected != pin else None,
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


def raycast(ctx, check, names=None, include_declared=True):
    root = ctx.data / 'raycast-extensions'
    source = ctx.source / 'dot_local/share/raycast-extensions'
    app_names = {p.parent.name for directory in (source, root) for p in directory.glob('*/package.json')}
    rows = []
    for name in sorted(app_names):
        if names is not None and name not in names:
            continue
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
                           desired if check else None, pinned=True, path=str(path), present=deployed, dependencies=dependencies, build_status=build_status,
                           status='pinned_outdated' if dependencies else build_status,
                           note='Build source digest; dependency updates use npm and require rebuilding.'))
    return rows


def swift(ctx, check, names=None, include_declared=True):
    rows = []
    policy_path = ctx.source / '.chezmoidata/package_policy.toml'
    policy = tomllib.loads(policy_path.read_text()).get('package_policy', {}).get('swift', {}) if policy_path.exists() else {}
    for name in ('mic', 'keymap-overlay'):
        if names is not None and name not in names:
            continue
        source = ctx.source / f'.chezmoiassets/{name}.swift'
        desired = hashlib.sha256(source.read_bytes()).hexdigest()
        target = ctx.home / '.local/bin' / name
        stamp = ctx.state / 'builds' / f'swift-{name}.json'
        receipt = json.loads(stamp.read_text()) if stamp.exists() else {}
        built = receipt.get('digest') if target.exists() and receipt.get('binary') == hashlib.sha256(target.read_bytes()).hexdigest() else None
        rows.append(record('swift', name, built, 'dotfiles source', desired if check else None,
                           desired if check else None, path=str(target), enabled=policy.get(name, True), declared=policy.get(name, True), present=target.exists(),
                           status='disabled' if not policy.get(name, True) and not target.exists() else 'missing' if not target.exists() else 'unknown' if built is None else 'current' if built == desired else 'update_available',
                           note='Source/binary receipt; pre-existing binaries without a receipt are unknown.'))
    return rows


def inventory(ctx, manager, check=True, names=None, include_declared=True):
    try:
        if manager in ('claude', 'codex', 'cursor'):
            rows = native(ctx, check, manager, names, include_declared)
        else:
            providers = {'brew': brew, 'mise': mise, 'gh': gh, 'pi': pi, 'zinit': zinit, 'externals': externals,
                         'apm': apm, 'mas': mas, 'setapp': setapp, 'xcode': xcode, 'raycast': raycast, 'swift': swift}
            rows = providers[manager](ctx, check, names, include_declared)
        return [row for row in rows if names is None or row['name'] in names]
    except (AttributeError, IndexError, KeyError, TypeError) as exc:
        raise Problem(f'{manager}: unexpected inventory response or configuration shape ({type(exc).__name__}); run the native inventory command to inspect it') from exc
