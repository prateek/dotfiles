import json
import tomllib

from tests.support.python import ROOT, RepoTestCase, declared_os


class ChezmoiConfigTests(RepoTestCase):
    def test_session_archive_alias_requires_explicit_host_registration(self):
        source = "home/dot_config/wiki-agent-sessions/config.toml.tmpl"
        missing = tomllib.loads(self.render(source).decode())
        self.assertEqual(missing, {"host_alias": ""})
        configured = tomllib.loads(self.render(source, data={
            "machines_local": {"wiki_host_alias": "buildbox"},
        }).decode())
        self.assertEqual(configured, {"host_alias": "buildbox"})

    def chezmoi(self, *args, expected_status=0):
        return self.command([
            "chezmoi", "--source", str(ROOT), "--config", str(self.config),
            "--destination", str(self.home), "--cache", str(self.work / "cache"),
            "--persistent-state", str(self.work / "state.boltdb"), "--no-tty", *args,
        ], expected_status=expected_status)

    def test_initialization_persists_machine_identity_disables_pager_and_pins_umask(self):
        self.chezmoi("init", "--promptDefaults", "--promptChoice", "machine_type=ci")
        text = self.config.read_text()
        config = tomllib.loads(text)
        self.assertEqual(config["pager"], "")
        self.assertEqual(config["data"]["machine_type"], "ci")
        self.assertNotIn("install_profile", text)
        effective = json.loads(self.chezmoi("dump-config", "--format=json").stdout)
        self.assertEqual(effective["pager"], "")
        self.assertEqual(effective["umask"], 0o022)
        self.assertEqual(effective["data"]["machine_type"], "ci")

    def managed(self, data):
        data = {"chezmoi": {"os": declared_os(data["machine_type"])}} | data
        return self.chezmoi(
            "--override-data", json.dumps(data), "managed", "--path-style=relative",
            "--include=files,symlinks,scripts", "--exclude=externals",
        ).stdout.decode().splitlines()

    def cat(self, data, target):
        data = {"chezmoi": {"os": declared_os(data["machine_type"])}} | data
        return self.chezmoi("--override-data", json.dumps(data), "cat", str(self.home / target)).stdout

    def test_devbox_allowlist_manages_only_opted_in_targets(self):
        roots = (".config/zsh/", ".config/tmux/", ".config/nvim/", ".config/git/", ".config/mise/")
        files = {
            ".zshenv", ".inputrc", ".lesskey", ".vimrc",
            ".chezmoiscripts/00-homebrew.sh", ".chezmoiscripts/05-core-tools.sh",
            ".chezmoiscripts/10-brew-bundle.sh", ".chezmoiscripts/10-zinit-compat.sh",
            ".chezmoiscripts/11-zinit-update.sh", ".chezmoiscripts/20-mise-install.sh",
            ".config/mise/config.toml", ".config/mise/conf.d/clis.toml",
            "code/scratch/.gitignore", "code/scratch/AGENTS.md", ".chezmoiscripts/41-scratch-dir.sh",
        }
        managed = self.managed({"machine_type": "devbox"})
        reconciler = ".local/bin/orca-devpod-reconcile"
        self.assertEqual([p for p in managed if p not in files and not p.startswith(roots)], [reconciler])
        self.assertLessEqual(files, set(managed))
        self.assertIn(".config/zsh/.zshrc", managed)
        self.assertNotIn(reconciler, self.managed({"machine_type": "personal"}))
        unrestricted = self.managed({
            "machine_type": "devbox", "machines_local": {"managed_allowlist": False},
        })
        self.assertIn(".agents/AGENTS.md", unrestricted)

    def test_a_machine_type_refuses_a_host_running_another_os(self):
        template = self.work / "features.tmpl"
        template.write_text('{{ includeTemplate "features.tmpl" . }}')
        result = self.chezmoi(
            "--override-data", json.dumps({"machine_type": "devbox", "chezmoi": {"os": "darwin"}}),
            "execute-template", "--file", str(template), expected_status=1,
        )
        self.assertIn(b'machine type "devbox" runs on linux, but this host runs darwin', result.stderr)

    def test_devbox_apply_leaves_other_owners_files_alone(self):
        owned = [".zshrc", "bin/gh", ".claude/commands/setup.md", ".agents/docs/acpx.md"]
        for path in owned:
            (self.home / path).parent.mkdir(parents=True, exist_ok=True)
            (self.home / path).write_text("owned elsewhere\n")
        self.env["DOTFILES_ROOT"] = str(ROOT)
        self.chezmoi("init", "--promptDefaults", "--promptChoice", "machine_type=devbox")
        self.chezmoi(
            "--override-data", json.dumps({"chezmoi": {"os": declared_os("devbox")}}),
            "apply", "--exclude=scripts,externals",
        )
        self.assertEqual([p for p in owned if not (self.home / p).exists()], [])

    def test_linux_brewfile_carries_formulae_but_no_casks_or_mac_only_formulae(self):
        brewfile = self.render("home/.chezmoitemplates/brewfile.tmpl", "devbox").decode()
        for entry in ('brew "git"', 'brew "fzf"', 'brew "git-spice"', 'brew "crit"', 'brew "herdr"',
                      # Homebrew refuses a tap formula unless the Brewfile trusts its tap.
                      'tap "raine/aven", trusted: true', 'brew "raine/aven/aven"',
                      'tap "sourcegraph/src-cli", trusted: true', 'brew "sourcegraph/src-cli/src-cli"'):
            self.assertIn(entry, brewfile)
        for entry in ("cask ", "mas ", 'brew "qcachegrind"', 'brew "wireshark"', "agent-safehouse", 'brew "fontforge"'):
            self.assertNotIn(entry, brewfile)
        gate = "{{ includeTemplate \"package-cask-enabled.tmpl\" (dict \"root\" . \"name\" \"gcloud-cli\") }}"
        template = self.work / "gate.tmpl"
        template.write_text(gate)
        self.assertEqual(self.render(template, "devbox"), b"false")
        self.assertEqual(self.render(template, "personal"), b"true")
        self.assertIn('brew "qcachegrind"', self.render("home/.chezmoitemplates/brewfile.tmpl", "personal").decode())

    def test_git_config_renders_to_one_path_per_machine(self):
        mac = self.managed({"machine_type": "personal"})
        self.assertIn(".gitconfig", mac)
        self.assertNotIn(".config/git/config", mac)
        devbox = self.managed({"machine_type": "devbox"})
        self.assertIn(".config/git/config", devbox)
        self.assertNotIn(".gitconfig", devbox)
        self.assertEqual(
            self.cat({"machine_type": "devbox"}, ".config/git/config"),
            self.cat({"machine_type": "personal"}, ".gitconfig"),
        )

    def test_reinitialization_carries_legacy_jamf_identity_to_the_top_level(self):
        self.config.write_text('[data]\nmachine_type = "work"\n[data.elevation]\njamf_policy_id = "LEGACY777"\n')
        self.chezmoi("init", "--promptDefaults")
        data = tomllib.loads(self.config.read_text())["data"]
        self.assertEqual(data["machine_type"], "work")
        self.assertEqual(data["jamf_policy_id"], "LEGACY777")

    def test_reinitialization_keeps_host_local_overrides_without_copying_committed_data(self):
        self.config.write_text(
            '[data]\nmachine_type = "homelab"\n'
            '[data.machines_local]\nsecrets_enabled = true\ngroups = ["core", "developer"]\n'
            '[data.secrets.refs]\nmoom_license = "op://Shared/Moom/license"\n'
        )
        self.chezmoi("init", "--promptDefaults")
        data = tomllib.loads(self.config.read_text())["data"]
        self.assertEqual(data["machines_local"], {"secrets_enabled": True, "groups": ["core", "developer"]})
        self.assertEqual(data["secrets"], {"refs": {"moom_license": "op://Shared/Moom/license"}})

        self.config.write_text('[data]\nmachine_type = "homelab"\n')
        self.chezmoi("init", "--promptDefaults")
        data = tomllib.loads(self.config.read_text())["data"]
        self.assertNotIn("machines_local", data)
        self.assertNotIn("secrets", data)

    def test_unmanaged_listing_excludes_local_and_secret_state_but_reports_unrelated_files(self):
        excluded = (
            ".zprofile.local", ".zshrc.local", ".config/chezmoi/chezmoi.toml",
            ".config/cmux/settings.json", ".config/op/config", ".gnupg/gpg.conf", ".ssh/config", ".ssh/id_ed25519",
        )
        for name in (*excluded, ".local-unmanaged-marker"):
            path = self.home / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.touch()
        listing = self.chezmoi("--override-data", '{"machine_type":"personal"}', "unmanaged", "--path-style=relative").stdout.decode().splitlines()
        self.assertIn(".local-unmanaged-marker", listing)
        for prefix in (".zprofile.local", ".zshrc.local", ".config/chezmoi", ".config/cmux/settings.json", ".config/op", ".gnupg", ".ssh"):
            self.assertFalse(any(path == prefix or path.startswith(prefix + "/") for path in listing), listing)
