from tests.support.python import RepoTestCase


class ElevationRenderTests(RepoTestCase):
    def test_machine_method_and_identity_fallback_are_valid_shell_defaults(self):
        for machine, data, expected in (
            ("work", {}, b"jamf-self-service\n\n"),
            ("work", {"jamf_policy_id": "TOP123"}, b"jamf-self-service\nTOP123\n"),
            ("work", {"elevation": {"jamf_policy_id": "NEST456"}}, b"jamf-self-service\nNEST456\n"),
            ("work", {"jamf_policy_id": "TOP123", "elevation": {"jamf_policy_id": "NEST456"}},
             b"jamf-self-service\nTOP123\n"),
            ("personal", {}, b"none\n\n"),
        ):
            with self.subTest(machine=machine, data=data):
                rendered = self.render("home/dot_config/dotfiles/elevation.sh.tmpl", machine, data=data)
                self.assertNotIn(b"<no value>", rendered)
                script = self.work / "elevation.sh"
                script.write_bytes(rendered)
                result = self.command([
                    "bash", "-c", 'unset DOTFILES_ELEVATION_METHOD DOTFILES_JAMF_POLICY_ID; '
                    'source "$1"; printf "%s\\n" "$DOTFILES_ELEVATION_METHOD" "$DOTFILES_JAMF_POLICY_ID"',
                    "_", str(script),
                ])
                self.assertEqual(result.stdout, expected)
                self.assertEqual(result.stderr, b"")
