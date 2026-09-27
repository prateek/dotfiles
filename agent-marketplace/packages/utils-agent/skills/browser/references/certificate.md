# Private service certificate in Orca

Use a supported host-scoped browser trust feature if the installed Orca
release offers one. Otherwise run the browser skill's
[`pinned-loopback-proxy.mjs`](../scripts/pinned-loopback-proxy.mjs)
for the owned service. The proxy listens on `127.0.0.1` and checks the exact
SHA-256 digest of the upstream leaf certificate before forwarding HTTP or
WebSocket traffic. It rewrites same-origin redirects and strips the `Secure`
cookie attribute only for the loopback HTTP endpoint. Keep that endpoint on
the local host and close its tab and proxy when finished.

First obtain the certificate digest through an authenticated channel, such as
an existing SSH session to the service host or its trusted management channel.
Do not accept a first digest fetched over the failing unauthenticated TLS
connection as proof. Reverify through that channel when the pin changes.
Store the pin and runtime state outside dotfiles; never commit service names,
addresses, account details, or credentials here.

```sh
proxy="$BROWSER_SKILL_DIR/scripts/pinned-loopback-proxy.mjs"
"$proxy" start --upstream 'https://HOST:PORT' --pin "$VERIFIED_SHA256" --state "$PRIVATE_STATE_FILE"
"$proxy" status --state "$PRIVATE_STATE_FILE"
"$proxy" stop --state "$PRIVATE_STATE_FILE"
```

The state file is created with mode 0600 and contains the loopback URL and a
control token. Keep its parent directory private. Startup reserves that path
exclusively; a second start fails instead of attaching to another service.
A pin mismatch returns 502 without forwarding the request. Sanitized upstream
failure classes go to `<state>.log` (mode 0600); request paths, headers, bodies,
and credentials are not logged. Verify signed-in application state in the browser; a working
proxy alone does not establish authentication. If the process crashes and a
stale state file remains, inspect its recorded PID and remove that task-owned
file before restarting. Do not stop a pre-existing proxy or tab owned by
another task.
