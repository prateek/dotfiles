import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { execFile, execFileSync } from 'node:child_process';
import { existsSync, mkdtempSync, readFileSync } from 'node:fs';
import https from 'node:https';
import http from 'node:http';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import test from 'node:test';

const helper = fileURLToPath(new URL('../../agent-marketplace/packages/utils-agent/skills/browser/scripts/pinned-loopback-proxy.mjs', import.meta.url));
const run = (...args) => execFileSync(process.execPath, [helper, ...args], { encoding: 'utf8', timeout: 10000 }).trim();
const startAsync = args => new Promise(resolve => execFile(process.execPath, [helper, ...args], { encoding: 'utf8', timeout: 10000 }, (error, stdout, stderr) => resolve({ error, stdout: stdout.trim(), stderr })));
const get = url => new Promise((resolve, reject) => http.get(url, response => {
  let body = ''; response.on('data', chunk => body += chunk); response.on('end', () => resolve({ status: response.statusCode, body }));
}).on('error', reject));

test('loopback proxy accepts only a pinned certificate and supports explicit lifecycle', async () => {
  const dir = mkdtempSync(path.join(os.tmpdir(), 'pinned-proxy-test-'));
  const key = path.join(dir, 'key.pem');
  const cert = path.join(dir, 'cert.pem');
  const state = path.join(dir, 'state.json');
  execFileSync('openssl', ['req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-subj', '/CN=localhost', '-days', '1', '-keyout', key, '-out', cert], { stdio: 'ignore' });
  const server = https.createServer({ key: readFileSync(key), cert: readFileSync(cert) }, (_request, response) => response.end('signed-in fixture'));
  server.on('upgrade', (_request, socket) => {
    socket.write('HTTP/1.1 101 Switching Protocols\r\nConnection: Upgrade\r\nUpgrade: websocket\r\n\r\n');
    socket.on('data', data => socket.write(data));
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const pin = createHash('sha256').update(new (await import('node:crypto')).X509Certificate(readFileSync(cert)).raw).digest('hex');
  const upstream = `https://127.0.0.1:${server.address().port}`;
  try {
    const url = run('start', '--upstream', upstream, '--pin', pin, '--state', state);
    assert.equal(run('status', '--state', state), url);
    assert.deepEqual(await get(url + '/'), { status: 200, body: 'signed-in fixture' });
    const consoleSocket = await new Promise((resolve, reject) => {
      const request = http.request(url + '/console', { headers: { Connection: 'Upgrade', Upgrade: 'websocket' } });
      request.on('upgrade', (_response, socket) => {
        socket.once('data', data => { assert.equal(data.toString(), 'console fixture'); resolve(socket); });
        socket.write('console fixture');
      });
      request.on('error', reject);
      request.end();
    });
    assert.equal((await get(url + '/__proxy_control')).status, 403);
    const closed = new Promise(resolve => consoleSocket.once('close', resolve));
    assert.equal(run('stop', '--state', state), 'stopped');
    await closed;
    const wrong = run('start', '--upstream', upstream, '--pin', '0'.repeat(64), '--state', state);
    assert.equal((await get(wrong + '/?token=dummy-secret')).status, 502);
    assert.match(readFileSync(`${state}.log`, 'utf8'), /proxy HTTP failure: PIN_MISMATCH/);
    assert.doesNotMatch(readFileSync(`${state}.log`, 'utf8'), /dummy-secret/);
    assert.equal(run('stop', '--state', state), 'stopped');
    const [first, second] = await Promise.all([
      startAsync(['start', '--upstream', upstream, '--pin', pin, '--state', state]),
      startAsync(['start', '--upstream', upstream, '--pin', '0'.repeat(64), '--state', state]),
    ]);
    const succeeded = [first, second].filter(result => !result.error);
    assert.equal(succeeded.length, 1);
    const active = JSON.parse(readFileSync(state, 'utf8'));
    assert.equal(succeeded[0].stdout, active.url);
    assert.equal(active.pin, succeeded[0] === first ? pin : '0'.repeat(64));
    assert.equal(run('stop', '--state', state), 'stopped');
  } finally {
    if (existsSync(state)) try { run('stop', '--state', state); } catch {}
    await new Promise(resolve => server.close(resolve));
  }
});
