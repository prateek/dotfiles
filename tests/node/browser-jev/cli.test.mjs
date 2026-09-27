import assert from "node:assert/strict";
import { execFileSync, spawn } from "node:child_process";
import { chmod, cp, mkdir, mkdtemp, readFile, readdir, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { setTimeout as delay } from "node:timers/promises";
import test from "node:test";

const source = fileURLToPath(new URL("../../../agent-marketplace/packages/utils-agent/skills/browser-jev/", import.meta.url));
const regularBrowser = fileURLToPath(new URL("../../../agent-marketplace/packages/utils-agent/skills/browser/", import.meta.url));
const token = "synthetic-provider-token-canary";
const account = "0123456789abcdef0123456789abcdef";
const value = "Zürich 🌳 東京";

async function fixture(t, { mutate = false, failCleanup = false, focused = true,
  desktopWindowStatus = "available", capabilities = [], reachable = true } = {}) {
  const root = await mkdtemp(join(tmpdir(), "jev-cli-test-"));
  t.after(async () => {
    try {
      for (const path of JSON.parse(await readFile(join(root, "permission-loss.json"), "utf8"))) await chmod(path, 0o700);
    } catch (error) { if (error.code !== "ENOENT") throw error; }
    await rm(root, { recursive: true, force: true });
  });
  const skills = join(root, "exported-skills");
  const skill = join(skills, "browser-jev");
  const temporary = join(root, "temporary");
  await mkdir(skills);
  await cp(source, skill, { recursive: true });
  await cp(regularBrowser, join(skills, "browser"), { recursive: true });
  await mkdir(temporary);
  const executable = join(root, "fake-orca.mjs");
  await writeFile(executable, `#!${process.execPath}
import {appendFileSync,readFileSync,writeFileSync,readdirSync,chmodSync} from 'node:fs';
import {join} from 'node:path';
const root=${JSON.stringify(root)}, expected=${JSON.stringify(value)};
const args=process.argv.slice(2);
appendFileSync(join(root,'browser-calls.jsonl'),JSON.stringify({args,env:process.env})+'\\n');
const page=args[args.indexOf('--page')+1];
let field=${JSON.stringify(mutate ? "" : value)};
try {field=readFileSync(join(root,'field'),'utf8')} catch {}
let result;
if(args[0]==='status') result={app:{desktopWindowStatus:${JSON.stringify(desktopWindowStatus)}},graph:{state:'ready'},
  runtime:{reachable:${reachable},state:'ready',runtimeId:'fixture-runtime',capabilities:${JSON.stringify(capabilities)}}};
else if(args[0]==='tab') result={tab:{browserPageId:page,worktreeId:'fixture-worktree',profileId:'isolated'}};
else if(args[0]==='fill') {
  field=args[args.indexOf('--value')+1];writeFileSync(join(root,'field'),field);
  result={success:true};
} else if(args[0]==='eval') {
  const check=args[args.indexOf('--expression')+1].includes(expected) && field===expected;
  const observation={url:'https://fixture.test/search',documentId:'document-one',text:'Synthetic fixture',truncated:false,focused:${focused},
    controls:[{scopeIndex:0,selector:'#query',token:'node-one',fingerprint:'field:'+field,tag:'input',type:'text',role:'textbox',label:'Query',value:field,href:'',visible:true,disabled:false,checked:null,options:[]}],
    checks:[{index:0,matched:check}],scroll:{x:0,y:0,maxX:0,maxY:0}};
  result={result:JSON.stringify(observation),origin:observation.url};
  if(${failCleanup} && check) {
    const base=join(process.env.TMPDIR,'browser-jev-'+process.getuid());
    const paths=readdirSync(base).map(name=>join(base,name));
    writeFileSync(join(root,'permission-loss.json'),JSON.stringify(paths));
    for(const path of paths) chmodSync(path,0);
  }
} else process.exit(4);
console.log(JSON.stringify({ok:true,result}));
`);
  await chmod(executable, 0o700);
  const preload = join(root, "fake-provider.mjs");
  await writeFile(preload, `import {appendFileSync} from 'node:fs';
globalThis.fetch=async(url,options)=>{
  appendFileSync(${JSON.stringify(join(root, "provider-calls"))},'called\\n');
  if(!${mutate}) throw Error('Unexpected provider request');
  if(url!==${JSON.stringify(`https://api.cloudflare.com/client/v4/accounts/${account}/ai/run`)}) throw Error('Unexpected endpoint');
  const input=JSON.parse(options.body).input;
  const answers=Object.fromEntries(Object.entries(input.questions).map(([name,question])=>{
    const ids=Object.keys(question.criteria);
    const choice=name==='operation'?'FILL':name==='FILL_target'?'c0_FILL':ids[0];
    if(!ids.includes(choice)) throw Error('Fixture choice is absent from submitted question');
    return [name,{type:'choice',choice,confidence:1,probabilities:Object.fromEntries(ids.map(id=>[id,id===choice?1:0]))}];
  }));
  return Response.json({success:true,errors:[],result:{state:'Completed',result:{model:'jev-fixture',answers,usage:{input_tokens:10,output_tokens:1}}}});
};`);
  const job = {
    version: 1, goal: `Show ${value}`, browser: { driver: "orca", worktree: "id:fixture-worktree", pageId: `page-${root.split("/").at(-1)}` },
    provider: { kind: "cloudflare", model: "typesafe/jev" }, limits: { actions: 2, decisions: 3, elapsedMs: 3000 },
    scope: { origins: ["https://fixture.test"], foregroundInput: mutate, controls: [{ selector: "#query", operations: ["FILL"], inputId: "query" }] },
    inputs: { query: value }, checks: [{ selector: "#query", property: "value", equals: value }],
  };
  const env = {
    PATH: `${dirname(process.execPath)}:/usr/bin:/bin`, HOME: root, TMPDIR: temporary,
    ORCA_CLI_COMMAND: executable, CLOUDFLARE_API_TOKEN: token, CLOUDFLARE_ACCOUNT_ID: account,
    UNRELATED_SECRET: "unrelated-secret-canary",
  };
  return { root, skill, env, job, preload };
}

async function invoke(fixture, input = JSON.stringify(fixture.job), { splitAt } = {}) {
  const child = spawn(process.execPath, ["--import", fixture.preload, join(fixture.skill, "scripts/run-jev")], {
    cwd: fixture.root, env: fixture.env, stdio: ["pipe", "pipe", "pipe"],
  });
  const stdout = [], stderr = [];
  child.stdout.on("data", (chunk) => stdout.push(chunk));
  child.stderr.on("data", (chunk) => stderr.push(chunk));
  const completed = new Promise((resolve, reject) => {
    const timer = setTimeout(() => { child.kill("SIGKILL"); reject(new Error("CLI exceeded fixture deadline")); }, 5000);
    child.once("error", (error) => { clearTimeout(timer); reject(error); });
    child.once("close", (code) => { clearTimeout(timer); resolve(code); });
  });
  const bytes = Buffer.from(input);
  if (splitAt !== undefined) {
    child.stdin.write(bytes.subarray(0, splitAt));
    await delay(100);
    child.stdin.end(bytes.subarray(splitAt));
  } else child.stdin.end(bytes);
  const code = await completed;
  const output = Buffer.concat(stdout).toString("utf8");
  assert.equal(output.trim().split("\n").length, 1);
  assert.equal(Buffer.concat(stderr).toString("utf8"), "");
  assert.ok(!output.includes(token));
  assert.ok(!output.includes(account));
  return { code, result: JSON.parse(output) };
}

test("copied skill runs outside the repository, emits one verified JSON result, and isolates browser credentials", async (t) => {
  const current = await fixture(t);
  const linkedPolicy = await readFile(join(current.skill, "../browser/references/policy.md"), "utf8");
  assert.match(linkedPolicy, /focus/i);
  const { code, result } = await invoke(current);
  assert.equal(code, 0);
  assert.equal(result.status, "verified");
  assert.equal(result.reason, "checks_passed");
  assert.deepEqual(result.receipts, []);
  const calls = (await readFile(join(current.root, "browser-calls.jsonl"), "utf8")).trim().split("\n").map(JSON.parse);
  assert.ok(calls.some(({ args }) => args[0] === "eval"));
  assert.ok(calls.some(({ args }) => args[0] === "status"));
  for (const call of calls) {
    assert.equal(call.env.CLOUDFLARE_API_TOKEN, undefined);
    assert.equal(call.env.CLOUDFLARE_ACCOUNT_ID, undefined);
    assert.equal(call.env.UNRELATED_SECRET, undefined);
    assert.ok(!JSON.stringify(call.args).includes(token));
    assert.ok(!JSON.stringify(call.args).includes(account));
  }
  assert.ok(!(await readdir(current.root)).includes("provider-calls"));
  assert.equal((await invoke(current)).code, 0);
});

test("UTF-8 job input survives a byte split within a multibyte character", async (t) => {
  const current = await fixture(t);
  const input = JSON.stringify(current.job);
  const splitAt = Buffer.from(input).lastIndexOf(Buffer.from("ü")) + 1;
  assert.ok(splitAt > 0);
  const { code, result } = await invoke(current, input, { splitAt });
  assert.equal(code, 0);
  assert.equal(result.status, "verified");
  const calls = (await readFile(join(current.root, "browser-calls.jsonl"), "utf8")).trim().split("\n").map(JSON.parse);
  assert.ok(calls.find(({ args }) => args[0] === "eval").args.join(" ").includes(value));
  assert.ok(!(await readdir(current.root)).includes("provider-calls"));
});

test("invalid JSON, invalid job shapes and oversized input fail before browser or provider access", async (t) => {
  const current = await fixture(t);
  for (const input of ["{not-json", JSON.stringify({ ...current.job, checks: [] }), " ".repeat(131073)]) {
    const { code, result } = await invoke(current, input);
    assert.equal(code, 1);
    assert.equal(result.reason, "invalid_job");
  }
  const files = await readdir(current.root);
  assert.ok(!files.includes("browser-calls.jsonl"));
  assert.ok(!files.includes("provider-calls"));
});

test("agent-browser rejects malformed, oversized and FIFO configs with a stable reason before browser access", async (t) => {
  const current = await fixture(t);
  const malformed = join(current.root, "malformed.json");
  await writeFile(malformed, "{");
  const oversized = join(current.root, "oversized.json");
  await writeFile(oversized, " ".repeat(4097));
  const fifo = join(current.root, "config.fifo");
  execFileSync("mkfifo", [fifo]);
  for (const config of [malformed, oversized, fifo]) {
    const job = { ...current.job, browser: { driver: "agent-browser", session: "fixture", pageId: "page-one", config } };
    const { code, result } = await invoke(current, JSON.stringify(job));
    assert.equal(code, 2);
    assert.equal(result.reason, "browser_config_invalid");
  }
  const files = await readdir(current.root);
  assert.ok(!files.includes("browser-calls.jsonl"));
  assert.ok(!files.includes("provider-calls"));
});

test("cleanup permission failure preserves the completed mutation receipt and verified result", {
  skip: process.getuid() === 0 ? "Permission-denial fixture requires a non-root user" : false,
}, async (t) => {
  const current = await fixture(t, { mutate: true, failCleanup: true });
  const { code, result } = await invoke(current);
  assert.equal(code, 0);
  assert.equal(result.status, "verified");
  assert.equal(result.cleanup, "browser_lock_release_failed");
  assert.deepEqual(result.receipts.map(({ operation, dispatch, effect }) => ({ operation, dispatch, effect })), [
    { operation: "FILL", dispatch: "completed", effect: "confirmed" },
  ]);
  assert.equal(await readFile(join(current.root, "field"), "utf8"), value);
  assert.equal(await readFile(join(current.root, "provider-calls"), "utf8"), "called\n");
});

test("an unfocused Orca page hands back before dispatching a model-selected mutation", async (t) => {
  const current = await fixture(t, { mutate: true, focused: false });
  const { code, result } = await invoke(current);
  assert.equal(code, 2);
  assert.equal(result.status, "handoff");
  assert.equal(result.reason, "window_not_focused");
  assert.equal(result.counters.decisions, 1);
  assert.equal(result.counters.actions, 0);
  assert.deepEqual(result.receipts, []);
  const calls = (await readFile(join(current.root, "browser-calls.jsonl"), "utf8")).trim().split("\n").map(JSON.parse);
  assert.ok(calls.every(({ args }) => ["status", "tab", "eval"].includes(args[0])));
  assert.ok(!(await readdir(current.root)).includes("field"));
});

test("only an advertised headless capability permits unfocused input without foreground consent", async (t) => {
  for (const headless of [false, true]) {
    const current = await fixture(t, { mutate: true, focused: false, desktopWindowStatus: "openable",
      capabilities: headless ? ["browser.headless.v1"] : [] });
    current.job.scope.foregroundInput = false;
    const { code, result } = await invoke(current);
    if (headless) {
      assert.equal(code, 0);
      assert.equal(result.status, "verified");
      assert.equal(result.receipts[0].effect, "confirmed");
      assert.equal(await readFile(join(current.root, "field"), "utf8"), value);
    } else {
      assert.equal(code, 2);
      assert.equal(result.reason, "foreground_required");
      assert.deepEqual(result.receipts, []);
      assert.ok(!(await readdir(current.root)).includes("field"));
    }
  }
});

test("an unreachable Orca runtime hands back before page inspection or provider access", async (t) => {
  const current = await fixture(t, { reachable: false });
  const { code, result } = await invoke(current);
  assert.equal(code, 2);
  assert.equal(result.reason, "browser_runtime_unavailable");
  const calls = (await readFile(join(current.root, "browser-calls.jsonl"), "utf8")).trim().split("\n").map(JSON.parse);
  assert.ok(calls.length > 0);
  assert.ok(calls.every(({ args }) => args[0] === "status"));
  assert.ok(!(await readdir(current.root)).includes("provider-calls"));
});
