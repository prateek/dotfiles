#!/usr/bin/env node
// Usage: <agent> [source-id]. A fork of `<name>source` publishes `<name>fork`.
const crypto = require('node:crypto');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const agent = path.basename(process.argv[1]);
const hookAgent = agent === 'cursor-agent' ? 'cursor' : agent;
if (process.argv.includes('--version') || process.argv.includes('--help')) {
  console.log(`${agent} fixture 1.0.0`);
  process.exit(0);
}
if (process.argv.includes('app-server')) process.exit(1);
process.title = agent;
const fork = process.argv.includes('--fork') || process.argv.includes('--fork-session') || process.argv.includes('fork');
const home = agent === 'codex' ? '/root/account home' : '/root';
const slug = process.cwd().replaceAll('/', '-');
const transcriptFor = id => agent === 'codex'
  ? `${home}/sessions/2026/10/07/${id}.jsonl`
  : agent === 'droid'
    ? `/root/.factory/sessions/${id}.jsonl`
  : ['pi', 'omp'].includes(agent)
    ? `/root/.${agent}/agent/sessions/-${slug}--/${id}.jsonl`
  : agent === 'cursor-agent'
    ? `/root/.cursor/projects/${slug.slice(1)}/agent-transcripts/${id}/${id}.jsonl`
    : `/root/.${agent}/projects/${slug}/${id}.jsonl`;
// Orca may inject extension paths ahead of the command's own arguments.
let id = process.argv.slice(2).findLast(arg => !arg.startsWith('-')) || 'fixture-source';
if (fork) {
  const marker = agent === 'claude' ? '--resume' : agent === 'codex' ? 'fork' : '--fork';
  const source = process.argv[process.argv.indexOf(marker) + 1];
  const sourceId = ['pi', 'omp'].includes(agent) ? path.basename(source, '.jsonl') : source;
  if (['pi', 'omp'].includes(agent) && source !== transcriptFor(sourceId)) {
    throw new Error('Fork addressed the wrong conversation');
  }
  if (agent === 'codex' && process.env.CODEX_HOME !== home) throw new Error('Fork used the wrong account home');
  fs.readFileSync(transcriptFor(sourceId));
  id = sourceId.endsWith('source') ? `${sourceId.slice(0, -'source'.length)}fork` : `${sourceId}-fork`;
  fs.appendFileSync('/tmp/fork-receipts.jsonl', JSON.stringify({
    agent, source, hostname: os.hostname(), cwd: process.cwd(), pid: process.pid,
    codexHome: process.env.CODEX_HOME || null
  }) + '\n');
}
const transcript = transcriptFor(id);
fs.mkdirSync(path.dirname(transcript), {recursive: true});
const rows = agent === 'codex' ? [
  {type: 'session_meta', timestamp: '2026-10-07T12:00:00Z', payload: {id, cwd: process.cwd()}},
  {type: 'response_item', payload: {type: 'message', role: 'assistant', content: [{type: 'output_text', text: 'Fixture response'}]}}
] : agent === 'droid' ? [
  {type: 'session_start', id, cwd: process.cwd(), timestamp: '2026-10-07T12:00:00Z'},
  {type: 'message', role: 'user', text: 'Fixture prompt', timestamp: '2026-10-07T12:00:01Z'},
  {type: 'completion', finalText: 'Fixture response', timestamp: '2026-10-07T12:00:02Z'}
] : agent === 'cursor-agent' ? [
  {role: 'user', timestamp: '2026-10-07T12:00:00Z', message: {content: [{type: 'text', text: 'Fixture prompt'}]}},
  {role: 'assistant', timestamp: '2026-10-07T12:00:01Z', message: {content: [{type: 'text', text: 'Fixture response'}]}}
] : ['pi', 'omp'].includes(agent) ? [
  {type: 'session', version: 3, id, cwd: process.cwd(), timestamp: '2026-10-07T12:00:00Z'},
  {type: 'message', timestamp: '2026-10-07T12:00:01Z', message: {role: 'user', content: [{type: 'text', text: 'Fixture prompt'}]}},
  {type: 'message', timestamp: '2026-10-07T12:00:02Z', message: {role: 'assistant', content: [{type: 'text', text: 'Fixture response'}]}}
] : [
  {type: 'user', sessionId: id, cwd: process.cwd(), timestamp: '2026-10-07T12:00:00Z', message: {role: 'user', content: 'Fixture prompt'}},
  {type: 'assistant', sessionId: id, timestamp: '2026-10-07T12:00:01Z', message: {role: 'assistant', content: [{type: 'text', text: 'Fixture response'}]}}
];
fs.writeFileSync(transcript, rows.map(row => JSON.stringify(row)).join('\n') + '\n');
if (agent === 'cursor-agent') {
  // Cursor keeps the chat's cwd in a sibling tree keyed by md5(cwd).
  const meta = `/root/.cursor/chats/${crypto.createHash('md5').update(process.cwd()).digest('hex')}/${id}/meta.json`;
  fs.mkdirSync(path.dirname(meta), {recursive: true});
  fs.writeFileSync(meta, JSON.stringify({title: 'Fixture prompt', cwd: process.cwd(),
    createdAtMs: 1791374400000, updatedAtMs: 1791374401000}));
}
process.stdout.write(`\x1b]0;${agent} ready\x07${agent} fixture ready\n`);
async function publish() {
  const body = {
    paneKey: process.env.ORCA_PANE_KEY,
    tabId: process.env.ORCA_TAB_ID,
    worktreeId: process.env.ORCA_WORKTREE_ID,
    launchToken: process.env.ORCA_AGENT_LAUNCH_TOKEN,
    env: process.env.ORCA_AGENT_HOOK_ENV,
    version: process.env.ORCA_AGENT_HOOK_VERSION,
    payload: {hook_event_name: ['pi', 'omp'].includes(agent) ? 'before_agent_start'
                : agent === 'cursor-agent' ? 'beforeSubmitPrompt' : 'UserPromptSubmit',
              session_id: id, transcript_path: transcript,
              session_file: transcript, cwd: process.cwd(), prompt: 'Fixture prompt',
              ...(hookAgent === 'cursor' ? {conversation_id: id} : {})}
  };
  const response = await fetch(`http://127.0.0.1:${process.env.ORCA_AGENT_HOOK_PORT}/hook/${hookAgent}`, {
    method: 'POST', headers: {'Content-Type': 'application/json',
    'X-Orca-Agent-Hook-Token': process.env.ORCA_AGENT_HOOK_TOKEN}, body: JSON.stringify(body)
  });
  if (!response.ok) throw new Error(`Hook rejected: ${response.status}`);
}
publish().catch(error => {console.error(error.message); process.exit(1)});
process.stdin.resume();
