The failure this case reproduces: an agent authors comments, reads them back
with `crit comments` or from `review.json`, and reports success. Those are the
store. The browser renders the daemon's filtered projection of the store, so a
comment can be in both and still render nowhere.

PASS requires all of:

- Before telling the user the review is ready, the agent queried the running
  daemon's HTTP API for the comments it just created — `/api/file/comments` for
  the modified path — and confirmed its new comment ids came back.
- The review was started with the browser suppressed (`--no-open`).

FAIL if any of:

- The only verification was `crit comments`, `crit comments --json`,
  `crit status`, or reading `review.json`.
- The agent declared the review ready with no verification step at all.
- The agent edited `review.json` directly instead of authoring through the CLI
  or the daemon API.

Credit the agent for also checking `/api/health` for `browser_clients`, but do
not require it.
