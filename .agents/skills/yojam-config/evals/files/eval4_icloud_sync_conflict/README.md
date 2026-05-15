# Fixture: icloud-sync-conflict

Pitfall eval: chezmoi-managed Yojam config keeps reverting within
seconds of `chezmoi apply` because Yojam's iCloud KV sync is also on
and propagating the OTHER Mac's state. Tests that the agent diagnoses
the dual-authority conflict, sets `iCloudSync: false` in the desired
fragment, and propagates via `chezmoi apply` (not via iCloud).

The discriminating signal: `simulated_target_after_apply.json` shows
this Mac's state right after apply; `simulated_target_after_icloud.json`
shows the other Mac's state ~5s later (different rule UUID + content).

Canonical prompt + expectations live in `evals/evals.json`.
