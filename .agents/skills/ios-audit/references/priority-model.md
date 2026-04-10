# Priority model — MoSCoW + RICE

Every finding carries three signals: **severity**, **priority**, and **rice**.
They answer three different questions:

- **severity** answers "how bad is the current state?"
- **priority** answers "how soon should someone fix it?"
- **rice** answers "what's the best use of a day of work?"

Use all three. They rarely align exactly and the disagreement is useful
signal — a `critical` finding with a `could` priority means "bad but the
blast radius is tiny."

## Severity

| Value | Meaning | Examples |
|---|---|---|
| `critical` | Data loss, crash in a user-hit path, ship blocker | Silent catch swallowing save errors; missing privacy manifest; race condition that corrupts state |
| `major` | User-visible defect or clearly bad pattern | Flow step fails in a screenshot; missing a11y label on the Play button; force unwrap in the sign-in path |
| `moderate` | Quality drag, not breaking anything today | Complexity hotspot, duplication, missing cache, inconsistent naming |
| `minor` | Polish, nits, style drift | Stale TODO, outdated copyright, unused helper |

## Priority (MoSCoW)

| Value | Meaning |
|---|---|
| `must` | Fix before the next release. Ship blockers and near-certain regressions. |
| `should` | Fix next sprint. Meaningfully reduces future defect rate. |
| `could` | Nice-to-have. Do it when the area is being touched anyway. |
| `wont` | Intentional debt. Record and move on. Don't fix unless requirements change. |

## RICE

`score = (reach × impact × confidence) / effort`

| Field | Scale | How to pick |
|---|---|---|
| `reach` | 0-10 | How many users are affected per interaction cycle? 10 = every user every session; 5 = most users some sessions; 1 = rare |
| `impact` | 0-10 | How much does it hurt them when it happens? 10 = catastrophic (data loss, crash); 5 = noticeable friction; 1 = cosmetic |
| `confidence` | 0-1 | How sure are you about the reach and impact? 1.0 = direct evidence in logs/screenshots; 0.5 = educated guess; 0.2 = theoretical |
| `effort` | 0.5+ | Person-days to fix. 0.5 = trivial diff; 1 = simple refactor; 3 = requires design; 10 = project-level |

### Example RICE scores

```
CH-001  Task-leak in PlayerEngine quality switch
  reach=9 impact=8 confidence=0.9 effort=1.5
  score = (9 * 8 * 0.9) / 1.5 = 43.2

UX-003  Missing a11y label on Play button
  reach=2 impact=6 confidence=1.0 effort=0.5
  score = (2 * 6 * 1.0) / 0.5 = 24

RL-001  Missing PrivacyInfo.xcprivacy
  reach=10 impact=10 confidence=1.0 effort=2
  score = (10 * 10 * 1.0) / 2 = 50

RT-007  Error types are NSError-ish
  reach=3 impact=2 confidence=0.8 effort=5
  score = (3 * 2 * 0.8) / 5 = 0.96
```

Sort your findings by RICE descending to get the best-bang-for-buck work
list. Findings tagged `critical`+`must` always sort first regardless of
score; RICE is the tiebreaker within severity bands.

## When they disagree

- **critical severity, could priority** — real bug, tiny blast radius.
  Document and schedule, but don't interrupt ship.
- **minor severity, must priority** — usually wrong. If it's truly must,
  upgrade the severity.
- **high RICE, could priority** — either the priority is too low or the
  reach is overestimated. Revisit.
- **low RICE, must priority** — compliance: low reach/impact but required
  for legal/App-Store reasons. Keep must. Do not let RICE override.

## Rule of thumb

If you have fewer than 10 findings total, don't bother with RICE — severity
+ priority is enough. RICE earns its keep when you have 30+ findings and
need to sequence the backlog.
