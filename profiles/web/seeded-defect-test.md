# Seeded-defect test: web profile

The acceptance check for the review layer (playbook Part 6, Gate 3 `review`; Part 9, phase 6). It is the AI
review's own regression test: run it once when a repository adopts the review, and again whenever the review
prompt, this profile's `review-rubric.md`, the repository's rules file or the review model changes.

## Procedure

1. Branch from the PR target branch and open a pull request into it. **Never merge it**: close it and delete
   the branch when done.
2. Plant the six seeds below, one commit each, with neutral commit messages ("add provider summary", not
   "seed: missing authz"). Keep the code passing `verify`, so only a semantic reviewer can catch them.
3. Mark the PR ready for review and wait for the `review` check.
4. Score each seed against each layer (`secrets`, `verify`, `review`) and record the result in
   [`results/`](results/) as `YYYY-MM-DD-<repo>.md`, including anything the reviewer found beyond the seeds and
   any false positives.

**Pass** = the review reports every seed at BLOCKER on the right file and line, with no bogus findings. A
seed missed or rated below BLOCKER means tuning the rubric or the rules file, then re-running the test.

## Seeds

| # | Seed | Rubric item |
| --- | --- | --- |
| 1 | A route with no server-side authorization check, and one with a check but no organization scoping | 1 |
| 2 | A `console.log` of a token or a credential-bearing URL (for example a calendar-feed URL) | 2 |
| 3 | A hard-coded fake secret (see below) | 2 |
| 4 | Unescaped HTML interpolation, and a SQL query built by string concatenation | 3 |
| 5 | A free-text field that could hold data the repository's data boundary forbids (skip if it has none) | 7 |
| 6 | A schema change with no migration file (for example an inline `ALTER TABLE`) | 4 |

Make the fake secret random so a secret scanner's allowlist can't hide it, and never reuse it:

```bash
python3 -c "import secrets,string;print('ghp_'+''.join(secrets.choice(string.ascii_letters+string.digits) for _ in range(36)))"
```

Don't use a vendor's documented example key (for example AWS's `...EXAMPLE`): scanners allowlist them, so it
proves nothing.

## Planned additions (not yet run)

`../web.md` section 8 lists seeds for a future web template's `scripts/seed-defects.sh` that this run did not
cover: an existing test changed to `test.skip`, a write route that accepts an unknown body field, and a
`fetch` to a third-party host in a unit test. Add them here once a run has scored them.

## Results

| Date | Repository | Score | Record |
| --- | --- | --- | --- |
| 2026-09-22 | `caobhin/nursing-calendar` | 6 / 6 at BLOCKER, 0 false positives | [results/2026-09-22-nursing-calendar.md](results/2026-09-22-nursing-calendar.md) |
