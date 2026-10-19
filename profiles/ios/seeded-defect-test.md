# Seeded-defect test: iOS profile

The acceptance check for the review layer (playbook Part 6, Gate 3 `review`; Part 9, phase 6). It is the AI
review's own regression test: run it once when a repository adopts the review, and again whenever the review
prompt, this profile's `review-rubric.md`, the repository's `AGENTS.md` or the review model changes.

Status: **ready to run, not yet run.** `ios-app-template` ships `scripts/seed-defects.sh` (since `59b2a9d`),
which plants these seeds; `scripts/seed-defects.sh --list` prints the answer key. Running it is a condition for
this profile becoming Active ([Profile status](../README.md#profile-status)). Record each run under `results/`
as `YYYY-MM-DD-<repo>.md`, in the format of `../web/results/`.

## Procedure

1. From a clean, up-to-date `main`, run `scripts/seed-defects.sh`. It creates branch
   `seed-defects/<time>` and commits the eight seeds below; it pushes nothing.
2. Push the branch and open a pull request into `main`. **Never merge it**: close it and delete the branch
   when done.
3. The ban-list seeds also fail SwiftLint, so `verify` goes red; that is expected and proves Gate 0 to 3 catch
   them too. The `review` check must still flag each seed on its own.
4. Mark the PR ready for review, wait for the `review` check, score each seed against each layer
   (`secrets`, `verify`, `review`) and record the result.

**Pass** = the review reports every seed at BLOCKER on the right file and line, with no bogus findings.

## Seeds

| # | Seed | File | Rubric rule |
| --- | --- | --- | --- |
| 1 | A session token written to `UserDefaults` | `App/Features/Settings/SessionCache.swift` | Secret outside `KeychainStore` |
| 2 | A new `ObservableObject` model with `@Published` | `App/Features/Items/ItemStats.swift` | Ban list |
| 3 | `NavigationView` in a new screen | `App/Features/Items/ItemStatsView.swift` | Ban list |
| 4 | `print` of a user's email (a fake one) | `App/Features/Settings/Diagnostics.swift` | Ban list; PII in logs |
| 5 | A force-unwrapped (`try!`) decode of a network response | `App/Features/Items/ItemImport.swift` | Force-unwrapped decoding |
| 6 | A Worker route mounted outside `requireSession` that returns every user's items | `Edge/src/routes/export.ts` | Worker route scoping |
| 7 | An icon-only button without an accessibility label or identifier | `App/Features/Items/ItemRowActions.swift` | Ban list (accessibility) |
| 8 | A hard-coded color and font in a view | `App/Features/Items/ItemStatsView.swift` | Ban list (theme roles) |

## Results

None yet.
