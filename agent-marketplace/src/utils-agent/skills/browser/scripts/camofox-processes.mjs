import childProcess from 'node:child_process';
import { appendFileSync, writeSync } from 'node:fs';
import { syncBuiltinESMExports } from 'node:module';

const originalSpawn = childProcess.spawn;
const journal = process.env.CAMOFOX_PROCESS_JOURNAL;
const executable = process.env.CAMOUFOX_EXECUTABLE;
if (!journal || !executable) throw new Error('Missing Camofox process ownership configuration');

childProcess.spawn = function (file, args, options) {
  const child = originalSpawn.call(this, file, args, options);
  if (file !== executable || !child.pid) return child;
  try {
    // Record the detached group before querying a child that may exit immediately.
    appendFileSync(journal, JSON.stringify({ event: 'spawn', pid: child.pid,
      group: options?.detached ? child.pid : null }) + '\n', { mode: 0o600 });
    const started = childProcess.execFileSync('/bin/ps',
      ['-p', String(child.pid), '-o', 'lstart='], { encoding: 'utf8', timeout: 2000 }).trim();
    if (!started) throw new Error('Browser process identity unavailable');
    appendFileSync(journal, JSON.stringify({ event: 'identity', pid: child.pid, started }) + '\n');
  } catch (error) {
    try { process.kill(options?.detached ? -child.pid : child.pid, 'SIGKILL'); } catch {}
    try {
      writeSync(2, `Camofox ownership journal failed: ${String(error).slice(0, 512)}\n`);
    } finally {
      process.exit(70);
    }
  }
  return child;
};
syncBuiltinESMExports();
