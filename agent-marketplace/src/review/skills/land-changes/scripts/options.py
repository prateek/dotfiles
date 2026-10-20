#!/usr/bin/env python3
"""Resolve scoped landing choices against discovery; never execute workflow commands."""

from __future__ import annotations

import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

OPERATIONS = {
    'via': ('method', 'method'),
    'run': ('action', 'execution'), 'skip': ('action', 'execution'),
    'require': ('gate', 'gate'), 'bypass': ('gate', 'gate'),
    'after': ('action', 'followup'), 'without-after': ('action', 'followup'),
    'wait': ('action', 'waiting'), 'no-wait': ('action', 'waiting'),
}
FIELDS = {'id', 'kind', 'source', 'scope', 'fingerprint', 'operation', 'dynamic'}
DEFAULTS_FILE = Path('.agents/land-changes.json')


class Once(argparse.Action):
    def __call__(self, parser, namespace, values, option_string=None):
        if getattr(namespace, self.dest) is not None:
            parser.error(f'duplicate option: {option_string}')
        setattr(namespace, self.dest, self.const if self.nargs == 0 else values)


def arguments():
    parser = argparse.ArgumentParser(description=__doc__, allow_abbrev=False)
    for name in ('repo-id', 'target'):
        parser.add_argument(f'--{name}', required=True, action=Once)
    parser.add_argument('--checkout', action=Once, help='destination checkout holding the preferences file (default: .)')
    parser.add_argument('--discovery', action=Once, help='JSON items/groups describing current native meanings')
    for operation in OPERATIONS:
        parser.add_argument(f'--{operation}', action='append', default=[], metavar='ID')
    parser.add_argument('--dynamic', action='append', default=[], metavar='GROUP',
                        help='explicitly save future membership within the selected group scope')
    parser.add_argument('--inspect', action=Once, nargs=0, const=True)
    mode = parser.add_mutually_exclusive_group()
    for flag in ('save-defaults', 'show-defaults', 'reset-defaults'):
        mode.add_argument(f'--{flag}', action=Once, nargs=0, const=True)
    args = parser.parse_args()
    explicit = [(op, name) for op in OPERATIONS for name in getattr(args, op.replace('-', '_'))]
    if args.save_defaults and not explicit:
        parser.error('--save-defaults requires explicit choices')
    if (args.show_defaults or args.reset_defaults) and (explicit or args.dynamic):
        parser.error('cannot combine show/reset with choices')
    if args.inspect and (args.save_defaults or args.reset_defaults):
        parser.error('cannot combine inspect with preference writes')
    if args.dynamic and not args.save_defaults:
        parser.error('--dynamic requires --save-defaults')
    if len(set(explicit)) != len(explicit) or len(set(args.dynamic)) != len(args.dynamic):
        parser.error('duplicate choice or dynamic group')
    if ('/' not in args.repo_id or '://' in args.repo_id or '@' in args.repo_id
            or any(part in ('', '.', '..') for part in args.repo_id.split('/'))
            or any(not v or any(c.isspace() or ord(c) < 32 for c in v) for v in (args.repo_id, args.target))):
        parser.error('identity must be canonical host/repository-path and a nonempty target without whitespace')
    return parser, args, explicit


def git_paths(checkout):
    def git(*args):
        result = subprocess.run(['git', '-C', checkout, 'rev-parse', '--path-format=absolute', *args],
                                text=True, capture_output=True)
        if result.returncode:
            raise ValueError(f'--checkout must be inside a Git worktree: {result.stderr.strip()}')
        return Path(result.stdout.strip())
    return git('--show-toplevel') / DEFAULTS_FILE, git('--git-path', 'land-changes.lock')


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f'duplicate JSON key: {key}')
        result[key] = value
    return result


def load_json(path):
    return json.loads(path.read_text(), object_pairs_hook=unique_object)


def text(value):
    return isinstance(value, str) and bool(value.strip()) and all(ord(c) >= 32 for c in value)


def validate_identity(value):
    if not all(text(value.get(k)) for k in ('id', 'kind', 'source')):
        raise ValueError('choice identity/source must be nonempty strings')
    if value['kind'] not in ('method', 'action', 'gate'):
        raise ValueError('unsupported choice kind')
    scope = value.get('scope')
    if not isinstance(scope, dict) or not all(text(k) and text(v) for k, v in scope.items()):
        raise ValueError('scope must map names to nonempty strings')


def slot(choice):
    domain = OPERATIONS[choice['operation']][1]
    return (domain, '' if domain == 'method' else choice['id'])


def read_discovery(path):
    if not path:
        return None
    data = load_json(Path(path))
    if not isinstance(data, dict) or set(data) - {'items', 'groups'} or not isinstance(data.get('items'), list):
        raise ValueError('discovery requires items and optional groups lists')
    if not isinstance(data.get('groups', []), list):
        raise ValueError('discovery groups must be a list')
    nodes = {}
    for group, entries in ((False, data['items']), (True, data.get('groups', []))):
        for node in entries:
            fields = {'id', 'kind', 'source', 'scope', 'meaning'} | ({'members'} if group else set())
            if not isinstance(node, dict) or set(node) != fields:
                raise ValueError('invalid discovery item/group fields')
            validate_identity(node)
            if not text(node['meaning']):
                raise ValueError('meaning must describe the stable effect or requirement')
            if node['id'] in nodes:
                raise ValueError(f'duplicate discovery name: {node["id"]}')
            if group and (node['kind'] == 'method' or not isinstance(node['members'], list)
                          or not all(text(m) for m in node['members'])
                          or len(set(node['members'])) != len(node['members']) or not node['scope']):
                raise ValueError('group requires unique members, action/gate kind, and bounded scope')
            signature = {k: node[k] for k in ('kind', 'source', 'scope', 'meaning')}
            fingerprint = hashlib.sha256(json.dumps(signature, sort_keys=True).encode()).hexdigest()
            nodes[node['id']] = dict(node, fingerprint=fingerprint, group=group)
    for node in nodes.values():
        if not node['group']:
            continue
        for name in node['members']:
            member = nodes.get(name)
            if not member or member['group'] or member['kind'] != node['kind']:
                raise ValueError(f'invalid group member: {name}')
            if any(member['scope'].get(k) != v for k, v in node['scope'].items()):
                raise ValueError(f'member {name} exceeds group scope: {node["id"]}')
    return nodes


def record(node, operation, dynamic=False):
    return {**{k: node[k] for k in ('id', 'kind', 'source', 'scope', 'fingerprint')},
            'operation': operation, 'dynamic': dynamic}


def explicit_choices(selections, dynamic, nodes):
    if (selections or dynamic) and nodes is None:
        raise ValueError('explicit choices require --discovery')
    selected_groups = {name for _, name in selections if name in (nodes or {}) and nodes[name]['group']}
    if set(dynamic) - selected_groups:
        raise ValueError('--dynamic must name a selected group')
    groups, concrete = {}, {}
    for operation, name in selections:
        if name not in nodes:
            raise ValueError(f'unknown discovered name: {name}')
        node = nodes[name]
        if OPERATIONS[operation][0] != node['kind']:
            raise ValueError(f'{operation} cannot select kind {node["kind"]}: {name}')
        records = ([record(node, operation, True)] if name in dynamic else
                   [record(nodes[m], operation) for m in node['members']] if node['group'] else
                   [record(node, operation)])
        target = groups if node['group'] else concrete
        for choice in records:
            key = slot(choice)
            if key in target and target[key]['operation'] != operation:
                raise ValueError(f'conflicting explicit choices for {name}')
            target[key] = choice
    return list((groups | concrete).values())


def validate_choices(choices):
    if not isinstance(choices, list):
        raise ValueError('choices must be a list')
    seen = set()
    for choice in choices:
        if not isinstance(choice, dict) or set(choice) != FIELDS:
            raise ValueError('unsupported choice fields')
        validate_identity(choice)
        if (not isinstance(choice['operation'], str) or choice['operation'] not in OPERATIONS
                or OPERATIONS[choice['operation']][0] != choice['kind']
                or type(choice['dynamic']) is not bool
                or choice['dynamic'] and (choice['kind'] == 'method' or not choice['scope'])
                or not isinstance(choice['fingerprint'], str)
                or not re.fullmatch(r'[0-9a-f]{64}', choice['fingerprint'])):
            raise ValueError('invalid choice operation, scope, or fingerprint')
        key = slot(choice)
        if key in seen:
            raise ValueError('duplicate saved choice')
        seen.add(key)


def read_file(path):
    """Return every destination's saved choices keyed by (repo_id, target)."""
    if not path.exists() and not path.is_symlink():
        return {}
    try:
        if path.is_symlink():
            raise ValueError('symlinked defaults file')
        data = load_json(path)
        if (not isinstance(data, dict) or set(data) != {'version', 'destinations'}
                or type(data['version']) is not int or data['version'] != 3
                or not isinstance(data['destinations'], list)):
            raise ValueError('unsupported schema')
        destinations = {}
        for entry in data['destinations']:
            if (not isinstance(entry, dict) or set(entry) != {'repo_id', 'target', 'choices'}
                    or not all(text(entry[k]) for k in ('repo_id', 'target'))):
                raise ValueError('unsupported destination fields')
            key = (entry['repo_id'], entry['target'])
            if key in destinations:
                raise ValueError(f'duplicate destination: {key[0]} {key[1]}')
            validate_choices(entry['choices'])
            destinations[key] = entry['choices']
        return destinations
    except (ValueError, UnicodeError) as error:
        raise ValueError(f'invalid defaults at {path}: {error}; repair it or restore it from Git') from error


def activate(choices, nodes, origin):
    effective, stale = {}, []
    for choice in sorted(choices, key=lambda c: not c['dynamic']):
        node = (nodes or {}).get(choice['id'])
        reason = ('discovery required' if nodes is None else 'native name missing' if node is None else
                  'native meaning or scope changed' if node['fingerprint'] != choice['fingerprint']
                  or node['group'] != choice['dynamic'] else None)
        if reason:
            stale.append({'choice': choice, 'reason': reason})
            continue
        members = [record(nodes[name], choice['operation']) for name in node['members']] if choice['dynamic'] else [choice]
        for member in members:
            key = slot(member)
            previous = effective.get(key)
            if choice['dynamic'] and previous and previous['operation'] != member['operation']:
                raise ValueError(f'conflicting dynamic groups for {member["id"]}; resolve membership or choices')
            effective[key] = dict(member, origin=origin, **({'group': choice['id']} if choice['dynamic'] else {}))
    return effective, stale


def write_file(path, destinations):
    if not destinations:
        path.unlink(missing_ok=True)
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    data = {'version': 3, 'destinations': [{'repo_id': repo_id, 'target': target, 'choices': choices}
                                           for (repo_id, target), choices in sorted(destinations.items())]}
    mode = path.stat().st_mode & 0o777 if path.exists() else 0o644
    fd, temporary = tempfile.mkstemp(prefix=f'.{path.name}.', dir=path.parent)
    try:
        with os.fdopen(fd, 'w') as stream:
            json.dump(data, stream, indent=2)
            stream.write('\n')
            stream.flush()
            os.fsync(stream.fileno())
        os.chmod(temporary, mode)
        os.replace(temporary, path)
    finally:
        Path(temporary).unlink(missing_ok=True)


def resolve(args, selections):
    path, lock_path = git_paths(args.checkout or '.')
    identity = (args.repo_id, args.target)
    nodes = read_discovery(args.discovery)
    explicit = explicit_choices(selections, args.dynamic, nodes)
    explicit_active, _ = activate(explicit, nodes, 'argument')

    def load_and_save():
        destinations = read_file(path)
        saved = destinations.get(identity, [])
        if args.reset_defaults:
            saved = []
        elif args.save_defaults:
            merged = {slot(c): c for c in saved if c['dynamic'] or slot(c) not in explicit_active}
            merged.update({slot(c): c for c in explicit})
            saved = list(merged.values())
            activate(saved, nodes, 'saved')
        else:
            return saved
        if saved:
            destinations[identity] = saved
        else:
            destinations.pop(identity, None)
        write_file(path, destinations)
        return saved

    if args.save_defaults or args.reset_defaults:
        descriptor = os.open(lock_path, os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
        with os.fdopen(descriptor, 'w') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            saved = load_and_save()
    else:
        saved = load_and_save()
    effective, stale = activate(saved, nodes, 'saved')
    effective.update(explicit_active)
    return {'repo_id': args.repo_id, 'target': args.target, 'choices': list(effective.values()),
            'stale': stale, 'saved_choices': saved,
            'defaults_path': str(path), 'defaults_saved': bool(args.save_defaults),
            'action': 'show_defaults' if args.show_defaults else 'reset_defaults' if args.reset_defaults
            else 'inspect' if args.inspect else 'resolve'}


def main():
    parser, args, selections = arguments()
    try:
        print(json.dumps(resolve(args, selections), indent=2))
    except (OSError, ValueError) as error:
        parser.exit(1, f'options: {error}\n')


if __name__ == '__main__':
    main()
