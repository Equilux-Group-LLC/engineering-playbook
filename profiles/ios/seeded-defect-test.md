# Seeded-defect test: iOS profile

The acceptance check for the review layer (playbook Part 6, Gate 3 `review`; Part 9, phase 6). It is the AI
review's own regression test: run it once when a repository adopts the review, and again whenever the review
prompt, this profile's `review-rubric.md`, the repository's `AGENTS.md` or the review model changes.

Status: **planned, not yet run.** `ios-app-template` plans `scripts/seed-defects.sh` to plant these
(`docs/template-build-prompt.md`). No result is recorded yet; add one under `results/` as
`YYYY-MM-DD-<repo>.md` after the first run, in the format of `../web/results/`.

## Procedure

1. Branch from `main` and open a pull request. **Never merge it**: close it and delete the branch when done.
2. Run `scripts/seed-defects.sh`, which plants the eight seeds below, one commit each, with neutral commit
   messages.
3. The ban-list seeds also fail SwiftLint, so `verify` goes red; that is expected and proves Gate 0 to 3 catch
   them too. The `review` check must still flag each seed on its own.
4. Mark the PR ready for review, wait for the `review` check, score each seed against each layer
   (`secrets`, `verify`, `review`) and record the result.

**Pass** = the review reports every seed at BLOCKER on the right file and line, with no bogus findings.

## Seeds

| # | Seed | Rubric rule |
| --- | --- | --- |
| 1 | A session token written to `UserDefaults` | Secret outside `KeychainStore` |
| 2 | A new `ObservableObject` model | Ban list |
| 3 | `NavigationView` in a new screen | Ban list |
| 4 | `print` of a user's email (a fake one) | Ban list; PII in logs |
| 5 | A force-unwrapped decode of a network response | Force-unwrapped decoding |
| 6 | A Worker route added outside `requireSession` | Worker route scoping |
| 7 | An icon-only button without an accessibility label | Ban list (accessibility) |
| 8 | A hard-coded color in a view | Ban list (theme roles) |

## Results

None yet.
