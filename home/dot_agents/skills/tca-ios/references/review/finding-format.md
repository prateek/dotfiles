# Applies to: TCA 1.25+, iOS 16+

# Finding Format

## Use When

Use this for every review finding.

## Schema

```markdown
### Finding: <short title>

Severity: Critical / High / Medium / Low
Confidence: High / Medium / Low

Files / symbols:
- path/to/File.swift:SymbolName

Evidence:
- Describe the observed code, with file references and line numbers when available.

Why it matters in TCA terms:
- Explain the correctness, lifecycle, testability, or maintainability concern.

Recommended fix:
- Give a focused incremental fix.

Suggested test:
- Name a concrete test that would catch the issue.
```

## Severity

- Critical: likely correctness bug, data loss, leaked work, broken navigation, or untestable production flow.
- High: serious maintainability, scalability, concurrency, or testing risk.
- Medium: useful improvement with clear evidence.
- Low: naming, consistency, local polish.

## Guardrails

No generic advice. Every finding needs evidence.
