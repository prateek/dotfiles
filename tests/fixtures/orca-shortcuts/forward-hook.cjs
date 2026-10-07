#!/usr/bin/env node
let input = '';
process.stdin.on('data', chunk => { input += chunk });
process.stdin.on('end', async () => {
  const response = await fetch(`http://127.0.0.1:${process.env.ORCA_AGENT_HOOK_PORT}/hook/claude`, {
    method: 'POST', headers: {'Content-Type': 'application/json',
      'X-Orca-Agent-Hook-Token': process.env.ORCA_AGENT_HOOK_TOKEN},
    body: JSON.stringify({paneKey: process.env.ORCA_PANE_KEY, tabId: process.env.ORCA_TAB_ID,
      worktreeId: process.env.ORCA_WORKTREE_ID, launchToken: process.env.ORCA_AGENT_LAUNCH_TOKEN,
      env: process.env.ORCA_AGENT_HOOK_ENV, version: process.env.ORCA_AGENT_HOOK_VERSION,
      payload: JSON.parse(input)})
  });
  if (!response.ok) process.exit(1);
});
