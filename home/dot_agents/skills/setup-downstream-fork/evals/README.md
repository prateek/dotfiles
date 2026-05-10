# setup-downstream-fork evals

Three test cases in `evals.json` covering the skill's core paths: fresh setup, doctor audit, conflict resolution.

## Running locally (no subagents)

### Test 1 — scaffold-fork-of-small-cli

Uses a local file-based upstream to avoid hitting GitHub. Requires `git` 2.39+.

```bash
# prepare a local upstream
rm -rf /tmp/fork-eval-upstream /tmp/fork-eval-out
mkdir /tmp/fork-eval-upstream && cd /tmp/fork-eval-upstream
git init -q -b main
echo 'print("hello")' > app.py
git add -A && git commit -q -m "initial"

# run the skill's setup script in dry-run against the local upstream
cd $DOTFILES/.agents/skills/setup-downstream-fork
python3 scripts/setup_fork.py \
  --upstream /tmp/fork-eval-upstream \
  --fork-name glow \
  --fork-owner prateek \
  --local-path /tmp/fork-eval-out \
  --llm-provider claude \
  --dry-run

# for a full local scaffold that actually writes files, run without --dry-run
# (will fail at gh repo create unless you have a real upstream + gh auth)
```

### Test 2 — doctor-audit-existing-fork

After Test 1 has produced a scaffolded fork, run doctor against it:

```bash
python3 scripts/doctor.py --path /tmp/fork-eval-out
python3 scripts/doctor.py --path /tmp/fork-eval-out --json | jq
```

Deliberately break something (e.g., delete `.fork/AGENTS.md`) and confirm doctor flags it.

### Test 3 — resolve-synthetic-conflict

Requires `ANTHROPIC_API_KEY` or `OPENAI_API_KEY` in env. Uses the resolver directly against a synthetic conflict file.

```bash
cat > /tmp/conflict.py <<'EOF'
def hello(quiet=False):
<<<<<<< HEAD
    if quiet: return
    print("hello from fork")
=======
    msg = "hello from upstream"
    print(msg.upper())
>>>>>>> upstream
EOF
LLM_PROVIDER=claude LLM_MODEL=claude-sonnet-4-6 \
  python3 templates/tools/llm_resolve.py.tmpl /tmp/conflict.py
```

## Running with subagents (full eval harness)

Follow the `skill-creator` workflow: spawn paired with-skill vs baseline subagents per eval, save outputs to an iteration workspace, grade with the assertions in `evals.json`, launch the eval viewer. See the skill-creator references at `~/.claude/skills/skill-creator/SKILL.md` for the command patterns.

## Known limitations

- Test 1's full path (including `gh repo create`, secrets, branch protection) requires real GitHub auth with the right scopes. Pre-flight in `setup_fork.py` will refuse to proceed without them. Use `--dry-run` to validate the orchestration logic without side effects.
- Test 3 is LLM-dependent and costs a few cents per run. Cache is on; repeat runs are free.
- Assertions are human-readable descriptions, not machine-checked predicates. A grading subagent interprets them against the outputs.
