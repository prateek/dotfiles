#!/usr/bin/env node
import http from 'node:http';
import https from 'node:https';
import tls from 'node:tls';
import { createHash, randomBytes } from 'node:crypto';
import { readFileSync, writeFileSync, unlinkSync, lstatSync, openSync, closeSync, existsSync, fchmodSync } from 'node:fs';
import { spawn } from 'node:child_process';
import { setTimeout as delay } from 'node:timers/promises';

function options() {
  const args = process.argv.slice(3);
  const values = {};
  for (let i = 0; i < args.length; i += 2) {
    if (!args[i]?.startsWith('--') || !args[i + 1]) throw Error('expected --option value');
    values[args[i].slice(2)] = args[i + 1];
  }
  return values;
}
function config(values) {
  const upstream = new URL(values.upstream);
  if (upstream.protocol !== 'https:' || upstream.username || upstream.password || upstream.pathname !== '/' || upstream.search || upstream.hash) throw Error('upstream must be an HTTPS origin');
  if (!/^[0-9a-f]{64}$/.test(values.pin || '')) throw Error('pin must be a SHA-256 leaf certificate digest');
  if (!values.state) throw Error('--state is required');
  return { upstream, pin: values.pin, state: values.state };
}
function readState(path) {
  if (lstatSync(path).isSymbolicLink()) throw Error('state path is a symlink');
  const state = JSON.parse(readFileSync(path, 'utf8'));
  if (!Number.isInteger(state.port) || !/^[0-9a-f]{64}$/.test(state.token) || !/^[0-9a-f]{32}$/.test(state.launchId)) throw Error('proxy is not ready');
  return state;
}
function readReservation(path) {
  if (lstatSync(path).isSymbolicLink()) throw Error('state path is a symlink');
  return JSON.parse(readFileSync(path, 'utf8'));
}
function control(path, action) {
  const state = readState(path);
  return new Promise((resolve, reject) => {
    const request = http.request({ hostname: '127.0.0.1', port: state.port, path: '/__proxy_control', method: action === 'stop' ? 'POST' : 'GET', headers: { 'x-proxy-token': state.token }, timeout: 2000 }, response => {
      response.resume();
      response.on('end', () => response.statusCode === 200 ? resolve(state) : reject(Error('proxy control rejected')));
    });
    request.on('error', reject);
    request.on('timeout', () => request.destroy(Error('proxy control timed out')));
    request.end();
  });
}
function failureClass(error) {
  const code = error?.code;
  return new Set(['PIN_MISMATCH', 'UPSTREAM_TIMEOUT', 'ECONNREFUSED', 'ECONNRESET', 'ENETUNREACH', 'EHOSTUNREACH', 'ENOTFOUND', 'EAI_AGAIN']).has(code) ? code : 'UPSTREAM_ERROR';
}
function serve({ upstream, pin, state }, launchId) {
  const reservation = readReservation(state);
  if (reservation.launchId !== launchId || reservation.upstream !== upstream.origin || reservation.pin !== pin) throw Error('startup reservation changed');
  const token = randomBytes(32).toString('hex');
  const agent = new https.Agent({ keepAlive: true });
  const sockets = new Set();
  agent.createConnection = (_opts, callback) => {
    let done = false;
    const finish = (error, socket) => { if (!done) { done = true; callback(error, socket); } };
    const socket = tls.connect({ host: upstream.hostname, port: Number(upstream.port || 443), servername: upstream.hostname, rejectUnauthorized: false }, () => {
      const raw = socket.getPeerCertificate().raw;
      if (!raw || createHash('sha256').update(raw).digest('hex') !== pin) {
        const error = Error('certificate pin mismatch'); error.code = 'PIN_MISMATCH';
        socket.destroy(); finish(error); return;
      }
      socket.setTimeout(0);
      finish(null, socket);
    });
    socket.setTimeout(10000, () => {
      const error = Error('upstream timeout'); error.code = 'UPSTREAM_TIMEOUT';
      socket.destroy(error);
    });
    socket.on('error', finish);
  };
  let localOrigin;
  const allowed = request => request.headers.host === new URL(localOrigin).host && (!request.headers.origin || request.headers.origin === localOrigin);
  const forward = request => {
    const headers = { ...request.headers, host: upstream.host };
    if (headers.origin) headers.origin = upstream.origin;
    if (headers.referer?.startsWith(localOrigin + '/')) headers.referer = upstream.origin + headers.referer.slice(localOrigin.length);
    return https.request({ hostname: upstream.hostname, port: upstream.port || 443, path: request.url, method: request.method, headers, agent });
  };
  const server = http.createServer((request, response) => {
    if (request.url === '/__proxy_control') {
      if (request.headers['x-proxy-token'] !== token) { response.writeHead(403).end(); return; }
      if (request.method === 'POST') response.once('finish', () => {
        server.close(() => process.exit(0));
        for (const socket of sockets) socket.destroy();
      });
      response.writeHead(200).end();
      return;
    }
    if (!allowed(request)) { response.writeHead(403).end(); return; }
    const remote = forward(request);
    remote.on('response', upstreamResponse => {
      const headers = { ...upstreamResponse.headers };
      if (headers.location?.startsWith(upstream.origin + '/')) headers.location = localOrigin + headers.location.slice(upstream.origin.length);
      if (headers['set-cookie']) headers['set-cookie'] = headers['set-cookie'].map(cookie => cookie.replace(/;\s*Secure\b/gi, ''));
      delete headers['strict-transport-security'];
      response.writeHead(upstreamResponse.statusCode, headers);
      upstreamResponse.pipe(response);
    });
    remote.on('error', error => {
      console.error(`proxy HTTP failure: ${failureClass(error)}`);
      if (!response.headersSent) response.writeHead(502);
      response.end('Pinned upstream unavailable');
    });
    request.on('aborted', () => remote.destroy());
    request.pipe(remote);
  });
  server.on('upgrade', (request, socket, head) => {
    if (!allowed(request)) { socket.end('HTTP/1.1 403 Forbidden\r\nConnection: close\r\n\r\n'); return; }
    const remote = forward(request);
    remote.on('upgrade', (response, upstreamSocket, upstreamHead) => {
      const headers = [];
      for (let i = 0; i < response.rawHeaders.length; i += 2) headers.push(`${response.rawHeaders[i]}: ${response.rawHeaders[i + 1]}`);
      socket.write(`HTTP/1.1 101 Switching Protocols\r\n${headers.join('\r\n')}\r\n\r\n`);
      if (upstreamHead.length) socket.write(upstreamHead);
      if (head.length) upstreamSocket.write(head);
      upstreamSocket.pipe(socket); socket.pipe(upstreamSocket);
      socket.on('close', () => upstreamSocket.destroy());
      upstreamSocket.on('close', () => socket.destroy());
      socket.on('error', () => upstreamSocket.destroy());
      upstreamSocket.on('error', () => socket.destroy());
    });
    remote.on('response', response => { response.resume(); socket.end(`HTTP/1.1 ${response.statusCode} Upstream Rejected\r\nConnection: close\r\n\r\n`); });
    remote.on('error', error => { console.error(`proxy WebSocket failure: ${failureClass(error)}`); socket.destroy(); });
    remote.end();
  });
  server.on('connection', socket => {
    sockets.add(socket);
    socket.on('close', () => sockets.delete(socket));
  });
  server.listen(0, '127.0.0.1', () => {
    localOrigin = `http://127.0.0.1:${server.address().port}`;
    writeFileSync(state, JSON.stringify({ launchId, upstream: upstream.origin, pin, port: server.address().port, token, pid: process.pid, url: localOrigin }), { mode: 0o600 });
  });
  process.on('exit', () => { try { if (readReservation(state).launchId === launchId) unlinkSync(state); } catch {} });
}

try {
  const action = process.argv[2];
  const values = options();
  if (action === 'serve') serve(config(values), values['launch-id']);
  else if (action === 'start') {
    const setup = config(values);
    const launchId = randomBytes(16).toString('hex');
    const log = `${setup.state}.log`;
    const logFd = openSync(log, 'a', 0o600);
    fchmodSync(logFd, 0o600);
    try {
      writeFileSync(setup.state, JSON.stringify({ launchId, upstream: setup.upstream.origin, pin: setup.pin }), { mode: 0o600, flag: 'wx' });
    } catch (error) {
      closeSync(logFd);
      throw error;
    }
    let child;
    try {
      child = spawn(process.execPath, [process.argv[1], 'serve', '--upstream', setup.upstream.origin, '--pin', setup.pin, '--state', setup.state, '--launch-id', launchId], { detached: true, stdio: ['ignore', logFd, logFd] });
    } catch (error) {
      try { if (readReservation(setup.state).launchId === launchId) unlinkSync(setup.state); } catch {}
      throw error;
    } finally {
      closeSync(logFd);
    }
    child.unref();
    let ready = false;
    for (let i = 0; i < 40; i++) {
      await delay(100);
      try {
        const active = readState(setup.state);
        if (active.launchId !== launchId || active.upstream !== setup.upstream.origin || active.pin !== setup.pin) throw Error('startup ownership changed');
        await control(setup.state, 'status');
        console.log(active.url); ready = true; break;
      } catch {}
    }
    if (!ready) {
      child.kill();
      try { if (readReservation(setup.state).launchId === launchId) unlinkSync(setup.state); } catch {}
      throw Error(`proxy did not start; inspect ${log}`);
    }
  } else if (action === 'status' || action === 'stop') {
    const state = await control(values.state, action);
    if (action === 'stop') {
      for (let i = 0; i < 50 && existsSync(values.state); i++) await delay(20);
      if (existsSync(values.state)) throw Error('proxy did not stop; inspect its log');
    }
    console.log(action === 'status' ? state.url : 'stopped');
  } else throw Error('usage: pinned-loopback-proxy.mjs start --upstream https://host:port --pin <sha256> --state <path> | status/stop --state <path>');
} catch (error) {
  console.error(`pinned-loopback-proxy: ${error.message}`);
  process.exitCode = 1;
}
