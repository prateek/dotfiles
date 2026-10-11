# Sync and login

Helper paths are relative to the skill root. Use the account, storefront, and
date range selected in `SKILL.md`. Sync needs local Chrome/Chromium; coverage
reporting needs Python 3. Consult command `--help` for other CLI options.

## Browser policy and identity

Before any CLI operation that launches Chrome, read `$utils-agent:browser` and
its `references/policy.md`; for login, also read its `references/auth.md`.
That skill owns focus agreement, authentication, and browser cleanup. Reuse an
existing focus agreement only while its named window/work remains covered.

amz-specific constraints:

- `login`, `--show`, and combinations such as `orders --live --show` may bring
  Chrome forward on macOS. amz exposes no documented background visible-launch
  option; obtain the browser policy's focus agreement before these launches.
- amz uses a dedicated retained Chrome profile and cookie jar under its account
  directory. Keep the user's requested human login/MFA/CAPTCHA hand-off.
- CLI login success should be followed by an authenticated read, such as the
  requested sync. `status` without `--live` only inspects local state.

Inspect accounts before creating one. `accounts add` also overwrites an existing
account's configuration, so reuse the chosen account unless an update is intended.
For a new US personal account, after choosing the name and agreeing login focus:

```sh
bash scripts/amz accounts add personal --type personal --country US --home com
bash scripts/amz login --account personal --market com
```

Verify setup through the authenticated read in the import step below.
Preserve cookies and profile state for subsequent syncs; inspect cookie metadata
only, following the browser skill's secret policy. Keep new database files
owner-only; `umask 077` before first use also covers SQLite companion files.

## Import the requested interval

Compute calendar cutoffs from the local date. For a rolling two-year interval,
use the same date two years earlier, clamping February 29 to February 28 when
the target year has no leap day. For a new storefront/parser, validate a small
sample first, then continue the authorized interval.

```sh
umask 077
bash scripts/amz sync --account personal --market com --only orders --since YYYY-MM-DD --delay 3s
```

Monitor page progress and final errors. If a run stalls, inspect and stop that
process before retrying; the same account profile must have only one active run.
In the macOS US trial, headless pagination stalled while a `--show` retry worked.
Use that retry only within the browser policy's focus agreement. When driving
an existing visible Orca pane, use `$utils-agent:orca-cli` to inspect and send
to that pane; shell input and browser focus are separate concerns.

`--since` is a pagination cutoff: amz also stores the first wholly older page.
Sync has no `--until` flag, so use date-bounded offline reads for intervals ending
before today. Orders-only sync does not populate payment, gift-card, return, or
summary tables. Use `--full` only for an all-history request; `--summaries` fetches
printable pages for return/refund-marked orders, not every invoice.

After successful exit, run the coverage helper from `SKILL.md` with the same
account/storefront and requested dates. Finish with the coverage result and any
gaps; preserve partial data and report the failed stage if sync did not finish.
