# Third-Party Imports

Remote skills should be vendored into package source before they become active.

Preferred path:

1. Add the remote dependency to the package's `apm.yml`.
2. Resolve it with
   `.agents/skills/agent-skill-management/scripts/vendor-agent-package
   <package>` once the APM dependency path is ready.
3. Review the resulting `skills/vendor/<skill-id>/` diff, including
   `SOURCE.md`.
4. Regenerate and validate generated projections.

Manual vendoring is allowed only when a useful remote skill cannot be expressed
as an APM dependency yet. Add source notes in the vendored skill root before
activating it.

Keep `apm.yml` dependencies unpinned so they target latest upstream refs. The
reviewed vendored snapshot is recorded by `apm.lock.yaml` plus each vendored
skill's `SOURCE.md` ref.
