# Cross-host topology and protocol

Type: grilling
Status: open
Blocked by: 01

## Question

How does an item written on host A reach a worktree inbox on host B, and how does the human see every host's items?

Options, depending on ticket 01:
- aven sync through a server Prateek controls (where: m4mini? reachable from work-mbp?)
- the CLI invoked over SSH
- Orca `--environment` against paired servers
- a small HTTP service over Tailscale

Decide:
- the topology
- auth
- the pending-queue behavior when B is unreachable
- how work and personal hosts stay separate (separate servers? no cross-writes at all?)

Today the only pairing is work-mbp to the `devbox-2` Orca server. There is no durable pairing between personal-mbp, m4mini and work-mbp.
