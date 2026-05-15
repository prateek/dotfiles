# Fixture: bisect-silent-disable-rule-launch-args

Pitfall eval: user added a rule with `ruleCustomLaunchArgs` set
(`--window-position=...`) and a clean `com.google.Chrome`
`targetBundleId`. Tests that the agent identifies the SECOND
rule-level security trigger — non-null `ruleCustomLaunchArgs` — and
recommends dropping the field. Discrimination test against eval2's
path-prefixed `targetBundleId` trigger.

Canonical prompt + expectations live in `evals/evals.json`.
