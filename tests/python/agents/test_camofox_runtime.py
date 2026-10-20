"""Privacy, artifact and ownership guarantees without downloading a browser in CI."""

import hashlib
import importlib.util
import json
import os
from pathlib import Path
import selectors
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch
import zipfile


ROOT = Path(__file__).resolve().parents[3]
SCRIPT = ROOT / "agent-marketplace/src/utils-agent/skills/browser/scripts/camofox-runtime.py"
spec = importlib.util.spec_from_file_location("camofox_runtime", SCRIPT)
runtime = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runtime)


class CamofoxRuntimeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def fixture(self):
        app = self.root / "app"
        app.mkdir()
        for name in ("package.json", "package-lock.json", "runtime.json"):
            (app / name).write_bytes((runtime.INPUTS / name).read_bytes())
        for name, version in {"@askjo/camofox-browser": "1.18.1", "camoufox-js": "0.11.5", "playwright-core": "1.58.2"}.items():
            path = app / "node_modules" / name
            path.mkdir(parents=True)
            (path / "package.json").write_text(json.dumps({"version": version}))
        (app / runtime.SERVER).write_text("// fixture, never executed\n")
        executable = app / "browser/Camoufox.app/Contents/MacOS/camoufox"
        executable.parent.mkdir(parents=True)
        executable.write_bytes(b"fixture browser bytes")
        resources = app / "browser/Camoufox.app/Contents/Resources"
        (resources / "distribution").mkdir(parents=True)
        (resources / "distribution/policies.json").write_text(json.dumps({"policies": {
            "DisableTelemetry": True, "DisableFirefoxStudies": True,
        }}))
        for parent in (app / "browser", resources):
            (parent / "version.json").write_text('{"version":"152.0.4","release":"beta.30"}')
        self.addCleanup(patch.stopall)
        patch.dict(runtime.PIN, {"executable_sha256": hashlib.sha256(b"fixture browser bytes").hexdigest()}).start()
        return app

    def test_host_optins_do_not_reach_the_child(self):
        state = self.root / "state"
        state.mkdir()
        with patch.dict(os.environ, {
            "CAMOFOX_CRASH_REPORT_ENABLED": "true", "SENTRY_DSN": "host-opt-in",
            "NODE_OPTIONS": "--require host-preload", "PROXY_HOST": "host-proxy",
            "CAMOFOX_PROFILE_DIR": "/someone-elses-state", "PROMETHEUS_ENABLED": "true",
        }):
            env = runtime.child_environment(state, Path(sys.executable))
        observed = json.loads(subprocess.check_output(
            [sys.executable, "-c", "import json,os; print(json.dumps(dict(os.environ)))"], env=env, text=True,
        ))
        self.assertEqual(observed["CAMOFOX_CRASH_REPORT_ENABLED"], "false")
        self.assertEqual(observed["SENTRY_DSN"], "")
        self.assertEqual(observed["PROMETHEUS_ENABLED"], "false")
        self.assertEqual(observed["MOZ_CRASHREPORTER_DISABLE"], "1")
        self.assertNotIn("NODE_OPTIONS", observed)
        self.assertNotIn("PROXY_HOST", observed)
        for key in ("HOME", "TMPDIR", "CAMOFOX_PROFILE_DIR", "CAMOFOX_COOKIES_DIR", "CAMOFOX_UPLOADS_DIR", "CAMOFOX_TRACES_DIR"):
            path = Path(observed[key])
            self.assertTrue(path.is_relative_to(state))
            self.assertEqual(path.stat().st_mode & 0o777, 0o700)

    def test_complete_pinned_fixture_is_accepted(self):
        runtime.validate(self.fixture())

    def test_node_discovery_and_version_probe_do_not_inherit_optins(self):
        bin_dir = self.root / "bin"
        bin_dir.mkdir()
        node = bin_dir / "node"
        for executable, output in ((bin_dir / "mise", str(node)), (node, "v24.12.0")):
            capture = self.root / (executable.name + "-env.json")
            executable.write_text(
                f"#!{sys.executable}\nimport json,os\n"
                f"open({str(capture)!r},'w').write(json.dumps(dict(os.environ)))\n"
                f"print({output!r})\n"
            )
            executable.chmod(0o700)
        with patch.dict(os.environ, {
            "PATH": str(bin_dir) + os.pathsep + os.environ["PATH"],
            "NODE_OPTIONS": "host-preload", "SENTRY_DSN": "host-reporting",
            "CAMOFOX_CRASH_REPORT_ENABLED": "true",
        }):
            self.assertEqual(runtime.node_executable(), node)
        for name in ("mise", "node"):
            observed = json.loads((self.root / (name + "-env.json")).read_text())
            self.assertNotIn("NODE_OPTIONS", observed)
            self.assertNotIn("SENTRY_DSN", observed)
            self.assertNotIn("CAMOFOX_CRASH_REPORT_ENABLED", observed)

    def test_missing_outer_bundle_metadata_is_rejected_before_launch(self):
        app = self.fixture()
        (app / "browser/version.json").unlink()
        with self.assertRaises((RuntimeError, FileNotFoundError)):
            runtime.validate(app)

    def test_modified_browser_bytes_are_rejected(self):
        app = self.fixture()
        (app / runtime.PIN["executable"]).write_bytes(b"unqualified replacement")
        with self.assertRaisesRegex(RuntimeError, "executable"):
            runtime.validate(app)

    def test_incompatible_playwright_is_rejected(self):
        app = self.fixture()
        (app / "node_modules/playwright-core/package.json").write_text('{"version":"1.64.1"}')
        with self.assertRaisesRegex(RuntimeError, "playwright-core"):
            runtime.validate(app)

    def test_enabled_browser_telemetry_is_rejected(self):
        app = self.fixture()
        (app / runtime.PIN["resources"] / "distribution/policies.json").write_text(
            '{"policies":{"DisableTelemetry":false,"DisableFirefoxStudies":true}}'
        )
        with self.assertRaisesRegex(RuntimeError, "telemetry"):
            runtime.validate(app)

    def test_reused_pid_is_not_an_owned_survivor(self):
        self.assertEqual(runtime.alive({42: "original launch"}, {42: (1, "another launch")}), [])
        self.assertEqual(runtime.alive({42: "original launch"}, {42: (1, "original launch")}), [42])


    @unittest.skipUnless(shutil.which("node"), "Requires Node for ownership preload")
    def test_preload_journal_failure_cannot_be_swallowed_by_server(self):
        journal = self.root / "directory-not-journal"
        journal.mkdir()
        for close_stderr in (False, True):
            with self.subTest(close_stderr=close_stderr):
                script = "const cp=require('node:child_process'),fs=require('node:fs');"
                if close_stderr:
                    script += "fs.closeSync(2);"
                script += "try {cp.spawn(process.env.CAMOUFOX_EXECUTABLE,['-c','import time;time.sleep(300)'],{detached:true,stdio:'ignore'});}catch(e){process.exit(0);}"
                env = {"PATH": os.environ["PATH"], "CAMOUFOX_EXECUTABLE": sys.executable,
                       "CAMOFOX_PROCESS_JOURNAL": str(journal)}
                result = subprocess.run([shutil.which("node"), "--import",
                    str(SCRIPT.with_name("camofox-processes.mjs")), "-e", script],
                    env=env, capture_output=True, text=True, timeout=10)
                self.assertEqual(result.returncode, 70, result.stderr)

    def test_invalid_ownership_journals_retain_uncertainty(self):
        journal = self.root / "processes.jsonl"
        cases = [None, "{bad}\n", '{"event":"spawn","pid":42,"group":42}\n',
                 '{"event":"spawn"']
        for contents in cases:
            with self.subTest(contents=contents):
                if contents is not None:
                    journal.write_text(contents)
                tracker = runtime.OwnedProcesses(99, journal)
                with patch.object(runtime, "process_table", return_value={}):
                    self.assertEqual(tracker.sample(complete=True), [])
                self.assertTrue(tracker.errors)

    def test_retired_group_is_not_reacquired_from_old_journal(self):
        journal = self.root / "processes.jsonl"
        journal.write_text('{"event":"spawn","pid":42,"group":42}\n'
                           '{"event":"identity","pid":42,"started":"old"}\n')
        tracker = runtime.OwnedProcesses(99, journal)
        with patch.object(runtime, "process_table", return_value={}):
            tracker.sample(complete=True)
        with patch.object(runtime, "process_table", return_value={42: (1, "replacement", 42)}):
            self.assertEqual(tracker.sample(complete=True), [])
        self.assertNotIn(42, tracker.groups)

    def test_spawn_between_observations_keeps_reparented_group_owned(self):
        journal = self.root / "processes.jsonl"
        journal.touch()
        tracker = runtime.OwnedProcesses(99, journal)

        def snapshot_before_spawn():
            journal.write_text('{"event":"spawn","pid":42,"group":42}\n'
                               '{"event":"identity","pid":42,"started":"launch"}\n')
            return {}

        with patch.object(runtime, "process_table", side_effect=snapshot_before_spawn):
            tracker.sample()
        with patch.object(runtime, "process_table", return_value={43: (1, "child", 42)}):
            self.assertEqual(tracker.sample(complete=True), [43])
        self.assertFalse(tracker.errors)

    def test_reused_server_pid_does_not_enroll_unrelated_descendants(self):
        journal = self.root / "processes.jsonl"
        journal.touch()
        tracker = runtime.OwnedProcesses(99, journal)
        with patch.object(runtime, "process_table", return_value={99: (1, "replacement", 99),
                                                               100: (99, "unrelated", 99)}):
            self.assertEqual(tracker.sample(complete=True), [])
        self.assertFalse(tracker.owned)

    def test_reused_group_leader_is_not_treated_as_owned(self):
        journal = self.root / "processes.jsonl"
        journal.write_text('{"event":"spawn","pid":42,"group":42}\n'
                           '{"event":"identity","pid":42,"started":"old"}\n')
        tracker = runtime.OwnedProcesses(99, journal)
        with patch.object(runtime, "process_table", return_value={42: (1, "replacement", 42)}):
            self.assertEqual(tracker.sample(complete=True), [])
        self.assertTrue(tracker.errors)
        self.assertNotIn(42, tracker.groups)


@unittest.skipUnless(sys.platform == "darwin", "Supervisor uses macOS lsof and ps")
class CamofoxSupervisorTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.home = self.root / "home"
        self.home.mkdir()
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.skill = self.root / "skill/scripts"
        shutil.copytree(SCRIPT.parent, self.skill, ignore=shutil.ignore_patterns("__pycache__"))
        self.script = self.skill / SCRIPT.name
        inputs = self.skill / "camofox"
        pin = json.loads((inputs / "runtime.json").read_text())
        self.browser_bytes = f"#!{sys.executable}\nimport time\ntime.sleep(300)\n".encode()
        pin["executable_sha256"] = hashlib.sha256(self.browser_bytes).hexdigest()
        (inputs / "runtime.json").write_text(json.dumps(pin))
        identity = hashlib.sha256(b"".join((inputs / n).read_bytes() for n in (
            "package.json", "package-lock.json", "runtime.json",
        ))).hexdigest()[:20]
        self.app = self.root / "cache/browser-skill/camofox" / identity
        self.app.mkdir(parents=True)
        for name in ("package.json", "package-lock.json", "runtime.json"):
            shutil.copyfile(inputs / name, self.app / name)
        for name, version in {"@askjo/camofox-browser": "1.18.1", "camoufox-js": "0.11.5", "playwright-core": "1.58.2"}.items():
            target = self.app / "node_modules" / name
            target.mkdir(parents=True)
            (target / "package.json").write_text(json.dumps({"version": version}))
        executable = self.app / pin["executable"]
        executable.parent.mkdir(parents=True)
        executable.write_bytes(self.browser_bytes)
        executable.chmod(0o700)
        resources = self.app / pin["resources"]
        (resources / "distribution").mkdir(parents=True)
        (resources / "distribution/policies.json").write_text(json.dumps({"policies": {
            "DisableTelemetry": True, "DisableFirefoxStudies": True,
        }}))
        for parent in (self.app / "browser", resources):
            (parent / "version.json").write_text('{"version":"152.0.4","release":"beta.30"}')
        server = self.app / runtime.SERVER
        server.write_text(
            "import http.server,json,os,pathlib,signal,subprocess,sys\n"
            "print('fixture startup diagnostic',flush=True)\n"
            f"if pathlib.Path({str(self.root / 'fail-server')!r}).exists():\n"
            " print('x'*70000+'fixture startup diagnostic',flush=True); sys.exit(17)\n"
            "child=subprocess.Popen([sys.executable,'-c','import time; time.sleep(300)'])\n"
            f"pathlib.Path({str(self.root / 'child-owner.json')!r}).write_text(json.dumps({{'pid':child.pid,'started':subprocess.check_output(['/bin/ps','-p',str(child.pid),'-o','lstart='],text=True).strip()}}))\n"
            "pathlib.Path('fixture.json').write_text(json.dumps({'child':child.pid,'env':dict(os.environ)}))\n"
            f"if pathlib.Path({str(self.root / 'fail-after-child')!r}).exists(): sys.exit(18)\n"
            "def terminate(*args):\n"
            f" marker=pathlib.Path({str(self.root / 'late-child')!r})\n"
            " if marker.exists():\n"
            "  late=subprocess.Popen([sys.executable,'-c','import time; time.sleep(300)'])\n"
            f"  pathlib.Path({str(self.root / 'late-owner.json')!r}).write_text(json.dumps({{'pid':late.pid,'started':subprocess.check_output(['/bin/ps','-p',str(late.pid),'-o','lstart='],text=True).strip()}}))\n"
            " sys.exit(int(marker.read_text()) if marker.exists() else 0)\n"
            "signal.signal(signal.SIGTERM,terminate)\n"
            "class Handler(http.server.BaseHTTPRequestHandler):\n"
            " def do_GET(self):\n"
            "  self.send_response(200); self.end_headers(); self.wfile.write(b'{\"ok\":true,\"engine\":\"camoufox\"}')\n"
            " def log_message(self,*args): pass\n"
            "http.server.HTTPServer(('127.0.0.1',int(os.environ['CAMOFOX_PORT'])),Handler).serve_forever()\n"
        )
        self.pristine_modules = self.root / "modules"
        shutil.copytree(self.app / "node_modules", self.pristine_modules)
        node = self.bin / "node"
        node.write_text(f"#!{sys.executable}\nimport os,pathlib,sys,time\n"
                        "if sys.argv[1:]==['--version']:\n"
                        f" if pathlib.Path({str(self.root / 'slow-preflight')!r}).exists():\n"
                        f"  pathlib.Path({str(self.root / 'preflight-started')!r}).touch()\n"
                        "  deadline=time.monotonic()+9\n"
                        f"  while not pathlib.Path({str(self.root / 'preflight-release')!r}).exists() and time.monotonic()<deadline: time.sleep(.01)\n"
                        " print('v24.12.0')\n"
                        "else:\n"
                        " args=sys.argv[1:]\n"
                        " if args[:1]==['--import']: args=args[2:]\n"
                        f" os.execv({sys.executable!r},[{sys.executable!r}]+args)\n")
        node.chmod(0o700)
        mise = self.bin / "mise"
        mise.write_text(f"#!{sys.executable}\nimport json,os,pathlib,sys\n"
                        f"with open({str(self.root / 'mise-calls.jsonl')!r},'a') as f: f.write(json.dumps({{'args':sys.argv[1:],'cwd':os.getcwd()}})+'\\n')\n"
                        f"if pathlib.Path({str(self.root / 'missing-node')!r}).exists(): sys.exit(1)\n"
                        f"print({str(node)!r})\n")
        mise.chmod(0o700)
        npm = self.bin / "npm"
        npm.write_text(f"#!{sys.executable}\nimport pathlib,shutil\n"
                       f"pathlib.Path({str(self.root / 'npm-ran')!r}).touch()\n"
                       f"shutil.copytree({str(self.pristine_modules)!r},pathlib.Path.cwd()/'node_modules')\n")
        npm.chmod(0o700)
        archive = self.root / "browser.zip"
        with zipfile.ZipFile(archive, "w") as bundle:
            for p in (self.app / "browser").rglob("*"):
                if p.is_file(): bundle.write(p, p.relative_to(self.app / "browser"))
        pin["archive_sha256"] = hashlib.sha256(archive.read_bytes()).hexdigest()
        (inputs / "runtime.json").write_text(json.dumps(pin))
        (self.app / "runtime.json").write_text(json.dumps(pin))
        new_identity = hashlib.sha256(b"".join((inputs / n).read_bytes() for n in (
            "package.json", "package-lock.json", "runtime.json",
        ))).hexdigest()[:20]
        destination = self.app.with_name(new_identity)
        self.app.rename(destination)
        self.app = destination
        self.archive = archive
        self.env = {**os.environ, "HOME": str(self.home), "XDG_CACHE_HOME": str(self.root / "cache"),
                    "PATH": str(self.bin) + os.pathsep + os.environ["PATH"],
                    "NODE_OPTIONS": "host-preload", "SENTRY_DSN": "host-reporting",
                    "CAMOFOX_CRASH_REPORT_ENABLED": "true"}
        self.processes = []
        self.receipts = []
        self.owned = {}
        self.helpers = {}
        self.addCleanup(self.stop_owned)

    def command(self, *args):
        return [sys.executable, "-B", str(self.script), *args]

    def invoke(self, *args):
        return subprocess.run(self.command(*args), env=self.env, cwd=self.root,
                              capture_output=True, text=True, timeout=30)

    def event(self, proc, key):
        with selectors.DefaultSelector() as selector:
            selector.register(proc.stdout, selectors.EVENT_READ)
            deadline = time.monotonic() + 15
            while time.monotonic() < deadline:
                self.assertTrue(selector.select(deadline - time.monotonic()), f"No {key} receipt")
                line = proc.stdout.readline()
                if not line:
                    self.fail(f"Exited before {key}: {proc.stderr.read()}")
                receipt = json.loads(line)
                if receipt.get(key): return receipt
        self.fail(f"No {key} receipt")

    def start(self, parent=False):
        command = self.command("run")
        if parent:
            command = [sys.executable, "-c", "import subprocess,sys,time; subprocess.Popen(sys.argv[1:]); time.sleep(300)", *command]
        proc = subprocess.Popen(command, env=self.env, cwd=self.root, text=True,
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE, start_new_session=True)
        self.processes.append(proc)
        ready = self.event(proc, "ready")
        self.receipts.append(ready)
        runtime.remember_children(ready["pid"], self.owned, runtime.process_table())
        return proc, ready

    def stop_owned(self):
        for pid in runtime.alive(self.helpers, runtime.process_table()):
            try: os.kill(pid, signal.SIGTERM)
            except ProcessLookupError: pass
        for name in ("child-owner.json", "late-owner.json"):
            journal = self.root / name
            if journal.exists():
                owner = json.loads(journal.read_text())
                self.owned[owner["pid"]] = owner["started"]
        for receipt in self.receipts:
            try: os.kill(receipt["pid"], signal.SIGTERM)
            except ProcessLookupError: pass
        for proc in self.processes:
            if proc.poll() is None: proc.terminate()
            try: proc.communicate(timeout=15)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.communicate(timeout=5)
            if proc.stdout: proc.stdout.close()
            if proc.stderr: proc.stderr.close()
        for pid in runtime.alive(self.owned, runtime.process_table()):
            try: os.kill(pid, signal.SIGTERM)
            except ProcessLookupError: pass
        deadline = time.monotonic() + 5
        while runtime.alive(self.owned, runtime.process_table()) and time.monotonic() < deadline:
            time.sleep(0.05)
        for pid in runtime.alive(self.owned, runtime.process_table()):
            try: os.kill(pid, signal.SIGKILL)
            except ProcessLookupError: pass
        for receipt in self.receipts:
            shutil.rmtree(receipt["stateDir"], ignore_errors=True)

    def test_signal_shutdown_cleans_descendants_and_private_state(self):
        for sig in (signal.SIGTERM, signal.SIGHUP):
            with self.subTest(signal=sig):
                proc, ready = self.start()
                observed = json.loads((Path(ready["stateDir"]) / "fixture.json").read_text())
                self.assertNotIn("NODE_OPTIONS", observed["env"])
                self.assertEqual(observed["env"]["SENTRY_DSN"], "")
                self.assertEqual(observed["env"]["CAMOFOX_CRASH_REPORT_ENABLED"], "false")
                proc.send_signal(sig)
                cleaned = self.event(proc, "cleaned")
                proc.wait(timeout=10)
                self.assertEqual(proc.returncode, 0)
                self.assertTrue(cleaned["serverStopped"])
                self.assertFalse(Path(ready["stateDir"]).exists())
                for pid in (ready["serverPid"], observed["child"]):
                    with self.assertRaises(ProcessLookupError): os.kill(pid, 0)

    def test_parent_loss_triggers_cleanup(self):
        parent, ready = self.start(parent=True)
        child = json.loads((Path(ready["stateDir"]) / "fixture.json").read_text())["child"]
        parent.kill()
        parent.wait(timeout=5)
        self.assertTrue(self.event(parent, "cleaned")["serverStopped"])
        self.assertFalse(Path(ready["stateDir"]).exists())
        with self.assertRaises(ProcessLookupError): os.kill(ready["serverPid"], 0)
        with self.assertRaises(ProcessLookupError): os.kill(child, 0)

    def test_parent_loss_during_preflight_prevents_server_launch(self):
        (self.root / "slow-preflight").touch()
        journal = self.root / "preflight-helper.pid"
        command = [sys.executable, "-c", "import pathlib,subprocess,sys,time; p=subprocess.Popen(sys.argv[2:]); pathlib.Path(sys.argv[1]).write_text(str(p.pid)); time.sleep(300)", str(journal), *self.command("run")]
        parent = subprocess.Popen(command, env=self.env, cwd=self.root, text=True,
                                  stdout=subprocess.PIPE, stderr=subprocess.PIPE, start_new_session=True)
        self.processes.append(parent)
        deadline = time.monotonic() + 5
        while not (self.root / "preflight-started").exists() and time.monotonic() < deadline:
            time.sleep(0.01)
        self.assertTrue((self.root / "preflight-started").exists())
        helper_pid = int(journal.read_text())
        self.helpers[helper_pid] = runtime.process_table()[helper_pid][1]
        parent.kill()
        parent.wait(timeout=5)
        (self.root / "preflight-release").touch()
        stdout, stderr = parent.communicate(timeout=10)
        self.assertNotIn('"ready": true', stdout)
        self.assertIn("parent", stderr.lower())
        self.assertFalse((self.root / "child-owner.json").exists())

    def test_failed_start_preserves_private_diagnostic(self):
        (self.root / "fail-server").touch()
        result = self.invoke("run")
        self.assertNotEqual(result.returncode, 0)
        receipts = [json.loads(line) for line in result.stdout.splitlines()]
        failure = next(r for r in receipts if "diagnostic" in r)
        diagnostic = Path(failure["diagnostic"])
        self.addCleanup(shutil.rmtree, diagnostic.parent)
        self.assertIn("fixture startup diagnostic", diagnostic.read_text())
        self.assertLessEqual(diagnostic.stat().st_size, 65536)
        self.assertEqual(diagnostic.stat().st_mode & 0o777, 0o600)
        self.assertEqual(diagnostic.parent.stat().st_mode & 0o777, 0o700)
        state = Path(receipts[-1]["stateDir"])
        self.addCleanup(shutil.rmtree, state, True)
        self.assertTrue(state.exists())
        self.assertFalse(receipts[-1]["cleaned"])
        self.assertTrue(receipts[-1]["cleanupUncertain"])
        self.assertIn("17", result.stderr)

    def test_child_spawned_during_shutdown_is_stopped_before_state_deletion(self):
        (self.root / "late-child").write_text("0")
        proc, ready = self.start()
        proc.terminate()
        self.assertTrue(self.event(proc, "cleaned")["serverStopped"])
        proc.wait(timeout=10)
        late = json.loads((self.root / "late-owner.json").read_text())
        self.assertFalse(Path(ready["stateDir"]).exists())
        with self.assertRaises(ProcessLookupError): os.kill(late["pid"], 0)

    def test_failed_shutdown_keeps_recovery_state_and_blocks_repair(self):
        (self.root / "late-child").write_text("17")
        proc, ready = self.start()
        proc.terminate()
        final = self.event(proc, "cleanupUncertain")
        proc.wait(timeout=10)
        self.assertNotEqual(proc.returncode, 0)
        self.assertFalse(final["cleaned"])
        self.assertTrue(Path(ready["stateDir"]).exists())
        repair = self.invoke("install", "--repair", "--archive", str(self.archive))
        self.assertNotEqual(repair.returncode, 0)
        self.assertIn("recover", repair.stderr.lower())
        self.assertFalse((self.root / "npm-ran").exists())

    def test_detached_browser_created_during_shutdown_is_journaled_and_stopped(self):
        self.env["TZ"] = "UTC"
        real_node = shutil.which("node")
        self.assertIsNotNone(real_node, "The macOS test lane supplies Node")
        (self.bin / "node").unlink()
        (self.bin / "node").symlink_to(Path(real_node).resolve())
        script = """
const http = require('node:http');
const fs = require('node:fs');
const cp = require('node:child_process');
http.createServer((req,res)=>res.end(JSON.stringify({ok:true,engine:'camoufox'})))
  .listen(Number(process.env.CAMOFOX_PORT),'127.0.0.1');
process.on('SIGTERM',()=>{
  const child = cp.spawn(process.env.CAMOUFOX_EXECUTABLE,[],{detached:true,stdio:'ignore'});
  child.unref();
  fs.writeFileSync(OWNER,JSON.stringify({pid:child.pid,started:cp.execFileSync('/bin/ps',['-p',String(child.pid),'-o','lstart='],{encoding:'utf8'}).trim()}));
  process.exit(0);
});
""".replace("OWNER", json.dumps(str(self.root / "late-owner.json")))
        (self.app / runtime.SERVER).write_text(script)
        proc, ready = self.start()
        proc.terminate()
        self.assertTrue(self.event(proc, "cleaned")["serverStopped"])
        proc.wait(timeout=10)
        late = json.loads((self.root / "late-owner.json").read_text())
        self.assertFalse(Path(ready["stateDir"]).exists())
        with self.assertRaises(ProcessLookupError): os.kill(late["pid"], 0)

    def test_check_does_not_install_missing_node(self):
        (self.root / "missing-node").touch()
        for command in ("check", "run"):
            result = self.invoke(command)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("install", result.stderr)
        calls = [json.loads(line) for line in (self.root / "mise-calls.jsonl").read_text().splitlines()]
        self.assertTrue(calls)
        self.assertTrue(all(call["args"][0] == "which" for call in calls))
        self.assertTrue(all(Path(call["cwd"]).resolve() == self.home.resolve() for call in calls))

    def test_server_exit_keeps_state_when_descendant_cleanup_is_uncertain(self):
        (self.root / "fail-after-child").touch()
        result = self.invoke("run")
        self.assertNotEqual(result.returncode, 0)
        final = json.loads(result.stdout.splitlines()[-1])
        state = Path(final["stateDir"])
        if state.exists():
            child = json.loads((state / "fixture.json").read_text())["child"]
            table = runtime.process_table()
            if child in table: self.owned[child] = table[child][1]
            self.addCleanup(shutil.rmtree, state, True)
        self.assertFalse(final["cleaned"])
        self.assertTrue(final["cleanupUncertain"])
        self.assertTrue(state.exists())
        for line in result.stdout.splitlines():
            receipt = json.loads(line)
            if "diagnostic" in receipt:
                self.addCleanup(shutil.rmtree, Path(receipt["diagnostic"]).parent)

    def test_repair_refuses_malformed_recovery_lease_before_installing(self):
        leases = self.app.with_suffix(".leases")
        leases.mkdir()
        (leases / "unknown-task.json").write_text("{broken}")
        result = self.invoke("install", "--repair", "--archive", str(self.archive))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("lease", result.stderr.lower())
        self.assertFalse((self.root / "npm-ran").exists())

    def test_repair_replaces_invalid_cache_and_refuses_an_active_runtime(self):
        proc, ready = self.start()
        busy = self.invoke("install", "--repair", "--archive", str(self.archive))
        self.assertNotEqual(busy.returncode, 0)
        self.assertIn("in use", busy.stderr)
        self.assertFalse((self.root / "npm-ran").exists())
        proc.terminate()
        self.event(proc, "cleaned")
        proc.wait(timeout=10)
        pin = json.loads((self.app / "runtime.json").read_text())
        (self.app / pin["executable"]).write_bytes(b"broken")
        before = self.invoke("check")
        self.assertNotEqual(before.returncode, 0)
        self.assertIn(str(self.app), before.stderr)
        invalid_archive = self.root / "invalid.zip"
        invalid_archive.write_bytes(b"not the qualified archive")
        failed = self.invoke("install", "--repair", "--archive", str(invalid_archive))
        self.assertNotEqual(failed.returncode, 0)
        self.assertIn("checksum", failed.stderr)
        self.assertEqual((self.app / pin["executable"]).read_bytes(), b"broken")
        task = ROOT / "home/dot_config/mise/tasks/browser/camofox/executable_install"
        repaired = subprocess.run(
            ["bash", str(task), "--repair", "--archive", str(self.archive)],
            env={**self.env, "BROWSER_SKILL_DIR": str(self.skill.parent)}, cwd=self.root,
            capture_output=True, text=True, timeout=30,
        )
        self.assertEqual(repaired.returncode, 0, repaired.stderr)
        checked = self.invoke("check")
        self.assertEqual(checked.returncode, 0, checked.stderr)
        self.assertTrue(json.loads(checked.stdout)["verified"])


if __name__ == "__main__":
    unittest.main()
