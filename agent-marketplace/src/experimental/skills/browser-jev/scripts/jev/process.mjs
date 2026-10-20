import { spawn } from "node:child_process";
import { createHash, randomUUID } from "node:crypto";
import { constants } from "node:fs";
import { lstat, mkdir, open, readdir, rmdir, unlink } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";

const environmentKeys = [
  "HOME", "PATH", "TMPDIR", "TMP", "TEMP", "USER", "LOGNAME", "LANG", "LC_ALL", "LC_CTYPE",
  "XDG_CONFIG_HOME", "XDG_CACHE_HOME", "XDG_DATA_HOME", "XDG_RUNTIME_DIR", "XDG_STATE_HOME",
  "ORCA_CLI_COMMAND", "ORCA_DEV_REPO_ROOT", "AGENT_BROWSER_NAMESPACE",
];

function failure(code) {
  return Object.assign(new Error(code), { code });
}

export async function command(executable, args, { signal, maxBytes = 1024 * 1024 } = {}) {
  if (signal?.aborted) throw failure("command_aborted");
  if (typeof executable !== "string" || !executable || executable.includes("\0")
      || !Array.isArray(args) || args.some((arg) => typeof arg !== "string" || arg.includes("\0"))
      || !Number.isSafeInteger(maxBytes) || maxBytes < 1) throw failure("command_failed");
  const env = Object.fromEntries(environmentKeys.filter((key) => process.env[key] !== undefined)
    .map((key) => [key, process.env[key]]));
  return new Promise((resolve, reject) => {
    let child;
    let error;
    let bytes = 0;
    let cleanupTimer;
    let settled = false;
    const stdout = [];
    const finish = (code) => {
      if (settled) return;
      settled = true;
      clearTimeout(cleanupTimer);
      signal?.removeEventListener("abort", abort);
      if (error || code !== 0) return reject(error ?? failure("command_failed"));
      try {
        resolve(JSON.parse(Buffer.concat(stdout).toString("utf8")));
      } catch {
        reject(failure("command_invalid_json"));
      }
    };
    const stop = (code) => {
      if (error || settled) return;
      error = failure(code);
      try {
        if (child.pid) process.kill(process.platform === "win32" ? child.pid : -child.pid, "SIGKILL");
      } catch {}
      cleanupTimer = setTimeout(() => {
        child.stdout.destroy();
        child.stderr.destroy();
        finish(null);
      }, 500);
    };
    const abort = () => stop("command_aborted");
    try {
      child = spawn(executable, args, { env, shell: false, detached: process.platform !== "win32", stdio: ["ignore", "pipe", "pipe"] });
    } catch {
      finish(null);
      return;
    }
    child.once("error", () => { error ??= failure("command_failed"); finish(null); });
    child.once("close", finish);
    for (const [stream, capture] of [[child.stdout, true], [child.stderr, false]]) {
      stream.on("data", (chunk) => {
        if (error) return;
        bytes += chunk.length;
        if (bytes > maxBytes) return stop("command_output_limit");
        if (capture) stdout.push(chunk);
      });
    }
    signal?.addEventListener("abort", abort, { once: true });
    if (signal?.aborted) abort();
  });
}

function identity(browser) {
  const resource = browser?.driver === "orca" ? browser.pageId
    : browser?.driver === "agent-browser" ? browser.session : undefined;
  if (typeof resource !== "string" || !resource) {
    throw failure("browser_lock_failed");
  }
  return createHash("sha256").update(JSON.stringify([browser.driver, resource])).digest("hex");
}

async function removeOwner(folder, owner) {
  try {
    await unlink(join(folder, owner));
  } catch (error) {
    if (error.code === "ENOENT") return;
    throw error;
  }
  try { await rmdir(folder); } catch (error) {
    if (!["ENOENT", "ENOTEMPTY"].includes(error.code)) throw error;
  }
}

async function reclaim(folder) {
  const gate = `${folder}.reclaim`;
  try { await mkdir(gate, { mode: 0o700 }); } catch (error) {
    if (error.code === "EEXIST") throw failure("reclaim_gate_busy");
    throw error;
  }
  try {
    return await reclaimOwner(folder);
  } finally {
    await rmdir(gate);
  }
}

async function reclaimOwner(folder) {
  const entries = await readdir(folder);
  if (entries.length !== 1 || !/^owner-[0-9]+-[a-f0-9-]+\.json$/.test(entries[0])) return false;
  const owner = entries[0];
  const handle = await open(join(folder, owner), constants.O_RDONLY | constants.O_NOFOLLOW);
  let record;
  try {
    const stat = await handle.stat();
    if (!stat.isFile() || stat.size > 1024 || (stat.mode & 0o077) || stat.uid !== process.getuid()) return false;
    record = JSON.parse(await handle.readFile("utf8"));
  } catch {
    return false;
  } finally {
    await handle.close();
  }
  if (!record || !Number.isSafeInteger(record.pid) || record.pid < 1 || !owner.startsWith(`owner-${record.pid}-`)) return false;
  try { process.kill(record.pid, 0); return false; } catch (error) {
    if (error.code !== "ESRCH") return false;
  }
  await removeOwner(folder, owner);
  return true;
}

export async function claimBrowser(browser, { directory = join(tmpdir(), `browser-jev-${process.getuid()}`) } = {}) {
  const folder = join(directory, identity(browser));
  const owner = `owner-${process.pid}-${randomUUID()}.json`;
  try {
    await mkdir(directory, { recursive: true, mode: 0o700 });
    const root = await lstat(directory);
    if (!root.isDirectory() || root.uid !== process.getuid() || (root.mode & 0o077)) throw failure("browser_lock_failed");
    for (let attempt = 0; attempt < 3; attempt++) {
      try {
        await mkdir(folder, { mode: 0o700 });
      } catch (error) {
        if (error.code !== "EEXIST") throw error;
        try {
          const stat = await lstat(folder);
          if (!stat.isDirectory() || stat.uid !== process.getuid() || (stat.mode & 0o077)) throw failure("browser_lock_failed");
          if (await reclaim(folder)) continue;
        } catch (error) {
          if (error.code === "ENOENT") continue;
          throw error;
        }
        throw failure("browser_busy");
      }
      try {
        const handle = await open(join(folder, owner), "wx", 0o600);
        try { await handle.writeFile(JSON.stringify({ pid: process.pid })); } finally { await handle.close(); }
      } catch (error) {
        await removeOwner(folder, owner);
        try { await rmdir(folder); } catch {}
        throw error;
      }
      let released = false;
      return async () => {
        if (released) return;
        try { await removeOwner(folder, owner); released = true; } catch { throw failure("browser_lock_failed"); }
      };
    }
    throw failure("browser_busy");
  } catch (error) {
    throw failure(["browser_busy", "reclaim_gate_busy"].includes(error.code) ? error.code : "browser_lock_failed");
  }
}
