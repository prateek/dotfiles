import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import * as fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { promisify } from "node:util";
import test from "node:test";
import * as work from "../../scripts/acpx/skill-rewrite.mjs";
import { createSkillFlow, createSweepFlow } from "../../scripts/acpx/skill-rewrite-flows.mjs";

const exec = promisify(execFile);
const api = {
  defineFlow: (definition) => definition,
  acp: (definition) => ({ ...definition, nodeType: "acp" }),
  action: (definition) => ({ ...definition, nodeType: "action" }),
};
const result = (stdout = "", code = 0) => ({ stdout, stderr: "", combinedOutput: stdout, exitCode: code, timedOut: false });

async function shell(execution) {
  const { stdout, stderr } = await exec(execution.command, execution.args, {
    cwd: execution.cwd, env: { ...process.env, ...execution.env },
    timeout: execution.timeoutMs, maxBuffer: execution.maxBufferBytes,
  });
  return { ...result(stdout), stderr, combinedOutput: stdout + stderr };
}

async function fixture(t) {
  const base = await fs.mkdtemp(path.join(os.tmpdir(), "skill-native-test-"));
  t.after(() => fs.rm(base, { recursive: true, force: true }));
  const repo = path.join(base, "source");
  await fs.mkdir(repo);
  const skills = ["one", "two"].map((name) => `${work.PACKAGES}/example/skills/${name}`);
  for (const skill of skills) {
    await fs.mkdir(path.join(repo, skill), { recursive: true });
    await fs.writeFile(path.join(repo, skill, "SKILL.md"), "Original\n");
    await fs.writeFile(path.join(repo, skill, "old.md"), "Old reference\n");
  }
  const plugin = path.join(repo, work.packageManifest(skills[0]));
  await fs.mkdir(path.dirname(plugin), { recursive: true });
  await work.writeJson(plugin, { name: "example", version: "1.2.3" });
  await fs.mkdir(path.join(repo, work.GUIDANCE), { recursive: true });
  for (const name of ["SKILL.md", "SKILL-MECHANICS.md"]) await fs.writeFile(path.join(repo, work.GUIDANCE, name), "Fixture guidance\n");
  await fs.writeFile(path.join(repo, "untouched.txt"), "Keep\n");
  const context = { state: { runId: "fixture-parent" }, runShell: shell };
  const git = (args, cwd = repo) => work.git(context, cwd, args);
  await git(["init", "-q"]);
  await git(["add", "-A"]);
  await git(["-c", "user.name=Fixture", "-c", "user.email=fixture@localhost", "-c", "commit.gpgSign=false", "commit", "-qm", "Fixture"]);
  return { base, repo, skills, context, git };
}

async function drive(flow, input, context, model) {
  const ctx = { ...context, input, outputs: {}, state: { runId: `fixture-${flow.name}` } };
  let current = flow.startAt;
  try {
    while (current) {
      const node = flow.nodes[current];
      if (node.nodeType === "acp") {
        await model(await node.prompt(ctx), node.profile);
        ctx.outputs[current] = await node.parse("Fixture response", ctx);
      } else {
        ctx.outputs[current] = await node.run(ctx);
      }
      current = flow.edges.find((edge) => edge.from === current)?.to;
    }
    return { action: "flow_run_result", runId: ctx.state.runId, runDir: "/fixture/native-run", status: "completed", outputs: ctx.outputs };
  } catch (error) {
    return { action: "flow_run_result", runId: ctx.state.runId, runDir: "/fixture/native-run", status: "failed", outputs: ctx.outputs, error: error.message };
  }
}

function modelFixture(journal, { mutateReview = false } = {}) {
  return async (prompt, profile) => {
    const task = JSON.parse(prompt.split("\n")[0].slice("Task metadata: ".length));
    journal.push({ phase: task.phase, roots: task.roots, profile });
    const report = { unresolved: [] };
    if (task.phase === "aggregate") {
      report.reviewedSkills = task.skills;
      await fs.appendFile(path.join(task.workspace, task.roots[0], "SKILL.md"), "Aggregate correction\n");
    } else {
      const files = await work.git({ runShell: shell }, task.workspace,
        ["ls-tree", "-r", "--name-only", "-z", task.baselineCommit, "--", ...task.roots]);
      report.coveredFiles = files.split("\0").filter(Boolean);
      const folder = path.join(task.workspace, task.roots[0]);
      if (task.phase === "rewrite") {
        await fs.rm(path.join(folder, "old.md"));
        await fs.writeFile(path.join(folder, "new.md"), "New reference\n");
        await fs.writeFile(path.join(folder, "helper.sh"), "#!/bin/sh\nexit 0\n", { mode: 0o755 });
      } else if (task.phase === "review") {
        report.findings = [{ id: "R1" }];
        if (mutateReview) await fs.writeFile(path.join(folder, "new.md"), "Reviewer mutation\n");
      } else {
        report.resolutions = [{ id: "R1", outcome: "fixed", evidence: "Added correction" }];
        await fs.appendFile(path.join(folder, "SKILL.md"), "Writer correction\n");
      }
    }
    await work.writeJson(task.report, report);
  };
}

function contextFixture(journal, options = {}) {
  const model = modelFixture(journal, options);
  const ctx = { state: { runId: "fixture-parent" }, runShell: async (execution) => {
    if (execution.command.endsWith("acpx-routing")) return result(JSON.stringify({ argv: ["fixture-afablex"], route: "fixture" }));
    if (execution.args[0] === "--version") return result("fixture version");
    if (execution.command === "just") return result("fixture validation", options.failValidation ? 1 : 0);
    if (execution.command !== "acpx") return shell(execution);
    assert.ok(execution.args.includes("--approve-all"));
    assert.equal(execution.args[execution.args.indexOf("--timeout") + 1], "1800");
    const task = await work.readJson(execution.args[execution.args.indexOf("--input-file") + 1]);
    const profiles = await work.readJson(path.join(execution.cwd, ".acpxrc.json"));
    assert.deepEqual(profiles.agents["skill-writer"].argv, ["fixture-writer"]);
    assert.deepEqual(profiles.agents["skill-opus"].argv, ["fixture-opus"]);
    return result(JSON.stringify(await drive(createSkillFlow(api), task, ctx, model)));
  } };
  return { ctx, model };
}

test("native graph owns all four model steps and keeps each skill ordered", () => {
  const child = createSkillFlow(api), parent = createSweepFlow(api);
  assert.deepEqual(Object.values(child.nodes).filter((node) => node.nodeType === "acp").map((node) => node.profile),
    ["skill-writer", "skill-opus", "skill-writer"]);
  assert.deepEqual(Object.values(parent.nodes).filter((node) => node.nodeType === "acp").map((node) => node.profile), ["afablex"]);
  assert.equal(child.nodes.rewrite.session.isolated, true);
  assert.deepEqual(child.edges.map((edge) => edge.to), ["rewrite", "saveDraft", "review", "checkReview", "fix", "saveFinal"]);
  assert.equal(parent.permissions.requireExplicitGrant, true);
});

test("exact model pins retain provider environment and reject unknown routes", () => {
  const writer = work.pinNativeRoute({ route: "codex", argv: ["env", "-u", "OPENAI_API_KEY",
    'CODEX_CONFIG={"model":"old","service_tier":"default"}', "codex-acp"] }, "writer");
  assert.deepEqual(JSON.parse(writer[3].slice("CODEX_CONFIG=".length)),
    { model: "gpt-6-sol", service_tier: "default", model_reasoning_effort: "high" });
  assert.deepEqual(writer.slice(1, 3), ["-u", "OPENAI_API_KEY"]);
  const opus = work.pinNativeRoute({ route: "claude-vertex", argv: ["env", "CLAUDE_CODE_USE_VERTEX=1",
    "ANTHROPIC_MODEL=old", "ANTHROPIC_DEFAULT_OPUS_MODEL=old", "CLAUDE_CODE_EFFORT_LEVEL=low", "claude-agent-acp"] }, "opus");
  for (const expected of ["ANTHROPIC_MODEL=claude-opus-5-5", "CLAUDE_CODE_EFFORT_LEVEL=high", "CLAUDE_CODE_USE_VERTEX=1"]) assert.ok(opus.includes(expected));
  assert.throws(() => work.pinNativeRoute({ route: "cursor", argv: ["cursor"] }, "writer"), /supply writerCommand/);
});

test("pool bounds active jobs, collects failures, and stops dequeuing on cancellation", async () => {
  const gate = Promise.withResolvers(), full = Promise.withResolvers();
  let active = 0, peak = 0;
  const pending = work.boundedMap([0, 1, 2, 3, 4], 2, async (item) => {
    active += 1; peak = Math.max(peak, active);
    if (active === 2) full.resolve();
    try { await gate.promise; if (item === 1) throw new Error("fixture failure"); return item; }
    finally { active -= 1; }
  });
  await full.promise;
  assert.equal(peak, 2);
  gate.resolve();
  const outcome = await pending;
  assert.deepEqual(outcome.results.sort(), [0, 2, 3, 4]);
  assert.deepEqual(outcome.failures, [{ item: 1, error: "fixture failure" }]);
  assert.equal(peak, 2);
  const abort = new AbortController(), visited = [];
  await assert.rejects(work.boundedMap([0, 1, 2], 1, async (item) => { visited.push(item); abort.abort(); }, abort.signal), /abort/i);
  assert.deepEqual(visited, [0]);
});

test("native pipeline exports aggregate fixes and preserves source bytes and index", async (t) => {
  const { repo, base, skills, git } = await fixture(t);
  await fs.writeFile(path.join(repo, skills[0], "SKILL.md"), "Pending source edit\n");
  await fs.writeFile(path.join(repo, skills[0], "pending.md"), "Untracked input\n");
  const beforeStatus = await git(["status", "--porcelain=v1", "-uall"]);
  const beforeIndex = await fs.readFile(path.join(repo, ".git/index"));
  const journal = [], { ctx, model } = contextFixture(journal);
  const outputDir = path.join(base, "run");
  const output = await drive(createSweepFlow(api), { repo, outputDir,
    writerCommand: ["fixture-writer"], opusCommand: ["fixture-opus"] }, ctx, model);
  assert.equal(output.status, "completed", output.error);
  assert.equal(output.outputs.export.status, "ready");
  assert.equal(output.outputs.export.versionBumps.length, 1);
  for (const skill of skills) assert.deepEqual(journal.filter((item) => item.roots.length === 1 && item.roots[0] === skill).map((item) => item.phase), ["rewrite", "review", "fix"]);
  assert.equal(journal.filter((item) => item.phase === "aggregate").length, 1);
  const replay = path.join(base, "replay");
  await work.clone(ctx, output.outputs.prepare, replay);
  await git(["apply", path.join(outputDir, "final.patch")], replay);
  assert.equal(await fs.readFile(path.join(replay, skills[0], "SKILL.md"), "utf8"), "Pending source edit\nWriter correction\nAggregate correction\n");
  await assert.rejects(fs.stat(path.join(replay, skills[0], "old.md")), { code: "ENOENT" });
  assert.equal(await fs.readFile(path.join(replay, skills[0], "new.md"), "utf8"), "New reference\n");
  assert.ok((await fs.stat(path.join(replay, skills[0], "helper.sh"))).mode & 0o100);
  assert.equal((await work.readJson(path.join(replay, work.packageManifest(skills[0])))).version, "1.2.4");
  assert.equal(await git(["status", "--porcelain=v1", "-uall"]), beforeStatus);
  assert.deepEqual(await fs.readFile(path.join(repo, ".git/index")), beforeIndex);
});

test("explicit skill selection limits model calls and patch scope", async (t) => {
  const { repo, base, skills, git } = await fixture(t);
  const journal = [], { ctx, model } = contextFixture(journal);
  const output = await drive(createSweepFlow(api), { repo, outputDir: path.join(base, "selected"),
    skills: [skills[1]], concurrency: 2,
    writerCommand: ["fixture-writer"], opusCommand: ["fixture-opus"] }, ctx, model);
  assert.equal(output.status, "completed", output.error);
  assert.deepEqual(output.outputs.prepare.skills, [skills[1]]);
  assert.deepEqual(journal.map((entry) => entry.phase), ["rewrite", "review", "fix", "aggregate"]);
  assert.ok(journal.every((entry) => entry.roots.length === 1 && entry.roots[0] === skills[1]));
  const changed = (await git(["diff", "--cached", "--name-only", output.outputs.prepare.baselineCommit],
    path.join(base, "selected/combined"))).trim().split("\n");
  assert.ok(changed.every((file) => file.startsWith(`${skills[1]}/`) || file === work.packageManifest(skills[1])));
  for (const [index, selection] of [[], [skills[0], skills[0]], ["../outside"], ["missing-skill"], "all"].entries()) {
    await assert.rejects(work.prepare(ctx, { repo, skills: selection, outputDir: path.join(base, `invalid-${index}`),
      writerCommand: ["fixture-writer"], opusCommand: ["fixture-opus"] }), /skills must|Unknown authored skill/);
  }
});

test("reviewer mutation and native failed status block aggregation without discarding work", async (t) => {
  const { repo, base } = await fixture(t);
  const journal = [], { ctx, model } = contextFixture(journal, { mutateReview: true });
  const output = await drive(createSweepFlow(api), { repo, outputDir: path.join(base, "run"),
    writerCommand: ["fixture-writer"], opusCommand: ["fixture-opus"] }, ctx, model);
  assert.equal(output.status, "failed");
  assert.match(output.error, /2 skill\(s\) failed/);
  assert.equal(journal.filter((item) => item.phase === "aggregate").length, 0);
  assert.equal((await fs.readdir(path.join(base, "run/workspaces"))).length, 2);
  await assert.rejects(fs.stat(path.join(base, "run/final.patch")), { code: "ENOENT" });
});

test("scope escapes and validation failures cannot produce the final patch", async (t) => {
  const { repo, base, skills } = await fixture(t);
  const journal = [], { ctx, model } = contextFixture(journal, { failValidation: true });
  const output = await drive(createSweepFlow(api), { repo, outputDir: path.join(base, "run"),
    writerCommand: ["fixture-writer"], opusCommand: ["fixture-opus"] }, ctx, model);
  assert.equal(output.status, "failed");
  assert.match(output.error, /just exited 1/);
  await assert.rejects(fs.stat(path.join(base, "run/final.patch")), { code: "ENOENT" });
  await assert.rejects(fs.stat(path.join(base, "run/receipt.json")), { code: "ENOENT" });
  const manifest = output.outputs.prepare, workspace = path.join(base, "scope");
  await work.clone(ctx, manifest, workspace);
  await fs.writeFile(path.join(workspace, "untouched.txt"), "Escape\n");
  await assert.rejects(work.capture(ctx, { ...manifest, workspace }, [skills[0]], path.join(base, "escape.patch")), /Out-of-scope/);
});

test("command deadlines belong to acpx and cancellation prevents a new command", async () => {
  const executions = [];
  const ctx = { runShell: async (execution) => { executions.push(execution); return { ...result(), timedOut: true }; } };
  await assert.rejects(work.command(ctx, "/fixture", "agent", [], { timeoutMs: 200 }), /timed out/);
  assert.equal(executions[0].timeoutMs, 200);
  const abort = new AbortController(); abort.abort();
  await assert.rejects(work.command({ ...ctx, signal: abort.signal }, "/fixture", "agent", []), /abort/i);
  assert.equal(executions.length, 1);
});
