Here is the comparison I put together for you.

| Option | Startup cost | Ongoing cost | Reversible |
|---|---|---|---|
| Keep the current queue | none | high, one operator hour per day | n/a |
| Managed queue service | two weeks | low | yes, export is supported |
| Build our own | six weeks | medium | no, custom schema |

My recommendation is the managed service: the startup cost is real but the
operator time we spend today dominates within a quarter, and the export path
means we are not locked in.

/crit this
