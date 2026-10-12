"""Command validation, inventory selection, and operation orchestration."""
import argparse
from collections import Counter
import json
import sys
import time

from actions import make_plan
from contracts import OPERATIONS, OPERATION_MODES
from core import Context, Problem, apm_identity
from presentation import emit, command_text
from providers import LIMITS, MANAGERS, inventory
from privileges import GUIDANCE, delegated, privilege
from readiness import doctor

ERRORS = (Problem, OSError, ValueError, KeyError, TypeError)
UNRESOLVED = ('unknown', 'missing', 'policy_mismatch')


class Parser(argparse.ArgumentParser):
    def error(self, message):
        raise Problem(message)


def parser():
    common = Parser(add_help=False)
    common.add_argument('--json', action='store_true', default=argparse.SUPPRESS, help='structured output, including errors')
    common.add_argument('--verbose', action='store_true', default=argparse.SUPPRESS, help='show provider limits and execution context')
    common.add_argument('--source', default=argparse.SUPPRESS, help='dotfiles checkout or chezmoi source (default: chezmoi source-path)')
    common.add_argument('--timeout', type=int, default=argparse.SUPPRESS, help='seconds per read-only probe (default: 45)')
    root = Parser(prog='dotpkgs', parents=[common], description='Inspect and manage machine packages through their owning installers.',
                  epilog='Examples: dotpkgs list; dotpkgs outdated; dotpkgs update mise:node --dry-run. ' + GUIDANCE)
    root.add_argument('--version', action='version', version='dotpkgs 1.1.0')
    subs = root.add_subparsers(dest='command', required=True)
    for name, help_text in [('managers', 'show supported operations (--verbose for limits)'), ('doctor', 'check offline executables and source configuration; no authentication/network checks')]:
        subs.add_parser(name, parents=[common], help=help_text)
    for name, help_text in [('list', 'show installed and desired packages without upstream checks'), ('status', 'show counts and packages needing attention'), ('outdated', 'show known updates and unresolved comparisons')]:
        sub = subs.add_parser(name, parents=[common], help=help_text, epilog=f'Example: dotpkgs {name} --manager mise')
        sub.add_argument('--manager', choices=MANAGERS, action='append', help='limit providers; repeatable')
        sub.add_argument('packages', nargs='*', help='manager:name IDs, or names with one --manager')
        if name in ('list', 'status'):
            sub.add_argument('--all', action='store_true', help='show dependencies, disabled packages, and current rows in text')
        if name in ('outdated', 'list'):
            sub.add_argument('--format', choices=('text', 'tsv'), default='text', help='TSV preserves installed-only inventory columns: name, installed, latest, kind, installed_on_request')
        if name == 'status':
            sub.add_argument('--cached', action='store_true', help='read the last complete provider snapshot without probing')
    for name, help_text in [('install', 'install packages and maintain declarations'), ('remove', 'remove packages and declarations'),
                            ('update', 'update selected packages, preserving version policy'), ('pin', 'hold/select a version'), ('unpin', 'follow latest where supported')]:
        sub = subs.add_parser(name, parents=[common], help=help_text, epilog='Use managers for supported operations. Preview changes with --dry-run. ' + GUIDANCE)
        sub.add_argument('--manager', choices=MANAGERS, action='append')
        sub.add_argument('packages', nargs='*', help='exact manager:name IDs, or names with one --manager')
        sub.add_argument('--dry-run', action='store_true', help='preview source changes and execution steps')
        if name == 'update':
            sub.add_argument('--all', action='store_true', help='update all enabled packages in selected providers')
            sub.add_argument('--latest', action='store_true', help='override pins/ranges; include self-updating casks and dependency bumps')
        if name in ('install', 'pin', 'remove'):
            sub.add_argument('--version', dest='requested_version', help='install: mise/Xcode; pin: supported providers; remove: Xcode only')
        if name == 'install':
            sub.add_argument('--group', help='selected package group for new Brew/MAS/Setapp/gh declarations')
            sub.add_argument('--kind', choices=('formula', 'cask'), help='Homebrew kind for a new package')
    sub = subs.add_parser('summary', parents=[common], help='shell-banner protocol (counts TSV and package JSON)')
    sub.add_argument('--manager', choices=MANAGERS, required=True)
    sub = subs.add_parser('exec', parents=[common], help='native passthrough; preserves streams and exit code; --json captures output',
                         usage='dotpkgs exec [options] manager -- native-arguments')
    sub.add_argument('manager', choices=MANAGERS)
    sub.add_argument('--dry-run', action='store_true', help='print the native command without running it')
    return root


def selection(args):
    packages = getattr(args, 'packages', [])
    selected = {} if packages else {m: [] for m in (args.manager or [])}
    for package in packages:
        prefix, sep, suffix = package.partition(':')
        if sep and prefix in MANAGERS:
            if args.manager and prefix not in args.manager:
                raise Problem(f'{package}: outside selected managers')
            selected.setdefault(prefix, []).append(suffix)
        elif len(args.manager or []) == 1:
            selected.setdefault(args.manager[0], []).append(package)
        else:
            raise Problem(f'{package}: use manager:name or one --manager; example: mise:node')
    return {manager: list(dict.fromkeys(names)) for manager, names in (selected or {m: [] for m in MANAGERS}).items()}


def read_result(ctx, args, manager, names):
    if manager == 'apm':
        names = [apm_identity(name) for name in names]
    cached = getattr(args, 'cached', False)
    if not cached and manager not in ('claude', 'codex', 'cursor') and not ctx.available(MANAGERS[manager][0]):
        return dict(manager=manager, status='unavailable', packages=[], reason=f'{MANAGERS[manager][0]} not installed')
    result = dict(manager=manager, status='ok')
    if cached:
        result.update(ctx.cache(manager), cached=True)
        rows = result['packages']
    else:
        rows = inventory(ctx, manager, check=args.command != 'list', names=names or None,
                         include_declared=getattr(args, 'json', False) or getattr(args, 'format', None) != 'tsv')
        if args.command == 'status':
            if not names:
                result.update(ctx.cache(manager, rows))
            else:
                result['checked_at'] = int(time.time())
            result['cached'] = False
    if names:
        missing = set(names) - {row['name'] for row in rows}
        if missing:
            raise Problem('package not found: ' + ', '.join(sorted(missing)) + f'; run dotpkgs list --manager {manager}')
        rows = [row for row in rows if row['name'] in names]
    result['summary'] = dict(Counter(row['status'] for row in rows))
    if args.command == 'outdated':
        result['unresolved'] = [row for row in rows if row['status'] in UNRESOLVED]
        rows = [row for row in rows if row['status'] in ('update_available', 'pinned_outdated')]
    result['packages'] = rows
    return result


def execute_plans(ctx, plans, payload):
    if not plans:
        return
    final_plan = plans[-1][0]
    try:
        final_plan.commit_edits()
    except ERRORS as exc:
        payload.update(ok=False, error=f'Source edits stopped: {exc}. Inspect source_status before retrying.')
    for plan, result in plans:
        paths = [edit['path'] for edit in result['plan']['edits']]
        applied = [path for path in paths if path in final_plan.source_outcomes]
        result['source_status'] = 'applied' if applied == paths and paths else 'partial' if applied else 'unchanged'
        result['applied_sources'] = applied
        if applied:
            (ctx.state / f'{plan.manager}.json').unlink(missing_ok=True)
        result['execution'] = [dict(status='not_started') for _ in plan.steps]
        result.update(status='not_started', reason='An earlier operation failed; native steps were not started.')
    if not payload['ok']:
        return
    for plan, result in plans:
        try:
            plan.execute(ctx)
            result['execution'] = plan.outcomes
            result['status'] = 'manual' if any(s['type'] == 'manual' for s in plan.steps) else 'completed'
            result.pop('reason', None)
            try:
                ctx.refresh_configuration()
                result['observed'] = inventory(ctx, plan.manager, check=False, names=plan.names or None)
                result['verification'] = 'Installed inventory observed after execution; run status for freshness and policy comparisons.'
            except ERRORS as exc:
                result['verification'] = f'Native steps completed; installed inventory could not be verified: {exc}'
            if result['status'] == 'manual':
                payload['ok'] = False
                result['verification'] = 'Manual steps remain; the operation is incomplete.'
        except ERRORS as exc:
            result.update(status='error', error=str(exc), execution=plan.outcomes)
            payload.update(ok=False, error='Execution stopped. Source edits may already be applied for operations not started; inspect applied_sources and execution before retrying.')
            break


def main(argv=None):
    argv = list(sys.argv[1:] if argv is None else argv)
    separator = argv.index('--') if '--' in argv else len(argv)
    as_json = '--json' in argv[:separator]
    try:
        args = parser().parse_args(argv[:separator])
        if args.command != 'exec' and separator < len(argv):
            args = parser().parse_args(argv)
        as_json = getattr(args, 'json', False)
        ctx = Context(getattr(args, 'source', None), getattr(args, 'timeout', 45))
        if ctx.timeout <= 0:
            raise Problem('--timeout must be positive')
        payload = {'schema_version': 1, 'ok': True}
        display = dict(command=args.command, show_all=getattr(args, 'all', False), verbose=getattr(args, 'verbose', False), explicit=bool(getattr(args, 'packages', [])))
        if args.command == 'managers':
            payload['managers'] = [dict(name=name, binary=binary, description=description, limits=LIMITS[name],
                                       operations=OPERATIONS[name], operation_modes=OPERATION_MODES.get(name, {}), privilege=privilege(name)) for name, (binary, description) in MANAGERS.items()]
        elif args.command == 'doctor':
            payload.update(doctor(ctx))
        elif args.command == 'summary':
            if not ctx.available(MANAGERS[args.manager][0]):
                emit(payload | {'ok': False, 'error': f'{MANAGERS[args.manager][0]} not installed'}, as_json)
                return 3
            rows = inventory(ctx, args.manager, check=True, include_declared=False)
            counts = Counter(row['status'] for row in rows)
            if not as_json:
                print(f"{counts['update_available'] + counts['pinned_outdated']}\t{len(rows)}\t{counts['pinned_outdated']}\t{counts['unknown']}")
                print(json.dumps(rows))
                return 0
            payload.update(packages=rows, summary=dict(counts))
        elif args.command == 'exec':
            if separator == len(argv) or not argv[separator + 1:]:
                raise Problem('exec requires -- followed by native arguments; example: dotpkgs exec brew -- info git')
            command = [MANAGERS[args.manager][0], *argv[separator + 1:]]
            payload.update(command=command, privilege=delegated())
            if not args.dry_run:
                result = ctx.passthrough(command, capture=as_json)
                code = result.returncode if result.returncode >= 0 else 128 - result.returncode
                if as_json:
                    emit(payload | dict(ok=code == 0, exit_code=code, stdout=result.stdout, stderr=result.stderr), True)
                return code
            if not as_json:
                print(command_text(dict(argv=command)))
                return 0
        else:
            selected = selection(args)
            if getattr(args, 'format', None) == 'tsv' and not as_json and len(selected) != 1:
                raise Problem('TSV requires one selected provider; use --manager or --json for multiple providers')
            reading = args.command in ('status', 'list', 'outdated')
            all_packages = getattr(args, 'all', False)
            if not reading:
                if not args.packages and not all_packages:
                    raise Problem('write operations require package IDs or update --all')
                if all_packages and args.packages:
                    raise Problem('choose package IDs or --all, not both')
                if getattr(args, 'kind', None) and set(selected) != {'brew'}:
                    raise Problem('--kind is only supported for Homebrew installs')
                if getattr(args, 'group', None) and not set(selected) <= {'brew','mas','setapp','gh'}:
                    raise Problem('--group is only supported for Brew/MAS/Setapp/gh installs')
                if not args.dry_run:
                    ctx.lock_writes()
            payload['results'] = []
            plans, shared_edits = [], {}
            explicit = bool(args.manager or args.packages)
            progress = not as_json and sys.stderr.isatty()
            for manager, names in selected.items():
                result = dict(manager=manager, status='ok')
                payload['results'].append(result)
                if progress:
                    print(f'{"Checking" if reading else "Planning"} {manager}…', file=sys.stderr, flush=True)
                try:
                    if reading:
                        result.update(read_result(ctx, args, manager, names))
                        if result['status'] == 'unavailable' and explicit:
                            payload['ok'] = False
                    elif all_packages and not ctx.available(MANAGERS[manager][0]):
                        result.update(status='skipped', reason='manager not installed')
                    else:
                        plan = make_plan(ctx, manager, args.command, names, latest=getattr(args, 'latest', False),
                                         version=getattr(args, 'requested_version', None), group=getattr(args, 'group', None),
                                         kind=getattr(args, 'kind', None), edits=shared_edits, all_packages=all_packages)
                        shared_edits = plan.edits
                        result.update(plan=plan.document(), status='planned')
                        plans.append((plan, result))
                except ERRORS as exc:
                    result.update(status='error', error=str(exc))
                    payload['ok'] = False
            if not reading and not args.dry_run:
                if not payload['ok']:
                    payload['error'] = 'Nothing executed: resolve the planning errors or select fewer managers.'
                else:
                    execute_plans(ctx, plans, payload)
            if getattr(args, 'format', None) == 'tsv' and not as_json:
                for result in payload['results']:
                    if result.get('error') or result['status'] == 'unavailable':
                        print(result.get('error') or result['reason'], file=sys.stderr)
                    for row in result.get('packages', []):
                        print('\t'.join(str(row.get(k) or '') for k in ('name', 'installed', 'latest', 'kind')) + '\t' + str(row.get('installed_on_request', False)).lower())
            else:
                emit(payload, as_json, **display)
            return 0 if payload['ok'] else 1
        emit(payload, as_json, **display)
        return 0 if payload['ok'] else 1
    except ERRORS as exc:
        emit({'schema_version': 1, 'ok': False, 'error': str(exc)}, as_json)
        return 2
    except KeyboardInterrupt:
        emit({'schema_version': 1, 'ok': False, 'error': 'interrupted'}, as_json)
        return 130
