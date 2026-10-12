"""Supported operations and option combinations shared by help and planning."""
from core import Problem

OPERATIONS = {
    'brew': ('install', 'remove', 'update', 'pin', 'unpin'),
    'mise': ('install', 'remove', 'update', 'pin', 'unpin'),
    'claude': ('install', 'remove', 'update'),
    'codex': ('install', 'remove', 'update', 'pin', 'unpin'),
    'cursor': ('install', 'remove', 'update'),
    'gh': ('install', 'remove', 'update', 'pin', 'unpin'),
    'zinit': ('install', 'remove', 'update', 'pin', 'unpin'),
    'apm': ('install', 'remove', 'update', 'pin', 'unpin'),
    'mas': ('install', 'remove', 'update'),
    'setapp': ('install', 'remove', 'update'),
    'xcode': ('install', 'remove', 'update', 'pin'),
    'raycast': ('install', 'update'),
    'externals': ('install', 'update'),
    'swift': ('install', 'remove', 'update'),
}
OPERATION_MODES = {'setapp': {'update': 'manual'}, 'apm': {name: 'review' for name in ('install', 'remove', 'update', 'pin', 'unpin')}}
VERSION_ACTIONS = {'mise': ('install', 'pin'), 'codex': ('pin',), 'gh': ('pin',),
                   'zinit': ('pin',), 'apm': ('pin',), 'xcode': ('install', 'pin', 'remove')}


def validate_operation(manager, action, names, version):
    if manager == 'xcode' and names and names != ['Xcode']:
        raise Problem('xcode package name is Xcode; use xcode:Xcode')
    if action not in OPERATIONS[manager]:
        if manager == 'xcode' and action == 'unpin':
            raise Problem('Xcode does not support unpin: its policy requires an exact version; use update --latest to select the newest stable release')
        if manager == 'raycast' and action == 'remove':
            raise Problem('Raycast removal requires an explicit change to its owning source directory; remove the imported extension in Raycast and reconcile its deployed files manually')
        raise Problem(f'{manager} does not support {action}; see dotpkgs managers --verbose')
    if version is not None:
        if not version or version.startswith('-') or any(c in version for c in '\n\r\t'):
            raise Problem('invalid version')
        if action not in VERSION_ACTIONS.get(manager, ()):
            raise Problem(f'{manager} {action} does not support --version')
