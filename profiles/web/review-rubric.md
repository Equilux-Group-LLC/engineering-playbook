# Review rubric: web profile

`ai-review.yml` appends this file to the reviewer's prompt when a caller passes `profile: web`. It adds to the
repository's rules file; where the two disagree, the stricter rule wins. Source: the `review-kit` checklist that
scored 6/6 on the 2026-09-22 seeded-defect test (`results/2026-09-22-nursing-calendar.md`), plus the web
profile's rubric additions (`../web.md`, section 7).

## Checklist

Check each of these on every new or changed file, and open callers in full where the diff alone is not enough.

1. **Authorization on the server** for every new or changed route, handler or server action, including scoping
   to the caller's own organization or tenant, not just "is logged in".
2. **Secrets and private data**: tokens, credential-bearing URLs (for example calendar-feed or webhook URLs),
   API keys or private data in source, logs, errors or responses. A secret committed to the branch needs
   rotating whether or not the PR merges; say so.
3. **Input and output**: unknown body fields rejected, SQL with bound parameters (never string concatenation
   or template literals with user input), output escaped (no unescaped HTML interpolation).
4. **Schema changes** have a migration file, correct ordering (no statement that depends on a later one), and
   a rollback or restore note if destructive. An inline `ALTER TABLE` in application code is a BLOCKER.
5. **Tests**: changed behavior has a test; no test was deleted, skipped or weakened. No new dependency without
   a reason.
6. **Workflows and deploy config** use least privilege and never run untrusted PR input in a shell (`${{ }}`
   expressions from PR fields go through `env:`, not straight into `run:`).
7. **Data boundary**: if the rules file names data that must never be stored, logged or shared (personal,
   health or financial data), a new field, column, log line or response that could hold it is a BLOCKER, even
   when it is free text and only "could" hold it. Cite the rule.

## BLOCKER

Anything in the checklist above that fails, and:

- A route or server action without an authorization check, or one that reads or writes another tenant's rows.
- SQL built by string concatenation or template literals with user input.
- User input rendered as HTML (`dangerouslySetInnerHTML`, `v-html`, `innerHTML`, unescaped template
  interpolation) without sanitizing.
- A secret in source, in client-bundled code, or in a `NEXT_PUBLIC_` / `VITE_` variable.
- `console.log` (or any logger) of a user identifier, token, credential-bearing URL or request body.
- A new `test.skip`, `it.only`, `describe.skip` or `.todo` on an existing test.

## SHOULD-FIX

- Icon-only button without an accessible name; E2E selectors by CSS class.
- `any` without a reason; floating promises.
- Hard-coded colors or fonts where the design system has tokens.

## Name what you could not verify

In the top-level comment, list what you could not check from the repository alone, specifically, not as a
generic disclaimer. For example: whether a leaked token is live; the live database schema compared with the
migrations; deployed host configuration (environment bindings, access rules, CSP headers set outside the
repo); and anything a missing tool stopped you from checking, naming the tool.

When a later run of this review (a new push to the same PR) shows that an earlier finding was wrong, correct
it in place and say why; do not repeat it.
