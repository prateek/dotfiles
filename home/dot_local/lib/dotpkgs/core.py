"""Shared records, process boundary, and installation context for dotpkgs."""
from __future__ import annotations

import hashlib
import fcntl
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time


class Problem(Exception):
    pass


def version(text):
    match = re.search(r'\d+\.[\w.+,-]+(?:-[\w.]+)?', text)
    return match.group(0) if match else text.strip()


def apm_identity(dependency):
    parts = dependency.partition('#')[0].removeprefix('https://github.com/').split('/', 2)
    if len(parts) < 2:
        raise Problem(f'invalid GitHub dependency: {dependency}')
    return '/'.join([parts[0].lower(), parts[1].removesuffix('.git').lower(), *parts[2:]])


def record(manager, name, installed=None, requested=None, latest=None, allowed=None,
           *, pinned=False, status=None, note=None, **extra):
    if status is None:
        if not installed:
            status = 'missing'
        elif latest is None:
            status = 'unknown'
        elif latest == installed:
            status = 'current'
        elif allowed == installed or (pinned and allowed is None):
            status = 'pinned_outdated'
        else:
            status = 'update_available'
    return dict(id=f'{manager}:{name}', manager=manager, name=name,
                installed=installed, requested=requested, latest=latest,
                latest_allowed=allowed, pinned=pinned, status=status, note=note, **extra)


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def atomic_write(path, text):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    mode = path.stat().st_mode & 0o777 if path.exists() else 0o600
    fd, temp = tempfile.mkstemp(prefix=f'.{path.name}.', dir=path.parent)
    try:
        with os.fdopen(fd, 'w') as handle:
            handle.write(text)
        os.chmod(temp, mode)
        os.replace(temp, path)
    finally:
        if os.path.exists(temp):
            os.unlink(temp)


class Context:
    def __init__(self, source=None, timeout=45):
        self.home = Path.home()
        self.config = Path(os.environ.get('XDG_CONFIG_HOME', self.home / '.config'))
        self.data = Path(os.environ.get('XDG_DATA_HOME', self.home / '.local/share'))
        self.state = Path(os.environ.get('XDG_STATE_HOME', self.home / '.local/state')) / 'dotfiles/dotpkgs'
        self.source_arg = source or os.environ.get("DOTPKGS_SOURCE")
        self.timeout = timeout
        self._source = None
        self._features = None
        self._groups = None

    def lock_writes(self):
        self.state.mkdir(parents=True, exist_ok=True)
        self._lock = (self.state / 'operations.lock').open('a')
        try:
            fcntl.flock(self._lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as exc:
            self._lock.close()
            raise Problem('another dotpkgs write is in progress') from exc

    def binary(self, name):
        key = 'DOTPKGS_' + name.upper().replace('-', '_') + '_BIN'
        return os.environ.get(key, name)

    def available(self, name):
        return shutil.which(self.binary(name)) is not None

    def run(self, argv, *, cwd=None, env=None, write=False, allowed_exit=(0,)):
        argv = [str(x) for x in argv]
        argv[0] = self.binary(argv[0])
        process_env = os.environ | {'NO_COLOR': '1', 'HOMEBREW_NO_AUTO_UPDATE': '1',
                                    'GIT_TERMINAL_PROMPT': '0', 'PWD': str(cwd or self.home)} | (env or {})
        # A project-specific mise selection must never leak into machine operations.
        for key in ('MISE_CONFIG_FILE', 'MISE_ENV', 'MISE_DEFAULT_CONFIG_FILENAME'):
            process_env.pop(key, None)
        try:
            result = subprocess.run(argv, cwd=cwd or self.home, env=process_env,
                                    text=True, stdout=sys.stderr if write else subprocess.PIPE,
                                    stderr=None if write else subprocess.PIPE,
                                    timeout=None if write else self.timeout,
                                    check=False)
        except (OSError, subprocess.TimeoutExpired) as exc:
            raise Problem(f'{argv[0]}: {type(exc).__name__}') from exc
        if result.returncode not in allowed_exit:
            # Do not echo arbitrary native diagnostics into JSON: they may contain auth.
            raise Problem(f'{Path(argv[0]).name} {argv[1] if len(argv) > 1 else ""} exited {result.returncode}')
        return result.stdout or ''

    def json(self, argv, **kwargs):
        try:
            return json.loads(self.run(argv, **kwargs))
        except ValueError as exc:
            raise Problem(f'{argv[0]} returned invalid JSON') from exc

    def fetch(self, url):
        return self.json(['curl', '-fsSL', '--max-time', str(self.timeout), url])

    @property
    def source(self):
        if self._source is None:
            path = Path(self.source_arg) if self.source_arg else Path(self.run(['chezmoi', 'source-path']).strip())
            if (path / 'home/.chezmoidata').is_dir():
                path /= 'home'
            if not (path / '.chezmoidata/packages.toml').is_file():
                raise Problem('dotfiles source not found; pass --source /path/to/dotfiles')
            self._source = path.resolve()
        return self._source

    @property
    def repo(self):
        return self.source.parent

    def render(self, template):
        return self.run(['chezmoi', '-S', self.source, 'execute-template', template])

    def features(self):
        if self._features is None:
            self._features = json.loads(self.render('{{ includeTemplate "features.tmpl" . }}'))
        return self._features

    def groups(self):
        import tomllib
        if self._groups is None:
            packages = tomllib.loads((self.source / '.chezmoidata/packages.toml').read_text())['packages']['groups']
            self._groups = {name: packages[name] for name in self.features()['groups']}
        return self._groups

    def declared(self, section):
        return {str(item.get('id', item['name'])): item for group in self.groups().values()
                for item in group.get(section, [])}

    def source_path(self, target):
        return Path(self.run(['chezmoi', '-S', self.source, 'source-path', target]).strip())

    def cache(self, manager, rows=None):
        path = self.state / f'{manager}.json'
        if rows is not None:
            atomic_write(path, json.dumps({'checked_at': int(time.time()), 'packages': rows}) + '\n')
        if not path.exists():
            raise Problem(f'no cached {manager} status; run dotpkgs status --manager {manager}')
        return json.loads(path.read_text())
