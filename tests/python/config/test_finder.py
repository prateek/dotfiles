import json
import plistlib
import stat

from tests.support.python import ROOT, RepoTestCase


class FinderQuickActionTests(RepoTestCase):
    def setUp(self):
        super().setUp()
        self.workflow = ROOT / "home/Library/private_Services/Copy Paths.workflow"
        self.info = self.workflow / "Contents/Info.plist"
        self.document = self.workflow / "Contents/Resources/document.wflow"

    def test_service_declaration_is_recognized_by_macos_for_finder_file_input(self):
        for path in (self.info, self.document):
            self.command(["plutil", "-lint", str(path)])
        self.command(["/System/Library/CoreServices/pbs", "-read_bundle", str(self.workflow)])
        info = plistlib.loads(self.info.read_bytes())
        self.assertEqual(info["CFBundleIdentifier"], "com.prateek.services.copy-paths")
        service = info["NSServices"][0]
        self.assertEqual(service["NSMenuItem"]["default"], "Copy Paths")
        self.assertEqual(service["NSRequiredContext"]["NSApplicationIdentifier"], "com.apple.finder")
        self.assertEqual(service["NSSendFileTypes"][0], "public.item")
        metadata = plistlib.loads(self.document.read_bytes())["workflowMetaData"]
        for key, value in {
            "workflowTypeIdentifier": "com.apple.Automator.servicesMenu",
            "serviceApplicationBundleID": "com.apple.finder",
            "serviceInputTypeIdentifier": "com.apple.Automator.fileSystemObject",
            "serviceOutputTypeIdentifier": "com.apple.Automator.nothing",
        }.items():
            self.assertEqual(metadata[key], value)

    def test_shell_action_copies_literal_selected_paths_one_per_line(self):
        action = plistlib.loads(self.document.read_bytes())["actions"][0]["action"]
        self.assertEqual(action["ActionBundlePath"], "/System/Library/Automator/Run Shell Script.action")
        params = action["ActionParameters"]
        self.assertIs(type(params["inputMethod"]), int)
        self.assertEqual(params["inputMethod"], 1)
        self.assertEqual(params["shell"], "/bin/zsh")
        command = params["COMMAND_STRING"]
        self.assertIn("/usr/bin/pbcopy", command)
        paths = [str(self.work / "first path.txt"), str(self.work / "second [path] ; $(touch injected).txt")]
        result = self.command(["/bin/zsh", "-f", "-c", command.replace("/usr/bin/pbcopy", "/bin/cat"), "--", *paths], cwd=self.work)
        self.assertEqual(result.stdout, ("\n".join(paths) + "\n").encode())
        self.assertEqual(result.stderr, b"")
        self.assertFalse((self.work / "injected").exists())

    def test_chezmoi_materializes_services_with_private_directory_permissions(self):
        (self.home / "Library").mkdir()
        services = self.home / "Library/Services"
        self.command([
            "chezmoi", "--source", str(ROOT), "--config", str(self.config),
            "--destination", str(self.home), "--cache", str(self.work / "cache"),
            "--persistent-state", str(self.work / "state.boltdb"), "--no-tty",
            "--override-data", json.dumps({"machine_type": "personal"}),
            "apply", "--exclude=scripts", str(services),
        ])
        self.assertEqual(stat.S_IMODE(services.stat().st_mode), 0o700)
        self.assertEqual((services / "Copy Paths.workflow/Contents/Info.plist").read_bytes(), self.info.read_bytes())
