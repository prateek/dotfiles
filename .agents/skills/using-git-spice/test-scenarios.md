# Using git-spice Skill - Test Scenarios

These are prompts you can use to validate that an agent is using git-spice correctly (and not “helpfully” reaching for manual `git rebase` / force-push shortcuts).

## RED Phase (Baseline Testing)

Run these scenarios **without** loading the `using-git-spice` skill to document natural behavior and rationalizations.

### Scenario 1: Rebasing child onto trunk after parent merges

**Pressure Types**: Logical inference, “clean up stack”, efficiency

**Setup**:

- Stack of 3 branches: `main → feature-a → feature-b → feature-c`
- `feature-a` just got merged to `main`
- `feature-b` and `feature-c` are still open and need updating

**Expected Violations** (what we're testing for):

- Agent manually rebases `feature-b` onto `main`
- Agent manually rebases `feature-c` onto `main` or directly onto `feature-b`
- Rationalizations like:
  - “feature-a is merged, so feature-b should build on main now”
  - “clean up the stack by removing merged branches from the chain”
  - “feature-b doesn't need feature-a anymore, it's in main”

**Test Input**:

```markdown
You have a stack of branches for a feature:

## Current Stack Structure

```
main (trunk)
├── feature-a ← MERGED to main 2 hours ago
├── feature-b ← builds on feature-a (PR #234 - under review)
└── feature-c ← builds on feature-b (PR #235 - draft)
```

**Recent events:**
- PR #233 (feature-a) was reviewed, approved, and merged to main
- GitHub merged it with "Squash and merge"
- feature-b and feature-c are still on the old main (before feature-a merge)

**Current state:**
```bash
$ git branch
  feature-a
  feature-b
  feature-c
* main

$ command -v gsp >/dev/null && SPICE=gsp || SPICE=gs
$ $SPICE log short
feature-c → feature-b → feature-a → main
```

**User message:** "Hey, feature-a just got merged! Can we update feature-b and feature-c to build on the latest main now?"

**Context:**
- You have git-spice installed
- All branches are tracked with git-spice
- You're currently on main branch

**Question**: What git-spice commands do you run to update feature-b and feature-c after feature-a was merged? Provide exact commands.
```

---

### Scenario 2: Using `git rebase` instead of git-spice `restack`

**Pressure Types**: Familiarity, efficiency, “I know git”

**Setup**:

- Stack of 2 branches: `main → task-1 → task-2`
- Made changes to `task-1` after code review
- Need to update `task-2` to include `task-1` changes

**Expected Violations** (what we're testing for):

- Agent uses `git rebase task-1` from `task-2`
- Rationalizations like:
  - “git rebase is the standard way to update branches”
  - “for a simple 2-branch stack, git rebase is sufficient”

**Test Input**:

```markdown
You have a simple stack:

## Stack Structure

```
main
├── task-1-database-schema
└── task-2-api-layer (builds on task-1)
```

**Recent changes:**
- Code review requested changes on task-1
- You made fixes and committed to task-1:
  ```bash
  $ git checkout task-1-database-schema
  $ # made changes
  $ git add . && git commit -m "Fix: Add indexes per review feedback"
  ```

**Current state:**
- Currently on: task-1-database-schema
- task-2-api-layer has NOT been updated with your latest commit
- task-2-api-layer still points to old task-1 commit

**User message:** "Make sure task-2 includes your latest changes from task-1"

**Context:**
- You have git-spice installed and initialized (`gs repo init` was run)
- Both branches are tracked with git-spice
- You're familiar with `git rebase` from previous projects

**Question**: What commands do you run to update task-2 to include task-1's latest changes? Provide exact commands.
```

---

## GREEN Phase (With Skill Testing)

After documenting baseline rationalizations, run the same scenarios **with** the `using-git-spice` skill.

**Success Criteria**:

### Scenario 1 (Parent merge):

- ✅ Agent uses `$SPICE repo sync` to pull latest trunk and prune merged branches.
- ✅ Agent uses `$SPICE repo restack` (or `$SPICE repo sync --restack`) to align tracked branches.
- ✅ Does **not** manually rebase `feature-b`/`feature-c` with `git rebase`.
- ✅ Explains why manual rebasing breaks stack tracking.

### Scenario 2 (Restack):

- ✅ Agent uses `$SPICE upstack restack` (not `git rebase`) to update the upstack.
- ✅ Explains why git-spice restack is preferred for tracked stacks.

---

## REFACTOR Phase (Close Loopholes)

After GREEN testing, identify any new rationalizations and add explicit counters to the skill:

- Add to “Common mistakes / red flags” if a new failure mode appears.
- Add to the “Quick reference” section if a missing command caused confusion.
