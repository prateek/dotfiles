# Fixture: bisect-silent-disable-target-bundle-id

Pitfall eval: user added a Brave routing rule with `targetBundleId`
set to `/Applications/Brave Browser.app`. Tests that the agent
identifies the import-time security pass disabling rules with
path-prefixed `targetBundleId` and recommends a reverse-DNS bundle
ID in the fragment instead.

The discriminating signal: `simulated_imported_config.json` shows
`enabled: false` on the path-prefixed rule but `enabled: true` on the
reverse-DNS sibling.

Canonical prompt + expectations live in `evals/evals.json`.
