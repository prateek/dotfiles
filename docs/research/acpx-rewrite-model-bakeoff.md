---
status: current
doc_type: research
owner: Prateek
created: 2026-09-03
updated: 2026-09-03
related:
  - ../../home/dot_agents/docs/acpx.md
  - ../../home/dot_acpx/config.json.tmpl
  - ../../home/dot_agents/packages/core/skills/local/writing-for-humans/SKILL.md
status_detail: "Backs the agptw pin (gpt-5.6-luna-high). Re-run the method here when the cursor-agent catalog moves a pinned family or the drift audit flags agptw."
---

# Which Model Should Do acpx Prose Rewrites

## Question

Delegated prose rewrites — hand a draft plus the `writing-for-humans` rules to
another agent and take back the edited text — ran on `agpt`
(`gpt-5.6-sol-high-fast`), the most expensive shortcut in the table. Sol's
strengths are long-horizon agentic coding. A rewrite is a single-turn,
no-tool-use edit against an explicit rule list, so the question is whether a
cheaper tier does it as well.

Two ways to get cheaper, and they are not the same lever:

- Turn Sol's reasoning down (`gpt-5.6-sol-low`).
- Drop to a smaller model in the family (`gpt-5.6-terra-*`, `gpt-5.6-luna-*`).

Cursor prices Sol above Terra above Luna, all from the third-party Other Models
pool, and every `-fast` id bills at 2x the standard rate. A background rewrite
does not need priority scheduling, so the candidates drop `-fast`.

## Candidates

| Agent name     | Model                    | Why in the set                      |
| -------------- | ------------------------ | ----------------------------------- |
| `c-sol-high`   | `gpt-5.6-sol-high-fast`  | Incumbent; the control              |
| `c-sol-low`    | `gpt-5.6-sol-low`        | Same model, reasoning turned down   |
| `c-terra-med`  | `gpt-5.6-terra-medium`   | Mid tier                            |
| `c-terra-high` | `gpt-5.6-terra-high`     | Mid tier, more reasoning            |
| `c-luna-med`   | `gpt-5.6-luna-medium`    | Cheapest tier                       |
| `c-luna-high`  | `gpt-5.6-luna-high`      | Cheapest tier, more reasoning       |

## Method

### Fixtures

Four drafts pulled from the local agentsview store, one per genre that this
workflow actually rewrites:

| Fixture             | Genre                    | Size  | Stresses                                |
| ------------------- | ------------------------ | ----- | --------------------------------------- |
| `01-status-reply`   | Terminal status recap    | 317w  | Bold-label bullets, em-dash density     |
| `02-pr-description` | PR title and body draft  | 775w  | Fenced blocks, filenames, commit SHAs   |
| `03-slack-draft`    | Paste-ready Slack message| 308w  | A block quote that must survive intact  |
| `04-plan-doc`       | Plan doc section         | 977w  | YAML front matter, 73 code spans, links |

The drafts are real work and personal output, so they stay out of this public
repo. Select equivalents with:

```sh
cp ~/.agentsview/sessions.db /tmp/av.db   # the daemon locks the live file
sqlite3 /tmp/av.db "
  SELECT m.id, s.project, length(m.content)
  FROM messages_fts f JOIN messages m ON m.id = f.rowid
  JOIN sessions s ON s.id = m.session_id
  WHERE messages_fts MATCH '\"not just\" OR \"isn''t just\" OR \"crucial\" OR \"seamless\"'
    AND m.role = 'assistant' AND length(m.content) BETWEEN 600 AND 2500
  ORDER BY m.id DESC LIMIT 30;"
```

Assistant messages carrying those tells were written without the writing
skills, which makes them honest rewrite inputs. For a document-shaped fixture,
query `tool_calls` for a `Write` to `docs/plans/*.md` and take
`json_extract(input_json, '$.content')`.

### Prompt

One preamble, identical for every candidate, then `DRAFT:` and the fixture.
The rules are inlined rather than reached by a file read, so the run measures
prose editing and not tool use. Write it to `preamble.md`:

```markdown
You are a prose editor. Rewrite the draft below so a human reads it as
human-written, without changing what it says.

Rules, in order:

1. Lead with the answer. Delete openers, closers, throat-clearing, and
   sentences that announce what the next sentence will do.
2. Kill negative parallelism: "not X, it's Y", "not just X but Y".
3. Be specific instead of significant. Swap inflating words (pivotal,
   crucial, robust, seamless, testament, landscape) for a fact or nothing.
4. Plain verbs: "is", "has", "does", or the active verb hiding in the noun.
5. End sentences at the fact. Cut "-ing" tack-ons that editorialize.
6. Earn adjectives and em-dashes. At most two em-dashes per page. No
   bold-label bullets, no decorative Unicode, no emoji unless the medium
   expects them.
7. Vary rhythm. One tricolon per short piece at most; break anaphora and
   elegant variation.

Guardrails:

- Only subtract and simplify. Never add facts, quotes, names, numbers,
  next steps, or opinions the source does not hold.
- Keep the author's rhythm, contractions, first person, swearing, and
  rough edges. Lowercase stays lowercase.
- Preserve code identifiers, API names, file paths, flags, commands, link
  targets, YAML front matter, and exact UI labels byte-for-byte.
- Leave code blocks, tables, and quoted text alone.
- If two rewrites are equally good, pick the shorter one.

Output the rewritten text and nothing else. No preamble, no commentary,
no summary of what you changed.

---

DRAFT:

```

The rules and guardrails track `writing-for-humans`; re-copy them from that
skill if it has moved on, or the bake-off measures a stale contract.

### Harness

Candidate shortcuts live in a scratch `.acpxrc.json`, which merges over
`~/.acpx/config.json`, so the bake-off never touches the chezmoi-managed
config:

```sh
mkdir -p /tmp/rewrite-bakeoff/{fixtures,prompts,full,out}
cat > /tmp/rewrite-bakeoff/.acpxrc.json <<'JSON'
{
  "agents": {
    "c-sol-high":   { "argv": ["cursor-agent", "--model", "gpt-5.6-sol-high-fast", "acp"] },
    "c-sol-low":    { "argv": ["cursor-agent", "--model", "gpt-5.6-sol-low", "acp"] },
    "c-terra-med":  { "argv": ["cursor-agent", "--model", "gpt-5.6-terra-medium", "acp"] },
    "c-terra-high": { "argv": ["cursor-agent", "--model", "gpt-5.6-terra-high", "acp"] },
    "c-luna-med":   { "argv": ["cursor-agent", "--model", "gpt-5.6-luna-medium", "acp"] },
    "c-luna-high":  { "argv": ["cursor-agent", "--model", "gpt-5.6-luna-high", "acp"] }
  }
}
JSON
cd /tmp/rewrite-bakeoff
for f in fixtures/*.md; do cat preamble.md "$f" > "prompts/$(basename "$f")"; done
```

`compare` gives the timing table:

```sh
acpx --format json --json-strict --no-terminal --non-interactive-permissions deny \
  --timeout 300 --prompt-retries 1 \
  compare c-sol-high c-sol-low c-terra-med c-terra-high c-luna-med c-luna-high \
  -f prompts/04-plan-doc.md > out/04-plan-doc.json
```

It does not give the prose: `CompareRow.final_message` is capped at 200
characters with newlines collapsed. Full text needs one `exec` per pair, where
`--format quiet` prints the final assistant message and nothing else:

```sh
for p in prompts/*.md; do b=$(basename "$p" .md)
  for a in c-sol-high c-sol-low c-terra-med c-terra-high c-luna-med c-luna-high; do
    acpx --format quiet --no-terminal --non-interactive-permissions deny \
      --timeout 300 --prompt-retries 1 "$a" exec -f "$p" > "full/$b.$a.md"
  done
done
```

### Scoring

Two axes, both mechanical, because a rewrite fails in two independent ways.

**Damage** counts what the edit did to facts, as three numbers per fixture:
code spans in the source that vanished, code spans in the output that were not
in the source, and Markdown link targets dropped. Every one of these is a
guardrail violation — the rules say preserve identifiers, paths, flags, and
link targets, and never add.

**Rules left** counts violations the edit should have removed and did not:
negative parallelism (`not just`, `isn't just`, `not X, but Y`) and
bold-label bullets. Em-dash counts, fenced-block counts, and retained-word
percentage are reported but not scored; the fence count never moved, and the
other two are judgement calls the source genre can justify.

Two axes rather than one composite, because the failure modes trade against
each other: an aggressive model scores well on rules left and badly on damage.

What the axes do not reach: damage sees inline code spans, Markdown link
targets, and fence counts, so a model can reword a prose fact, mangle YAML
front matter, or restructure a block quote and still score zero. Rules left
covers two of the seven anti-slop rules, the two that are greppable. The
remaining five, and whether the prose reads better at all, went unmeasured
except by reading the outputs. Treat both numbers as a floor on damage and a
floor on laziness, not as a quality score.

## Results

Damage is `lostCode/invented/lostLink`. Rules left is `negative-parallelism +
bold-bullets`. Source counts head each block.

```
01-status-reply    317w, 20 code spans, 0 links, 1 neg, 2 bullets, 7 em-dash
  c-sol-high     keep  93.1%   dmg 0/0/0   left 0+0   em 3
  c-sol-low      keep  89.3%   dmg 0/0/0   left 0+0   em 3
  c-terra-high   keep  82.3%   dmg 0/0/0   left 0+0   em 1
  c-terra-med    keep  83.9%   dmg 0/0/0   left 0+0   em 1
  c-luna-high    keep  89.9%   dmg 1/0/0   left 1+0   em 4
  c-luna-med     keep  94.6%   dmg 0/0/0   left 1+0   em 0

02-pr-description  775w, 31 code spans, 0 links, 0 neg, 0 bullets, 8 em-dash
  c-sol-high     keep  87.6%   dmg 0/0/0   left 0+0   em 0
  c-sol-low      keep  86.2%   dmg 1/0/0   left 0+0   em 0
  c-terra-high   keep  74.2%   dmg 2/0/0   left 0+0   em 0
  c-terra-med    keep  96.9%   dmg 0/0/0   left 0+0   em 7
  c-luna-high    keep  90.8%   dmg 0/0/0   left 0+0   em 3
  c-luna-med     keep  91.2%   dmg 0/0/0   left 0+0   em 3

03-slack-draft     308w, 8 code spans, 0 links, 0 neg, 0 bullets, 2 em-dash
  c-sol-high     keep  81.2%   dmg 2/0/0   left 0+0   em 2
  c-sol-low      keep  76.0%   dmg 0/0/0   left 0+0   em 2
  c-terra-high   keep  81.5%   dmg 2/0/0   left 0+0   em 2
  c-terra-med    keep  87.3%   dmg 0/0/0   left 0+0   em 2
  c-luna-high    keep  89.9%   dmg 0/0/0   left 0+0   em 2
  c-luna-med     keep  92.9%   dmg 0/0/0   left 0+0   em 2

04-plan-doc        977w, 73 code spans, 6 links, 0 neg, 6 bullets, 8 em-dash
  c-sol-high     keep  89.7%   dmg 0/0/0   left 0+0   em 0
  c-sol-low      keep  88.9%   dmg 2/1/0   left 0+0   em 0
  c-terra-high   keep  80.7%   dmg 0/0/1   left 0+6   em 2
  c-terra-med    keep  77.8%   dmg 0/0/1   left 0+4   em 0
  c-luna-high    keep  97.1%   dmg 0/0/0   left 0+0   em 0
  c-luna-med     keep  97.3%   dmg 0/0/0   left 0+6   em 2
```

Totals across the four fixtures, and wall time for all four `exec` runs:

| Agent          | Damage | Rules left | Wall  |
| -------------- | -----: | ---------: | ----: |
| `c-luna-high`  |      1 |          1 |  62 s |
| `c-terra-med`  |      1 |          4 |  55 s |
| `c-luna-med`   |      0 |          7 |  66 s |
| `c-sol-high`   |      2 |          0 |  64 s |
| `c-sol-low`    |      4 |          0 |  76 s |
| `c-terra-high` |      5 |          6 |  57 s |

Every run finished `ok` with `end_turn`; nothing timed out or hit a retry.
Wall time separates the candidates by less than the noise between repeats and
did not inform the pick. cursor-agent reports no token counts over ACP, so
`CompareRow.input_tokens` and `output_tokens` are always null and per-run cost
cannot be measured from the harness.

Each individual failure, read back against its source. The fixtures stay
private, so these describe the kind of anchor lost rather than quoting it:

- `c-sol-low` on `04-plan-doc` dropped a CLI flag together with its path
  argument, and emitted a code span the source never had. The only invention
  in the whole matrix.
- `c-terra-high` on `02-pr-description` deleted two test filenames from a PR
  body.
- `c-terra-high` and `c-terra-med` on `04-plan-doc` both dropped the same
  relative link target out of a sentence they otherwise kept.
- `c-sol-high` and `c-terra-high` on `03-slack-draft` cut a whole sentence,
  taking two channel references with it.
- `c-luna-high` on `01-status-reply` cut a closing offer and the command
  inside it, and left one negative parallelism.

## Conclusions

**`gpt-5.6-luna-high` is the rewrite model.** It sits on the frontier: less
damage than the incumbent Sol and within one violation of it on rule
application, from the cheapest tier in the GPT-5.6 family, without the `-fast`
2x multiplier. Shipped as the `agptw` shortcut.

**Turning Sol's reasoning down is the wrong lever.** `gpt-5.6-sol-low` was the
only candidate to invent a code span, and it lost more source than Sol at high.
Less reasoning on a big model degrades faithfulness before it saves anything.
Reach for a smaller model at high reasoning instead.

**Reasoning tier moved rule application within Luna, and not within Terra.**
Luna went from six bold-label bullets left at `-medium` to none at `-high`.
Terra went the other way, four left at `-medium` and six at `-high`. One
family improving and the other regressing is not a reasoning-tier law; it is
two data points. Take the Luna result at face value — `-high` is the tier that
cleared the bullets on the model being shipped — and do not generalize the
mechanism to a family this matrix did not test.

**Terra is out at both tiers.** At `-high` it was the most destructive
candidate in the matrix while still leaving six violations, and at `-medium`
it dropped a link target. Its one advantage over `agptw` is that `-medium`
matched it on total damage; that is not enough to earn a second shortcut.

**Aggressive editing costs facts.** The three lowest retained-word scores
(`c-terra-high` at 74.2%, `c-sol-low` at 76.0%, `c-terra-med` at 77.8%) belong
to candidates that dropped source anchors. The rewrite guardrails say subtract
and simplify; a model that subtracts hardest subtracts identifiers too.

## Caveats

- Four fixtures and one run each. The matrix separates the candidates cleanly
  on damage, but a single sample per pair cannot distinguish a two-violation
  gap from run-to-run variance.
- Scoring is mechanical. It catches dropped identifiers and unremoved
  constructions; it does not judge whether the prose reads better.
- Cursor does not publish per-token rates in a form the CLI exposes, so the
  cost claim rests on Cursor's published tier ordering (Sol above Terra above
  Luna, `-fast` at 2x), not on measured spend.
- `cursor-agent` model ids pin a generation and go stale. Re-run this method
  when `scripts/audit/acpx-model-drift.sh` flags `gpt-5.6-luna-high`, or when a
  new family lands below Luna.
