# Category Patterns

Use these as starting points, not rigid requirements.

## Default Root

```text
Important Documents/
  00-Inbox/
  01-Identity/
  02-Immigration/
  03-Work/
  04-Home/
  05-Health/
  06-Taxes/
  07-Finance/
  08-Education/
  09-Legal/
  10-Family/
  99-Archive/
```

Keep the root narrow. Add a top-level folder only when the category is durable and large enough to justify it.

## Domain Patterns

### Identity

Good fits:

- Passport
- Driver license
- Birth certificate
- SSN or tax identifiers
- National ID

Pattern:

```text
01-Identity/
  Passport/
  Driver-License/
  Birth-Certificate/
```

### Immigration

Group by case or renewal, not by random file type.

Pattern:

```text
02-Immigration/
  H1B/
    2024-02-renewal/
  I94/
  Green-Card/
    2025-eb1a/
```

### Work

Group by employer or process.

Pattern:

```text
03-Work/
  OpenAI/
    Offer-Letter/
    Background-Check/
  Uber/
    Equity/
    Employment-Letters/
```

### Home

Group by address, move, or landlord interaction.

Pattern:

```text
04-Home/
  2025-nyc-apartment-renewal/
  2018-move/
```

### Health

Use providers, episodes, or claim groups.

Pattern:

```text
05-Health/
  Insurance/
  Providers/
    MSKCC/
  Episodes/
    2018-treatment/
```

### Taxes

Taxes work best by year.

Pattern:

```text
06-Taxes/
  2023/
  2024/
  2025/
```

Within a year, keep return, e-file receipt, W-2 or 1099 forms, and notable correspondence together.

## Archive Pattern

Archive closed cases without cluttering active folders.

Pattern:

```text
99-Archive/
  2014-canada-visa/
  2018-old-apartment-applications/
```

## Naming Rules

Prefer:

- `2025-04-18 offer-letter-openai.pdf`
- `2024-08-22 i94.pdf`
- `2025-07-30 dmv-appointment-confirmation.pdf`

Avoid:

- `scan.pdf`
- `final-final.pdf`
- `August 6, 2016.pdf`
- `Documents/`

## Common Exclusions

These usually belong elsewhere:

- Code repositories
- School notes and assignments
- Creative writing
- Photo libraries unrelated to a case
- Build artifacts
- App caches
- Raw exports that only support a temporary analysis
