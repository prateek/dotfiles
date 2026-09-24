# agent-browser driver

The terminal default; mise installs `agent-browser` machine-wide. Its
version-matched guide, `agent-browser skills get core`, is the command
reference; load it before the first command.

1. Choose the session name as [auth.md](../auth.md) describes. The examples
   below use `checkout-k3f9`; type the real name into every command.
2. Pass the session on every command, and the safety flags on every command
   that opens or reads a page:

   ```bash
   agent-browser --session checkout-k3f9 --content-boundaries \
     --max-output 50000 --confirm-actions eval,download open <url>
   ```

   Add `--restore` from the first command when [auth.md](../auth.md) keeps a
   login for this session. For an isolated session with no `--restore` or
   `--profile`, also add `--allowed-domains <list>` when the task names its
   sites; agent-browser rejects the allowlist alongside restored state and
   profiles.
3. Work in the loop: `snapshot -i`, act on `@e` refs, `wait` for an exact
   condition, then `snapshot -i` again.
4. Finish with `agent-browser --session checkout-k3f9 close`.

## Pending actions

`--confirm-actions` makes agent-browser hold `eval` and `download` as pending
actions. A pending action is a question for Prateek, not his answer. Ask him
whenever [policy.md](../policy.md) calls for confirmation, then run
`agent-browser --session checkout-k3f9 confirm <id>` after he agrees or
`agent-browser --session checkout-k3f9 deny <id>` otherwise. A pending action
denies itself after 60 seconds; keep that default. When one expires, run the
action again and ask again.
