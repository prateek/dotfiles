#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14"
# dependencies = []
# ///
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / "scripts/storage/ensure-code-volume"
HOOK = ROOT / "home/.chezmoitemplates/host-mounts.sh.tmpl"
UUID = "8C16DA8F-1B9B-4ADC-9C7D-EFA8FF8B15D7"

TOOLS = r'''#!/usr/bin/env python3
import json, os, pathlib, plistlib, subprocess, sys
root = pathlib.Path(os.environ["MOUNT_TEST_ROOT"])
state_file = root / "state.json"
state = json.loads(state_file.read_text())
tool, args = pathlib.Path(sys.argv[0]).name, sys.argv[1:]
target = state["target"]
def save():
    state_file.write_text(json.dumps(state))
def event(name):
    with (root / "events").open("a") as out:
        out.write(name + "\n")
if tool == "id":
    print("0")
elif tool == "stat":
    if args != ["/etc/fstab"]:
        raise SystemExit("unexpected stat: " + repr(args))
    raise SystemExit(0 if (root / "fstab").exists() else 1)
elif tool == "cat":
    if not args:
        sys.stdout.buffer.write(sys.stdin.buffer.read())
    else:
        path = root / "fstab" if args == ["/etc/fstab"] else pathlib.Path(args[0])
        sys.stdout.buffer.write(path.read_bytes())
elif tool == "sudo":
    event("sudo")
    if args[:1] == ["env"]:
        os.execvpe("env", args, os.environ)
    elif args[:1] == ["mkdir"] and args[-1] == target:
        pathlib.Path(target).mkdir(exist_ok=True)
    elif args[:1] == ["chown"] and args[-1] == target:
        pass
    elif args[:1] == ["chmod"] and args[-1] == target:
        os.chmod(target, int(args[1], 8))
    elif args[:2] == ["diskutil", "enableOwnership"]:
        os.execvpe("diskutil", args, os.environ)
    else:
        raise SystemExit("unexpected sudo: " + repr(args))
elif tool == "vifs":
    event("vifs")
    (root / "fstab").touch(exist_ok=True)
    if state.get("fstab_race"):
        (root / "fstab").write_text("LABEL=other " + target + " apfs rw 0 0\n")
    raise SystemExit(subprocess.call([os.environ["EDITOR"], str(root / "fstab")]))
elif tool == "diskutil":
    if args[:2] == ["info", "-plist"]:
        event("info")
        if args[2] == state["uuid"] and not state.get("present", True):
            raise SystemExit(1)
        if args[2] == state["uuid"] or (args[2] == target and state["mounted_at"] == target):
            info = {"VolumeUUID": state["uuid"], "FilesystemType": "apfs", "Internal": False,
                    "WritableVolume": True, "Locked": False, "GlobalPermissionsEnabled": True,
                    "MountPoint": state["mounted_at"]}
            info.update(state.get("info", {}))
        else:
            info = {"VolumeUUID": "OTHER", "FilesystemType": "apfs", "Internal": True,
                    "MountPoint": target if state.get("wrong_mount") else "/"}
        sys.stdout.buffer.write(plistlib.dumps(info))
    elif args == ["unmount", state["uuid"]]:
        event("unmount")
        if state.get("busy"):
            raise SystemExit("volume busy")
        state["mounted_at"] = ""
        save()
    elif args == ["mount", "-mountPoint", target, state["uuid"]]:
        event("mount")
        state["mounted_at"] = target
        pathlib.Path(target).mkdir(exist_ok=True)
        os.chmod(target, 0o700)
        save()
    elif args == ["enableOwnership", state["uuid"]]:
        event("ownership")
        state.setdefault("info", {})["GlobalPermissionsEnabled"] = True
        save()
    else:
        raise SystemExit("unexpected diskutil: " + repr(args))
else:
    raise SystemExit("unexpected tool: " + tool)
'''


@unittest.skipUnless(sys.platform == "darwin", "macOS mount helper")
class HostMounts(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.target = self.root / "home/code"
        self.target.parent.mkdir()
        self.bin = self.root / "bin"
        self.bin.mkdir()
        for name in ("id", "stat", "cat", "sudo", "vifs", "diskutil"):
            tool = self.bin / name
            tool.write_text(TOOLS.replace("#!/usr/bin/env python3", "#!" + sys.executable, 1))
            tool.chmod(0o755)
        self.env = dict(os.environ, MOUNT_TEST_ROOT=str(self.root),
                        PATH=str(self.bin) + os.pathsep + os.environ["PATH"],
                        HOME=str(self.target.parent),
                        XDG_CONFIG_HOME=str(self.root / "config"),
                        XDG_CACHE_HOME=str(self.root / "cache"),
                        XDG_STATE_HOME=str(self.root / "state"),
                        DOTFILES_SKIP_PLIST_HOOKS="1", DOTFILES_SKIP_LAUNCHCTL_SYNC="1")
        self.state = dict(uuid=UUID, target=str(self.target), mounted_at=str(self.target))
        self.target.mkdir()
        self.entry = f"UUID={UUID} {self.target} apfs rw 0 0\n"
        self.fstab = self.root / "fstab"
        self.fstab.write_text("# retained configuration\n" + self.entry)

    def run_helper(self, **changes):
        self.state.update(changes)
        (self.root / "state.json").write_text(json.dumps(self.state))
        result = subprocess.run(["/bin/bash", str(HELPER), UUID, str(self.target)],
                                env=self.env, capture_output=True, text=True)
        self.state = json.loads((self.root / "state.json").read_text())
        return result

    def mutations(self):
        events = self.root / "events"
        return [line for line in events.read_text().splitlines() if line != "info"] if events.exists() else []

    def test_healthy_mount_is_unchanged_on_repeated_runs(self):
        before = self.fstab.read_bytes()
        for _ in range(2):
            result = self.run_helper()
            self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.fstab.read_bytes(), before)
        self.assertEqual(self.mutations(), [])

    def test_check_mode_refuses_repair_without_mutating(self):
        self.state["mounted_at"] = ""
        (self.root / "state.json").write_text(json.dumps(self.state))
        result = subprocess.run(["/bin/bash", str(HELPER), "--check", UUID, str(self.target)],
                                env=self.env, capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("needs setup", result.stderr)
        self.assertEqual(self.mutations(), [])

    def test_missing_fstab_is_created_once(self):
        self.fstab.unlink()
        result = self.run_helper()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.fstab.read_text().strip(), self.entry.strip())
        again = self.run_helper()
        self.assertEqual(again.returncode, 0, again.stderr)
        self.assertEqual(self.mutations().count("vifs"), 1)

    def test_disabled_ownership_is_enabled_without_remounting(self):
        result = self.run_helper(info={"GlobalPermissionsEnabled": False})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(self.state["info"]["GlobalPermissionsEnabled"])
        self.assertNotIn("unmount", self.mutations())
        self.assertNotIn("mount", self.mutations())

    def test_mounts_existing_volume_and_preserves_unrelated_fstab_entries(self):
        unrelated = "# custom entry\nLABEL=Other /Volumes/Other apfs rw 0 0\n"
        self.fstab.write_text(unrelated)
        self.target.rmdir()
        result = self.run_helper(mounted_at="/Volumes/Code")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.state["mounted_at"], str(self.target))
        self.assertIn(unrelated, self.fstab.read_text())
        self.assertEqual(self.fstab.read_text().count(self.entry), 1)
        again = self.run_helper()
        self.assertEqual(again.returncode, 0, again.stderr)
        self.assertEqual(self.mutations().count("mount"), 1)

    def test_unsafe_volume_states_stop_before_changes(self):
        for changes, message in (({"present": False}, "unavailable"),
                                 ({"info": {"Internal": True}}, "internal disk"),
                                 ({"info": {"FilesystemType": "hfs"}}, "must use APFS"),
                                 ({"info": {"Locked": True}}, "is locked"),
                                 ({"info": {"WritableVolume": False}}, "not writable"),
                                 ({"info": {"VolumeUUID": "OTHER"}}, "identity does not match")):
            with self.subTest(changes=changes):
                self.state.update(present=True, info={})
                result = self.run_helper(**changes)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(message, result.stderr)
                self.assertEqual(self.mutations(), [])

    def test_local_data_symlinks_and_other_mounts_are_not_hidden(self):
        (self.target / "uncommitted.txt").write_text("keep me")
        result = self.run_helper(mounted_at="")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("contains local files", result.stderr)
        self.assertEqual((self.target / "uncommitted.txt").read_text(), "keep me")
        (self.target / "uncommitted.txt").unlink()
        self.target.rmdir()
        self.target.symlink_to(self.target.parent)
        result = self.run_helper()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("is a symlink", result.stderr)
        self.target.unlink()
        self.target.mkdir()
        result = self.run_helper(wrong_mount=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Another volume occupies", result.stderr)
        self.assertEqual(self.mutations(), [])

    def test_busy_volume_is_not_forced_offline(self):
        result = self.run_helper(mounted_at="/Volumes/Code", busy=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("SSD is busy", result.stderr)
        self.assertEqual(self.state["mounted_at"], "/Volumes/Code")
        self.assertNotIn("mount", self.mutations())

    def test_conflicting_and_duplicate_fstab_entries_are_preserved(self):
        for content in (self.entry * 2, f"LABEL=Other {self.target} apfs rw 0 0\n",
                        f"UUID={UUID} /elsewhere apfs rw 0 0\n"):
            with self.subTest(content=content):
                self.fstab.write_text(content)
                result = self.run_helper()
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("Conflicting or duplicate", result.stderr)
                self.assertEqual(self.fstab.read_text(), content)
                self.assertEqual(self.mutations(), [])

    def test_fstab_is_checked_again_under_vifs_lock(self):
        self.fstab.write_text("")
        result = self.run_helper(fstab_race=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Conflicting or duplicate", result.stderr)
        self.assertIn("vifs", self.mutations())
        self.assertNotIn(UUID, self.fstab.read_text())
        self.assertNotIn("mount", self.mutations())

    def chezmoi_fixture(self):
        source = self.root / "source"
        for directory in (".chezmoitemplates", ".chezmoidata", ".chezmoiscripts"):
            (source / directory).mkdir(parents=True)
        shutil.copy(ROOT / "home/.chezmoitemplates/features.tmpl", source / ".chezmoitemplates")
        shutil.copy(ROOT / "home/.chezmoidata/machines.toml", source / ".chezmoidata")
        shutil.copy(HOOK, source / ".chezmoitemplates")
        modifier = source / "modify_result"
        modifier.write_text('#!/bin/bash\nprintf computed >"$MOUNT_TEST_ROOT/modifier-ran"\nprintf result\n')
        modifier.chmod(0o755)
        downstream = source / ".chezmoiscripts/run_once_before_00-homebrew.sh"
        downstream.write_text('#!/bin/bash\nprintf ran >"$MOUNT_TEST_ROOT/downstream-ran"\n')
        config = self.root / "chezmoi.toml"
        config.write_text(f'''sourceDir = {json.dumps(str(source))}
[data]
dotfiles_dir = {json.dumps(str(ROOT))}
machine_type = "ci"
[data.machines_local]
code_volume_uuid = "{UUID}"
[hooks.apply.pre]
command = {json.dumps(str(ROOT / "scripts/chezmoi-hooks/plist-hooks.sh"))}
args = ["pre"]
''')
        return [shutil.which("chezmoi"), "--config", str(config), "--destination", str(self.target.parent),
                "--cache", str(self.root / "chezmoi-cache"), "--persistent-state", str(self.root / "state.boltdb"),
                "--no-tty"]

    def test_apply_blocks_modifiers_and_later_setup_when_ssd_is_missing(self):
        command = self.chezmoi_fixture()
        self.state["present"] = False
        (self.root / "state.json").write_text(json.dumps(self.state))
        result = subprocess.run(command + ["apply"], env=self.env, capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("unavailable", result.stderr)
        self.assertFalse((self.root / "modifier-ran").exists())
        self.assertFalse((self.root / "downstream-ran").exists())
        self.assertFalse((self.target.parent / "result").exists())
        self.assertEqual(self.mutations(), [])

    def test_apply_reconciles_before_modifiers_and_checks_again_on_next_apply(self):
        command = self.chezmoi_fixture()
        self.state["mounted_at"] = ""
        self.fstab.write_text("")
        (self.root / "state.json").write_text(json.dumps(self.state))
        result = subprocess.run(command + ["apply"], env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.root / "modifier-ran").exists())
        self.assertTrue((self.root / "downstream-ran").exists())
        self.assertEqual((self.target.parent / "result").read_text(), "result")
        state = json.loads((self.root / "state.json").read_text())
        self.assertEqual(state["mounted_at"], str(self.target))
        status = subprocess.run(command + ["status"], env=self.env, capture_output=True, text=True)
        self.assertEqual(status.returncode, 0, status.stderr)
        self.assertEqual(status.stdout, "")
        state["present"] = False
        (self.root / "state.json").write_text(json.dumps(state))
        (self.root / "modifier-ran").unlink()
        again = subprocess.run(command + ["apply"], env=self.env, capture_output=True, text=True)
        self.assertNotEqual(again.returncode, 0)
        self.assertIn("unavailable", again.stderr)
        self.assertFalse((self.root / "modifier-ran").exists())

    def test_attached_option_values_cannot_disable_the_mount_check(self):
        command = self.chezmoi_fixture()
        config = self.root / "config.toml"
        Path(command[2]).rename(config)
        self.state["present"] = False
        (self.root / "state.json").write_text(json.dumps(self.state))
        for prefix, flags in (("-c", []), ("-vc", []), ("-c", ["-xexternals"]),
                              ("-nc", ["--dry-run=false"])):
            with self.subTest(prefix=prefix, flags=flags):
                invocation = [command[0], prefix + str(config), *command[3:], "apply", *flags]
                result = subprocess.run(invocation, env=self.env, capture_output=True, text=True)
                self.assertNotEqual(result.returncode, 0, result.stderr)
                self.assertIn("unavailable", result.stderr)
                self.assertFalse((self.root / "modifier-ran").exists())
                self.assertFalse((self.root / "downstream-ran").exists())
                self.assertFalse((self.target.parent / "result").exists())

    def test_dry_run_does_not_reconcile_mounts(self):
        command = self.chezmoi_fixture()
        self.state["present"] = False
        (self.root / "state.json").write_text(json.dumps(self.state))
        result = subprocess.run(command + ["apply", "--dry-run"], env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse((self.root / "events").exists())

    def test_json_data_cannot_disable_the_mount_check(self):
        command = self.chezmoi_fixture()
        self.state["present"] = False
        (self.root / "state.json").write_text(json.dumps(self.state))
        for text in ('words -n words', 'words --dry-run words', 'quote " -nv \\ end'):
            with self.subTest(text=text):
                result = subprocess.run(command + ["--override-data", json.dumps({"note": text}), "apply"],
                                        env=self.env, capture_output=True, text=True)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("unavailable", result.stderr)
                self.assertFalse((self.root / "modifier-ran").exists())

    def test_last_dry_run_flag_controls_mount_reconciliation(self):
        command = self.chezmoi_fixture()
        self.state["present"] = False
        (self.root / "state.json").write_text(json.dumps(self.state))
        for flags, dry_run in ((["-nv"], True), (["--dry-run=false", "-n"], True),
                               (["-n", "--dry-run=false"], False), (["-n=false"], False),
                               (["-nv=false"], True), (["-vn=false"], False)):
            with self.subTest(flags=flags):
                result = subprocess.run(command + ["apply", *flags], env=self.env, capture_output=True, text=True)
                self.assertEqual(result.returncode == 0, dry_run, result.stderr)
                if not dry_run:
                    self.assertIn("unavailable", result.stderr)

    def test_configured_storage_paths_reach_both_shell_startup_paths(self):
        config = self.root / "empty.toml"
        config.write_text("")
        tart = str(self.root / "unmounted/vms/tart")
        artifacts = str(self.root / "unmounted/artifacts/winmux")
        data = dict(machine_type="ci", dotfiles_dir=str(ROOT),
                    machines_local=dict(tart_home=tart, winmux_e2e_artifact_root=artifacts))
        zsh_dir = Path(self.env["XDG_CONFIG_HOME"]) / "zsh"
        zsh_dir.mkdir(parents=True)
        for source, target in (("dot_zshenv.tmpl", self.target.parent / ".zshenv"),
                               ("dot_config/zsh/dot_zshenv.tmpl", zsh_dir / ".zshenv")):
            render = subprocess.run([shutil.which("chezmoi"), "--config", str(config),
                                     "--source", str(ROOT), "--override-data", json.dumps(data),
                                     "execute-template", "--file", str(ROOT / "home" / source)],
                                    env=self.env, capture_output=True, text=True, check=True)
            target.write_text(render.stdout)
        for inherited in (False, True):
            for override in (None, str(self.root / "chosen-tart")):
                with self.subTest(inherited=inherited, override=override):
                    env = dict(self.env)
                    for key in ("TART_HOME", "WINMUX_E2E_ARTIFACT_ROOT", "ZDOTDIR"):
                        env.pop(key, None)
                    if inherited:
                        env["ZDOTDIR"] = str(zsh_dir)
                    if override:
                        env["TART_HOME"] = override
                    shell = subprocess.run(["/bin/zsh", "-c", 'printf "%s\\n%s\\n" "$TART_HOME" "$WINMUX_E2E_ARTIFACT_ROOT"'],
                                           env=env, capture_output=True, text=True, check=True)
                    self.assertEqual(shell.stdout.splitlines(), [override or tart, artifacts])
        self.assertFalse(Path(tart).exists())
        self.assertFalse(Path(artifacts).exists())

    def test_first_init_apply_checks_storage_before_modifiers(self):
        command = self.chezmoi_fixture()
        config = self.root / "chezmoi.toml"
        (self.root / "source/.chezmoi.toml.tmpl").write_text(config.read_text())
        config.unlink()
        self.state["present"] = False
        (self.root / "state.json").write_text(json.dumps(self.state))
        result = subprocess.run(command + ["init", "--source", str(self.root / "source"), "--apply"],
                                env=self.env, capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("unavailable", result.stderr)
        self.assertFalse((self.root / "modifier-ran").exists())
        self.assertFalse((self.root / "downstream-ran").exists())

    def test_apply_preserves_inline_and_file_data_overrides(self):
        command = self.chezmoi_fixture()
        self.state["present"] = False
        (self.root / "state.json").write_text(json.dumps(self.state))
        value = dict(machines_local=dict(run_install_scripts=False),
                     description='two words, "quotes", and $(touch SHOULD_NOT_RUN)')
        override_file = self.root / "override data.json"
        override_file.write_text(json.dumps(value))
        for args in (["--override-data", json.dumps(value)],
                     ["--override-data=" + json.dumps(value)],
                     ["--override-data-file", str(override_file)],
                     ["--override-data-file=" + str(override_file)],
                     ["--override-data-file", override_file.name]):
            with self.subTest(args=args[:1]):
                result = subprocess.run(command + args + ["apply"], env=self.env,
                                        capture_output=True, text=True, cwd=self.root)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertFalse((self.root / "events").exists())
                self.assertFalse((self.root / "SHOULD_NOT_RUN").exists())

    def test_hook_is_scoped_to_configured_macos_hosts(self):
        config = self.root / "empty.toml"
        config.write_text("")
        cases = (("m4mini", "darwin", True, True),
                 ("unconfigured-host", "darwin", True, False),
                 ("m4mini", "linux", True, False),
                 ("m4mini", "darwin", False, False))
        for host, operating_system, install, expected in cases:
            with self.subTest(host=host, operating_system=operating_system, install=install):
                data = dict(machine_type="ci", dotfiles_dir=str(ROOT),
                            machines_local=dict(run_install_scripts=install),
                            chezmoi=dict(hostname=host, os=operating_system))
                result = subprocess.run([shutil.which("chezmoi"), "--config", str(config),
                                         "--source", str(ROOT), "--override-data", json.dumps(data),
                                         "execute-template", "--file", str(HOOK)],
                                        env=self.env, capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(bool(result.stdout.strip()), expected)
                if expected:
                    syntax = subprocess.run(["/bin/bash", "-n"], input=result.stdout,
                                            capture_output=True, text=True)
                    self.assertEqual(syntax.returncode, 0, syntax.stderr)


if __name__ == "__main__":
    unittest.main()
