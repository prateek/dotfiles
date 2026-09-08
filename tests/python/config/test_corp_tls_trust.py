import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys
import unittest

from tests.support.python import ROOT, RepoTestCase

HOOK = "home/.chezmoiscripts/run_after_19-corp-ca-bundle.sh.tmpl"
PLIST = "home/Library/LaunchAgents/com.prateek.gui-corp-ca.plist.tmpl"
PUBLISHER = ROOT / "home/dot_local/bin/executable_corp-ca-gui-env"
LABEL = "com.prateek.gui-corp-ca"

# Real certificates, because the hook decides what to export by parsing them.
# A self-signed CA is a trust anchor macOS would list in its admin trust
# domain; the intermediate and the device-identity leaf are the two shapes
# `security find-certificate -a` also returns and that must not become anchors.
ROOT_CA = """-----BEGIN CERTIFICATE-----
MIIBQzCB6qADAgECAgkAk07kVfUfOmwwCgYIKoZIzj0EAwIwHDEaMBgGA1UEAwwR
VGVzdCBDb3JwIFJvb3QgQ0EwIBcNMjYwOTA4MTcyNDIxWhgPMjEyNjA4MTUxNzI0
MjFaMBwxGjAYBgNVBAMMEVRlc3QgQ29ycCBSb290IENBMFkwEwYHKoZIzj0CAQYI
KoZIzj0DAQcDQgAEpGTUpLhkue4Mr2vs071jdeTQ+fVPUNWKuTXglUd9TDxiBd6R
l8hsiSVZ2+90ZGkpW3nUu3FF6KeDhyVHBGP486MTMBEwDwYDVR0TAQH/BAUwAwEB
/zAKBggqhkjOPQQDAgNIADBFAiBTByYirfG50vLXI5RkfC/PIUaEPw7xKJ8qjgeo
9IiPzgIhALEIy4jp7CPdxj1h6i+cBRT0M5+3ijYRvzplELmHsv4w
-----END CERTIFICATE-----
"""
INTERMEDIATE = """-----BEGIN CERTIFICATE-----
MIIBRzCB7aADAgECAgkA9ZixrawIacowCgYIKoZIzj0EAwIwHDEaMBgGA1UEAwwR
VGVzdCBDb3JwIFJvb3QgQ0EwIBcNMjYwOTA4MTcyNDIxWhgPMjEyNjA4MTUxNzI0
MjFaMB8xHTAbBgNVBAMMFFRlc3QgQ29ycCBJc3N1aW5nIENBMFkwEwYHKoZIzj0C
AQYIKoZIzj0DAQcDQgAEHI2f6c8Wcn36qZu+MHyElsa+mWJPp30+uZRmpqri9CDF
rsX8U422aGak4naZwdgZcmkBWZZ0riHyfRnC65fumKMTMBEwDwYDVR0TAQH/BAUw
AwEB/zAKBggqhkjOPQQDAgNJADBGAiEAzSie2l9vSU2qZblUNqQBkyjopmECVOI8
VQa1SYwU2rECIQDhVB5nvMdwVa2gOHFTXh6De++ode6jXeRhLLRPQJrEMQ==
-----END CERTIFICATE-----
"""
ROTATED_ROOT_CA = """-----BEGIN CERTIFICATE-----
MIICPzCCAeSgAwIBAgIJANGVoynDX+/oMAoGCCqGSM49BAMCMB8xHTAbBgNVBAMM
FFRlc3QgQ29ycCBSb290IENBIEcyMCAXDTI2MDkwODE3MzI1MVoYDzIxMjYwODE1
MTczMjUxWjAfMR0wGwYDVQQDDBRUZXN0IENvcnAgUm9vdCBDQSBHMjCCAUswggED
BgcqhkjOPQIBMIH3AgEBMCwGByqGSM49AQECIQD/////AAAAAQAAAAAAAAAAAAAA
AP///////////////zBbBCD/////AAAAAQAAAAAAAAAAAAAAAP//////////////
/AQgWsY12Ko6k+ez671VdpiGvGUdBrDMU7D2O848PifSYEsDFQDEnTYIhucEk2pm
eOETnSa3gZ9+kARBBGsX0fLhLEJH+Lzm5WOkQPJ3A32BLeszoPShOUXYmMKWT+NC
4v4af5uO5+tKfA+eFivOM1drMV7Oy7ZAaDe/UfUCIQD/////AAAAAP//////////
vOb6racXnoTzucrC/GMlUQIBAQNCAASvvUGmGrAF9hLQym7GxNaFTu0XT6D0R/GO
xTmMQYwEvc2M+ufeupZAWuBI1KFTFL/Ih/h4AYn3uKZkPNY1teyHoxMwETAPBgNV
HRMBAf8EBTADAQH/MAoGCCqGSM49BAMCA0kAMEYCIQCPemG5St1rfT7fYuP5VrFj
s7V2doPQfdIFkvkGGioA+gIhAOv3vp4DE8xD7MVsYTo65x26l2Kyy4JiMH6fySv8
/X8B
-----END CERTIFICATE-----
"""
IDENTITY_LEAF = """-----BEGIN CERTIFICATE-----
MIIBSzCB8aADAgECAgkA5UU7iWbEgBUwCgYIKoZIzj0EAwIwITEfMB0GA1UEAwwW
cGVyc29uQGV4YW1wbGUuaW52YWxpZDAgFw0yNjA5MDgxNzI0MjFaGA8yMTI2MDgx
NTE3MjQyMVowITEfMB0GA1UEAwwWcGVyc29uQGV4YW1wbGUuaW52YWxpZDBZMBMG
ByqGSM49AgEGCCqGSM49AwEHA0IABMjax/F3FFOVHo5PmXGnfFRmn7A4g/9iiTJ+
lK/LlVDPs2C160gRgmk+bDCXfv+NdluMlGJHYpW/4iNZuqgd+v2jEDAOMAwGA1Ud
EwEB/wQCMAAwCgYIKoZIzj0EAwIDSQAwRgIhAOW1NGYl23mQ/A6yzC6bYGRpgK8B
f0gtIR4yqoT5lCBYAiEA2j1/CToxNExcpaNejrlO+V47DihwlU9fBO/V3xGqHgE=
-----END CERTIFICATE-----
"""
KEYCHAIN = INTERMEDIATE + IDENTITY_LEAF + ROOT_CA

# launchd's GUI domain and the System keychain, as files. Both real tools mutate
# machine-wide state a test must never touch. `bootstrap` and `kickstart` really
# execute the job so the launch agent's contract is exercised rather than echoed:
# the wrapper runs through its own shebang, under the environment the plist
# supplies, and its setenv has to land in the same store the test reads back.
TOOLS = r'''#!/usr/bin/env python3
import json, os, pathlib, plistlib, subprocess, sys
root = pathlib.Path(os.environ["CA_TEST_ROOT"])
store = root / "launchd.json"
state = json.loads(store.read_text()) if store.exists() else {"env": {}, "jobs": []}
tool, args = pathlib.Path(sys.argv[0]).name, sys.argv[1:]

if tool == "security":
    if args[:2] != ["find-certificate", "-a"] or args[-1] != "/Library/Keychains/System.keychain":
        raise SystemExit("unexpected security: " + repr(args))
    export = root / "keychain.pem"
    if not export.exists():
        raise SystemExit(1)
    sys.stdout.write(export.read_text())
    raise SystemExit(0)

with (root / "calls").open("a") as out:
    out.write(" ".join([tool, *args]) + "\n")


def run_job(job):
    """Execute a loaded job the way launchd would, from the plist alone."""
    env = {key: os.environ[key] for key in ("HOME", "CA_TEST_ROOT")}
    # The plist pins PATH so the job never inherits a stray one. Keep the fake
    # tools reachable ahead of it; that the pin can resolve launchctl for real
    # is asserted separately against the filesystem.
    pinned = job.get("EnvironmentVariables", {}).get("PATH", "")
    env["PATH"] = os.pathsep.join(
        filter(None, [str(pathlib.Path(sys.argv[0]).resolve().parent), pinned]))
    subprocess.run(job["ProgramArguments"], env=env, check=False)


status = 0
if args[:1] == ["getenv"]:
    value = state["env"].get(args[1])
    if value is not None:
        print(value)
elif args[:1] == ["setenv"]:
    state["env"][args[1]] = args[2]
elif args[:1] == ["unsetenv"]:
    state["env"].pop(args[1], None)
elif args[:1] == ["bootout"]:
    label = args[1].rsplit("/", 1)[-1]
    status = 0 if label in state["jobs"] else 3
    state["jobs"] = [job for job in state["jobs"] if job != label]
elif args[:1] == ["bootstrap"]:
    source = pathlib.Path(args[2])
    job = plistlib.loads(source.read_bytes())
    state["jobs"] = sorted(set(state["jobs"]) | {job["Label"]})
    (root / "jobs").mkdir(exist_ok=True)
    (root / "jobs" / job["Label"]).write_bytes(source.read_bytes())
    store.write_text(json.dumps(state))  # The child writes it next; do not clobber.
    if job.get("RunAtLoad"):
        run_job(job)
    raise SystemExit(0)
elif args[:1] == ["kickstart"]:
    label = args[-1].rsplit("/", 1)[-1]
    if label not in state["jobs"]:
        raise SystemExit(3)
    store.write_text(json.dumps(state))
    run_job(plistlib.loads((root / "jobs" / label).read_bytes()))
    raise SystemExit(0)
elif args[:1] == ["print"]:
    status = 0 if args[1].rsplit("/", 1)[-1] in state["jobs"] else 113
else:
    raise SystemExit("unexpected launchctl: " + repr(args))
store.write_text(json.dumps(state))
raise SystemExit(status)
'''


@unittest.skipUnless(sys.platform == "darwin", "launchd GUI domain trust")
class CorporateTlsTrust(RepoTestCase):
    fixture_prefix = "dotfiles-corp-ca-"

    def setUp(self):
        super().setUp()
        self.bin = self.work / "bin"
        self.bin.mkdir()
        for name in ("launchctl", "security"):
            tool = self.bin / name
            tool.write_text(TOOLS.replace("#!/usr/bin/env python3", "#!" + sys.executable, 1))
            tool.chmod(0o755)
        self.env = dict(self.env, CA_TEST_ROOT=str(self.work),
                        PATH=str(self.bin) + os.pathsep + os.environ["PATH"])
        self.keychain = self.work / "keychain.pem"
        self.keychain.write_text(KEYCHAIN)
        self.bundle = self.home / ".config/certs/corp-ca-bundle.pem"
        self.publisher = self.home / ".local/bin/corp-ca-gui-env"
        self.plist = self.home / f"Library/LaunchAgents/{LABEL}.plist"

    def domain(self):
        store = self.work / "launchd.json"
        return json.loads(store.read_text()) if store.exists() else {"env": {}, "jobs": []}

    def calls(self):
        record = self.work / "calls"
        return record.read_text().splitlines() if record.exists() else []

    def subjects(self, pem):
        """Certificate subjects in file order, as openssl reads them back."""
        end = "-----END CERTIFICATE-----\n"
        return [
            subprocess.run(["/usr/bin/openssl", "x509", "-noout", "-subject"],
                           input=block + end, capture_output=True, text=True,
                           check=True).stdout.split("subject=", 1)[1].strip()
            for block in pem.split(end)[:-1]
        ]

    def install_targets(self, machine="work"):
        """Materialize what chezmoi would write for a TLS-inspected machine."""
        self.publisher.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy(PUBLISHER, self.publisher)
        self.publisher.chmod(0o755)
        self.plist.parent.mkdir(parents=True, exist_ok=True)
        self.plist.write_bytes(self.render(PLIST, machine, data={"chezmoi": {"homeDir": str(self.home)}}))

    def run_publisher(self):
        # Through its own shebang, not an explicit interpreter: launchd execs
        # ProgramArguments directly, so a broken shebang is a real outage.
        return self.command([str(self.publisher)])

    def run_hook(self, machine="work"):
        script = self.work / "hook.sh"
        script.write_bytes(self.render(HOOK, machine, data={"chezmoi": {"os": "darwin"}}))
        return subprocess.run(["/bin/bash", str(script)], env=self.env,
                              capture_output=True, text=True, timeout=120)

    def test_publisher_tracks_the_bundle_and_withdraws_trust_when_it_disappears(self):
        self.install_targets()
        self.bundle.parent.mkdir(parents=True)
        self.bundle.write_text(ROOT_CA)

        self.run_publisher()
        self.assertEqual(self.domain()["env"], {"NODE_EXTRA_CA_CERTS": str(self.bundle)})

        # Idempotent: a second run must not re-announce an unchanged value.
        self.run_publisher()
        self.assertEqual([call for call in self.calls() if call.startswith("launchctl setenv")],
                         [f"launchctl setenv NODE_EXTRA_CA_CERTS {self.bundle}"])

        # A pointer at a deleted bundle makes Node warn and silently drop the
        # extra roots, which is indistinguishable from no corporate trust.
        self.bundle.unlink()
        self.run_publisher()
        self.assertEqual(self.domain()["env"], {})

        (self.work / "calls").unlink()
        self.run_publisher()
        self.assertEqual(self.calls(), ["launchctl getenv NODE_EXTRA_CA_CERTS"])

    def test_only_self_signed_cas_become_node_trust_anchors(self):
        self.install_targets()
        self.assertEqual(self.run_hook().returncode, 0)

        # NODE_EXTRA_CA_CERTS promotes every PEM it is handed to a trust anchor
        # and ignores macOS trust settings, so exporting the whole keychain would
        # let Node terminate a chain at an intermediate macOS does not treat as a
        # root — and would drag the device identity's name and email along too.
        self.assertEqual(self.subjects(KEYCHAIN),
                         ["/CN=Test Corp Issuing CA", "/CN=person@example.invalid",
                          "/CN=Test Corp Root CA"])
        self.assertEqual(self.subjects(self.bundle.read_text()), ["/CN=Test Corp Root CA"])

    def test_apply_regenerates_the_bundle_from_the_keychain_and_loads_the_agent(self):
        self.install_targets()
        result = self.run_hook()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.bundle.read_text(), ROOT_CA)
        self.assertEqual(self.bundle.stat().st_mode & 0o777, 0o644)
        self.assertEqual(self.bundle.parent.stat().st_mode & 0o777, 0o700)
        self.assertEqual(self.domain()["env"], {"NODE_EXTRA_CA_CERTS": str(self.bundle)})
        self.assertEqual(self.domain()["jobs"], [LABEL])
        # Staging happens inside the bundle directory so the swap is a rename;
        # nothing may survive the run.
        self.assertEqual(sorted(p.name for p in self.bundle.parent.iterdir()),
                         ["corp-ca-bundle.pem"])

        # Rotated roots must land on the next apply; a bundle that quietly falls
        # behind fails exactly like a missing one.
        self.keychain.write_text(ROTATED_ROOT_CA)
        self.assertEqual(self.run_hook().returncode, 0)
        self.assertEqual(self.bundle.read_text(), ROTATED_ROOT_CA)

        # An unreadable keychain keeps yesterday's roots rather than removing trust.
        self.keychain.unlink()
        result = self.run_hook()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("System keychain", result.stderr)
        self.assertEqual(self.bundle.read_text(), ROTATED_ROOT_CA)
        self.assertEqual(self.domain()["env"], {"NODE_EXTRA_CA_CERTS": str(self.bundle)})

    def test_a_truncated_export_never_replaces_working_roots(self):
        self.install_targets()
        self.run_hook()
        self.assertEqual(self.bundle.read_text(), ROOT_CA)

        # `security` exiting 0 on a half-written certificate is the failure the
        # marker-only check used to wave through: Node cannot load it, and the
        # symptom is identical to having no corporate trust at all.
        self.keychain.write_text(ROOT_CA[: len(ROOT_CA) // 2])
        result = self.run_hook()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("trust anchors", result.stderr)
        self.assertEqual(self.bundle.read_text(), ROOT_CA)

        # So is a keychain that holds nothing the filter accepts.
        self.keychain.write_text(IDENTITY_LEAF)
        self.assertEqual(self.run_hook().returncode, 0)
        self.assertEqual(self.bundle.read_text(), ROOT_CA)

    def test_launch_agent_publishes_trust_for_every_gui_session(self):
        self.install_targets()
        self.bundle.parent.mkdir(parents=True)
        self.bundle.write_text(ROOT_CA)
        job = plistlib.loads(self.plist.read_bytes())

        # `launchctl setenv` writes to the caller's bootstrap context, so the
        # variable only reaches Dock-launched apps when launchd runs the wrapper
        # itself. Loading the job has to be what publishes it.
        self.assertEqual(self.domain()["env"], {})
        self.command(["launchctl", "bootstrap", "gui/501", str(self.plist)])
        self.assertEqual(self.domain()["env"], {"NODE_EXTRA_CA_CERTS": str(self.bundle)})

        # The pin exists so the job never depends on whatever PATH the GUI
        # domain last inherited; it still has to be able to resolve launchctl.
        self.assertIsNotNone(shutil.which("launchctl", path=job["EnvironmentVariables"]["PATH"]))
        self.assertEqual(job["LimitLoadToSessionType"], "Aqua")
        # One-shot: the job's only output is the session environment, so launchd
        # must not treat each clean exit as a crash to respawn.
        self.assertNotIn("KeepAlive", job)

    def test_leaving_the_feature_withdraws_trust_instead_of_stranding_it(self):
        self.install_targets()
        self.run_hook()
        self.assertEqual(self.domain()["jobs"], [LABEL])

        # chezmoi stops managing the agent when tls_inspection goes off but does
        # not delete it, so the hook has to.
        (self.work / "calls").unlink()
        result = self.run_hook("personal")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.domain(), {"env": {}, "jobs": []})
        self.assertFalse(self.plist.exists())
        self.assertFalse(self.publisher.exists())
        self.assertFalse(self.bundle.exists())

        # And costs nothing on a machine that never had the feature.
        (self.work / "calls").unlink()
        self.assertEqual(self.run_hook("personal").returncode, 0)
        self.assertEqual(self.calls(), [])

    def test_node_trust_reaches_both_shell_startup_paths_only_where_tls_is_inspected(self):
        zsh_dir = Path(self.env["XDG_CONFIG_HOME"]) / "zsh"
        zsh_dir.mkdir(parents=True)
        expected = str(self.home / ".config/certs/corp-ca-bundle.pem")
        Path(expected).parent.mkdir(parents=True)
        Path(expected).write_text(ROOT_CA)
        inherited = str(self.work / "inherited.pem")

        for machine, wanted in (("work", expected), ("personal", "")):
            for source, target in (("dot_zshenv.tmpl", self.home / ".zshenv"),
                                   ("dot_config/zsh/dot_zshenv.tmpl", zsh_dir / ".zshenv")):
                target.write_bytes(self.render(f"home/{source}", machine,
                                               data={"dotfiles_dir": str(ROOT)}))
            for zdotdir in (None, str(zsh_dir)):
                for preset in (None, inherited):
                    with self.subTest(machine=machine, zdotdir=zdotdir, preset=preset):
                        env = dict(self.env)
                        env.pop("NODE_EXTRA_CA_CERTS", None)
                        env.pop("ZDOTDIR", None)
                        if zdotdir:
                            env["ZDOTDIR"] = zdotdir
                        if preset:
                            env["NODE_EXTRA_CA_CERTS"] = preset
                        shell = subprocess.run(["/bin/zsh", "-c", 'printf "%s" "$NODE_EXTRA_CA_CERTS"'],
                                               env=env, capture_output=True, text=True, check=True)
                        self.assertEqual(shell.stdout, preset or wanted)
