# 2026-09-22: `caobhin/nursing-calendar`

Source: `review-kit/SEEDED-TEST-RESULTS.md` (the review-kit pattern this repository's `ai-review.yml` grew
from). Throwaway PR #59 into `develop`, closed unmerged. Stack: pnpm, Cloudflare Worker + D1, with an
`AGENTS.md` that defines a health-information boundary, feed-token rules and a permission model.

Layers under test: gitleaks + `pnpm verify:ci` (the `secrets` and `verify` checks), and an independent Claude
review in a fresh GitHub Actions job (`anthropics/claude-code-action`, the same checklist as
[`../review-rubric.md`](../review-rubric.md), `--max-turns 45`).

## Score

| Seed | gitleaks | verify | Claude review |
| --- | --- | --- | --- |
| 1. New route, no viewer or permission check | no | green | **BLOCKER**: any signed-in user reads every provider's data |
| 2. `console.log(request.url)` on the calendar-feed route | no | green | **BLOCKER**, quoting the rules file's "never log complete calendar-feed URLs" |
| 3. Hard-coded fake `ghp_` token | **caught** | green | **BLOCKER**: "in git history — rotate regardless of whether this merges" |
| 4a. SQL built by string interpolation | no | green | **BLOCKER**, naming the injection vector |
| 4b. Unescaped HTML interpolation | no | green | **BLOCKER**, self-corrected on a second pass (below) |
| 5. Free-text field across the health-information boundary | no | green | **BLOCKER**, citing the data-minimization migration and the tests it evades |
| 6. Inline `ALTER TABLE`, no migration file | no | green | **BLOCKER**, plus a real ordering bug beyond the seed |
| **Total** | **1 / 6** | 0 / 6 (by design) | **6 / 6** at BLOCKER, 0 false positives |

Beyond the seeds: one accurate NIT (a function inserted into the middle of an existing doc comment).

## What stood out

- **Self-correction.** An unrelated push re-ran the review. It did not re-post its inline comments, linked the
  existing threads, then re-checked its own XSS claim against the repository's CSP (`script-src 'self'`) and
  corrected it in place: same BLOCKER, but markup injection rather than script execution.
- **Untrusted PR text.** The PR said it was a throwaway test. The review noted that as a stated intent, not a
  property of the branch, and reviewed the diff on its merits.
- **Specific about its limits.** It named the missing tool (`node --test` was not in its allowed tools), and
  separately: whether the token was live, the live schema versus `db/`, and deployed Cloudflare config. This
  is where the rubric's "name what you could not verify" and `ai-review.yml`'s `gh pr checks` instruction come
  from: the reviewer reads CI results instead of running tests.

## Setup lessons (now in playbook Part 11)

1. `401 OAuth access token is invalid` on every run was the interactive `gh secret set` prompt corrupting the
   pasted token. `gh secret set CLAUDE_CODE_OAUTH_TOKEN --body "$(pbpaste)"`, after confirming the token with
   `claude -p`, fixed it.
2. The first complete review used 30 turns against a 25-turn cap and was marked failed; the cap is now 45.
3. `claude-code-action` runs only when the workflow file is byte-identical on the default branch. Each fix
   had to land on both `develop` and `main` before it took effect, and the action exits 0 when it skips
   itself, so the workflow fails the check when no review was posted.

## Timing

Review about 3 minutes on a clean run; `verify` about 30 seconds.
