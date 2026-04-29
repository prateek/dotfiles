# GitHub App setup — one-time, ~5 minutes

This walkthrough creates a dedicated GitHub App that your fork's sync
workflow will use to create PRs. Unlike a PAT, PRs authored by an App
trigger downstream CI workflows (GitHub's anti-recursion rule only
applies to the built-in `GITHUB_TOKEN`). App credentials also don't
expire — you rotate the private key when you want, not every 90 days.

You do this **once per GitHub account** and reuse the App across every
fork the skill generates.

## 1. Create the App

Open https://github.com/settings/apps/new in a browser. Fill in:

- **GitHub App name**: `<your-handle>-fork-sync-bot` (must be globally
  unique across GitHub — pick anything that's free).
- **Homepage URL**: `https://github.com/<your-handle>` — GitHub requires
  the field; your profile URL is fine.
- **Webhook → Active**: **uncheck** this box. The skill doesn't use
  webhooks.
- **Permissions → Repository permissions**, set:
  - **Contents**: Read and write *(push sync branches, update
    `.fork/revision.txt`)*
  - **Issues**: Read and write *(the conflict-resolve workflow files
    a needs-human tracking issue)*
  - **Metadata**: Read-only *(required by GitHub, always)*
  - **Pull requests**: Read and write *(create sync PRs via `gh pr
    create`)*
  - **Actions**: Read-only *(lets the App read CI status if you add
    future workflow checks; optional, but cheap to grant)*

  Leave everything else at "No access".
- **Where can this GitHub App be installed?**: **Only on this account**.

Click **Create GitHub App**. GitHub drops you on the App's settings
page. Leave that tab open — you need values from it.

## 2. Capture the App ID

Top of the settings page, under the App name:

```
App ID: 1234567
```

Copy it. This is `fork_app_id`.

## 3. Generate and download the private key

Scroll to **Private keys** → **Generate a private key**. Your browser
downloads a file named like `<app-slug>.<date>.private-key.pem`. Move
it somewhere you'll remember (you'll stash it in 1Password next and
delete the local copy). The contents look like:

```
-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQ...
-----END RSA PRIVATE KEY-----
```

This is `fork_app_private_key`. Treat it like a password — anyone with
this file can impersonate the App.

## 4. Install the App on your account

In the left sidebar of the App settings page, click **Install App**.
Pick your account, and on the install page choose **Only select
repositories**. You don't have to pick any repos yet — the skill will
add the fork automatically during `configure_gh`. Click **Install**.

After install, GitHub redirects to a URL like:

```
https://github.com/settings/installations/98765432
```

The number at the end (`98765432`) is your `fork_app_installation_id`.
Copy it.

## 5. Stash the three values

You now have three things to store:

- `fork_app_id` — the 6-7 digit number from step 2.
- `fork_app_private_key` — the multi-line PEM from step 3.
- `fork_app_installation_id` — the number from step 4.

Put them in whichever store your resolver config points at. For 1Password:

```
1Password → Personal → New item → Secure Note
  title:  "Fork Sync Bot (GitHub App)"
  fields:
    app_id               = 1234567
    installation_id      = 98765432
    private_key (concealed, multi-line) = <paste full PEM including BEGIN/END>
```

Delete the downloaded `.pem` file from your local disk once it's in
1Password — you won't need it again, and leaving it in `~/Downloads`
is an avoidable foot-gun.

## 6. Point the resolver at them

Edit `~/.config/setup-downstream-fork/config.toml` (or rerun
`setup_fork.py --init-config` and update just those three keys):

```toml
[secrets]
fork_app_id              = "op://Personal/Fork Sync Bot (GitHub App)/app_id"
fork_app_installation_id = "op://Personal/Fork Sync Bot (GitHub App)/installation_id"
fork_app_private_key     = "op://Personal/Fork Sync Bot (GitHub App)/private_key"
```

Verify:

```bash
setup_fork.py --validate-config
```

You should see `✓` next to all three `fork_app_*` entries. If the
`private_key` line shows something weird, check that the 1Password
field type is **Password** (or a multi-line text field) rather than a
single-line field that might mangle newlines.

## 7. You're done

Next time you run `setup_fork.py --upstream ... --fork-name ...`,
`configure_gh` detects the three App secrets, adds the new fork to
your App's installation (one `gh api` call), pushes `FORK_APP_ID` and
`FORK_APP_PRIVATE_KEY` as repo secrets, and skips the
`FORK_SYNC_TOKEN` path entirely. The generated sync workflow mints a
1-hour installation token per run via
`actions/create-github-app-token` and uses that for pushes and
`gh pr create`.

## Troubleshooting

**"Resource not accessible by integration" in the workflow log.**
Almost always one of:
- You missed a permission on step 1. Go back to the App settings,
  flip the missing one to Read & write, and re-run the sync workflow.
- You didn't install the App on your account. Step 4.
- The App is installed but not on the specific fork repo.
  `configure_gh` normally does this, but if you created the repo
  manually, run:
  ```bash
  gh api -X PUT /user/installations/$FORK_APP_INSTALLATION_ID/repositories/$(gh repo view OWNER/REPO --json id --jq .id)
  ```

**Private key contains unexpected characters / PEM parse error.**
1Password's "password" field type can sometimes collapse whitespace.
Use a multi-line text field or a secure-note with the PEM in a single
field. To test the resolver returns a usable value:

```bash
setup_fork.py --validate-config
op read "op://Personal/Fork Sync Bot (GitHub App)/private_key" | head -1
# expect: -----BEGIN RSA PRIVATE KEY-----
```

**Want to rotate the private key.**
Back on the App settings page, **Generate a private key** again.
Download the new one, update 1Password, revoke the old one from the
same settings page. No workflow change needed — existing forks will
pick up the new key on their next run via the resolver.

**Want to un-install from a specific fork.**
`gh api -X DELETE
/user/installations/$FORK_APP_INSTALLATION_ID/repositories/$REPO_ID`.
The App stays installed on your account; only that one repo stops
getting access.
