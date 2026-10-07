#!/usr/bin/env node
const {spawn} = require('node:child_process');
const fs = require('node:fs');
process.title = 'claude';
const hook = {hooks: [{type: 'command', command: 'node /dotfiles/tests/fixtures/orca-shortcuts/forward-hook.cjs'}]};
const settings = {hooks: {SessionStart: [hook], UserPromptSubmit: [hook], Stop: [hook]}};
const child = spawn('/opt/real-agents/bin/claude', ['-p', '--verbose', '--input-format', 'stream-json',
  '--output-format', 'stream-json', '--model', 'claude-sonnet-4-6',
  '--settings', JSON.stringify(settings)], {
  env: {...process.env, ANTHROPIC_BASE_URL: 'http://127.0.0.1:8033', ANTHROPIC_API_KEY: 'fixture-only',
    CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC: '1'}, stdio: ['pipe', 'pipe', 'inherit']
});
let buffer = '';
child.stdout.on('data', chunk => {
  process.stdout.write(chunk);
  buffer += chunk;
  while (buffer.includes('\n')) {
    const end = buffer.indexOf('\n');
    const line = buffer.slice(0, end);
    buffer = buffer.slice(end + 1);
    try {
      const event = JSON.parse(line);
      if (event.type === 'result') fs.writeFileSync('/tmp/real-claude-result.json', JSON.stringify(event));
    } catch {}
  }
});
child.on('exit', code => process.exit(code ?? 1));
process.stdout.write('\x1b]0;Claude Code\x07');
child.stdin.write(JSON.stringify({type: 'user', message: {role: 'user', content: 'Return the fixture answer.'}}) + '\n');
