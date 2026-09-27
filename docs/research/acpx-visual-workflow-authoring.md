---
status: active
doc_type: research
owner: Prateek
created: 2026-09-26
updated: 2026-09-26
related:
  - ../references/acpx-routing.md
status_detail: "Point-in-time investigation of visual authoring, adjacent integrations, and installed acpx version. No runtime changes."
---

# Visual Authoring for acpx Workflows

## Finding

As of 2026-09-26, no supported visual authoring interface for native
`acpx/flows` workflows was found. Native authoring uses TypeScript; the
upstream architecture explicitly lists “No visual builder” as a non-goal.
The graphical application shown in acpx demonstrations inspects saved runs.
[Architecture](https://github.com/openclaw/acpx/blob/c62ae8cd86757e2dba644ed7b402d6a36d75031e/docs/2026-03-25-acpx-flows-architecture.md),
[maintainer's launch explanation](https://solmaz.io/x/2038565725690900992/).

Visual orchestration around acpx is feasible with another workflow engine.
That would create workflows belonging to the other engine; no native acpx
import/export integration was found in the candidates below.

## Native acpx

The supported authoring surface is experimental: a `.ts` module imports
`defineFlow` and node helpers from `acpx/flows`. `acpx flow run` loads the
module and persists run state under `~/.acpx/flows/runs/`.
[Flows guide](https://github.com/openclaw/acpx/blob/c62ae8cd86757e2dba644ed7b402d6a36d75031e/docs/flows.md).

The source tree contains a React Flow replay viewer. It displays node status,
step transcripts, and a timeline; live runs update over WebSocket. It is
read-only and cannot execute flows. The documented launch command is
`pnpm viewer` from the acpx source checkout.
[Viewer documentation](https://github.com/openclaw/acpx/blob/c62ae8cd86757e2dba644ed7b402d6a36d75031e/docs/flows.md#replay-viewer).

Local inspection found acpx **0.19.3**. `acpx flow --help` exposes `run`
and help, with no editor command. The installed package contains `dist`,
`skills`, README, and LICENSE; the viewer lives in the source tree.
The npm `latest` tag and GitHub latest release both resolve to **0.19.3**,
published on 2026-09-25. No newer published version was available to upgrade
to during this check. Mise already selects 0.19.3 through a `latest` setting
owned by the [managed CLI configuration](../../home/dot_config/mise/conf.d/clis.toml).
[Release](https://github.com/openclaw/acpx/releases/tag/v0.19.3),
[npm metadata](https://registry.npmjs.org/acpx/latest).

## Available Alternatives

| Option | Visual authoring | Relationship to acpx |
| --- | --- | --- |
| acpx replay viewer | No; run inspection | Reads acpx run bundles |
| Self-hosted n8n + Execute Command | Yes, in n8n | Can invoke acpx CLI commands |
| Node-RED + `exec` | Yes, in Node-RED | Can invoke acpx CLI commands |
| `n8n-nodes-acp` | Yes, in n8n | Calls ACP harnesses directly; separate from acpx |

n8n's Execute Command node runs a shell command where n8n executes. It can
therefore invoke an installed acpx command, including a whole existing flow.
This is an integration inference from the documented command boundary; it
was not exercised. Execute Command is unavailable on n8n Cloud and disabled
by default starting in n8n 2.0. In Docker, commands run inside the container,
so acpx, credentials, and repositories must be accessible there.
[Execute Command documentation](https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.executecommand).

Node-RED provides a canvas for wiring nodes. Its core `exec` node supports
commands, timeout configuration, and separate stdout/stderr/exit-code outputs.
Using it to invoke acpx is similarly feasible but untested. The resulting
graph remains a Node-RED flow.
[Editor guide](https://nodered.org/docs/user-guide/editor/),
[`exec` source](https://github.com/node-red/node-red/blob/master/packages/node_modules/%40node-red/nodes/core/function/90-exec.html).

There is also a concrete ACP integration:
[`wyvernzora/n8n-nodes-acp`](https://github.com/wyvernzora/n8n-nodes-acp/tree/7165d0ea304b68eb7e2d8979129c9068006b03cc).
It connects n8n nodes to a sidecar harness, with Codex and OpenCode harnesses
included. Each input item receives its own ACP session and disposable scratch
workspace. This differs from operating on an existing acpx session and repo.
The project's README calls it early, with package version `0.0.0` and an
unstable contract. Treat it as a candidate to evaluate, not a verified local
solution. Its documented interface contains no acpx flow import/export.
[README at inspected revision](https://github.com/wyvernzora/n8n-nodes-acp/blob/7165d0ea304b68eb7e2d8979129c9068006b03cc/README.md).

## Practical Recommendation

To retain native acpx execution, describe the workflow in Markdown with a
Mermaid diagram, implement it through `acpx/flows`, then inspect trial runs
in the viewer. This matches the maintainer's documented authoring process;
diagram-to-TypeScript generation remains work for a human or coding agent.
[Maintainer's process](https://solmaz.io/x/2038565725690900992/).

If drag-and-drop editing is the priority, evaluate Node-RED or self-hosted
n8n as the orchestration layer and call acpx from their command nodes.
The command boundary needs explicit input/output handling and session/cwd
selection. Calling `acpx flow run` from one node preserves that flow's
internal behavior, but its internal topology still must be edited in
TypeScript.

## Evidence Boundary

Checked local CLI/package metadata, current upstream source and docs, release
metadata, exact-term web searches for acpx visual editors/builders, GitHub
repository search, and the integrations cited above. Upstream was inspected
at `c62ae8cd86757e2dba644ed7b402d6a36d75031e`; release 0.19.3 points to
`6b4714c7aaac8c38b1fe38354848d2546f65d87d`.

The negative finding applies to this search scope and date. It cannot rule
out unpublished tools or unindexed experiments. No candidate was installed,
no agent workflow was executed, and no visual editor was tested end to end.
