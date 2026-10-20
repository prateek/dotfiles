"""Reviewable operation plans. Planning never runs a package mutation."""
from __future__ import annotations

import difflib
import json
from pathlib import Path
import re
import shlex
import shutil
import tempfile
import time
import tomllib

from core import APM_CLI, Problem, apm_identity, atomic_write, digest
from providers import MANAGERS, apm_cli_requirement, apm_cli_resolve, inventory, pi_source, tree_digest
from privileges import privilege
from contracts import validate_operation


class Plan:
    def __init__(self, manager, action):
        self.manager, self.action = manager, action
        self.steps = []
        self.edits = {}
        self.edited_paths = set()
        self.notes = []
        self.outcomes = []
        self.source_outcomes = {}
        self.names = []

    def command(self, *argv, cwd=None, env=None):
        self.steps.append(dict(type='command', argv=[str(x) for x in argv],
                               cwd=str(cwd) if cwd else None, env=env or {}))

    def text(self, path):
        path = Path(path)
        return self.edits[str(path)]['after'] if str(path) in self.edits else path.read_text() if path.exists() else ''

    def edit(self, path, after):
        path = Path(path)
        before = path.read_text() if path.exists() else ''
        self.edits[str(path)] = dict(before=before, after=after, exists=path.exists())
        self.edited_paths.add(str(path))

    def toml(self, path, mutate):
        import tomlkit
        data = tomlkit.parse(self.text(path))
        mutate(data)
        self.edit(path, tomlkit.dumps(data))

    def document(self):
        edits = []
        for path, change in self.edits.items():
            if path not in self.edited_paths or change['before'] == change['after']:
                continue
            edits.append(dict(path=path, diff=''.join(difflib.unified_diff(
                change['before'].splitlines(True), change['after'].splitlines(True),
                fromfile=path, tofile=path))))
        return dict(manager=self.manager, action=self.action, edits=edits, steps=[dict(step, privilege=privilege(self.manager, step)) for step in self.steps], notes=self.notes)

    def commit_edits(self):
        for path, change in self.edits.items():
            current = Path(path).read_text() if Path(path).exists() else ''
            if current != change['before'] or Path(path).exists() != change['exists']:
                raise Problem(f'source changed while planning: {path}; retry')
        for path, change in self.edits.items():
            if not change['exists'] or change['before'] != change['after']:
                atomic_write(path, change['after'])
                self.source_outcomes[path] = 'applied'

    def execute(self, ctx):
        (ctx.state / f'{self.manager}.json').unlink(missing_ok=True)
        self.outcomes = [dict(status='not_started') for _ in self.steps]
        for step, outcome in zip(self.steps, self.outcomes):
            try:
                self.execute_step(ctx, step, outcome)
                outcome['status'] = 'manual' if step['type'] == 'manual' else 'completed'
            except (Problem, OSError, ValueError, KeyError, TypeError) as exc:
                outcome.update(status='failed', error=str(exc))
                raise

    def execute_step(self, ctx, step, outcome):
        if step['type'] == 'command':
            ctx.run(step['argv'], cwd=step['cwd'], env=step['env'], write=True)
        elif step['type'] == 'quarantine':
            source = Path(step['path'])
            if source.exists() or source.is_symlink():
                destination = ctx.state / 'removed' / f'{time.time_ns()}-{source.name}'
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.move(str(source), destination)
                outcome['destination'] = str(destination)
        elif step['type'] == 'installer':
            with tempfile.TemporaryDirectory(prefix='dotpkgs-installer-') as scratch:
                path = Path(scratch) / 'install.sh'
                ctx.run(['curl', '-fsSL', '--max-time', '60', step['url'], '-o', path], write=True)
                ctx.run([step['shell'], path, *step.get('args', [])], env=step['env'], write=True)
        elif step['type'] == 'manual':
            return
        elif step['type'] == 'receipt':
            path = Path(step['source'])
            value = tree_digest(path) if path.is_dir() else digest(path)
            data = {'digest': value}
            if step.get('binary'):
                data['binary'] = digest(step['binary'])
            atomic_write(ctx.state / 'builds' / step['name'], json.dumps(data) + '\n')


def apply_target(plan, ctx, path, *, directory=False):
    flags = ['--parent-dirs', '--recursive'] if directory else []
    plan.command('chezmoi', '-S', ctx.source, 'apply', '--exclude=scripts', *flags, path)


def hook(plan, ctx, pattern):
    matches = list((ctx.source / '.chezmoiscripts').glob(pattern))
    if len(matches) != 1:
        raise Problem(f'expected one installation hook matching {pattern}')
    plan.command('chezmoi', '-S', ctx.source, 'apply', '--include=scripts', '--source-path', matches[0])


def edit_package(plan, ctx, section, name, remove=False, group=None):
    if section == 'setapp_apps' and ('/' in name or name in ('.', '..')):
        raise Problem('Setapp requires a catalog display name, not a path')
    path = ctx.source / '.chezmoidata/packages.toml'
    def mutate(data):
        groups = data['packages']['groups']
        selected = list(ctx.groups())
        owners = [key for key in selected if any(str(v.get('id', v['name'])) == name for v in groups[key].get(section, []))]
        fork_owners = [key for key in selected if section in ('brews', 'casks') and any(v['name'] == name for v in groups[key].get('entries', []))]
        if remove:
            for key in fork_owners:
                groups[key]['entries'] = [v for v in groups[key]['entries'] if v['name'] != name]
            for key in owners:
                groups[key][section] = [v for v in groups[key][section] if str(v.get('id', v['name'])) != name]
            if not owners and not fork_owners:
                plan.notes.append(f'{name} has no selected package declaration; removing installed copy only.')
        elif not owners and not fork_owners:
            if group == 'forks':
                raise Problem('declare fork replacements through fork-lifecycle-entry before installing them')
            if group not in selected:
                raise Problem('new declarations require --group naming a selected package group: ' + ', '.join(selected))
            import tomlkit
            entry = tomlkit.inline_table()
            entry.update({'name': name})
            if section == 'mas':
                entry['id'] = int(name)
            groups[group].setdefault(section, []).append(entry)
    plan.toml(path, mutate)


def mise_edit(plan, ctx, row, requested=None, remove=False):
    target = row.get('source')
    if not target:
        raise Problem(f'no configuration owner for {row["name"]}')
    target = Path(target)
    try:
        path = ctx.source_path(target)
    except Problem:
        # Host-local mise config is an established unmanaged override surface.
        if target.parent != ctx.config / 'mise/conf.d' or target.name != 'zz-local.toml':
            raise Problem(f'{target} is not a managed or supported host-local mise file')
        if remove:
            raise Problem(f'{row["name"]}: cannot safely remove a host-local override; inspect and remove its underlying declarations before uninstalling')
        path = target
    text = plan.text(path)
    name = row['name']
    if path.suffix != '.tmpl':
        def mutate(data):
            tools = data.setdefault('tools', {})
            if remove:
                tools.pop(name, None)
            elif isinstance(tools.get(name), dict):
                tools[name]['version'] = requested
            else:
                tools[name] = requested
        plan.toml(path, mutate)
    else:
        # Literal entries coexist with Go template control flow. Edit only a
        # uniquely identified TOML assignment, preserving comments and options.
        pattern = re.compile(r'^(?:' + re.escape(json.dumps(name)) + '|' + re.escape(name) + r')\s*=\s*(.+)$', re.M)
        matches = list(pattern.finditer(text))
        if len(matches) != 1:
            catalogue = ctx.source / '.chezmoidata/agents.toml'
            agents = tomllib.loads(plan.text(catalogue))['agents']
            owner = next((key for key, entry in agents.items() if entry.get('mise') == name), None)
            if not owner:
                raise Problem(f'{name} is an agent adapter; change its parent agent declaration rather than removing a required adapter')
            if remove:
                agent_selection(plan, ctx, owner, True)
            else:
                plan.toml(catalogue, lambda data: data['agents'][owner].__setitem__('version', requested))
            apply_target(plan, ctx, target)
            return
        match = matches[0]
        if remove:
            updated = text[:match.start()] + text[match.end():]
        else:
            value = match[1]
            if value.startswith('{'):
                value, count = re.subn(r'(\bversion\s*=\s*)"[^"]*"', lambda m: m[1] + json.dumps(requested), value, count=1)
            else:
                value, count = re.subn(r'^"[^"]*"', lambda _: json.dumps(requested), value, count=1)
            if count != 1:
                raise Problem(f'cannot safely edit version assignment for {name}')
            updated = text[:match.start(1)] + value + text[match.end(1):]
        plan.edit(path, updated)
    if path != target:
        apply_target(plan, ctx, target)


def brew_plan(plan, ctx, action, names, latest, version, group, rows):
    by_name = {r['name']: r for r in rows}
    if action == 'update':
        plan.command('brew', 'update')
        selected = [by_name[n] for n in names]
        batches = {'formula': [], 'cask': []}
        for row in selected:
            if row['status'] == 'missing':
                plan.notes.append(f'{row["name"]}: missing; use dotpkgs install brew:{row["name"]} to install it')
                continue
            if row['pinned'] and not latest:
                plan.notes.append(f'{row["name"]}: held by Homebrew pin')
                continue
            if not latest and row['kind'] == 'cask' and (row['auto_updates'] or row['version_latest']):
                plan.notes.append(f'{row["name"]}: excluded by Homebrew normal cask policy; use --latest to include it')
                continue
            if row['pinned']:
                plan.command('brew', 'unpin', row['name'])
            batches[row['kind']].append(row['name'])
        for kind, batch in batches.items():
            if batch:
                argv = ['brew', 'upgrade', '--' + kind]
                if latest and kind == 'cask':
                    argv.append('--greedy')
                plan.command(*argv, *batch)
    else:
        for name in names:
            row = by_name.get(name, {})
            kind = row.get('kind', plan.kind or 'formula')
            section = 'casks' if kind == 'cask' else 'brews'
            if action in ('install', 'remove'):
                edit_package(plan, ctx, section, name, action == 'remove', group)
                plan.command('brew', 'install' if action == 'install' else 'uninstall', '--' + kind, name)
            elif action in ('pin', 'unpin'):
                if version:
                    raise Problem('Homebrew pin holds the installed version; use a versioned formula to select another release')
                plan.command('brew', action, name)


def mise_plan(plan, ctx, action, names, latest, version, group, rows):
    by_name = {r['name']: r for r in rows}
    for name in names:
        row = by_name.get(name)
        if action == 'install' and row is not None and version is not None:
            raise Problem(f'{name} is already configured; use pin --version to change its policy')
        if action == 'install' and row is None:
            path = ctx.source / 'dot_config/mise/conf.d/dotpkgs.toml'
            plan.toml(path, lambda data: data.setdefault('tools', {}).__setitem__(name, version or 'latest'))
            apply_target(plan, ctx, ctx.config / 'mise/conf.d/dotpkgs.toml')
            plan.command('mise', 'install', name)
        elif action in ('pin', 'unpin') or (action == 'update' and latest):
            if row is None:
                raise Problem(f'{name} is not configured')
            requested = version if action == 'pin' else 'latest'
            if not requested:
                raise Problem('mise pin requires --version')
            if row['requested'] != requested:
                mise_edit(plan, ctx, row, requested)
            plan.command('mise', 'upgrade', '--no-prune', name) if requested == 'latest' else plan.command('mise', 'install', name)
        elif action == 'remove':
            if row:
                mise_edit(plan, ctx, row, remove=True)
            plan.command('mise', 'uninstall', '--all', name)
        elif action == 'update':
            plan.command('mise', 'upgrade', '--no-prune', name)
        elif action == 'install':
            plan.command('mise', 'install', name)


def agent_selection(plan, ctx, name, remove):
    features = ctx.features()
    host = ctx.render('{{ .chezmoi.hostname }}').strip()
    path = ctx.source / '.chezmoidata/machines.toml'
    staged = tomllib.loads(plan.text(path))
    selected = list(staged.get('machines', {}).get('host', {}).get(host, {}).get('agent_clis', features['agent_clis']))
    if remove:
        selected = [item for item in selected if item != name]
    elif name not in selected:
        selected.append(name)
    plan.toml(path, lambda data:
              data['machines'].setdefault('host', {}).setdefault(host, {}).__setitem__('agent_clis', selected))


def native_plan(plan, ctx, action, names, latest, version, group, rows):
    manager = plan.manager
    binary = MANAGERS[manager][0]
    if names != [binary]:
        raise Problem(f'{manager} package name is {binary}')
    row = rows[0]
    if manager == 'codex' and (action in ('pin', 'unpin') or (action == 'update' and latest and row['pinned'])):
        requested = version if action == 'pin' else 'latest'
        if not requested or not re.fullmatch(r'latest|[0-9]+\.[0-9]+\.[0-9]+(?:-(?:alpha|beta)(?:\.[0-9]+){0,2})?', requested):
            raise Problem('Codex pin requires --version x.y.z (or a native alpha/beta release)')
        plan.toml(ctx.source / '.chezmoidata/package_policy.toml', lambda data:
                  data.setdefault('package_policy', {}).setdefault('native', {}).__setitem__('codex', requested))
        plan.steps.append(dict(type='installer', url='https://chatgpt.com/codex/install.sh', shell='sh',
                               args=['--release', requested], env={'CODEX_HOME': str(ctx.home / '.codex'),
                               'CODEX_NON_INTERACTIVE': '1', 'PATH': str(ctx.home / '.local/bin') + ':/usr/bin:/bin:/usr/sbin:/sbin'}))
        return
    if action in ('pin', 'unpin'):
        raise Problem(f'{manager} has no integrated durable pin control; use its native controls through exec (an install version alone does not disable auto-update)')
    if action == 'update' and row['pinned'] and not latest:
        plan.notes.append(f'{binary}: held at {row["requested"]}')
        return
    if action == 'install':
        agent_selection(plan, ctx, binary, False)
        pattern = {'claude': '*06-claude-native*', 'codex': '*07-codex-standalone*', 'cursor': '*07-cursor-agent*'}[manager]
        hook(plan, ctx, pattern)
    elif action == 'remove':
        agent_selection(plan, ctx, binary, True)
        plan.steps.append({'type': 'quarantine', 'path': str(ctx.home / '.local/bin' / binary)})
        if manager == 'cursor':
            plan.steps.append({'type': 'quarantine', 'path': str(ctx.home / '.local/bin/agent')})
        plan.notes.append('Launcher removed reversibly; account configuration and running sessions are preserved. Reconcile agent plugins with chezmoi apply.')
    else:
        if manager == 'claude' and latest:
            plan.command(binary, 'install', 'latest')
            return
        plan.command(binary, 'update', env={'CODEX_HOME': str(ctx.home / '.codex')} if manager == 'codex' else None)


def gh_plan(plan, ctx, action, names, latest, version, group, rows):
    by_name = {row['name']: row for row in rows}
    for name in names:
        if action == 'install':
            edit_package(plan, ctx, 'gh_extensions', name, group=group)
            plan.command('gh', 'extension', 'install', name)
        elif action == 'remove':
            edit_package(plan, ctx, 'gh_extensions', name, True)
            plan.command('gh', 'extension', 'remove', name)
        elif action == 'pin':
            if not version:
                raise Problem('gh pin requires --version (tag or commit)')
            plan.command('gh', 'extension', 'remove', name)
            plan.command('gh', 'extension', 'install', name, '--pin', version)
            plan.notes.append(f'{name}: replacement removes the installed extension first; a failed installation leaves it uninstalled.')
        elif action == 'unpin' or (latest and by_name[name]['pinned']):
            plan.command('gh', 'extension', 'remove', name)
            plan.command('gh', 'extension', 'install', name)
        elif by_name[name]['pinned']:
            plan.notes.append(f'{name}: held by its native gh pin')
        else:
            plan.command('gh', 'extension', 'upgrade', name)


def pi_plan(plan, ctx, action, names, latest, version, group, rows):
    by_name = {row['name']: row for row in rows}
    settings = ctx.home / '.pi/agent/settings.json'

    def declare(identity, source):
        """Set, add, or (source None) drop the pi catalogue entry for one package identity."""
        def mutate(data):
            packages = data['agents']['pi'].setdefault('packages', [])
            index = next((i for i, entry in enumerate(packages) if pi_source(entry)[0] == identity), None)
            if source is None:
                if index is not None:
                    del packages[index]
            elif index is None:
                packages.append(source)
            else:
                packages[index] = source
        plan.toml(ctx.source / '.chezmoidata/agents.toml', mutate)

    for name in names:
        identity, pin = pi_source(name)
        if pin:
            raise Problem(f'{name}: name the package without its pin; use --version')
        row = by_name.get(identity)
        if action == 'install':
            source = identity + ('@' + version if version else '')
            declare(identity, source)
            apply_target(plan, ctx, settings)
            plan.command('pi', 'install', source, '--no-approve')
        elif action == 'remove':
            declare(identity, None)
            plan.command('pi', 'remove', row['source'], '--no-approve')
        elif action == 'pin' or action == 'unpin' or (latest and row['pinned']):
            if action == 'pin' and not version:
                raise Problem('pi pin requires --version (npm version, git tag, or commit)')
            source = identity + ('@' + version if action == 'pin' else '')
            if not row.get('declared'):
                plan.notes.append(f'{identity}: not in the pi catalogue; the pin change adds it as a managed package.')
            declare(identity, source)
            apply_target(plan, ctx, settings)
            plan.command('pi', 'update', source, '--no-approve')
        elif row['pinned']:
            plan.notes.append(f'{identity}: held at {row["requested"]}')
        else:
            plan.command('pi', 'update', row['source'], '--no-approve')


def git_plan(plan, ctx, action, names, latest, version, group, rows):
    by_name = {r['name']: r for r in rows}
    if plan.manager == 'zinit' and action in ('install', 'remove'):
        source = ctx.source / 'dot_config/zsh/zinit-init.zsh'
        text = plan.text(source)
        for name in names:
            if not re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+', name):
                raise Problem('zinit requires owner/repository names')
            pattern = re.compile(r'^zinit light ' + re.escape(name) + r'\s*$', re.M)
            if action == 'install':
                if not pattern.search(text):
                    text += '\nzinit light ' + name + '\n'
                plan.command('zsh', '-fc', 'source "$1"; zinit light "$2"', 'dotpkgs', ctx.data / 'zinit/zinit.git/zinit.zsh', name)
            else:
                match = pattern.search(text)
                if match:
                    start = match.start()
                    previous = text[:start].rstrip('\n').splitlines()[-1:]
                    if previous and previous[0].startswith('zinit ice '):
                        start = text.rfind(previous[0], 0, start)
                    text = text[:start] + text[match.end():]
                plan.command('zsh', '-fc', 'source "$1"; zinit delete --yes "$2"', 'dotpkgs', ctx.data / 'zinit/zinit.git/zinit.zsh', name)
        plan.edit(source, text)
        apply_target(plan, ctx, ctx.config / 'zsh/zinit-init.zsh')
        return
    if plan.manager == 'externals' and action in ('pin', 'unpin'):
        raise Problem('external refs belong to .chezmoiexternal.toml.tmpl; edit its checkout/pull policy before changing the checkout')
    if action == 'install' and plan.manager == 'externals':
        plan.command('chezmoi', '-S', ctx.source, 'apply', '--refresh-externals', '--exclude=scripts', *[ctx.home / n for n in names])
        return
    if action not in ('update', 'pin', 'unpin'):
        raise Problem('Git-managed entries must be added/removed in their owning zinit or chezmoi external declaration; use exec for native operations')
    if plan.manager == 'zinit' and (action in ('pin', 'unpin') or latest):
        source = ctx.source / 'dot_config/zsh/zinit-init.zsh'
        lines = plan.text(source).splitlines()
        for name in names:
            if action == 'update' and not by_name[name]['pinned']:
                continue
            position = next((i for i, line in enumerate(lines) if line == 'zinit light ' + name), None)
            if position is None:
                raise Problem(f'{name}: no simple zinit declaration; edit its ice/version options directly')
            if position and lines[position - 1].startswith('zinit ice '):
                ice = re.sub(r"\s+ver(?:\"[^\"]*\"|'[^']*'|[^\s]+)", '', lines[position - 1])
                if action == 'pin':
                    ice += ' ver' + shlex.quote(version or '')
                lines[position - 1] = ice
            elif action == 'pin':
                lines.insert(position, 'zinit ice ver' + shlex.quote(version or ''))
        plan.edit(source, '\n'.join(lines) + '\n')
        apply_target(plan, ctx, ctx.config / 'zsh/zinit-init.zsh')
    for name in names:
        row = by_name[name]
        if row.get('dirty'):
            raise Problem(f'{name}: local Git changes; update refused')
        path = row['path']
        if action == 'pin':
            if not version:
                raise Problem('Git pin requires --version (tag or commit)')
            plan.command('git', '-C', path, 'fetch', 'origin', version)
            plan.command('git', '-C', path, 'checkout', '--detach', 'FETCH_HEAD')
            if plan.manager == 'zinit':
                plan.command('zsh', '-fc', 'source "$1"; zinit compile "$2"', 'dotpkgs', ctx.data / 'zinit/zinit.git/zinit.zsh', name)
        elif row['pinned'] and not latest and action != 'unpin':
            plan.notes.append(f'{name}: detached revision is held')
        elif plan.manager == 'zinit' and action == 'update' and not row['pinned']:
            root = ctx.data / 'zinit/zinit.git/zinit.zsh'
            plan.command('zsh', '-fc', 'source "$1"; zinit update "$2"', 'dotpkgs', root, name)
        elif row['pinned']:
            plan.command('git', '-C', path, 'fetch', 'origin')
            branch = ctx.run(['git', '-C', path, 'symbolic-ref', '--short', 'refs/remotes/origin/HEAD']).strip().removeprefix('origin/')
            plan.command('git', '-C', path, 'checkout', branch)
            plan.command('git', '-C', path, 'pull', '--ff-only')
        else:
            plan.command('git', '-C', path, 'pull', '--ff-only')


def apm_cli_plan(plan, ctx, root, action, latest, version):
    if action in ('install', 'remove'):
        raise Problem('apm:apm-cli is the marketplace build tool; change agent-marketplace/pyproject.toml to replace it')
    parts = apm_cli_requirement(root)
    if parts is None:
        raise Problem('apm:apm-cli has no requirement in agent-marketplace/pyproject.toml')
    if action == 'pin' and not version:
        raise Problem('apm pin requires --version')
    target = None
    if action == 'pin':
        target = f'=={version}'
    elif action == 'unpin':
        installed = next((r['installed'] for r in inventory(ctx, 'apm', check=False, names=[APM_CLI])), None)
        if not installed:
            raise Problem('apm:apm-cli is not in agent-marketplace/uv.lock; run uv lock before unpinning')
        target = f'>={installed}'
    elif action == 'update' and latest and parts['specifier']:
        newest = apm_cli_resolve(ctx, root, APM_CLI, parts['requires_python'])
        if apm_cli_resolve(ctx, root, parts['requirement'], parts['requires_python']) != newest:
            target = ('==' if parts['specifier'].startswith('==') else '>=') + newest
    if target:
        requirement = parts['name'] + (parts['extras'] or '') + target + ('; ' + parts['marker'][1:].strip() if parts['marker'] else '')
        plan.toml(root / 'pyproject.toml', lambda data: data['project']['dependencies'].__setitem__(parts['index'], requirement))
    plan.command('uv', 'lock', '--upgrade-package', APM_CLI, cwd=root)
    plan.command('uv', 'sync', '--locked', cwd=root)


def apm_plan(plan, ctx, action, names, latest, version, group, rows):
    import yaml
    root = ctx.repo / 'agent-marketplace'
    graph = [name for name in names if name != APM_CLI]
    if len(graph) < len(names):
        if graph and version:
            raise Problem('--version means a PyPI release for apm:apm-cli and a Git ref for graph dependencies; pin them separately')
        apm_cli_plan(plan, ctx, root, action, latest, version)
        if not graph:
            plan.command('just', 'check', cwd=root)
            plan.steps.append(dict(type='manual', instruction='Review the uv.lock change and check result. After acceptance, install an existing apm:dependency ID to rebuild and materialize the marketplace with this apm-cli.'))
            return
    names = graph
    if action == 'update' and set(names) != {r['name'] for r in rows} - {APM_CLI}:
        raise Problem('APM updates the shared graph; use update --all --manager apm')
    if action == 'install' and all(name in {r['name'] for r in rows if r['direct']} for name in names):
        plan.command('just', 'check', cwd=root)
        hook(plan, ctx, '*36-agent-plugins*')
        return
    if action in ('install', 'remove', 'pin', 'unpin') or latest:
        path = root / 'vendor/apm.yml'
        data = yaml.safe_load(plan.text(path))
        deps = data['devDependencies']['apm']
        for name in names:
            found = next((d for d in deps if apm_identity(d) == name), None)
            if found is None and action != 'install':
                if action == 'update':
                    continue
                raise Problem(f'{name}: no direct declaration; change its parent dependency')
            declared_name = found.partition('#')[0] if found else name
            if action == 'remove':
                catalog = root / 'marketplace.toml'
                for plugin, source in tomllib.loads(catalog.read_text())['plugins'].items():
                    if any(apm_identity(entry['dependency']) == name for section in ('skills', 'payloads') for entry in source.get(section, []) if entry.get('dependency')):
                        raise Problem(f'{name} is selected by plugin {plugin} in {catalog}; remove its selections before removing the dependency')
                if found:
                    deps.remove(found)
            elif action == 'pin':
                if not version:
                    raise Problem('apm pin requires --version (tag or commit)')
                deps[deps.index(found)] = declared_name + '#' + version
            elif found:
                deps[deps.index(found)] = declared_name
            else:
                deps.append(name)
        plan.edit(path, yaml.safe_dump(data, sort_keys=False, allow_unicode=True))
    plan.command('just', 'update' if action == 'update' else 'fetch', cwd=root)
    plan.command('just', 'check', cwd=root)
    plan.steps.append(dict(type='manual', instruction='Review acquired lock/cache and any failed patches. After acceptance, install an existing apm:dependency ID to validate and materialize the marketplace. New dependencies also need explicit plugin selections.'))


def app_plan(plan, ctx, action, names, latest, version, group, rows):
    manager = plan.manager
    if action in ('pin', 'unpin'):
        raise Problem(f'{manager} does not support version pins')
    if manager == 'mas':
        by_name = {r['name']: r for r in rows}
        for name in names:
            if not name.isdecimal():
                raise Problem('MAS requires numeric app IDs')
            if action in ('install', 'remove'):
                edit_package(plan, ctx, 'mas', name, action == 'remove', group)
            elif by_name.get(name, {}).get('status') == 'missing':
                plan.notes.append(f'{name}: missing; use dotpkgs install mas:{name} to install it')
                continue
            elif by_name.get(name, {}).get('status') != 'update_available':
                plan.notes.append(f'{name}: no App Store update')
                continue
            plan.command('mas', {'install': 'install', 'remove': 'uninstall', 'update': 'upgrade'}[action], name)
    else:
        if action == 'install':
            for name in names:
                edit_package(plan, ctx, 'setapp_apps', name, group=group)
            hook(plan, ctx, '*22-setapp-apps*')
        elif action == 'remove':
            for name in names:
                edit_package(plan, ctx, 'setapp_apps', name, True)
                row = next((r for r in rows if r['name'] == name), {})
                if row.get('path'):
                    plan.steps.append({'type': 'quarantine', 'path': row['path']})
        else:
            plan.steps.append(dict(type='manual', instruction='Open Setapp and update subscription apps. Its signed client owns updates; there is no supported unattended update API.'))


def npm_json(ctx, argv, empty):
    text = ctx.run(argv).strip()
    if not text:
        return empty
    try:
        return json.loads(text)
    except ValueError as exc:
        raise Problem('npm returned invalid JSON') from exc


VERSION = r'[0-9]+\.[0-9]+\.[0-9]+(?:[-+][A-Za-z0-9.-]+)?'


def version_key(version):
    return tuple(int(part) for part in re.match(r'(\d+)\.(\d+)\.(\d+)', version).groups())


def latest_dependencies(ctx, data):
    """Bump every manifest dependency to its latest release that siblings' required peer ranges permit, never below an exact pin."""
    sections = ('dependencies', 'devDependencies', 'optionalDependencies')
    candidates, pins = {}, {}
    for section in sections:
        for dependency, spec in data.get(section, {}).items():
            if spec.startswith(('file:', 'link:', 'workspace:', 'git', 'npm:', 'http')):
                raise Problem(f'{dependency}: source/alias dependency needs an explicit declaration change')
            resolved = ctx.json(['npm', 'view', dependency, 'version', '--json'])
            if not isinstance(resolved, str) or not re.fullmatch(VERSION, resolved):
                raise Problem(f'{dependency}: npm returned an invalid latest version')
            candidates[dependency] = resolved
            if re.fullmatch(VERSION, spec):
                pins[dependency] = spec
    holders = {}
    for dependency, resolved in candidates.items():
        peers = npm_json(ctx, ['npm', 'view', f'{dependency}@{resolved}', 'peerDependencies', '--json'], {})
        meta = npm_json(ctx, ['npm', 'view', f'{dependency}@{resolved}', 'peerDependenciesMeta', '--json'], {})
        if not isinstance(peers, dict) or not isinstance(meta, dict):
            raise Problem(f'{dependency}: npm returned an unexpected peerDependencies shape')
        for peer, spec in peers.items():
            optional = isinstance(meta.get(peer), dict) and meta[peer].get('optional') is True
            if peer in candidates and isinstance(spec, str) and not optional:
                holders.setdefault(peer, {})[dependency] = spec
    notes = []
    for peer, ranges in sorted(holders.items()):
        permitted = npm_json(ctx, ['npm', 'view', f'{peer}@{" ".join(ranges.values())}', 'version', '--json'], [])
        permitted = [permitted] if isinstance(permitted, str) else permitted
        if not permitted:
            raise Problem(f'{peer}: no release satisfies the peer ranges from {", ".join(sorted(ranges))}')
        if candidates[peer] in permitted:
            continue
        chosen = max(permitted, key=version_key)
        if peer in pins and version_key(chosen) < version_key(pins[peer]):
            candidates[peer] = pins[peer]
            notes.append(f'{peer}: kept at {pins[peer]}; peer ranges from {", ".join(sorted(ranges))} permit at most {chosen}')
        else:
            candidates[peer] = chosen
            notes.append(f'{peer}: held at {chosen} by peer ranges from {", ".join(sorted(ranges))}')
    for section in sections:
        for dependency in data.get(section, {}):
            data[section][dependency] = candidates[dependency]
    return notes


def build_plan(plan, ctx, action, names, latest, version, group, rows):
    if action in ('pin', 'unpin'):
        raise Problem('Build inputs are pinned by Git/package-lock.json; use source control to change the revision')
    if action == 'remove':
        if plan.manager == 'raycast':
            raise Problem('Raycast removal requires an explicit change to its owning source directory; remove the imported extension in Raycast and reconcile its deployed files manually')
        for name in names:
            plan.toml(ctx.source / '.chezmoidata/package_policy.toml', lambda data, n=name:
                      data.setdefault('package_policy', {}).setdefault('swift', {}).__setitem__(n, False))
            plan.steps.append(dict(type='quarantine', path=str(ctx.home / '.local/bin' / name)))
        return
    by_name = {r['name']: r for r in rows}
    for name in names:
        if plan.manager == 'swift':
            if name not in ('mic', 'keymap-overlay'):
                raise Problem('unknown Swift helper')
            if action == 'update' and by_name.get(name, {}).get('status') == 'current':
                plan.notes.append(f'{name}: binary matches its source receipt')
                continue
            plan.toml(ctx.source / '.chezmoidata/package_policy.toml', lambda data, n=name:
                      data.setdefault('package_policy', {}).setdefault('swift', {}).__setitem__(n, True))
            source = ctx.source / f'.chezmoiassets/{name}.swift'
            target = ctx.home / '.local/bin' / name
            plan.command('mkdir', '-p', target.parent)
            plan.command('swiftc', '-O', source, '-o', target)
            plan.steps.append(dict(type='receipt', name=f'swift-{name}.json', source=str(source), binary=str(target)))
        else:
            row = next((r for r in rows if r['name'] == name), None)
            if row is None:
                raise Problem(f'unknown Raycast extension: {name}')
            path = Path(row['path'])
            changed = False
            if latest:
                source = ctx.source / 'dot_local/share/raycast-extensions' / name
                manifest = source / 'package.json'
                before = plan.text(manifest)
                data = json.loads(before)
                plan.notes.extend(latest_dependencies(ctx, data))
                after = json.dumps(data, indent=2) + '\n'
                changed = after != before
                if changed:
                    plan.edit(manifest, after)
                    plan.command('npm', 'install', '--package-lock-only', '--ignore-scripts', cwd=source)
            if action == 'update' and not changed and row.get('build_status') == 'current':
                plan.notes.append(f'{name}: build matches its source receipt')
                continue
            if latest or not (path / 'package.json').is_file():
                apply_target(plan, ctx, path, directory=True)
            plan.command('npm', 'ci', '--omit=dev', cwd=path)
            plan.command('npm', 'exec', '--', 'ray', 'build', '--non-interactive', cwd=path)
            plan.steps.append(dict(type='receipt', name=f'raycast-{name}.json', source=str(path)))


def xcode_plan(plan, ctx, action, names, latest, version, group, rows):
    if action == 'update' and not latest and not version and rows[0]['installed'] == rows[0]['requested']:
        plan.notes.append(f'Xcode {rows[0]["installed"]} already matches the selected policy.')
        return
    if action == 'remove':
        if not version:
            raise Problem('Xcode removal requires --version; the selected policy is unchanged')
        plan.command('xcodes', 'uninstall', version)
        return
    if latest:
        data = inventory(ctx, 'xcode')
        version = data[0]['latest']
        if not version:
            raise Problem('cannot resolve latest stable Xcode')
    if action == 'pin' and not version:
        raise Problem('Xcode pin requires --version')
    path = ctx.source / 'dot_agents/state/ios-triple.json'
    data = json.loads(plan.text(path))
    if version:
        data['xcode_version'] = version
        data.pop('xcode_version_min', None)
        plan.edit(path, json.dumps(data, indent=2) + '\n')
        apply_target(plan, ctx, ctx.home / '.agents/state/ios-triple.json')
    plan.command('xcodes', 'install', version or data['xcode_version'], '--experimental-unxip')
    plan.command('xcodes', 'select', version or data['xcode_version'])
    plan.notes.append('Review iOS runtime/device compatibility in ios-triple.json after changing Xcode; installer may require Apple ID/admin access.')


def make_plan(ctx, manager, action, names, *, latest=False, version=None, group=None, kind=None, edits=None, all_packages=False):
    validate_operation(manager, action, names, version)
    plan = Plan(manager, action)
    plan.edits = dict(edits or {})
    plan.kind = kind
    if manager == 'apm':
        names = [apm_identity(name) for name in names]
    rows = inventory(ctx, manager, check=manager == 'mas' and action == 'update', names=None if manager == 'apm' else names or None)
    if len({r['name'] for r in rows}) != len(rows):
        raise Problem('multiple active versions of one package; select/edit its native configuration explicitly')
    if not names:
        if action != 'update' or not all_packages:
            raise Problem('expanding a manager requires update --all')
        names = [r['name'] for r in rows if r.get('enabled', True)]
    if not names:
        plan.notes.append('No installed or configured packages.')
        return plan
    plan.names = names
    if any(not name or name.startswith('-') or any(c in name for c in '\n\r\t') for name in names):
        raise Problem('invalid package name')
    if action not in ('install',) and manager not in ('xcode',) and any(n not in {r['name'] for r in rows} for n in names):
        raise Problem('package not found; use dotpkgs list to resolve its exact name')
    dispatch = {'brew': brew_plan, 'mise': mise_plan, 'gh': gh_plan, 'pi': pi_plan,
                'zinit': git_plan, 'externals': git_plan, 'apm': apm_plan,
                'mas': app_plan, 'setapp': app_plan, 'raycast': build_plan,
                'swift': build_plan, 'xcode': xcode_plan}
    dispatch.get(manager, native_plan)(plan, ctx, action, names, latest, version, group, rows)
    return plan
