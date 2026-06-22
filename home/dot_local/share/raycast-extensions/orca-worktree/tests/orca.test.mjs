import test from "node:test";
import assert from "node:assert/strict";

import {
  ORCA_DEFAULT_AGENT,
  buildOhcArgs,
  parseAgentIds,
  parseGitHubRepo,
  parseOrcaJson,
  resultMarkdown,
  summarizeResult,
} from "../src/orca.mjs";

test("parseGitHubRepo accepts owner/repo", () => {
  assert.deepEqual(parseGitHubRepo("stablyai/orca"), { ok: true, slug: "stablyai/orca" });
});

test("parseGitHubRepo accepts GitHub URLs and ignores deeper paths", () => {
  assert.deepEqual(parseGitHubRepo("https://github.com/stablyai/orca/pull/123?tab=files"), {
    ok: true,
    slug: "stablyai/orca",
  });
});

test("parseGitHubRepo rejects non-GitHub hosts", () => {
  assert.equal(parseGitHubRepo("https://gitlab.com/stablyai/orca").ok, false);
});

test("parseAgentIds reads ids from Orca help text", () => {
  const help = "  --provider <agent>     Agent id such as codex, claude, or gemini";
  assert.deepEqual(parseAgentIds(help), ["claude", "codex", "gemini"]);
});

test("buildOhcArgs omits Orca default agent and includes user options", () => {
  assert.deepEqual(
    buildOhcArgs(
      {
        worktreeName: "remote-servers",
        agent: ORCA_DEFAULT_AGENT,
        prompt: "how do remote servers work?",
        setup: "skip",
        baseBranch: "origin/main",
        issue: "",
        linearIssue: "",
        comment: "remote server question",
        parentWorktree: "",
        noParent: true,
        runHooks: false,
        focusOrca: true,
      },
      "stablyai/orca",
    ),
    [
      "stablyai/orca",
      "--name",
      "remote-servers",
      "--prompt",
      "how do remote servers work?",
      "--setup",
      "skip",
      "--base-branch",
      "origin/main",
      "--comment",
      "remote server question",
      "--no-parent",
      "--activate",
    ],
  );
});

test("parseOrcaJson and summarizeResult keep useful success details", () => {
  const response = parseOrcaJson(`noise
{
  "ok": true,
  "result": {
    "worktree": {
      "id": "repo-id::/tmp/worktree",
      "repoId": "repo-id",
      "projectId": "github:stablyai/orca",
      "path": "/tmp/worktree",
      "branch": "refs/heads/remote-servers",
      "displayName": "remote-servers",
      "createdWithAgent": "codex",
      "baseRef": "refs/remotes/origin/main",
      "workspaceStatus": "in-progress"
    },
    "startupTerminal": {
      "spawned": true,
      "handle": "term_123"
    },
    "warnings": []
  }
}`);

  const summary = summarizeResult(response);
  assert.equal(summary.name, "remote-servers");
  assert.equal(summary.path, "/tmp/worktree");
  assert.equal(summary.branch, "remote-servers");
  assert.equal(summary.agent, "codex");
  assert.equal(summary.terminalHandle, "term_123");
  assert.match(resultMarkdown(summary), /Created remote-servers/);
});
