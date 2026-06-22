import { execFile } from "node:child_process";
import { access } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);

export const ORCA_DEFAULT_AGENT = "__orca_default__";

const DEFAULT_PATH = [
  "/opt/homebrew/bin",
  "/usr/local/bin",
  "/usr/bin",
  "/bin",
  "/usr/sbin",
  "/sbin",
  join(homedir(), ".local", "bin"),
  join(homedir(), ".local", "share", "mise", "shims"),
].join(":");

export function commandEnv(extra = {}) {
  return {
    ...process.env,
    PATH: `${DEFAULT_PATH}:${process.env.PATH ?? ""}`,
    ...extra,
  };
}

export async function execCli(command, args, options = {}) {
  try {
    const result = await execFileAsync(command, args, {
      env: commandEnv(options.env),
      maxBuffer: options.maxBuffer ?? 1024 * 1024 * 8,
      timeout: options.timeout ?? 1000 * 60 * 10,
    });
    return result.stdout;
  } catch (error) {
    const stderr = typeof error.stderr === "string" ? error.stderr.trim() : "";
    const stdout = typeof error.stdout === "string" ? error.stdout.trim() : "";
    const detail = stderr || stdout || error.message || String(error);
    throw new Error(detail);
  }
}

export async function resolveOhcHelperPath() {
  const candidates = [
    process.env.OHC_HELPER_PATH,
    join(homedir(), ".config", "zsh", "autoload", "ohc"),
    join(homedir(), "dotfiles", "home", "dot_config", "zsh", "autoload", "ohc"),
  ].filter(Boolean);

  for (const candidate of candidates) {
    try {
      await access(candidate);
      return candidate;
    } catch {
      // Try the next known helper location.
    }
  }

  throw new Error("Could not find ohc. Run chezmoi apply, or set OHC_HELPER_PATH for development.");
}

export function parseGitHubRepo(input) {
  const raw = String(input ?? "").trim();
  if (!raw) {
    return { ok: false, error: "Enter a GitHub repo such as stablyai/orca." };
  }

  let candidate = raw.replace(/[?#].*$/, "").replace(/\.git$/, "");

  if (candidate.includes("://")) {
    let parsed;
    try {
      parsed = new URL(candidate);
    } catch {
      return { ok: false, error: "Enter a valid GitHub URL or owner/repo slug." };
    }
    if (parsed.hostname !== "github.com") {
      return { ok: false, error: "Only github.com repositories are supported." };
    }
    candidate = parsed.pathname.replace(/^\/+/, "");
  } else if (candidate.startsWith("git@github.com:")) {
    candidate = candidate.slice("git@github.com:".length);
  } else if (candidate.startsWith("github.com/")) {
    candidate = candidate.slice("github.com/".length);
  }

  const [owner, repo, ...rest] = candidate.split("/").filter(Boolean);
  if (!owner || !repo) {
    return { ok: false, error: "Use owner/repo, or paste a GitHub repo URL." };
  }
  if (rest.length > 0) {
    candidate = `${owner}/${repo}`;
  }

  if (!/^[A-Za-z0-9](?:[A-Za-z0-9-]{0,38}[A-Za-z0-9])?$/.test(owner)) {
    return { ok: false, error: "GitHub owner names can contain letters, numbers, and hyphens." };
  }
  if (!/^[A-Za-z0-9._-]+$/.test(repo) || repo === "." || repo === "..") {
    return { ok: false, error: "GitHub repo names can contain letters, numbers, dots, underscores, and hyphens." };
  }

  return { ok: true, slug: `${owner}/${repo}` };
}

export function parseAgentIds(helpText) {
  const found = new Set();
  const text = String(helpText ?? "");

  for (const match of text.matchAll(/Agent id such as ([^.:\n]+)/gi)) {
    for (const piece of match[1].split(/,|\bor\b/gi)) {
      const id = piece.trim();
      if (/^[a-z][a-z0-9_-]*$/.test(id)) {
        found.add(id);
      }
    }
  }

  for (const match of text.matchAll(/--(?:agent|provider)\s+([a-z][a-z0-9_-]*)\b/gi)) {
    found.add(match[1]);
  }

  return Array.from(found).sort();
}

export async function loadAgentIds() {
  const help = await execCli("orca", ["automations", "create", "--help"], { timeout: 15000 });
  return parseAgentIds(help);
}

export function buildOhcArgs(values, slug) {
  const args = [slug];
  const worktreeName = values.worktreeName?.trim();
  const prompt = values.prompt?.trim();
  const baseBranch = values.baseBranch?.trim();
  const issue = values.issue?.trim();
  const linearIssue = values.linearIssue?.trim();
  const comment = values.comment?.trim();
  const parentWorktree = values.parentWorktree?.trim();

  if (worktreeName) args.push("--name", worktreeName);
  if (values.agent && values.agent !== ORCA_DEFAULT_AGENT) args.push("--agent", values.agent);
  if (prompt) args.push("--prompt", prompt);
  if (values.setup && values.setup !== "inherit") args.push("--setup", values.setup);
  if (baseBranch) args.push("--base-branch", baseBranch);
  if (issue) args.push("--issue", issue);
  if (linearIssue) args.push("--linear-issue", linearIssue);
  if (comment) args.push("--comment", comment);
  if (values.noParent) {
    args.push("--no-parent");
  } else if (parentWorktree) {
    args.push("--parent-worktree", parentWorktree);
  }
  if (values.runHooks) args.push("--run-hooks");
  if (values.focusOrca) args.push("--activate");

  return args;
}

export function parseOrcaJson(output) {
  const trimmed = String(output ?? "").trim();
  if (!trimmed) {
    throw new Error("ohc completed without JSON output.");
  }
  const start = trimmed.indexOf("{");
  const end = trimmed.lastIndexOf("}");
  if (start < 0 || end < start) {
    throw new Error(`ohc did not return JSON: ${trimmed}`);
  }

  let parsed;
  try {
    parsed = JSON.parse(trimmed.slice(start, end + 1));
  } catch (error) {
    throw new Error(`Could not parse Orca JSON: ${error instanceof Error ? error.message : String(error)}`);
  }

  if (!parsed.ok) {
    const message = parsed.error?.message || parsed.error?.code || "Orca command failed.";
    throw new Error(message);
  }

  return parsed;
}

export function summarizeResult(response) {
  const worktree = response?.result?.worktree ?? {};
  const terminal = response?.result?.startupTerminal ?? {};
  const setup = response?.result?.setup ?? {};
  const warnings = response?.result?.warnings ?? [];
  const branch = typeof worktree.branch === "string" ? worktree.branch.replace(/^refs\/heads\//, "") : "";

  return {
    id: worktree.id ?? "",
    name: worktree.displayName || branch || "Worktree",
    path: worktree.path ?? "",
    branch,
    repoId: worktree.repoId ?? "",
    projectId: worktree.projectId ?? "",
    agent: worktree.createdWithAgent ?? "",
    status: worktree.workspaceStatus ?? "",
    baseRef: worktree.baseRef ?? "",
    terminalHandle: terminal.handle ?? "",
    terminalSpawned: Boolean(terminal.spawned),
    setupRunner: setup.runnerScriptPath ?? "",
    warnings,
  };
}

export function resultMarkdown(summary) {
  const rows = [
    ["Worktree", summary.name],
    ["Path", summary.path],
    ["Branch", summary.branch],
    ["Agent", summary.agent || "Orca default"],
    ["Status", summary.status],
    ["Base", summary.baseRef],
    ["Project", summary.projectId],
    ["Terminal", summary.terminalHandle],
  ].filter(([, value]) => Boolean(value));

  const warningText =
    summary.warnings.length > 0
      ? `\n\n## Warnings\n${summary.warnings.map((warning) => `- ${warning}`).join("\n")}`
      : "";

  return `# Created ${summary.name}\n\n${rows.map(([label, value]) => `**${label}:** ${value}`).join("\n\n")}${warningText}`;
}

export async function focusOrca(summary) {
  if (summary.terminalHandle) {
    await execCli("orca", ["terminal", "switch", "--terminal", summary.terminalHandle, "--json"], { timeout: 30000 });
  }
  await execCli("open", ["-a", "Orca"], { timeout: 30000 });
}
