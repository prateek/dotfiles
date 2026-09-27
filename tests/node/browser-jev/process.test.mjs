import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { once } from "node:events";
import { chmod, mkdir, mkdtemp, readFile, readdir, rmdir, rm, stat, symlink, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { setTimeout as delay } from "node:timers/promises";
import test from "node:test";
import { command, claimBrowser } from "../../../agent-marketplace/packages/utils-agent/skills/browser-jev/scripts/jev/process.mjs";

const moduleURL = new URL("../../../agent-marketplace/packages/utils-agent/skills/browser-jev/scripts/jev/process.mjs", import.meta.url).href;
const browser = { driver: "orca", worktree: "path:/test/worktree", pageId: "page-one" };

async function fixture(t) {
  const directory = await mkdtemp(join(tmpdir(), "jev-process-test-"));
  t.after(() => rm(directory, { recursive: true, force: true }));
  return directory;
}

async function waitForFile(path) {
  const until = Date.now() + 3000;
  while (Date.now() < until) {
    try { return await readFile(path, "utf8"); } catch (error) {
      if (error.code !== "ENOENT") throw error;
    }
    await delay(10);
  }
  throw new Error("Fixture process did not become ready");
}

test("command preserves literal argv and strips provider and unrelated environment secrets", async (t) => {
  const values = {
    CLOUDFLARE_API_TOKEN: "token-canary", CLOUDFLARE_ACCOUNT_ID: "account-canary",
    UNRELATED_SECRET: "other-canary", ORCA_CLI_COMMAND: "/test/orca wrapper",
    AGENT_BROWSER_NAMESPACE: "owned-namespace",
  };
  const prior = Object.fromEntries(Object.keys(values).map((key) => [key, process.env[key]]));
  Object.assign(process.env, values);
  t.after(() => {
    for (const [key, value] of Object.entries(prior)) {
      if (value === undefined) delete process.env[key]; else process.env[key] = value;
    }
  });
  const literal = "$(touch /never-run) ; $HOME `echo no`";
  const result = await command(process.execPath, ["-e", "console.log(JSON.stringify({env:process.env,arg:process.argv[1]}))", literal]);
  assert.equal(result.arg, literal);
  assert.equal(result.env.HOME, process.env.HOME);
  assert.equal(result.env.PATH, process.env.PATH);
  assert.equal(result.env.ORCA_CLI_COMMAND, values.ORCA_CLI_COMMAND);
  assert.equal(result.env.AGENT_BROWSER_NAMESPACE, values.AGENT_BROWSER_NAMESPACE);
  for (const key of ["CLOUDFLARE_API_TOKEN", "CLOUDFLARE_ACCOUNT_ID", "UNRELATED_SECRET"]) {
    assert.equal(result.env[key], undefined);
  }
});

test("command errors never include stderr, bad JSON, executable paths or secret argv", async () => {
  const canary = "private-page-canary";
  const cases = [
    [process.execPath, ["-e", `process.stderr.write('${canary}');process.exit(7)`], "command_failed"],
    [process.execPath, ["-e", `process.stdout.write('${canary}')`], "command_invalid_json"],
    [`/missing/${canary}`, [canary], "command_failed"],
  ];
  for (const [executable, args, code] of cases) {
    await assert.rejects(command(executable, args), (error) => {
      assert.equal(error.code, code);
      assert.equal(error.message, code);
      assert.ok(!error.stack.includes(canary));
      return true;
    });
  }
});

test("both stdout and discarded stderr are bounded", async () => {
  for (const stream of ["stdout", "stderr"]) {
    await assert.rejects(command(process.execPath, ["-e", `process.${stream}.write('x'.repeat(4096));setInterval(()=>{},1000)`], {
      maxBytes: 1024, signal: AbortSignal.timeout(3000),
    }), { code: "command_output_limit" });
  }
});

test("abort terminates the child and its descendant even when the descendant ignores TERM", async (t) => {
  const directory = await fixture(t);
  const ready = join(directory, "ready");
  const heartbeat = join(directory, "heartbeat");
  const descendant = `const fs=require('node:fs');process.on('SIGTERM',()=>{});setInterval(()=>fs.appendFileSync(process.argv[1],'x'),10);`;
  const script = `const {spawn}=require('node:child_process');const fs=require('node:fs');
    const child=spawn(process.execPath,['-e',${JSON.stringify(descendant)},${JSON.stringify(heartbeat)}],{stdio:'ignore'});
    fs.writeFileSync(${JSON.stringify(ready)},JSON.stringify({parent:process.pid,child:child.pid}));setInterval(()=>{},1000);`;
  const controller = new AbortController();
  const pending = command(process.execPath, ["-e", script], { signal: AbortSignal.any([controller.signal, AbortSignal.timeout(4000)]) });
  const rejected = assert.rejects(pending, { code: "command_aborted" });
  const pids = JSON.parse(await waitForFile(ready));
  t.after(() => { for (const pid of Object.values(pids)) { try { process.kill(pid, "SIGKILL"); } catch {} } });
  await waitForFile(heartbeat);
  controller.abort();
  await rejected;
  const stopped = await readFile(heartbeat, "utf8");
  await delay(150);
  assert.equal(await readFile(heartbeat, "utf8"), stopped);
  assert.throws(() => process.kill(pids.parent, 0), { code: "ESRCH" });
});

test("an already aborted call launches nothing", async (t) => {
  const directory = await fixture(t);
  const marker = join(directory, "unexpected");
  await assert.rejects(command(process.execPath, ["-e", `require('node:fs').writeFileSync(${JSON.stringify(marker)},'bad')`], {
    signal: AbortSignal.abort(),
  }), { code: "command_aborted" });
  assert.deepEqual(await readdir(directory), []);
});

test("one browser identity has one owner, releases idempotently, and uses private files", async (t) => {
  const directory = await fixture(t);
  const results = await Promise.allSettled(Array.from({ length: 8 }, () => claimBrowser(browser, { directory })));
  const winners = results.filter((result) => result.status === "fulfilled");
  assert.equal(winners.length, 1);
  for (const result of results.filter((result) => result.status === "rejected")) {
    assert.ok(["browser_busy", "reclaim_gate_busy"].includes(result.reason.code));
  }
  const [folder] = await readdir(directory);
  assert.equal((await stat(join(directory, folder))).mode & 0o777, 0o700);
  const [owner] = await readdir(join(directory, folder));
  assert.equal((await stat(join(directory, folder, owner))).mode & 0o777, 0o600);
  await winners[0].value();
  const release = await claimBrowser(browser, { directory });
  await winners[0].value();
  await assert.rejects(claimBrowser(browser, { directory }), { code: "browser_busy" });
  await release();
  assert.deepEqual(await readdir(directory), []);
});

test("claims contend across processes and recover only after the owner exits", async (t) => {
  const directory = await fixture(t);
  const script = `import {claimBrowser} from ${JSON.stringify(moduleURL)};
    await claimBrowser(${JSON.stringify(browser)},{directory:${JSON.stringify(directory)}});
    console.log('ready');setInterval(()=>{},1000);`;
  const child = spawn(process.execPath, ["--input-type=module", "-e", script], { stdio: ["ignore", "pipe", "pipe"] });
  const exited = once(child, "exit");
  t.after(() => child.kill("SIGKILL"));
  await once(child.stdout, "data", { signal: AbortSignal.timeout(3000) });
  await assert.rejects(claimBrowser(browser, { directory }), { code: "browser_busy" });
  child.kill("SIGKILL");
  await exited;
  const claims = await Promise.allSettled(Array.from({ length: 6 }, () => claimBrowser(browser, { directory })));
  const winners = claims.filter((result) => result.status === "fulfilled");
  assert.equal(winners.length, 1);
  for (const result of claims.filter((result) => result.status === "rejected")) {
    assert.ok(["browser_busy", "reclaim_gate_busy"].includes(result.reason.code));
  }
  await winners[0].value();
  assert.deepEqual(await readdir(directory), []);
});

test("an orphaned reclaim gate has a distinct fail-closed result and can be recovered manually", async (t) => {
  const directory = await fixture(t);
  const script = `import {claimBrowser} from ${JSON.stringify(moduleURL)};
    await claimBrowser(${JSON.stringify(browser)},{directory:${JSON.stringify(directory)}});
    console.log('ready');setInterval(()=>{},1000);`;
  const child = spawn(process.execPath, ["--input-type=module", "-e", script], { stdio: ["ignore", "pipe", "pipe"] });
  const exited = once(child, "exit");
  t.after(() => child.kill("SIGKILL"));
  await once(child.stdout, "data", { signal: AbortSignal.timeout(3000) });
  child.kill("SIGKILL");
  await exited;
  const [folder] = await readdir(directory);
  const gate = join(directory, `${folder}.reclaim`);
  await mkdir(gate, { mode: 0o700 });
  await assert.rejects(claimBrowser(browser, { directory }), { code: "reclaim_gate_busy" });
  await rmdir(gate);
  const release = await claimBrowser(browser, { directory });
  await release();
  assert.deepEqual(await readdir(directory), []);
});

test("different browser identities can coexist and malformed ownership stays busy", async (t) => {
  const directory = await fixture(t);
  const a = await claimBrowser(browser, { directory });
  const b = await claimBrowser({ ...browser, pageId: "page-two" }, { directory });
  const c = await claimBrowser({ driver: "agent-browser", session: "fixture", pageId: "page-one" }, { directory });
  await Promise.all([a(), b(), c()]);
  const release = await claimBrowser(browser, { directory });
  const [folder] = await readdir(directory);
  const [owner] = await readdir(join(directory, folder));
  await writeFile(join(directory, folder, owner), "not-valid-json");
  await assert.rejects(claimBrowser(browser, { directory }), { code: "browser_busy" });
  await release();
});

test("Orca worktree aliases cannot claim the same globally identified page twice", async (t) => {
  const directory = await fixture(t);
  const release = await claimBrowser(browser, { directory });
  t.after(release);
  await assert.rejects(claimBrowser({ ...browser, worktree: "id:worktree-alias" }, { directory }), {
    code: "browser_busy",
  });
});

test("agent-browser claims cover the whole named session across different pages", async (t) => {
  const directory = await fixture(t);
  const release = await claimBrowser({ driver: "agent-browser", session: "shared", pageId: "one" }, { directory });
  t.after(release);
  await assert.rejects(claimBrowser({ driver: "agent-browser", session: "shared", pageId: "two" }, { directory }), {
    code: "browser_busy",
  });
  const independent = await claimBrowser({ driver: "agent-browser", session: "other", pageId: "one" }, { directory });
  await independent();
});

test("public or symlinked lock directories fail closed without changing permissions", async (t) => {
  const directory = await fixture(t);
  await chmod(directory, 0o755);
  await assert.rejects(claimBrowser(browser, { directory }), { code: "browser_lock_failed" });
  assert.equal((await stat(directory)).mode & 0o777, 0o755);
  await chmod(directory, 0o700);
  const link = join(directory, "linked");
  await symlink(directory, link);
  await assert.rejects(claimBrowser(browser, { directory: link }), { code: "browser_lock_failed" });
});
