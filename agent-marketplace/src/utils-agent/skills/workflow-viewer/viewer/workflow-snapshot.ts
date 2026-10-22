// Prints one Claude Code Workflow run as JSON: status, phases and each agent's state, current tool
// and result. `workflow-viewer --once` runs it; agents and scripts can read a run without a terminal.
import { findRun, Run, snapshot } from "./workflow-model.ts";

const want = process.argv[2];
const found = findRun(want);
if (!found) {
  console.error(want ? `workflow-viewer: no run matches "${want}"` : "workflow-viewer: no workflow runs under ~/.claude/projects");
  process.exit(1);
}
console.log(JSON.stringify(snapshot(new Run(found.dir).refresh()), null, 2));
