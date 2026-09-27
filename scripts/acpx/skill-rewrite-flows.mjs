import * as work from "./skill-rewrite.mjs";

const MINUTE = 60_000;
const permissions = {
  requiredMode: "approve-all",
  requireExplicitGrant: true,
  reason: "Author patches in disposable checkouts and write review reports.",
};

function edges(ids) {
  return ids.slice(1).map((to, index) => ({ from: ids[index], to }));
}

export function createSkillFlow({ acp, action, defineFlow }) {
  const agent = (phase, profile) => acp({
    profile,
    session: { isolated: true },
    cwd: ({ input }) => input.workspace,
    prompt: ({ input }) => work.prompt(input, phase),
    parse: (_text, { input }) => work.report(input, phase),
  });
  return defineFlow({
    name: "rewrite-one-authored-skill",
    run: { title: ({ input }) => input.skill },
    permissions,
    startAt: "setup",
    nodes: {
      setup: action({ timeoutMs: 10 * MINUTE, run: (ctx) => work.setupSkill(ctx, ctx.input) }),
      rewrite: agent("rewrite", "skill-writer"),
      saveDraft: action({ timeoutMs: 5 * MINUTE, run: (ctx) => work.saveDraft(ctx, ctx.input) }),
      review: agent("review", "skill-opus"),
      checkReview: action({ timeoutMs: 5 * MINUTE, run: (ctx) => work.checkReview(ctx, ctx.input) }),
      fix: agent("fix", "skill-writer"),
      saveFinal: action({ timeoutMs: 5 * MINUTE, run: (ctx) => work.saveFinal(ctx, ctx.input) }),
    },
    edges: edges(["setup", "rewrite", "saveDraft", "review", "checkReview", "fix", "saveFinal"]),
  });
}

export function createSweepFlow({ acp, action, defineFlow }) {
  return defineFlow({
    name: "rewrite-authored-skills",
    permissions,
    startAt: "prepare",
    nodes: {
      prepare: action({ timeoutMs: 10 * MINUTE, run: (ctx) => work.prepare(ctx, ctx.input ?? {}) }),
      rewriteSkills: action({
        timeoutMs: 7 * 24 * 60 * MINUTE,
        run: (ctx) => work.rewriteSkills(ctx, ctx.outputs.prepare),
      }),
      assemble: action({ timeoutMs: 30 * MINUTE, run: (ctx) => work.assemble(ctx, ctx.outputs.prepare) }),
      aggregateReview: acp({
        profile: "afablex",
        timeoutMs: 30 * MINUTE,
        session: { isolated: true },
        cwd: ({ outputs }) => outputs.assemble.workspace,
        prompt: ({ outputs }) => work.prompt(outputs.assemble, "aggregate"),
        parse: (_text, { outputs }) => work.report(outputs.assemble, "aggregate"),
      }),
      export: action({ timeoutMs: 2 * 60 * MINUTE, run: (ctx) => work.exportPatch(ctx, ctx.outputs.assemble) }),
    },
    edges: edges(["prepare", "rewriteSkills", "assemble", "aggregateReview", "export"]),
  });
}
