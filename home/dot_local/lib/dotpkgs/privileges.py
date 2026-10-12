"""Privilege guidance shared by discovery and operation plans."""

GUIDANCE = (
    'Run dotpkgs as your normal user, never sudo dotpkgs. Reads and dry runs '
    'need no sudo. Planned writes label elevation needs; native tools own prompts.'
)


def privilege(manager, step=None):
    sudo, reason = 'not_needed', 'Writes user-owned files; existing toolchains must already be installed.'
    if manager == 'brew':
        sudo, reason = 'may_prompt', 'Formula operations need no sudo; cask installers/removal may request it through Homebrew.'
    elif manager == 'mas':
        sudo, reason = 'required', 'App install/update/removal requires root; mas requests elevation itself.'
    elif manager == 'xcode':
        sudo, reason = 'may_prompt', 'xcodes requests elevation for installation setup/selection; removal depends on bundle permissions.'
    elif manager == 'setapp':
        reason = 'Install uses a writable app directory; removal needs bundle write access and does not auto-elevate. Client updates are manual.'
    if step is not None:
        kind = step['type']
        if kind == 'manual':
            sudo, reason = 'manual', 'Follow the named app/review step; any authorization belongs to that workflow.'
        elif kind in ('receipt', 'quarantine'):
            sudo, reason = 'not_needed', 'Requires user write access to these paths; dotpkgs does not retry with sudo.'
        elif kind == 'command':
            argv = step['argv']
            if manager == 'brew' and (argv[1] in ('update', 'pin', 'unpin') or '--formula' in argv):
                sudo, reason = 'not_needed', 'Runs as the Homebrew owner; no sudo needed.'
            if manager == 'xcode' and argv[:2] == ['xcodes', 'select']:
                sudo, reason = 'required', 'Changing the system developer directory requires elevation; xcodes handles sudo.'
    return dict(sudo=sudo, reason=reason)


def delegated():
    return dict(sudo='delegated', reason='Native arguments are not classified; check the native command help. Run dotpkgs as your normal user.')
