# Slack Conventions (Skill-like)

## Purpose

Use this playbook for all Slack read/search/send tasks.

## When to use

- Posting updates, review requests, or project coordination messages.
- Resolving channel routing questions (where to post what).
- Any task involving Slack history lookup or message sending.

## Defaults

- Prefer the OpenAI Slack connector for Slack interactions.
- Do not guess channel IDs; resolve them before use.
- Treat `tmp-` channels as temporary project/experiment channels.
- Treat `ext-` channels as external (contains non-OpenAI participants).
- If a channel is private (lock icon), keep messaging need-to-know.
- Feedback pattern to expect:
  - `#project-x` for execution.
  - `#project-x-feedback` (or similar) for feedback loops.

## Workflow

### 1) Pick the target channel by purpose

Use the channel snapshot below to select the right destination.

### 2) Use the standard review request format

Review request format (exact):

```text
r? <PR_LINK> - <brief one-line description>
cc @reviewer1 @reviewer2
```

### 3) Send concise context

- One line on what changed.
- Include link(s).
- Add `cc` only for needed reviewers.

## Channel snapshot (relevant set)

### Offleash coordination

| Channel                       | ID            | Use / when to use                                     |
| ----------------------------- | ------------- | ----------------------------------------------------- |
| `#proj-offleash`              | `C099V6W28KT` | Main project coordination for offleash work.          |
| `#proj-offleash-migration`    | `C0AC3U96HDM` | Cross-team migration coordination and status updates. |
| `#proj-regression-management` | `C09JKNPK7N3` | Regression tracking and mitigation planning.          |
| `#proj-ai-on-obs`             | `C093C5XL0BF` | AI-on-observability project execution and discussion. |

### External / vendor channels (`ext-`)

| Channel                                | ID            | Use / when to use                                                   |
| -------------------------------------- | ------------- | ------------------------------------------------------------------- |
| `#ext-openai-chronosphere`             | `C0811JC9KEG` | Primary OpenAI <> Chronosphere coordination.                        |
| `#ext-openai-applied-obs-chronosphere` | `C08LASU7J86` | Applied observability discussions with Chronosphere.                |
| `#ext-openai-dd`                       | `C089T66SLHY` | OpenAI <> Datadog engineering/support channel.                      |
| `#ext-offleash-chatgpt-infra`          | `C09H4E3Q4F3` | Offleash workstream with external parties for ChatGPT infra.        |
| `#ext-offleash-inference`              | `C09QQESRCJ3` | Offleash inference-specific external coordination.                  |
| `#ext-offleash-temporal`               | `C09QM8PA031` | Offleash temporal-specific external coordination.                   |
| `#ext-proj-offleash-api-infra`         | `C09MQG2CQE9` | Offleash API infra external coordination.                           |
| `#ext-tmp-aw-time-travel-metrics`      | `C0AADR6528P` | Temporary external channel for AW time-travel metrics project work. |

### Observability support / alerts / announcements

| Channel                         | ID            | Use / when to use                                            |
| ------------------------------- | ------------- | ------------------------------------------------------------ |
| `#observability-support`        | `C05U6E4DA75` | Default support/help channel for observability questions.    |
| `#observability-request-review` | `C0A7CKHK5QF` | `r?` requests and review routing.                            |
| `#observability-announce`       | `C08HHMYTPQB` | Announcements only; subscribe for high-signal changes.       |
| `#observability-alerts`         | `C06N8ARK3FA` | Alert stream awareness and triage context.                   |
| `#observability-ops`            | `C0906GP50G1` | Ops/production log context for observability team workflows. |
| `#obs-q4-dris`                  | `C09K0C1G9DL` | DRI-focused project coordination.                            |

### Team / pod channels

| Channel                              | ID            | Use / when to use                                       |
| ------------------------------------ | ------------- | ------------------------------------------------------- |
| `#applied-infra-team`                | `C07L6E1RZD0` | Team coordination and internal infra chatter.           |
| `#applied-infra-social`              | `C07LVBC39PA` | Lightweight social/team communication.                  |
| `#applied-observability-team`        | `C0719KWQD0V` | Applied observability team coordination.                |
| `#applied-observability-watercooler` | `C07N0L7KPEX` | Low-friction social discussion for the team.            |
| `#applied-observability-nyc`         | `C09UDTG563W` | NYC-local coordination for applied observability folks. |
| `#obs-platform-pod`                  | `C07J46746JK` | Obs platform pod execution and local decisions.         |
| `#obs-experiences-pod`               | `C09RB0Q2G1E` | Obs experiences pod execution and local decisions.      |

## Validation checklist

- Correct channel selected for audience and sensitivity.
- Channel ID verified.
- Review request message matches exact format when asking for review.
