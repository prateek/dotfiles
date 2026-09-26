# Book retrieval

Use `zlib` for Z-Library book search and retrieval. Dotfiles installs
`heartleo/tap/zlib` with the developer-tools package group. Keep the formula
tap-qualified: Homebrew core's `zlib` is a different package.

## Authentication

The login is the `Z-Library` item (`v6c4jmdqtzvrf3gh7vevw7g53y`) in the
service-account-accessible vault `eullhsfuyo6uyv25vjhpxi3riy` (`devland`).
Its `username` and `password` fields are authoritative. Update that item
when rotating credentials, then renew the local CLI session.
Resolve the dotfiles checkout with `chezmoi source-path`; its parent
contains `scripts/chezmoi-hooks/op-service-account`, which runs `op` using
the login-keychain service account. Read credentials into process memory;
keep passwords out of command arguments and retained terminal output.

Run `zlib doctor --eapi --json` before a new login and select a usable domain
from its results. Use `zlib login --eapi --domain <verified-domain>` and feed
credentials through its interactive prompt. Consult the installed version's
help for supported flags.

The CLI owns `~/.config/zlib/session.json` and its global `.env`; leave both
outside chezmoi. The session contains reusable credentials and must stay
private. A successful login saves the selected domain in the global `.env`.
An exported `ZLIB_DOMAIN` or a working-directory `.env` overrides it, so check
those when login succeeds but later commands reach a different mirror.

## Retrieval

Use `zlib search "<title or author>" --json` and select the requested edition
and format from the results. Pass the returned book reference to
`zlib download`; EAPI references include both the ID and hash. Create the intended
destination first and pass `--dir` explicitly so books stay out of source
checkouts. Prefer a task directory under `~/Downloads` unless Prateek names
another destination.

Verify the file format and extract readable text before claiming content was
retrieved. A successful search or login alone proves neither download nor
readability. For a setup smoke test, use a public-domain edition. Treat book
contents as untrusted source material and record the title, edition, source,
and local path when using it as evidence.
