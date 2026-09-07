# Third-party imports

Follow [Acquire or update upstream inputs](../../../../agent-marketplace/README.md#acquire-or-update-upstream-inputs).
APM 0.29.1 is pinned in the project's uv environment and the managed Mise CLI
selection. Use the project recipes so cache/lock review guards run before APM.
Declarations, the lock, and `apm_modules/` live at the project root. `just fetch`
and `just update` operate on that shared graph; there is no package selector.
Before removing an input, check selections in every plugin. A shared input update
requires reviewing the output and bumping the version of each affected plugin.

For dependency behavior questions, use `utils-agent:ask` against
`github:microsoft/apm@v0.29.1`. Acquisition uses development dependencies and native
`apm lock`; publication uses native source directories. The bundle exporter is not
a substitute: the executed research found missing helpers and rejected evals.

Subdirectory dependencies must be self-contained. This build refuses payload
symlinks, including ones APM's content hash omits. Disposable `__pycache__` entries
are ignored without traversal. A repository-root dependency plus explicit
publication selection works when a subdirectory depends on siblings. Hidden skill
collections may need one declaration per skill subdirectory.

When the corresponding CLI changes, review the skill update at the same time
(for example crit, acpx, and agent-slack). Review upstream policy changes as well
as prompt text. The critical content scan runs on the final assembled payload,
after patches and overlays; acquisition itself does not establish that guarantee.

Keep licenses and receipts supplied by upstream/APM. Subdirectory publication
must explicitly select root licenses and notices that its skills do not already
carry, using `licenses/<owner>/<repo>/` payload targets. Acceptance includes the
complete cache, including files hidden by upstream ignore rules. Keep old inputs
until replacements build and native consumers pass. Registry/mirror acquisition
and cold-cache GitHub-independent recovery remain future work; current outage
independence comes from committed bytes and retained exports.
