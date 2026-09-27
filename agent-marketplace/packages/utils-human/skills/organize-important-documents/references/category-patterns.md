# Category Patterns

Treat these layouts as starting points. Add a top-level category only when it is durable and large enough to need its own place.

## Default root

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

Keep the root narrow and use subfolders for cases, providers, or years.

## By life domain

**Identity** groups core credentials and certificates:

```text
01-Identity/
  Passport/
  Driver-License/
  Birth-Certificate/
```

**Immigration** groups records by case or renewal, rather than file type:

```text
02-Immigration/
  H1B/
    2024-02-renewal/
  I94/
  Green-Card/
    2025-eb1a/
```

**Work** groups records by employer or process:

```text
03-Work/
  OpenAI/
    Offer-Letter/
    Background-Check/
  Uber/
    Equity/
    Employment-Letters/
```

**Home** groups records by address, move, or landlord interaction:

```text
04-Home/
  2025-nyc-apartment-renewal/
  2018-move/
```

**Health** groups records by provider, episode, or claim:

```text
05-Health/
  Insurance/
  Providers/
    MSKCC/
  Episodes/
    2018-treatment/
```

**Taxes** groups by year. Keep the return, e-file receipt, W-2 or 1099 forms, and notable correspondence together:

```text
06-Taxes/
  2023/
  2024/
  2025/
```

## Archive closed work

Move closed cases out of active folders while retaining a clear label:

```text
99-Archive/
  2014-canada-visa/
  2018-old-apartment-applications/
```

## Name files for retrieval

Use an ISO date followed by a useful description:

- `2025-04-18 offer-letter-openai.pdf`
- `2024-08-22 i94.pdf`
- `2025-07-30 dmv-appointment-confirmation.pdf`

Avoid names that hide the document's date or purpose, such as `scan.pdf`, `final-final.pdf`, `August 6, 2016.pdf`, or `Documents/`.

## Keep unrelated work elsewhere

Common exclusions include code repositories, school notes and assignments, creative writing, unrelated photo libraries, build artifacts, app caches, and raw exports kept only for temporary analysis.
