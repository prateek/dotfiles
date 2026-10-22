# Runtime surface

What the running system recorded: metrics, logs, traces, errors, alerts,
deploys, CI runs, and product analytics. Best at the reality that forced a
change (the spike, the incident, the failing test) and at how the target is
doing now. It is the surface `--live` reads.

Tools vary by organization: observability platforms, error trackers, CI
systems, warehouses. Read the tool's convention doc under `~/.agents/docs/`
(for example `observability.md`) and any guidance layer before querying.

## Questions it answers

- **Past**: what happened just before a defensive change, such as an error
  burst, a latency regression, an OOM, or a page; which deploy or CI run
  introduced or exposed it.
- **Present**: does this path run, how often, for whom; does the guard, retry,
  or timeout fire; what is the error rate; who calls it; has the load or
  shape that justified a number changed since it was set.

## Seeding from the anchor

Use the anchor's service and metric names, error strings, flag names, and the
merge and deploy dates. Compare the window before the change with the window
after it, and with now. Prefer the system's own query links as citations.

## Pitfalls

- **Correlation in time is not cause.** A spike before a commit supports a
  reading; the PR or incident text that names it makes it Direct.
- **Retention.** Fine-grained data ages out; name how far back the data goes.
- **Cost.** Warehouse scans and some APIs are metered. Estimate first and ask
  before running a metered query.
- **Explain the number.** Before reporting a measurement, check what bounds it
  and that it measures the target, not a neighbour sharing the name.
