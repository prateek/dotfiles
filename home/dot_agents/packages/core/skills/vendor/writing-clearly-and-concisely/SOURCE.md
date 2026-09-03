# Source

- Upstream: https://github.com/aiskillstore/marketplace/tree/f7130a5b2c8c16873aa67d8d2a1f957bdf079b8b/skills/cygnusfear/writing-clearly-and-concisely
- APM dependency: `aiskillstore/marketplace/skills/cygnusfear/writing-clearly-and-concisely`
- Ref: `f7130a5b2c8c16873aa67d8d2a1f957bdf079b8b`
- License: not declared in the upstream repository metadata.
- Notes: Moved from local source to vendored package source after public source matching. Local delta: the skill is made user-invoked only, so it costs no listing budget in the always-on `core` root while `writing-for-humans` routes to it and the human can still invoke it by name — `disable-model-invocation: true` in the frontmatter covers Claude Code, pi, and cursor-agent, and an added `agents/openai.yaml` sets `policy.allow_implicit_invocation: false` for Codex, which ignores the frontmatter key.
