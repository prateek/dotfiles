"""Offline executable, source, and provider configuration checks."""
import json
from pathlib import Path
import tomllib

from core import Problem
from providers import MANAGERS


def doctor(ctx):
    payload = {'results': []}
    try:
        payload['source'] = str(ctx.source)
        packages = tomllib.loads((ctx.source / '.chezmoidata/packages.toml').read_text())
        if not isinstance(packages['packages']['groups'], dict):
            raise ValueError('package groups must be a table')
        ctx.groups()
        for name in ('machines.toml', 'agents.toml', 'package_policy.toml'):
            path = ctx.source / '.chezmoidata' / name
            if path.exists():
                tomllib.loads(path.read_text())
        policy = ctx.source / 'dot_agents/state/ios-triple.json'
        if policy.exists():
            json.loads(policy.read_text())['xcode_version']
        payload['configuration'] = 'valid'
    except (Problem, OSError, ValueError, KeyError, TypeError) as exc:
        payload.update(ok=False, configuration='invalid', error=f'source configuration: {exc}')
    for name, (binary, _) in MANAGERS.items():
        present = ctx.available(binary)
        paths = {
            'zinit': [ctx.data / 'zinit/zinit.git/zinit.zsh'],
            'pi': [ctx.home / '.pi/agent/settings.json'],
            'setapp': [Path('/Applications/Setapp.app'), ctx.home / 'Applications/Setapp.app'],
            'apm': [ctx.source / '../agent-marketplace/apm.yml'] if payload.get('source') else [],
            'raycast': [ctx.source / 'dot_local/share/raycast-extensions'] if payload.get('source') else [],
        }.get(name)
        configured = any(path.exists() for path in paths) if paths is not None else None
        status = 'available' if present else 'unavailable'
        reason = f'{binary} found' if present else f'{binary} not installed'
        if paths is not None:
            status = status if configured else 'not_configured'
            reason += '; provider files present' if configured else '; provider files or app missing'
        payload['results'].append(dict(manager=name, status=status, reason=reason,
                                       executable=present, configured=configured,
                                       auth='not probed', network='not probed'))
    return payload
