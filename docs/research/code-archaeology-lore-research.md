---
status: active
doc_type: research
summary: "How public skills, tool builders, and project conventions recover the why behind code, and what a reproducible 'lore' agent skill should steal."
owner: Prateek
created: 2026-10-22
updated: 2026-10-22
related:
  - pstack-context-impact.md
  - ghost-of-commits-past-prior-art.md
---

# Code Archaeology for Agents: Prior Art for a `lore` Skill

Question: how do public repos, agent-skill authors, and tool builders recover the
intent behind code, and how do they make that repeatable for coding agents?
Evidence gathered 2026-10-22 from primary sources: the SKILL.md files themselves,
official docs, and specs. Star counts come from `gh api repos/<o>/<r>` on that date.

## 1. Anthropic, "Redesigning source control at Anthropic"

Source: <https://www.anthropic.com/research/redesigning-source-control>.

The post does not live up to the premise of this brief. It is about **Scion**, an
in-house VCS built because the monorepo went from ~2,500 to 30,000+ merged changes
a day (May to September 2026). It contains **no concrete examples of attaching
surrounding context (rationale, discussion, docs) to code changes**. The parts that
matter for archaeology:

- **History and blame as a server API.** "The server answers questions about file
  history and blame"; all client queries are "also exposed via API, so in many
  cases jobs don't need a local repository at all." Blame and path history are
  precomputed "derived data", built incrementally per changeset.
- **Ask the system of record, not the log.** Engineers often had to tell Claude
  "no". The example given: "multiple systems … tried to brute force looking up when
  a change merged to main by linearly reading the commit log instead of asking our
  code review tool." That is the main lesson for `lore`: go to the tool that owns
  the fact (the review system, the PR API) before you reconstruct it from git.
- **Review shifts to intent.** Reviewers "now examine the *intent* of the change as
  opposed to reading every line of code." Their review tool can tell comment-only
  changes apart from sensitive logic changes.
- **Its proposal for the ecosystem** is about scale, not context. Forges should
  offer "comprehensive server-side RPCs like Scion, perhaps even in a standardized
  way across forges"; negotiation, sparse checkout, and shallow fetch should
  compose better.

Inference (mine): if forges standardize history and blame RPCs, a `lore` skill
should expect history queries to work without a full clone and call them through
an API (`gh api`, MCP). A partial clone is already the norm on Prateek's work
machine.

## 2. Public agent skills that do archaeology

| Skill | Repo (stars) | What it actually instructs |
|---|---|---|
| [`git-archaeology`](https://github.com/pullfrog/pullfrog/blob/82247c3a490f7a17f8672a3af207279989dc873b/skills/git-archaeology/SKILL.md) | pullfrog/pullfrog (1,348) | The best git-only command reference. Opens with output discipline: start with `--oneline`/`--stat`, drill in with `git show <sha> -- <path>`, never run `git log -p` without a path. Organized as a decision tree by intent: `-S` (pickaxe: count changes; misses in-file moves), `-G` (regex over hunks), `-L :fn:file` / `-L N,M:file`, `--follow`, `blame --reverse <old>..HEAD` to find where a deleted line died, `--all --full-history --diff-filter=D` for deleted files, and `--grep` for messages. Git only: no PRs, no tickets. |
| [`commit-archaeologist`](https://github.com/Shubhamsaboo/awesome-llm-apps/blob/6c16b23f1bacd0fdf240bb5141ef45e59e82c306/agent_skills/commit-archaeologist/SKILL.md) | Shubhamsaboo/awesome-llm-apps (142,669; star count reflects the collection, not the skill) | Bundles a read-only `archaeologist.py` that returns JSON with `introduced_by`, `timeline`, `co_changed`, `authors`, and `intent_signals` (issue refs, reverts, "workaround"/"temporary" words). Report shape: bottom line plus high/medium/low confidence, origin, timeline, companion files, intent evidence, change risk. Its evidence rules are the reusable part: "Current blame ownership is not proof of original authorship"; "An empty signal list means the messages do not say why. It does not mean the change had no reason." Local only, no network. |
| [`why`](https://github.com/cursor/plugins/blob/main/pstack/skills/why/SKILL.md) (pstack) | cursor/plugins (13,557) | The most complete design. **Already vendored here** at `agent-marketplace/vendor/apm_modules/cursor/plugins/pstack/skills/why/`, and `default_loaded = false` in `home/.chezmoidata/agent_plugins.toml`. Steps: (1) build a code anchor inline (blame, `log --follow -p`, PR numbers from `(#1234)` subjects, `gh pr view --json title,body,…,closingIssuesReferences,comments,reviews`); (2) find the available MCPs and map each one to seven evidence categories (source control, tracker, long-form docs, chat, infra observability, error tracking, analytics warehouse); (3) run one parallel investigator per category, adding an incident-postmortem playbook when the code looks defensive; (4) hand the results to one synthesizer. Skipping a category needs a written reason ("no MCP" counts as a gap, not a choice). Five confidence tiers (Direct / Supported / Inferred / Speculative / Unknown) with phrasing rules in [`references/epistemics.md`](https://github.com/cursor/plugins/blob/main/pstack/skills/why/references/epistemics.md). Output ends with a Sources Consulted line per investigator, nulls included, then Preserve / Change / Avoid / Risk when a change is planned. The [Slack playbook](https://github.com/cursor/plugins/blob/main/pstack/skills/why/references/sources/slack.md): search by PR author around the merge date, then by PR URL or `/pull/<n>`, then by error string; always fetch the whole thread; watch for retention cliffs, invisible DMs, and jokes read as decisions. Cost: a full parallel fan-out by default, and it is Cursor-specific (model slugs, `mcps/` directory). |
| [`github-deep-review`](https://github.com/steipete/agent-scripts/blob/1159adf26ad007df38b87debb107d3946008d38b/skills/github-deep-review/SKILL.md) | steipete/agent-scripts (7,397) | Fetch GitHub refs with `gh … --json`, not a browser. The provenance rule is unusually strict: `git log -S/-G`, blame, and linked PRs only *locate candidates*. Before writing "introduced by", inspect the raw parents (`git --no-replace-objects cat-file -p <sha>`) and diff parent to commit on the implicated path, with a repro or test where you can. Prefer "current source and executable proof over issue comments". |
| [`commit-context`](https://github.com/rohitg00/agentmemory/blob/1c995081c45dd465877c4f6ecbf313490baa8820/plugin/skills/commit-context/SKILL.md) | rohitg00/agentmemory (29,791) | Blame or `log -L` gives a SHA, then `memory_commit_lookup` returns the linked agent session. Anti-pattern it names: narrating intent from the diff when the lookup returns `commit: null`; the answer is "predates session linking". |
| [`explain`](https://github.com/entireio/skills/blob/fe5266f76d846222c73b080ce39fd803dd705198/skills/explain/SKILL.md) | entireio/skills (226) | Blame finds the commit, then `entire checkpoint explain --commit <sha>` returns the session transcript. It stops with a fixed message on each failure (untracked file, uncommitted code, no transcript). |
| [`trace`](https://github.com/ptetau/pskills/blob/03297cb73a5946a9eaae9fda3b76aaf978a0d1a1/plugins/pdlc/skills/trace/SKILL.md) | ptetau/pskills (not checked) | Works in both directions over structured trailers: blame, then `git log -1 --format=%B` to read `Req:` / `Intent:` / `Ticket:` / `Change:`; the reverse direction uses `git log --all --grep "Change: CH-xxxx"`. "A missing link is a useful finding." |
| [`git-investigate`](https://github.com/sd0xdev/sd0x-harness/blob/a4d4bc1493a936a20721aeecf7391e347a4be88e/skills/git-investigate/SKILL.md) | sd0xdev/sd0x-harness (194) | A thin table: who (blame), when (`log --follow`), why (commit message plus PR). Root-cause focus. |
| [`chestertons-fence`](https://github.com/wadejensen/agent-dotfiles/blob/dc69ba60fa7835d8226eae51494561c558db33ee/skills/chestertons-fence/SKILL.md) | wadejensen/agent-dotfiles (0) | Posture only: five questions (why it exists, why this way, intentional vs incidental, invariants, blast radius) and no procedure. |
| [`memtrace-decision-memory`](https://github.com/syncable-dev/memtrace-public/blob/09ff24781d20b5d86bb6df36b33f54f10336b430/plugins/memtrace-skills/skills/memtrace-decision-memory/SKILL.md) | syncable-dev/memtrace-public (not checked) | A vendor MCP (`why_is_this_here`, `recall_decision`, `verify_intent`) over decisions mined from coding conversations. Its rule: "Do not guess rationale from a diff or git log." |

Search method: `gh search code --filename SKILL.md` for "archaeology", "git log -S",
"git log -L", "pickaxe", "Chesterton", and "why does this code exist". No hits came
back for SKILL.md files that combine blame with Slack, or blame with the commit→PR
API, beyond pstack `why`. I did not query skills.sh separately, so treat it as an
unsearched gap.

Patterns across the skills: git-only skills (pullfrog, sd0x) are cheap and
deterministic but stop at the commit message. Session-linking skills
(agentmemory, Entire) answer "why" only for agent-written code made after their
tool was installed. Only pstack `why` treats chat, docs, and trackers as
first-class sources. Every serious skill treats "no evidence found" as a
reportable result, not a failure.

## 3. Established tooling and practice

### Git primitives

- **`git log -L`**: "Trace the evolution of the line range … or by the function
  name regex … within the <file>"; implies `--patch`, accepts `-S`/`-G`, and
  starts from a single revision. [git docs](https://git-scm.com/docs/git-log#Documentation/git-log.txt--Lltstartgtltendgtltfilegt);
  source: `Documentation/line-range-options.adoc` in git/git.
- **`-S` / `-G`**: `-S` finds "differences that change the number of occurrences
  of the specified string". [git-log](https://git-scm.com/docs/git-log#Documentation/git-log.txt--Sltstringgt)
- **`git blame -C`, `--reverse`, `--ignore-revs-file`**: `-C` detects lines moved
  or copied from other files; `--reverse <start>..<end>` "shows the last revision
  in which a line has existed"; `--ignore-revs-file` takes an `fsck.skipList`-format
  file and stacks with `blame.ignoreRevsFile`. [git-blame](https://git-scm.com/docs/git-blame)
- **GitHub honors `.git-blame-ignore-revs`** at the repo root in its blame view,
  with a banner; a commit that last *modified* a line still shows. [GitHub Docs](https://docs.github.com/en/repositories/working-with-files/using-files/viewing-and-understanding-files#ignore-commits-in-the-blame-view)
- **Trailers**: key/value lines in a final block after a blank line, parsed by
  `git interpret-trailers`, extractable with `--format='%(trailers:key=Link)'`.
  [git-interpret-trailers](https://git-scm.com/docs/git-interpret-trailers),
  [pretty-formats](https://git-scm.com/docs/pretty-formats)
- **Notes**: annotate an object "without touching the objects themselves"; the
  default ref is `refs/notes/commits`, shown by `git log` under `Notes:`, and
  rewrites need `notes.rewrite.<command>` to carry them. [git-notes](https://git-scm.com/docs/git-notes).
  Not verified from primary docs here: that notes refs are left out of default
  push/fetch refspecs. It is widely stated, but I did not confirm it.

### Forge APIs

- **Commit to PR**: `GET /repos/{o}/{r}/commits/{sha}/pulls` "Lists the merged
  pull request that introduced the commit … If the commit is not present in the
  default branch, it will return merged and open pull requests." [GitHub REST](https://docs.github.com/en/rest/commits/commits#list-pull-requests-associated-with-a-commit).
  Checked live: `gh api repos/cli/cli/commits/99750e15…/pulls` returned #14768, and
  GraphQL `Commit.associatedPullRequests` agreed. This beats parsing `(#123)` out
  of subjects, which only works for squash merges.
- **github/github-mcp-server** exposes `get_commit`, `list_commits`,
  `pull_request_read` (methods `get_diff`, `get_commits`, `get_review_comments`
  with original line coordinates for outdated threads, `get_reviews`,
  `get_comments`), `search_pull_requests`, `issue_read`, `search_issues`,
  `list_discussions`, `get_discussion`, and `get_discussion_comments`. [README](https://github.com/github/github-mcp-server)
- **The reference git MCP server** (`modelcontextprotocol/servers/src/git`) has
  `git_log`/`git_show`/`git_diff` but **no blame or pickaxe tool**. [README](https://github.com/modelcontextprotocol/servers/tree/main/src/git).
  Shell git stays the better archaeology surface.

### Commit-message conventions

- **Linux kernel**: "Describe your problem … there must be an underlying problem
  that motivated you"; add `Link:` tags for related discussion, and preferably use
  `lore.kernel.org/<Message-ID>`. Also: "try to make your explanation
  understandable without external resources … summarize the relevant points of
  the discussion." [submitting-patches](https://docs.kernel.org/process/submitting-patches.html#describe-your-changes).
  The tip tree adds bracketed refs (`[1]`) mapped to `Link: … # [1]`, and
  `patch.msgid.link` for the patch origin, so tools can find the original
  submission. [maintainer-tip](https://docs.kernel.org/process/maintainer-tip.html)
- **Name collision**: [lore.kernel.org](https://lore.kernel.org/) is the kernel's
  public-inbox archive of mailing lists (LKML, netdev, git, qemu-devel, and more).
  "lore" already means "the mail archive behind a `Link:` trailer" to kernel and
  git developers. A skill named `lore` is fine locally, but expect search noise
  and a reader who assumes kernel tooling.
- **Google eng-practices**: a CL description is "a public record of change". It
  should say **why**, including "decisions you made that aren't reflected in the
  source code", because otherwise future developers can't tell "whether they can
  move [Chesterton's fence](https://abseil.io/resources/swe-book/html/ch03.html#understand_context)".
  Include bug numbers and design-doc links, but those links "may not be visible to
  future readers due to access restrictions or retention policies". [cl-descriptions](https://google.github.io/eng-practices/review/developer/cl-descriptions.html)
- **Chesterton's fence**: cited above through Google's SWE book. I did not fetch
  the original text (G.K. Chesterton, *The Thing*, 1929); treat that attribution
  as unverified here.

### Decision records

- **Nygard (2011)**: without recorded rationale a newcomer can only "blindly accept"
  or "blindly change" a decision. ADRs live in the repo and are numbered and never
  reused. Reversed ADRs stay, marked superseded. Sections: Context, Decision,
  Status, Consequences. [Cognitect blog](https://www.cognitect.com/blog/2011/11/15/documenting-architecture-decisions)
- **MADR** (adr/madr, 2,579 stars): `docs/decisions/`; optional front matter
  `status` (`superseded by ADR-0123`), `date`, `decision-makers`, `consulted`,
  `informed`; sections Context and Problem Statement, Decision Drivers, Considered
  Options, Decision Outcome, Consequences, Confirmation. [template](https://github.com/adr/madr/blob/main/template/adr-template.md)
- **adr-tools** (npryce/adr-tools, 5,737 stars): CLI, default dir `doc/adr`.
  [README](https://github.com/npryce/adr-tools)
- The `consulted`/`decision-makers` fields are useful pointers: they name the
  people whose Slack or DMs hold the rest of the story.

### Linking commits to trackers and chat

- **Linear**: issue ID in branch name or PR title; closing (`fixes`), non-closing
  (`refs`, `part of`), and relation (`related to`) magic words in PR or commit;
  commit linking needs a webhook and works with one GitHub org only. [Linear docs](https://linear.app/docs/github)
- **Jira**: the key (`JRA-123`, uppercase) in branch, commit, or PR title fills
  the issue's Development panel. [Atlassian](https://support.atlassian.com/jira-software-cloud/docs/reference-issues-in-your-development-work/)
- **Slack**: `search.messages` (user token, `search:read`, Tier 2) supports
  `in:` / `from:` modifiers and returns a permalink per match. It is now marked
  "legacy", with `assistant.search.context` (Real-time Search API) recommended.
  [Slack docs](https://docs.slack.dev/reference/methods/search.messages)
- **Session-to-commit linkers**, newer and agent-specific:
  [git-ai](https://github.com/git-ai-project/git-ai) (2,881 stars) stores AI
  authorship logs as git notes under `refs/notes/ai` and its
  [standard](https://github.com/git-ai-project/git-ai/blob/main/specs/git_ai_standard_v3.0.0.md)
  forbids the default notes ref. [Entire CLI](https://github.com/entireio/cli)
  (5,202 stars) stores session checkpoints as `refs/entire/checkpoints/<shard>/<id>`,
  outside branch history. Both turn "what was the agent asked" into a git lookup.

## 4. Patterns worth stealing

1. **Cheap to expensive, stop at Direct evidence.** One order fits every source
   above: code and comments and tests, then blame/`log -L`/pickaxe, then the full
   commit message and trailers, then commit→PR API (body, reviews, review
   comments), then linked issues and ADRs, then docs, chat, and trackers by
   anchored search. pstack runs everything in parallel by default. A succinct
   skill should stop at the first **Direct** citation unless the question needs
   corroboration or the change is risky. That is my proposal, not established
   practice.
2. **Anchor before searching outward.** Every remote query should key off facts
   from git: SHA, PR number, author, merge date, ticket IDs, error strings, PR URL.
   pstack's Slack search (author ± merge date, PR URL, error string) is the
   template for any chat or doc surface.
3. **Ask the owning system.** Use the commit→PR API rather than subject parsing,
   and the tracker for ticket state (Anthropic's merge-time example; GitHub API).
4. **Separate locating from proving.** steipete's raw-parent diff rule plus
   commit-archaeologist's blame ≠ author rule.
5. **Tiered confidence with matching phrasing.** pstack's Direct / Supported /
   Inferred / Speculative / Unknown, where confidence words require an adjacent
   citation.
6. **Name the nulls.** Each source consulted gets one line: queried, found or
   empty, or skipped with a reason. An unavailable surface is a gap, not a skip
   (pstack, pdlc `trace`).
7. **Provenance = permalink + quoted line.** SHA (enough characters), PR/issue
   URL, Slack permalink, doc URL with heading. The kernel and Google rules apply
   in reverse: links rot or sit behind ACLs, so quote the sentence that carries
   the why.
8. **Discover surfaces at runtime; don't hardcode them.** pstack maps whatever
   MCPs and CLIs exist onto categories. For Prateek's public repo this matches
   ADR 0039: the skill names categories (chat, docs, tracker) and a generic
   playbook, and the work overlay supplies employer-specific channel maps,
   workspace URLs, and auth.
9. **Bound the output.** `--oneline` first, scope by path or date, never
   unscoped `log -p` (pullfrog).
10. **Feed the result back.** When archaeology recovers a why that only lived in
    Slack, the cheap durable fix is a code comment, ADR, or commit trailer
    (Google's "public record", the kernel's "summarize the discussion"). That
    belongs in the handoff, not as a silent edit.

## Implications for a lore skill

Outcome, 2026-10-22: these findings shaped the `core` plugin's
[`lore` skill](../../agent-marketplace/src/core/skills/lore/SKILL.md), a
harness-neutral rewrite that keeps pstack's epistemics and full fan-out by
default, with `--depth quick` for the early-stop ladder.

- **Start from pstack `why`; don't write from scratch.** It is already vendored
  and default-off. A `lore` skill could be a lean, harness-neutral rewrite of its
  method: sequential with early stop instead of seven forced subagents, no Cursor
  model slugs, the epistemics tiers kept nearly verbatim. Reusing vs. forking is a
  packaging decision for `agent-skill-management`.
- **Core ladder (generic, public repo):** code/tests/comments → `blame -w -C
  --ignore-revs-file` / `log -L` / `-S`/`-G` → `git log -1 --format=%B` + trailers →
  `gh api …/commits/<sha>/pulls` → `gh pr view --json body,reviews,comments` and
  review threads → linked issues and `docs/adr` → org surfaces via anchored
  search → (optional) agent-session archives (git-ai notes, Entire refs,
  Prateek's `agent-session-wiki`).
- **Org surfaces through an overlay contract:** the skill defines categories and
  query recipes (author ± merge window, PR URL, ticket ID, error string, fetch
  whole thread, note retention cliff); the work overlay maps categories to tools
  (Slack CLI, Google Workspace, Linear/Jira/Confluence MCPs). No employer names in
  the public skill.
- **Output contract:** bottom line with tier; evidence list with permalinks and
  short quotes; sources-consulted ledger including nulls; Preserve / Change /
  Avoid / Risk when an edit follows.
- **Stop conditions:** a Direct citation from an author-written source that
  answers the question; or every reachable category queried with anchored terms
  and logged; or the user's time/budget bound.
- **Naming:** "lore" collides with lore.kernel.org. Keep it if the local meaning
  is clear, and say in the description that it is not the kernel archive tool.
- **Open gaps:** skills.sh not searched directly; star counts not checked for
  ptetau/pskills and memtrace-public; the default-refspec behavior of git notes
  and the Chesterton original are unverified here.
