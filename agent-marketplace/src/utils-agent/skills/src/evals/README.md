# src trigger evaluation

`trigger-evals.json` checks that the installed description loads this skill
for upstream-source requests and stays out of web search, clarifying
questions, Sourcegraph searches, and questions about local files. Cases come
from real requests. Run it from the checkout after materializing the plugin:

```bash
agent-marketplace/scripts/trigger-eval/run.sh \
  --skill-dir agent-marketplace/src/utils-agent/skills/src --runs 3
```

The runner scores the first tool call only and exits 1 when any case misses;
`run.sh --help` lists its options.

A design-scoping request such as "what would it take to support a git server
as a backend for https://github.com/rclone/rclone" is not a case. Its first
call reads the machine engineering conventions, as `~/.agents/AGENTS.md`
directs for technical investigation, and it loads this skill second, so the
first-tool runner scores a correct run as a miss (0/3 on 2026-10-20). The
replacement rclone case asks for the source directly.
