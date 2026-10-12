"""dotpkgs command contract and shared status entry point."""
import argparse
from collections import Counter
import json
from pathlib import Path
import shlex
import sys

from actions import make_plan
from core import Context, Problem, apm_identity
from providers import LIMITS, MANAGERS, inventory
from privileges import GUIDANCE, delegated, privilege


class Parser(argparse.ArgumentParser):
    def error(self, message):
        raise Problem(message)


def parser():
    common = Parser(add_help=False)
    common.add_argument('--json', action='store_true', default=argparse.SUPPRESS, help='stable JSON output, including errors')
    common.add_argument('--source', default=argparse.SUPPRESS, help='dotfiles checkout or chezmoi source (default: chezmoi source-path)')
    common.add_argument('--timeout', type=int, default=argparse.SUPPRESS, help='seconds per read-only probe (default: 45)')
    root = Parser(prog='dotpkgs', parents=[common], description='Inspect and manage machine packages through their owning installers.', epilog=GUIDANCE)
    root.add_argument('--version', action='version', version='dotpkgs 1.0.0')
    subs = root.add_subparsers(dest='command', required=True)
    for name, help in [('managers', 'discover supported installation paths'), ('doctor', 'check offline prerequisites and configuration')]:
        subs.add_parser(name, parents=[common], help=help)
    for name, help in [('list', 'inventory installed/configured packages without upstream checks'), ('status', 'compare installed, requested, allowed and latest versions'), ('outdated', 'list available updates, including updates beyond pins')]:
        sub = subs.add_parser(name, parents=[common], help=help, epilog=GUIDANCE)
        sub.add_argument('--manager', choices=MANAGERS, action='append', help='limit checks; repeatable')
        sub.add_argument('packages', nargs='*', help='exact manager:name IDs, or names with --manager')
        if name in ('outdated', 'list'):
            sub.add_argument('--format', choices=('text', 'tsv'), default='text', help='TSV: name, installed, latest, kind, installed_on_request; --json has the full contract')
        if name == 'status':
            sub.add_argument('--cached', action='store_true', help='read the last successful check without invoking managers')
    for name, help in [('install', 'install packages and maintain owning declarations'), ('remove', 'remove packages and their declarations'),
                       ('update', 'update selected packages (preserves version policy by default)'),
                       ('pin', 'hold/select a version where the owner supports it'), ('unpin', 'follow latest where supported')]:
        sub = subs.add_parser(name, parents=[common], help=help, epilog=GUIDANCE)
        sub.add_argument('--manager', choices=MANAGERS, action='append')
        sub.add_argument('packages', nargs='*', help='exact manager:name IDs, or names with --manager')
        sub.add_argument('--all', action='store_true', help='operate on all packages in selected managers (all managers if omitted)')
        sub.add_argument('--dry-run', action='store_true', help='show commands/source diffs without executing writes')
        sub.add_argument('--version', dest='requested_version', help='requested version, tag, or commit')
        sub.add_argument('--group', help='selected package group for new Brew/MAS/Setapp/gh declarations')
        sub.add_argument('--kind', choices=('formula', 'cask'), help='Homebrew kind for a new package')
        if name == 'update':
            sub.add_argument('--latest', action='store_true', help='explicitly override pins/ranges; include self-updating casks and dependency bumps')
    sub = subs.add_parser('summary', parents=[common], help='banner protocol: counts TSV, then package JSON (live check)')
    sub.add_argument('--manager', choices=MANAGERS, required=True)
    sub = subs.add_parser('exec', parents=[common], help='run a manager-native command (runtime-only escape hatch)',
                         usage='dotpkgs exec [options] manager -- native-arguments')
    sub.add_argument('manager', choices=MANAGERS)
    sub.add_argument('--dry-run', action='store_true')
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
            raise Problem(f'{package}: use manager:name or one --manager')
    return selected or {m: [] for m in MANAGERS}


def emit(payload, as_json):
    if as_json:
        print(json.dumps(payload, sort_keys=True))
        return
    if payload.get('error'):
        print('dotpkgs: ' + payload['error'], file=sys.stderr)
    for item in payload.get('managers', []):
        print(f'{item["name"]:12} {item["description"]}')
        print('  ' + item['limits'])
        print(f"  sudo: {item['privilege']['sudo']} — {item['privilege']['reason']}")
    for result in payload.get('results', []):
        print(f'{result["manager"]}: {result["status"]}' + (f' — {result["error"]}' if result.get('error') else ''))
        if result.get('checked_at'):
            print(f'  cached check: {result["checked_at"]}')
        for row in result.get('packages', []):
            print(f'  {row["name"]:40} {row["status"]:18} installed={row["installed"] or "—"}  requested={row["requested"] or "—"}  allowed={row["latest_allowed"] or "?"}  latest={row["latest"] or "?"}')
            for dependency in row.get('dependencies', []):
                print(f"    {dependency['name']}: {dependency['installed'] or 'missing'} → {dependency['latest']} (requested {dependency['requested']}, allowed {dependency['latest_allowed']})")
        plan = result.get('plan', {})
        for edit in plan.get('edits', []):
            print(edit['diff'], end='')
        for step in plan.get('steps', []):
            print(f"  sudo: {step['privilege']['sudo']} — {step['privilege']['reason']}")
            if step['type'] == 'command':
                location = f'(cd {shlex.quote(step["cwd"])}) ' if step['cwd'] else ''
                print('  ' + location + shlex.join(step['argv']))
            else:
                print('  ' + json.dumps(step))
        for note in plan.get('notes', []):
            print('  ' + note)


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
        if args.command == 'managers':
            payload['managers'] = [dict(name=name, binary=binary, description=description, limits=LIMITS[name], privilege=privilege(name))
                                   for name, (binary, description) in MANAGERS.items()]
        elif args.command == 'doctor':
            payload['results'] = [dict(manager=name, status='available' if ctx.available(binary) else 'unavailable',
                                      auth='native manager credentials; not probed', network='not probed')
                                  for name, (binary, _) in MANAGERS.items()]
            try:
                payload['source'] = str(ctx.source)
            except Problem as exc:
                payload['ok'] = False
                payload['error'] = str(exc)
        elif args.command == 'summary':
            if not ctx.available(MANAGERS[args.manager][0]):
                print(f'{MANAGERS[args.manager][0]} not installed', file=sys.stderr)
                return 3
            rows = inventory(ctx, args.manager, check=True)
            ctx.cache(args.manager, rows)
            counts = Counter(r['status'] for r in rows)
            outdated = counts['update_available'] + counts['pinned_outdated']
            if as_json:
                payload.update(packages=rows, summary=dict(counts))
            else:
                print(f"{outdated}\t{len(rows)}\t{counts['pinned_outdated']}\t{counts['unknown']}")
                print(json.dumps(rows))
                return 0
        elif args.command == 'exec':
            if separator == len(argv):
                raise Problem('exec requires -- before native arguments')
            values = argv[separator + 1:]
            if not values:
                raise Problem('exec requires native arguments after --')
            command = [MANAGERS[args.manager][0], *values]
            payload['command'] = command
            payload['privilege'] = delegated()
            if not args.dry_run:
                ctx.run(command, write=True)
            if not as_json:
                print(shlex.join(command))
                print("sudo: delegated — " + payload["privilege"]["reason"])
        else:
            selected = selection(args)
            reading = args.command in ('status', 'list', 'outdated')
            if not reading and not args.packages and not args.all:
                raise Problem('write operations require package IDs or --all')
            if not reading and args.all and args.packages:
                raise Problem('choose package IDs or --all, not both')
            if not reading and args.all and args.command in ('remove', 'pin', 'unpin', 'install'):
                raise Problem('--all is supported for update; other writes require explicit package IDs')
            if not reading and not args.dry_run:
                ctx.lock_writes()
            results = []
            payload['results'] = results
            plans = []
            shared_edits = {}
            for manager, names in selected.items():
                result = {'manager': manager, 'status': 'ok'}
                results.append(result)
                try:
                    if not reading and args.all and not ctx.available(MANAGERS[manager][0]):
                        result.update(status='skipped', reason='manager not installed')
                        continue
                    if reading:
                        if manager not in ('claude', 'codex', 'cursor') and not getattr(args, 'cached', False) and not ctx.available(MANAGERS[manager][0]):
                            result.update(status='unavailable', packages=[], reason='manager not installed')
                            continue
                        if getattr(args, 'cached', False):
                            result.update(ctx.cache(manager))
                        else:
                            result['packages'] = inventory(ctx, manager, check=args.command != 'list')
                            if args.command == 'status':
                                result.update(ctx.cache(manager, result['packages']))
                        if names:
                            if manager == 'apm':
                                names = [apm_identity(name) for name in names]
                            found = {r['name'] for r in result['packages']}
                            if set(names) - found:
                                raise Problem('package not found: ' + ', '.join(sorted(set(names) - found)))
                            result['packages'] = [r for r in result['packages'] if r['name'] in names]
                        if args.command == 'outdated':
                            result['packages'] = [r for r in result['packages'] if r['status'] in ('update_available', 'pinned_outdated')]
                        result['summary'] = dict(Counter(r['status'] for r in result['packages']))
                    else:
                        plan = make_plan(ctx, manager, args.command, names,
                                         latest=getattr(args, 'latest', False), version=args.requested_version,
                                         group=args.group, kind=args.kind, edits=shared_edits, all_packages=args.all)
                        shared_edits = plan.edits
                        result['plan'] = plan.document()
                        result['status'] = 'planned'
                        plans.append((plan, result))
                except (Problem, OSError, ValueError, KeyError, TypeError) as exc:
                    result.update(status='error', error=str(exc))
                    payload['ok'] = False
            if not reading and not args.dry_run:
                if not payload['ok']:
                    payload['error'] = 'Nothing executed: resolve the reported planning errors or select fewer managers.'
                else:
                    if plans:
                        plans[-1][0].commit_edits()
                        for plan, _ in plans:
                            (ctx.state / f'{plan.manager}.json').unlink(missing_ok=True)
                    for plan, result in plans:
                        try:
                            plan.execute(ctx)
                            result['status'] = 'manual' if any(s['type'] == 'manual' for s in plan.steps) else 'completed'
                            if result['status'] == 'manual':
                                payload['ok'] = False
                        except (Problem, OSError, ValueError, KeyError, TypeError) as exc:
                            result.update(status='error', error=str(exc))
                            payload['ok'] = False
                            payload['error'] = 'Execution stopped; earlier completed steps remain applied. Inspect source diffs before retrying.'
                            break
            if args.command in ('outdated', 'list') and args.format == 'tsv' and not as_json:
                for result in results:
                    if result.get('error'):
                        print(result['error'], file=sys.stderr)
                    for row in result.get('packages', []):
                        print('\t'.join(str(row.get(k) or '') for k in ('name', 'installed', 'latest', 'kind')) + '\t' + str(row.get('installed_on_request', False)).lower())
            else:
                emit(payload, as_json)
            return 0 if payload['ok'] else 1
        emit(payload, as_json)
        return 0 if payload['ok'] else 1
    except (Problem, OSError, ValueError, KeyError, TypeError) as exc:
        emit({'schema_version': 1, 'ok': False, 'error': str(exc)}, as_json)
        return 2
    except KeyboardInterrupt:
        emit({'schema_version': 1, 'ok': False, 'error': 'interrupted'}, as_json)
        return 130
