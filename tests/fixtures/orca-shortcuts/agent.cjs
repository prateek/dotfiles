#!/usr/bin/env node
const fs = require('node:fs');
const path = require('node:path');
const agent = path.basename(process.argv[1]);
if (process.argv.includes('--version') || process.argv.includes('--help')) {
  console.log(`${agent} fixture 1.0.0`);
  process.exit(0);
}
if (process.argv.includes('app-server')) process.exit(1);
process.title = agent;
const fork = process.argv.includes('--fork') || process.argv.includes('--fork-session') || process.argv.includes('fork');
const id = fork ? 'fixture-fork' : 'fixture-source';
const home = agent === 'codex' ? '/root/account home' : '/root';
const transcript = agent === 'codex'
  ? `${home}/sessions/2026/10/07/${id}.jsonl`
  : `/root/.${agent}/projects/workspace/${id}.jsonl`;
if (fork) {
  const marker = agent === 'claude' ? '--resume' : agent === 'codex' ? 'fork' : '--fork';
  const source = process.argv[process.argv.indexOf(marker) + 1];
  const expected = ['pi', 'omp'].includes(agent) ? transcript.replace('fixture-fork', 'fixture-source') : 'fixture-source';
  if (source !== expected) throw new Error('Fork addressed the wrong conversation');
  if (agent === 'codex' && process.env.CODEX_HOME !== home) throw new Error('Fork used the wrong account home');
}
fs.mkdirSync(path.dirname(transcript), {recursive: true});
const rows = agent === 'codex' ? [
  {type: 'session_meta', timestamp: '2026-10-07T12:00:00Z', payload: {id, cwd: process.cwd()}},
  {type: 'response_item', payload: {type: 'message', role: 'assistant', content: [{type: 'output_text', text: 'Fixture response'}]}}
] : [
  {type: 'user', sessionId: id, cwd: process.cwd(), timestamp: '2026-10-07T12:00:00Z', message: {role: 'user', content: 'Fixture prompt'}},
  {type: 'assistant', sessionId: id, timestamp: '2026-10-07T12:00:01Z', message: {role: 'assistant', content: [{type: 'text', text: 'Fixture response'}]}}
];
fs.writeFileSync(transcript, rows.map(row => JSON.stringify(row)).join('\n') + '\n');
process.stdout.write(`\x1b]0;${agent} ready\x07${agent} fixture ready\n`);
async function publish() {
  const body = {
    paneKey: process.env.ORCA_PANE_KEY,
    tabId: process.env.ORCA_TAB_ID,
    worktreeId: process.env.ORCA_WORKTREE_ID,
    launchToken: process.env.ORCA_AGENT_LAUNCH_TOKEN,
    env: process.env.ORCA_AGENT_HOOK_ENV,
    version: process.env.ORCA_AGENT_HOOK_VERSION,
    payload: {hook_event_name: ['pi', 'omp'].includes(agent) ? 'before_agent_start' : 'UserPromptSubmit', session_id: id, transcript_path: transcript,
              session_file: transcript, cwd: process.cwd(), prompt: 'Fixture prompt'}
  };
  const response = await fetch(`http://127.0.0.1:${process.env.ORCA_AGENT_HOOK_PORT}/hook/${agent}`, {
    method: 'POST', headers: {'Content-Type': 'application/json',
    'X-Orca-Agent-Hook-Token': process.env.ORCA_AGENT_HOOK_TOKEN}, body: JSON.stringify(body)
  });
  if (!response.ok) throw new Error(`Hook rejected: ${response.status}`);
}
publish().catch(error => {console.error(error.message); process.exit(1)});
process.stdin.resume();
