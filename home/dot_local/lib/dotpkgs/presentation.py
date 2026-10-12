"""Human views; machine formats bypass presentation filtering."""
from datetime import datetime, timezone
import json
import shlex
import sys

LABELS = {'current': 'current', 'update_available': 'update available', 'pinned_outdated': 'held back',
          'policy_mismatch': 'policy mismatch', 'missing': 'missing', 'unknown': 'unresolved', 'disabled': 'disabled'}


def command_text(step):
    env = ' '.join(f'{key}={shlex.quote(value)}' for key, value in step.get('env', {}).items())
    command = ((env + ' ') if env else '') + shlex.join(step['argv'])
    return f'(cd {shlex.quote(step["cwd"])} && {command})' if step.get('cwd') else command


def step_text(step):
    kind = step['type']
    if kind == 'command':
        return command_text(step)
    if kind == 'manual':
        return 'Manual: ' + step['instruction']
    if kind == 'quarantine':
        return 'Archive ' + step['path']
    if kind == 'installer':
        return f'Install using {step["url"]} ({step["shell"]} {shlex.join(step.get("args", []))})'
    if kind == 'receipt':
        return 'Record build receipt: ' + step['name']
    raise ValueError(f'unknown step type: {kind}')


def counts_text(counts):
    return ', '.join(f'{count} {LABELS.get(state, state)}' for state, count in counts.items() if count) or 'no packages'


def package_line(row, inventory=False):
    installed = row['installed']
    if installed and len(installed) >= 40 and all(c in '0123456789abcdef' for c in installed):
        installed = installed[:12]
    installed = installed or ('present; version unrecorded' if row.get('present') else '—')
    title = f' ({row["title"]})' if row.get('title') else ''
    base = f'  {row["id"]}{title}  {installed}'
    if inventory:
        if row['status'] in ('missing', 'disabled'):
            return base + '  ' + row['status']
        return base + (f'  pinned: {row["requested"]}' if row['pinned'] else '')
    status = LABELS.get(row['status'], row['status'])
    if row['status'] == 'unknown':
        status = 'unresolved'
    base += '  ' + status
    if row.get('latest') and row['status'] not in ('current', 'disabled'):
        base += f' → {row["latest"]}'
    if row['pinned'] or row['status'] == 'policy_mismatch':
        base += f' (policy: {row["requested"]})'
    return base


def emit(payload, as_json=False, *, command=None, show_all=False, verbose=False, explicit=False):
    if as_json:
        print(json.dumps(payload, sort_keys=True))
        return
    if payload.get('error'):
        print('dotpkgs: ' + payload['error'], file=sys.stderr)
    if payload.get('source'):
        print('Source: ' + payload['source'])
    if payload.get('configuration'):
        print('Configuration: ' + payload['configuration'])
        print('Offline checks only; authentication, network, and toolchain execution were not tested.')
    if 'managers' in payload:
        print('MANAGER      INSTALL REMOVE UPDATE PIN UNPIN')
        for item in payload['managers']:
            operations = item['operations']
            cells = [item.get('operation_modes', {}).get(name, 'yes' if name in operations else '—')
                     for name in ('install', 'remove', 'update', 'pin', 'unpin')]
            print(f'{item["name"]:12} ' + ' '.join(f'{cell:7}' for cell in cells).rstrip())
            if verbose:
                print('  ' + item['description'] + '. ' + item['limits'])
                print('  Privileges: ' + item['privilege']['reason'])
        if not verbose:
            print('Use managers --verbose for provider limits and privilege requirements.')
    for result in payload.get('results', []):
        if command == 'doctor':
            print(f'{result["manager"]}: {result["status"]} — {result["reason"]}')
            continue
        if result['status'] in ('error', 'unavailable', 'skipped', 'not_started'):
            message = result.get('error') or result.get('reason', '')
            print(f'{result["manager"]}: {result["status"]} — {message}', file=sys.stderr if result['status'] in ('error','unavailable') else sys.stdout)
        rows = result.get('packages', [])
        if 'packages' in result and result['status'] == 'ok':
            counts = result.get('summary', {})
            total = sum(counts.values())
            print(f'{result["manager"]}: {total} packages' + ('' if command == 'list' else ' — ' + counts_text(counts)))
            if result.get('checked_at'):
                stamp = datetime.fromtimestamp(result['checked_at'], timezone.utc).isoformat(timespec='seconds')
                print(f'  {"Cached" if result.get("cached") else "Checked"} {stamp}')
            shown = 0
            for row in rows:
                if not show_all and not explicit:
                    if row['status'] == 'disabled':
                        continue
                    if command == 'list' and row.get('kind') == 'formula' and not row.get('installed_on_request') and not row.get('declared'):
                        continue
                    if command == 'status' and row['status'] == 'current':
                        continue
                print(package_line(row, inventory=command == 'list'))
                shown += 1
                if command != 'list' or verbose:
                    if row.get('note'):
                        print('    ' + row['note'])
                    for dependency in row.get('dependencies', []):
                        print(f'    {dependency["name"]}: {dependency["installed"] or "missing"} → {dependency["latest"]}')
            for row in result.get('unresolved', []):
                print(package_line(row))
                if row.get('note'):
                    print('    ' + row['note'])
            if command in ('list', 'status') and shown < len(rows):
                print(f'  {len(rows) - shown} rows hidden; use --all to show them.')
            if command == 'outdated' and not rows:
                print('  No known updates.' if result.get('unresolved') else '  No updates available within this provider’s comparison scope.')
        if 'plan' not in result:
            continue
        plan = result['plan']
        if result['status'] not in ('error', 'skipped', 'not_started'):
            print(f'{result["manager"]}: {result["status"]} — {len(plan["edits"])} source edits, {len(plan["steps"])} steps')
        if result.get('source_status'):
            print('  Source edits: ' + result['source_status'])
        for edit in plan['edits']:
            print(edit['diff'], end='')
        for index, step in enumerate(plan['steps']):
            outcome = result.get('execution', [])
            state = outcome[index]['status'] if outcome else 'planned'
            print(f'  {index + 1}. [{state}] {step_text(step)}')
            if outcome and outcome[index].get('destination'):
                print('     Recovery: ' + outcome[index]['destination'])
            if step['privilege']['sudo'] != 'not_needed' or verbose:
                print('     ' + step['privilege']['reason'])
            if verbose and step['type'] == 'installer':
                print('     Environment: ' + ' '.join(f'{k}={shlex.quote(v)}' for k, v in step['env'].items()))
        for note in plan['notes']:
            print('  ' + note)
        if result.get('verification'):
            print('  ' + result['verification'])
        for row in result.get('observed', []):
            print('  Observed: ' + row['id'] + ' ' + (row['installed'] or row['status']))
