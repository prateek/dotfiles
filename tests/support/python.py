import json
import os
import subprocess
import tempfile
import tomllib
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def declared_os(machine_type, data=None):
    """The OS a machine type declares; features.tmpl refuses any other.

    A type layer the test injects through data wins over machines.toml. None when
    neither declares one, so the render keeps the host's OS.
    """
    injected = (data or {}).get("machines", {}).get("type", {}).get(machine_type, {})
    if "os" in injected:
        return injected["os"]
    machines = tomllib.loads((ROOT / "home/.chezmoidata/machines.toml").read_text())["machines"]
    return machines["type"].get(machine_type, {}).get("os")


class RepoTestCase(unittest.TestCase):
    fixture_prefix = "dotfiles test "

    def setUp(self):
        self.work = Path(self.enterContext(tempfile.TemporaryDirectory(prefix=self.fixture_prefix)))
        self.home = self.work / "home"
        self.home.mkdir()
        self.config = self.work / "chezmoi.toml"
        self.config.write_text("")
        self.env = {
            key: value for key, value in os.environ.items()
            if not key.startswith(("CHEZMOI_", "GIT_", "ORCA_"))
            and key not in ("BASH_ENV", "ENV", "CDPATH", "GHPATH", "FPATH")
        }
        self.env.update(
            HOME=str(self.home), ZDOTDIR=str(self.home),
            GIT_CONFIG_NOSYSTEM="1", GIT_CONFIG_GLOBAL="/dev/null",
            DOTFILES_SKIP_LAUNCHCTL_SYNC="1",
        )
        for name in ("CONFIG", "STATE", "DATA", "CACHE", "RUNTIME"):
            path = self.work / name.lower()
            path.mkdir()
            suffix = "DIR" if name == "RUNTIME" else "HOME"
            self.env[f"XDG_{name}_{suffix}"] = str(path)

    def command(self, argv, raw=b"", *, expected_status=0, env=None, cwd=ROOT):
        result = subprocess.run(
            argv, input=raw, capture_output=True, check=False, timeout=30,
            cwd=cwd, env=self.env | (env or {}),
        )
        self.assertEqual(
            result.returncode, expected_status,
            f"{argv!r}\nstdout: {result.stdout.decode(errors='replace')}\n"
            f"stderr: {result.stderr.decode(errors='replace')}",
        )
        return result

    def render(self, relative_path, machine_type="personal", *, data=None, source=ROOT):
        data = dict(data or {})
        override = {"chezmoi": {"hostname": "dotfiles-test-host"}}
        if operating_system := declared_os(machine_type or "personal", data):
            override["chezmoi"]["os"] = operating_system
        override["chezmoi"] |= data.pop("chezmoi", {})
        if machine_type is not None:
            override["machine_type"] = machine_type
        override |= data
        result = self.command([
            "chezmoi", "--source", str(source), "--config", str(self.config),
            "--destination", str(self.home), "--cache", str(self.work / "cache"),
            "--persistent-state", str(self.work / "state.boltdb"), "--no-tty",
            "--override-data", json.dumps(override),
            "execute-template", "--file", str(ROOT / relative_path),
        ])
        self.assertEqual(result.stderr, b"")
        return result.stdout

    def modifier(self, relative_path, machine_type="personal", *, data=None, source=ROOT):
        script = self.work / Path(relative_path).name.removesuffix(".tmpl")
        script.write_bytes(self.render(relative_path, machine_type, data=data, source=source))
        script.chmod(0o700)
        return [str(script)]
