import fcntl
import hashlib
import io
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import shutil
import sys
import tarfile
import threading

from tests.support.python import ROOT, RepoTestCase


class FirefoxSettingsTests(RepoTestCase):
    def setUp(self):
        super().setUp()
        self.work = self.work.resolve()
        self.source = self.work / "settings"
        shutil.copytree(ROOT / "home/dot_config/firefox", self.source)
        self.firefox = self.work / "Firefox"
        self.app = self.work / "Firefox.app"
        (self.app / "Contents/Resources").mkdir(parents=True)
        self.archive = self.work / "ultima.tar.gz"
        self.upstream = {
            "userChrome.css": b'@import url(customChrome.css);',
            "userContent.css": b'@import url(customContent.css);',
            "theme/layout.css": b'/* upstream layout */',
            "userchromejs/firefox/config.js": b"// loader\nlockPref('xpinstall.signatures.required', false);\nlockPref('extensions.install_origins.enabled', false);\n",
            "userchromejs/firefox/defaults/pref/config-prefs.js": b'pref("test.loader", true);',
        }
        self.make_archive(self.upstream)
        self.profile = self.firefox / "Profiles/dotfiles-sage"

    def make_archive(self, files):
        with tarfile.open(self.archive, "w:gz") as archive:
            for name, data in files.items():
                member = tarfile.TarInfo("upstream/" + name)
                member.size = len(data)
                archive.addfile(member, io.BytesIO(data))
        lock = json.loads((self.source / "ultima.lock.json").read_text())
        lock["sha256"] = hashlib.sha256(self.archive.read_bytes()).hexdigest()
        (self.source / "ultima.lock.json").write_text(json.dumps(lock))

    def install(self, *args, status=0, env=None):
        return self.command([
            sys.executable, str(ROOT / "scripts/firefox/install-settings"),
            "--source", str(self.source), "--firefox-root", str(self.firefox),
            "--app", str(self.app), "--archive", str(self.archive), *args,
        ], expected_status=status, env=env)

    def test_fresh_install_is_empty_and_repeat_preserves_browsing_data(self):
        self.install()
        self.assertIn("Name=Sage", (self.firefox / "profiles.ini").read_text())
        self.assertIn("StartWithLastProfile=0", (self.firefox / "profiles.ini").read_text())
        self.assertTrue((self.profile / "chrome/customChrome.css").exists())
        self.assertEqual((self.app / "Contents/Resources/config.js").read_bytes(), b'// loader\n')
        user_js = self.profile / "user.js"
        self.assertIn('user_pref("datareporting.healthreport.uploadEnabled", false)', user_js.read_text())
        for name in ("sessionstore.jsonlz4", "places.sqlite", "cookies.sqlite", "logins.json", "storage/default/extension/idb"):
            target = self.profile / name
            self.assertFalse(target.exists())
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(b"private sentinel\x00\xff")
        user_js.write_text(user_js.read_text() + 'user_pref("user.owns.this", "keep");\n')
        before = {p: (p.read_bytes(), p.stat().st_mtime_ns) for p in self.profile.rglob("*") if p.is_file()}
        result = self.install()
        self.assertIn('"changedFiles": 0', result.stdout.decode())
        for path, expected in before.items():
            self.assertEqual((path.read_bytes(), path.stat().st_mtime_ns), expected)

    def test_previews_do_not_write_and_bad_checksum_fails_before_install(self):
        self.install("--dry-run")
        self.assertFalse(self.firefox.exists())
        self.archive.write_bytes(b"bad download")
        failure = self.install(status=1)
        self.assertIn(b"checksum mismatch", failure.stderr)
        self.assertFalse(self.firefox.exists())

    def test_update_preserves_local_preferences_and_backs_up_replaced_settings(self):
        self.install()
        user_js = self.profile / "user.js"
        user_js.write_text('// local header\n' + user_js.read_text() + 'user_pref("user.local", 42);\n')
        before = user_js.read_bytes()
        (self.source / "user.js").write_text('user_pref("browser.startup.page", 3);\n')
        self.install()
        self.assertTrue(user_js.read_text().startswith('// local header\n'))
        self.assertTrue(user_js.read_text().endswith('user_pref("user.local", 42);\n'))
        self.assertEqual(user_js.read_text().count('// BEGIN DOTFILES FIREFOX'), 1)
        backups = list((self.work / "state/dotfiles/captures/firefox-settings").glob("*/manifest.json"))
        self.assertEqual(len(backups), 1)
        manifest = json.loads(backups[0].read_text())
        entry = next(k for k, v in manifest.items() if Path(v).resolve() == user_js.resolve())
        self.assertEqual((backups[0].parent / entry).read_bytes(), before)

    def test_existing_theme_and_loader_conflicts_do_not_overwrite(self):
        self.profile.mkdir(parents=True)
        chrome = self.profile / "chrome"
        chrome.mkdir()
        (chrome / "userChrome.css").write_text('/* user theme */')
        failure = self.install("--profile", str(self.profile), status=3)
        self.assertIn(b"unmanaged", failure.stderr)
        self.assertFalse((self.profile / "user.js").exists())
        loader = self.app / "Contents/Resources/config.js"
        loader.write_text('// another owner')
        (chrome / 'userChrome.css').write_bytes(self.upstream['userChrome.css'])
        failure = self.install("--profile", str(self.profile), status=3)
        self.assertIn(b"config.js", failure.stderr)
        self.assertEqual(loader.read_text(), '// another owner')
        self.assertEqual((chrome / "userChrome.css").read_bytes(), self.upstream['userChrome.css'])

    def test_live_profile_lock_and_local_edits_are_preserved(self):
        self.install()
        new_css = self.source / "customChrome.css"
        new_css.write_text(new_css.read_text() + '\n/* revision */\n')
        original = (self.profile / "chrome/customChrome.css").read_bytes()
        with (self.profile / ".parentlock").open("a+b") as lock:
            fcntl.lockf(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            self.install(status=2)
        self.assertEqual((self.profile / "chrome/customChrome.css").read_bytes(), original)
        (self.profile / "chrome/customChrome.css").write_text('/* local edit */')
        failure = self.install(status=3)
        self.assertIn(b"Locally edited managed", failure.stderr)
        self.assertEqual((self.profile / "chrome/customChrome.css").read_text(), '/* local edit */')

    def test_ambiguous_profiles_and_symlinked_theme_destinations_fail_closed(self):
        self.firefox.mkdir()
        (self.firefox / "profiles.ini").write_text('[Profile0]\nPath=Profiles/one\n[Profile1]\nPath=Profiles/two\n')
        failure = self.install(status=3)
        self.assertIn(b"unambiguous", failure.stderr)
        self.profile.mkdir(parents=True)
        outside = self.work / "outside"
        outside.mkdir()
        (self.profile / "chrome").symlink_to(outside)
        failure = self.install("--profile", str(self.profile), status=3)
        self.assertIn(b"symlink", failure.stderr)
        self.assertEqual(list(outside.iterdir()), [])

    def test_adoption_preview_lists_replacements_and_preserves_unmanaged_scripts(self):
        self.profile.mkdir(parents=True)
        chrome = self.profile / "chrome"
        chrome.mkdir()
        (chrome / "userChrome.css").write_text('/* user theme */')
        scripts = chrome / "userchromejs/scripts/ffu"
        scripts.mkdir(parents=True)
        extra = scripts / "personal.ffu.js"
        extra.write_text("// personal")
        old_motion = scripts / "arc-sidebar-motion.ffu.js"
        old_motion.write_bytes((self.source / "sidebar-motion.ffu.js").read_bytes())
        loader = self.app / "Contents/Resources/config.js"
        loader.write_text('// old loader')
        result = self.install("--profile", str(self.profile), "--adopt-theme", "--dry-run")
        preview = json.loads(result.stdout)
        actions = {item["path"]: item["action"] for item in preview["changes"]}
        self.assertEqual(actions[str(loader)], "replace")
        self.assertEqual(actions[str(old_motion)], "delete")
        self.assertEqual(actions[str(self.profile / "user.js")], "create")
        self.assertEqual(preview["unmanagedScripts"], [str(extra)])
        self.assertEqual(loader.read_text(), '// old loader')
        self.install("--profile", str(self.profile), "--adopt-theme")
        self.assertEqual(loader.read_bytes(), b"// loader\n")
        self.assertFalse(old_motion.exists())
        self.assertEqual(extra.read_text(), "// personal")
        backups = list((self.work / "state/dotfiles/captures/firefox-settings").glob("*/manifest.json"))
        saved = json.loads(backups[0].read_text())
        entry = next(k for k, v in saved.items() if Path(v) == loader)
        self.assertEqual((backups[0].parent / entry).read_bytes(), b"// old loader")

    def test_loader_upgrades_preserve_local_edits_and_restore_after_app_update(self):
        self.install()
        loader = self.app / "Contents/Resources/config.js"
        self.upstream["userchromejs/firefox/config.js"] = b"// upgraded loader\n"
        self.make_archive(self.upstream)
        self.install()
        self.assertEqual(loader.read_bytes(), b"// upgraded loader\n")
        loader.write_bytes(b"// local edit")
        failure = self.install(status=3)
        self.assertIn(b"Locally edited", failure.stderr)
        self.assertEqual(loader.read_bytes(), b"// local edit")
        loader.unlink()
        self.install()
        self.assertEqual(loader.read_bytes(), b"// upgraded loader\n")

    def test_reformatted_security_disables_are_rejected_before_writes(self):
        self.upstream["userchromejs/firefox/config.js"] = b'lockPref( "xpinstall.signatures.required", false );'
        self.make_archive(self.upstream)
        failure = self.install(status=1)
        self.assertIn(b"security", failure.stderr)
        self.assertFalse(self.firefox.exists())

    def test_running_browser_allows_previews_and_noops_but_defers_changes(self):
        self.install()
        commands = self.work / "bin"
        commands.mkdir()
        ps = commands / "ps"
        ps.write_text("#!/bin/sh\nprintf '%s\\n' '" + str(self.app / "Contents/MacOS/firefox") + "'\n")
        ps.chmod(0o700)
        env = {"PATH": str(commands) + ":" + self.env["PATH"]}
        self.install(env=env)
        css = self.source / "customChrome.css"
        css.write_text(css.read_text() + "/* update */")
        before = (self.profile / "chrome/customChrome.css").read_bytes()
        self.install("--dry-run", env=env)
        self.install(status=2, env=env)
        self.assertEqual((self.profile / "chrome/customChrome.css").read_bytes(), before)

    def test_interrupted_first_install_resumes_without_adoption_or_registry_edits(self):
        injection = self.work / "fault"
        injection.mkdir()
        (injection / "sitecustomize.py").write_text(
            "import os\nfrom pathlib import Path\noriginal = os.replace\n"
            "def replace(src, dst, *args, **kwargs):\n"
            "    result = original(src, dst, *args, **kwargs)\n"
            "    if Path(dst).name == os.environ['INTERRUPT_FILE']: os._exit(91)\n"
            "    return result\nos.replace = replace\n"
        )
        for name in ("profiles.ini", "userChrome.css", "config.js", "dotfiles-files.json", "user.js"):
            with self.subTest(after=name):
                shutil.rmtree(self.firefox, ignore_errors=True)
                resources = self.app / "Contents/Resources"
                shutil.rmtree(resources)
                resources.mkdir()
                self.install(status=91, env={"PYTHONPATH": str(injection), "INTERRUPT_FILE": name})
                self.install()
                self.assertIn("Name=Sage", (self.firefox / "profiles.ini").read_text())
                self.assertEqual((self.profile / "chrome/customChrome.css").read_bytes(), (self.source / "customChrome.css").read_bytes())
                self.assertIn('datareporting.healthreport.uploadEnabled', (self.profile / "user.js").read_text())
                self.assertIn('"changedFiles": 0', self.install().stdout.decode())

    def test_download_outage_defers_without_writes_and_retry_installs(self):
        responses = [503, 200]
        archive = self.archive.read_bytes()

        class Download(BaseHTTPRequestHandler):
            def do_GET(self):
                code = responses.pop(0)
                self.send_response(code)
                self.end_headers()
                if code == 200:
                    self.wfile.write(archive)

            def log_message(self, *args):
                pass

        server = ThreadingHTTPServer(("127.0.0.1", 0), Download)
        worker = threading.Thread(target=server.serve_forever, daemon=True)
        worker.start()
        try:
            lock_path = self.source / "ultima.lock.json"
            lock = json.loads(lock_path.read_text())
            lock["url"] = f"http://127.0.0.1:{server.server_port}/ultima.tar.gz"
            lock_path.write_text(json.dumps(lock))
            download = self.work / "download.tar.gz"
            failure = self.install("--archive", str(download), status=2)
            self.assertIn(b"download", failure.stderr)
            self.assertFalse(self.firefox.exists())
            self.assertFalse(download.exists())
            self.install("--archive", str(download))
            self.assertEqual(download.read_bytes(), archive)
            self.assertTrue((self.profile / "chrome/customChrome.css").exists())
        finally:
            server.shutdown()
            server.server_close()
            worker.join()

    def test_conflicts_report_all_paths_and_distinguish_loader_from_theme(self):
        self.profile.mkdir(parents=True)
        chrome = self.profile / "chrome"
        chrome.mkdir()
        (chrome / "userChrome.css").write_text("/* user theme */")
        (self.app / "Contents/Resources/config.js").write_text("// user loader")
        failure = self.install("--profile", str(self.profile), status=3)
        self.assertIn(b"userChrome.css", failure.stderr)
        self.assertIn(b"AutoConfig loader", failure.stderr)
        self.assertIn(b"config.js", failure.stderr)
        self.assertIn(b"--adopt-theme --dry-run", failure.stderr)
        self.assertFalse((self.profile / "user.js").exists())

    def test_package_hook_and_assets_are_personal_mac_only(self):
        hook = "home/.chezmoiscripts/run_after_23-firefox-settings.sh.tmpl"
        for machine in ("personal", "work", "homelab", "ci", "devbox"):
            with self.subTest(machine=machine):
                output = self.render(hook, machine).decode()
                ignored = self.render("home/.chezmoiignore", machine).decode()
                self.assertEqual("install-settings" in output, machine == "personal")
                self.assertEqual("\n.config/firefox\n" in ignored, machine != "personal")

    def test_sidebery_import_cannot_carry_panels_snapshots_or_favicons(self):
        backup = json.loads((self.source / "sidebery-settings.json").read_text())
        self.assertEqual(set(backup), {"ver", "settings"})
        self.assertFalse(backup["settings"]["syncSaveSettings"])
        self.assertFalse(backup["settings"]["snapAutoExport"])
        css = (self.source / "customContent.css").read_text()
        self.assertNotIn("navarc-", css)
        self.assertNotIn("/Users/", css)
        self.assertIn('moz-extension://[^/]+/sidebery/group[.]html', css)
