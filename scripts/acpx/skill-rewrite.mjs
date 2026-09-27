import { createHash } from "node:crypto";
import * as fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

export const PACKAGES = "agent-marketplace/packages";
export const GUIDANCE = "agent-marketplace/apm_modules/mattpocock/skills/skills/productivity/writing-for-agents";
const HERE = path.dirname(fileURLToPath(import.meta.url));
const CHILD_RUNTIME = ["rewrite-skill.flow.mjs", "skill-rewrite-flows.mjs", "skill-rewrite.mjs"];
const hash = (bytes) => createHash("sha256").update(bytes).digest("hex");
const lines = (value) => value.split("\0").filter(Boolean);
const sameSet = (a, b) => Array.isArray(a) && new Set(a).size === b.length && b.every((item) => a.includes(item));

export async function writeJson(file, value) {
  await fs.writeFile(`${file}.tmp`, `${JSON.stringify(value, null, 2)}\n`, { mode: 0o600 });
  await fs.rename(`${file}.tmp`, file);
}

export async function readJson(file) {
  return JSON.parse(await fs.readFile(file, "utf8"));
}

export async function command(ctx, cwd, executable, args, options = {}) {
  ctx.signal?.throwIfAborted();
  if (!ctx.runShell) throw new Error("This operation requires an acpx action context");
  const { log, ...execution } = options;
  const result = await ctx.runShell({
    command: executable, args, cwd, timeoutMs: 300_000,
    maxBufferBytes: 16 * 1024 * 1024, ...execution,
  });
  if (log) await fs.writeFile(log, result.combinedOutput, { mode: 0o600 });
  if (result.timedOut || result.exitCode !== 0) {
    throw new Error(`${executable} ${result.timedOut ? "timed out" : `exited ${result.exitCode}`}: ${log ?? result.stderr.slice(-4000)}`);
  }
  return result.stdout;
}

export const git = (ctx, cwd, args, options) => command(ctx, cwd, "git", ["-c", "core.hooksPath=/dev/null", ...args], options);

export function pinNativeRoute(selection, family) {
  const argv = [...selection.argv];
  const replace = (key, transform) => {
    const positions = argv.flatMap((part, index) => part.startsWith(`${key}=`) ? [index] : []);
    if (positions.length !== 1) throw new Error(`Route needs exactly one ${key} assignment`);
    const index = positions[0];
    argv[index] = `${key}=${transform(argv[index].slice(key.length + 1))}`;
  };
  if (family === "writer" && selection.route === "codex") {
    replace("CODEX_CONFIG", (value) => JSON.stringify({
      ...JSON.parse(value), model: "gpt-6-sol", model_reasoning_effort: "high",
    }));
  } else if (family === "opus" && ["claude", "claude-vertex"].includes(selection.route)) {
    replace("ANTHROPIC_MODEL", () => "claude-opus-5-5");
    replace("ANTHROPIC_DEFAULT_OPUS_MODEL", () => "claude-opus-5-5");
    replace("CLAUDE_CODE_EFFORT_LEVEL", () => "high");
  } else {
    throw new Error(`Cannot pin ${family} through ${selection.route}; supply ${family}Command argv explicitly`);
  }
  return validateArgv(argv);
}

function validateArgv(argv) {
  if (!Array.isArray(argv) || !argv.length || argv.some((value) => typeof value !== "string" || !value)) {
    throw new Error("Agent commands must be nonempty argv arrays");
  }
  return argv;
}

async function directoryEntries(directory) {
  try { return await fs.readdir(directory, { withFileTypes: true }); }
  catch (error) { if (error.code === "ENOENT") return []; throw error; }
}

async function rejectSymlinks(directory) {
  for (const entry of await directoryEntries(directory)) {
    const target = path.join(directory, entry.name);
    if (entry.isSymbolicLink()) throw new Error(`Symlink skill payload: ${target}`);
    if (entry.isDirectory()) await rejectSymlinks(target);
  }
}

export async function discover(repo) {
  const skills = [];
  for (const pkg of await directoryEntries(path.join(repo, PACKAGES))) {
    if (pkg.isSymbolicLink()) throw new Error(`Symlink package: ${pkg.name}`);
    if (!pkg.isDirectory()) continue;
    const root = path.join(PACKAGES, pkg.name, "skills");
    const stat = await fs.lstat(path.join(repo, root)).catch((error) => {
      if (error.code === "ENOENT") return null; throw error;
    });
    if (stat?.isSymbolicLink()) throw new Error(`Symlink skill directory: ${root}`);
    for (const skill of await directoryEntries(path.join(repo, root))) {
      if (skill.isSymbolicLink()) throw new Error(`Symlink skill: ${skill.name}`);
      if (!skill.isDirectory()) continue;
      const relative = path.join(root, skill.name);
      const folder = path.join(repo, relative);
      if (!(await fs.stat(path.join(folder, "SKILL.md"))).isFile()) throw new Error(`Missing skill entrypoint: ${relative}`);
      await rejectSymlinks(folder);
      skills.push(relative);
    }
  }
  if (!skills.length) throw new Error("No authored skills found");
  return skills.sort();
}

async function snapshot(ctx, repo, runDir) {
  const target = path.join(runDir, "baseline");
  const index = path.join(runDir, "snapshot.index");
  const env = { GIT_INDEX_FILE: index, GIT_LITERAL_PATHSPECS: "1" };
  await git(ctx, repo, ["read-tree", "HEAD"], { env });
  await git(ctx, repo, ["add", "-A", "--", "."], { env });
  const tree = (await git(ctx, repo, ["write-tree"], { env })).trim();
  await fs.mkdir(target);
  await git(ctx, repo, ["checkout-index", "--all", `--prefix=${target}/`], { env });
  await git(ctx, target, ["init", "-q"]);
  await git(ctx, target, ["add", "-A", "-f", "--", "."]);
  await git(ctx, target, ["-c", "user.name=Skill rewrite", "-c", "user.email=skill-rewrite@localhost",
    "-c", "commit.gpgSign=false", "commit", "-qm", "Input snapshot"]);
  await fs.rm(index);
  return { sourceTree: tree, baselineCommit: (await git(ctx, target, ["rev-parse", "HEAD"])).trim() };
}

export async function prepare(ctx, options) {
  const allowed = ["repo", "skills", "concurrency", "agentTimeoutSeconds", "outputDir", "writerCommand", "opusCommand"];
  if (!options || typeof options !== "object" || Array.isArray(options)) throw new Error("Flow input must be an object");
  for (const key of Object.keys(options)) if (!allowed.includes(key)) throw new Error(`Unknown input: ${key}`);
  if (options.skills !== undefined && (!Array.isArray(options.skills) || !options.skills.length ||
      options.skills.some((skill) => typeof skill !== "string" || !skill) ||
      new Set(options.skills).size !== options.skills.length)) {
    throw new Error("skills must be a nonempty array of unique authored skill paths");
  }
  const repo = await fs.realpath(options.repo ?? process.cwd());
  const root = await fs.realpath((await git(ctx, repo, ["rev-parse", "--show-toplevel"])).trim());
  if (repo !== root) throw new Error("repo must be the repository root");
  const concurrency = options.concurrency ?? 3;
  const agentTimeoutSeconds = options.agentTimeoutSeconds ?? 1800;
  if (!Number.isInteger(concurrency) || concurrency < 1 || concurrency > 16) throw new Error("concurrency must be 1–16");
  if (!Number.isInteger(agentTimeoutSeconds) || agentTimeoutSeconds < 1 || agentTimeoutSeconds > 21600) {
    throw new Error("agentTimeoutSeconds must be 1–21600");
  }
  const agents = {};
  for (const [family, shortcut] of [["writer", "agpt"], ["opus", "aopus"]]) {
    agents[family] = options[`${family}Command`] === undefined
      ? pinNativeRoute(JSON.parse(await command(ctx, repo, path.join(os.homedir(), ".agents/bin/acpx-routing"), ["show", shortcut])), family)
      : validateArgv(options[`${family}Command`]);
  }
  await command(ctx, repo, path.join(os.homedir(), ".agents/bin/acpx-routing"), ["show", "afablex"]);
  await command(ctx, repo, "acpx", ["--version"]);
  await command(ctx, repo, "just", ["--version"]);
  let runDir;
  if (options.outputDir) {
    const requested = path.resolve(options.outputDir);
    const parent = await fs.realpath(path.dirname(requested));
    runDir = path.join(parent, path.basename(requested));
    if (runDir === repo || runDir.startsWith(`${repo}${path.sep}`)) throw new Error("outputDir must be outside the source checkout");
    await fs.mkdir(runDir, { mode: 0o700 });
  } else {
    runDir = await fs.realpath(await fs.mkdtemp(path.join(os.tmpdir(), "acpx-skill-rewrite-")));
  }
  const baseline = await snapshot(ctx, repo, runDir);
  const seed = path.join(runDir, "baseline");
  const authored = await discover(seed);
  const skills = [...(options.skills ?? authored)].sort();
  for (const skill of skills) if (!authored.includes(skill)) throw new Error(`Unknown authored skill: ${skill}`);
  for (const name of ["SKILL.md", "SKILL-MECHANICS.md"]) await fs.access(path.join(seed, GUIDANCE, name));
  for (const name of ["jobs", "workspaces", "runtime"]) await fs.mkdir(path.join(runDir, name));
  for (const name of CHILD_RUNTIME) await fs.copyFile(path.join(HERE, name), path.join(runDir, "runtime", name));
  await fs.cp(path.join(HERE, "skill-rewrite-prompts"), path.join(runDir, "prompts"), { recursive: true });
  const manifest = { schema: 2, runDir, source: repo, parentRunId: ctx.state.runId, ...baseline,
    skills, concurrency, agentTimeoutSeconds, agents };
  await writeJson(path.join(runDir, "manifest.json"), manifest);
  return manifest;
}

export async function clone(ctx, manifest, target) {
  await git(ctx, manifest.runDir, ["clone", "--quiet", "--shared", path.join(manifest.runDir, "baseline"), target]);
  await git(ctx, target, ["remote", "remove", "origin"]);
}

export async function capture(ctx, task, roots, destination) {
  const { workspace, baselineCommit: base } = task;
  if ((await git(ctx, workspace, ["rev-parse", "HEAD"])).trim() !== base) throw new Error("Agent changed repository history");
  await git(ctx, workspace, ["add", "-A", "--", "."]);
  for (const root of roots) {
    if (await fs.lstat(path.join(workspace, root)).catch(() => null)) await git(ctx, workspace, ["add", "-A", "-f", "--", root]);
  }
  const changed = lines(await git(ctx, workspace, ["diff", "--cached", "--name-only", "-z", base]));
  const escaped = changed.filter((file) => !roots.some((root) => file === root || file.startsWith(`${root}/`)));
  if (escaped.length) throw new Error(`Out-of-scope changes: ${escaped.join(", ")}`);
  for (const file of changed) {
    if ((await fs.lstat(path.join(workspace, file)).catch(() => null))?.isSymbolicLink()) throw new Error(`Symlink output: ${file}`);
    if (file.split("/").includes("__pycache__")) throw new Error(`Generated bytecode: ${file}`);
  }
  for (const skill of task.skills.filter((skill) => roots.includes(skill))) {
    if (!(await fs.stat(path.join(workspace, skill, "SKILL.md")).catch(() => null))?.isFile()) throw new Error(`Removed skill entrypoint: ${skill}`);
  }
  await git(ctx, workspace, ["diff", "--cached", "--check", base]);
  const patch = await git(ctx, workspace, ["diff", "--cached", "--binary", "--full-index", "--no-ext-diff",
    "--no-textconv", "--no-color", "--src-prefix=a/", "--dst-prefix=b/", "--no-renames", base]);
  await fs.writeFile(destination, patch, { mode: 0o600 });
  return changed;
}

export async function prompt(task, phase) {
  const metadata = { phase, workspace: task.workspace, roots: task.roots, runDir: task.runDir,
    report: path.join(task.artifacts, `${phase}.report.json`), artifacts: task.artifacts,
    baselineCommit: task.baselineCommit, skills: task.roots, guidance: path.join(task.workspace, GUIDANCE) };
  return `Task metadata: ${JSON.stringify(metadata)}\n\n${await fs.readFile(path.join(task.runDir, "prompts/common.md"), "utf8")}\n${await fs.readFile(path.join(task.runDir, "prompts", `${phase}.md`), "utf8")}`;
}

export async function report(task, phase) {
  const file = path.join(task.artifacts, `${phase}.report.json`);
  const result = await readJson(file);
  if (!Array.isArray(result.unresolved) || result.unresolved.length) throw new Error(`Missing or unresolved completion report: ${file}`);
  const key = phase === "aggregate" ? "reviewedSkills" : "coveredFiles";
  if (!sameSet(result[key], phase === "aggregate" ? task.skills : task.originalFiles)) throw new Error(`Incomplete ${key}: ${file}`);
  if (phase === "review") {
    if (!Array.isArray(result.findings) || result.findings.some((item) => typeof item.id !== "string" || !item.id)) throw new Error(`Invalid findings: ${file}`);
    const ids = result.findings.map((item) => item.id);
    if (new Set(ids).size !== ids.length) throw new Error(`Duplicate finding IDs: ${file}`);
  }
  if (phase === "fix") {
    const review = await readJson(path.join(task.artifacts, "review.report.json"));
    const resolutions = result.resolutions ?? [];
    if (!Array.isArray(resolutions) || !sameSet(resolutions.map((item) => item.id), review.findings.map((item) => item.id)) ||
        resolutions.some((item) => !["fixed", "rejected"].includes(item.outcome) || !item.evidence)) {
      throw new Error(`Not every finding has an evidenced resolution: ${file}`);
    }
  }
  return result;
}

export async function setupSkill(ctx, task) {
  await clone(ctx, task, task.workspace);
  return { skill: task.skill, workspace: task.workspace, parentRunId: task.parentRunId };
}

export async function saveDraft(ctx, task) {
  await report(task, "rewrite");
  const patch = path.join(task.artifacts, "draft.patch");
  await capture(ctx, task, task.roots, patch);
  return { patch };
}

export async function checkReview(ctx, task) {
  await report(task, "review");
  const temporary = path.join(task.artifacts, "after-review.patch");
  await capture(ctx, task, task.roots, temporary);
  if (!(await fs.readFile(temporary)).equals(await fs.readFile(path.join(task.artifacts, "draft.patch")))) {
    throw new Error("Read-only reviewer changed the workspace");
  }
  await fs.rm(temporary);
  return { review: path.join(task.artifacts, "review.report.json") };
}

export async function saveFinal(ctx, task) {
  await report(task, "fix");
  const patch = path.join(task.artifacts, "final.patch");
  const changed = await capture(ctx, task, task.roots, patch);
  return { skill: task.skill, status: "complete", patch, sha256: hash(await fs.readFile(patch)), changed };
}

export async function boundedMap(items, concurrency, worker, signal) {
  let next = 0;
  const results = [], failures = [];
  await Promise.all(Array.from({ length: Math.min(concurrency, items.length) }, async () => {
    while (next < items.length && !signal?.aborted) {
      const item = items[next++];
      try { results.push(await worker(item)); }
      catch (error) { failures.push({ item, error: error.message }); }
    }
  }));
  signal?.throwIfAborted();
  return { results, failures };
}

export async function rewriteSkills(ctx, manifest) {
  const outcome = await boundedMap(manifest.skills, manifest.concurrency, async (skill) => {
    const id = `${String(manifest.skills.indexOf(skill)).padStart(4, "0")}-${path.basename(skill)}`;
    const artifacts = path.join(manifest.runDir, "jobs", id);
    await fs.mkdir(artifacts);
    const originalFiles = lines(await git(ctx, path.join(manifest.runDir, "baseline"),
      ["ls-tree", "-r", "--name-only", "-z", manifest.baselineCommit, "--", skill]));
    const task = { ...manifest, skill, roots: [skill], originalFiles, artifacts,
      workspace: path.join(manifest.runDir, "workspaces", id) };
    await writeJson(path.join(artifacts, "input.json"), task);
    await writeJson(path.join(artifacts, ".acpxrc.json"), { agents: {
      "skill-writer": { argv: manifest.agents.writer }, "skill-opus": { argv: manifest.agents.opus },
    } });
    let flowRun;
    try {
      const args = ["--cwd", artifacts, "--approve-all", "--non-interactive-permissions", "deny",
        "--format", "json", "--json-strict", "--timeout", String(manifest.agentTimeoutSeconds),
        "flow", "run", path.join(manifest.runDir, "runtime/rewrite-skill.flow.mjs"),
        "--input-file", path.join(artifacts, "input.json")];
      await writeJson(path.join(artifacts, "invocation.json"), { command: "acpx", args });
      const output = await command(ctx, artifacts, "acpx", args, {
        timeoutMs: (3 * manifest.agentTimeoutSeconds + 1800) * 1000,
        env: { PYTHONDONTWRITEBYTECODE: "1" }, log: path.join(artifacts, "native-flow.log"),
      });
      flowRun = JSON.parse(output);
      await writeJson(path.join(artifacts, "native-flow.json"), flowRun);
      if (flowRun.status !== "completed" || !flowRun.outputs?.saveFinal) throw new Error(`Child flow ${flowRun.status}: ${flowRun.runDir}`);
      const result = { ...flowRun.outputs.saveFinal, runId: flowRun.runId, runDir: flowRun.runDir };
      await writeJson(path.join(artifacts, "result.json"), result);
      await fs.rm(task.workspace, { recursive: true });
      return result;
    } catch (error) {
      await writeJson(path.join(artifacts, "result.json"), { skill, status: "failed", error: error.message,
        workspace: task.workspace, runDir: flowRun?.runDir });
      throw error;
    }
  }, ctx.signal);
  outcome.results.sort((a, b) => a.skill.localeCompare(b.skill));
  await writeJson(path.join(manifest.runDir, "results.json"), outcome);
  if (outcome.failures.length) throw new Error(`${outcome.failures.length} skill(s) failed; see ${manifest.runDir}/results.json`);
  return outcome;
}

async function verifiedRows(manifest) {
  const { results, failures } = await readJson(path.join(manifest.runDir, "results.json"));
  if (failures.length || !sameSet(results.map((row) => row.skill), manifest.skills)) throw new Error("Every skill must succeed before aggregate review");
  for (const row of results) {
    if (hash(await fs.readFile(row.patch)) !== row.sha256) throw new Error(`Changed worker patch: ${row.patch}`);
  }
  return results;
}

export async function assemble(ctx, manifest) {
  const rows = await verifiedRows(manifest);
  const task = { ...manifest, workspace: path.join(manifest.runDir, "combined"),
    artifacts: path.join(manifest.runDir, "aggregate"), roots: manifest.skills };
  await clone(ctx, manifest, task.workspace);
  for (const row of rows) {
    if ((await fs.stat(row.patch)).size) {
      await git(ctx, task.workspace, ["apply", "--check", row.patch]);
      await git(ctx, task.workspace, ["apply", row.patch]);
    }
  }
  await capture(ctx, task, task.roots, path.join(manifest.runDir, "combined-before-review.patch"));
  await fs.mkdir(task.artifacts);
  return task;
}

export const packageManifest = (skill) => `${skill.split("/").slice(0, 3).join("/")}/.codex-plugin/plugin.json`;

export async function exportPatch(ctx, task) {
  await report(task, "aggregate");
  await verifiedRows(task);
  const candidate = path.join(task.runDir, "candidate.patch");
  const changed = await capture(ctx, task, task.roots, candidate);
  const versions = [...new Set(task.skills.filter((skill) => changed.some((file) => file.startsWith(`${skill}/`))).map(packageManifest))].sort();
  for (const name of versions) {
    const file = path.join(task.workspace, name);
    const value = await readJson(file);
    if (!/^\d+\.\d+\.\d+$/.test(value.version)) throw new Error(`Cannot increment plugin version: ${name}`);
    const parts = value.version.split(".");
    value.version = `${parts[0]}.${parts[1]}.${Number(parts[2]) + 1}`;
    await writeJson(file, value);
  }
  await capture(ctx, task, [...task.roots, ...versions], candidate);
  await command(ctx, task.workspace, "just", ["-f", "agent-marketplace/justfile", "-d", "agent-marketplace", "check"],
    { timeoutMs: 3_600_000, log: path.join(task.runDir, "validation.log"), env: { PYTHONDONTWRITEBYTECODE: "1" } });
  await capture(ctx, task, [...task.roots, ...versions], candidate);
  const verification = path.join(task.runDir, "patch-check");
  await clone(ctx, task, verification);
  if ((await fs.stat(candidate)).size) await git(ctx, verification, ["apply", "--check", candidate]);
  await fs.rm(verification, { recursive: true });
  const final = path.join(task.runDir, "final.patch");
  await fs.rename(candidate, final);
  const receipt = { status: "ready", patch: final, bytes: (await fs.stat(final)).size,
    sha256: hash(await fs.readFile(final)), sourceTree: task.sourceTree, skills: task.skills.length,
    versionBumps: versions, parentRunId: task.parentRunId, review: path.join(task.artifacts, "aggregate.report.json"),
    validation: path.join(task.runDir, "validation.log") };
  await writeJson(path.join(task.runDir, "receipt.json"), receipt);
  return receipt;
}
