---
name: verify
description: Pre-commit check for this repository. Runs verify:fast, then /simplify on the changed source, then verify:fast again. Use right before every commit that changes code, and when asked "is this ready", "verify" or "check my work".
---

# Verify before commit

Never commit while any run below is red. The full `verify` runs at pre-push and in CI, not here.

1. Run `.harness/run-contract.sh verify:fast`. If it is red, stop. Fix the cause under the testing-harness
   rules: never delete, skip or weaken a test. Do not continue on red.
2. If the change touches UI or a route and this repo has a /run recipe (web) or XcodeBuildMCP (iOS), launch
   the app and exercise the changed path once. Note what you saw.
3. List the changed source files (staged + unstaged, excluding docs, generated files, lockfiles, snapshots,
   test/**, Tests/**, *.test.*, *_test.*, *.spec.*). If they total fewer than ~20 changed lines, go to step 6.
4. Stash or note the current state, then run /simplify on exactly those paths, with these constraints: do not
   modify any test file, fixture or snapshot; do not change behaviour, public interfaces, error messages or
   log output; keep each fix minimal.
5. Run `.harness/run-contract.sh verify:fast` again.
   - Green: keep the /simplify edits.
   - Red: restore every file /simplify changed to its pre-step-4 content, re-run verify:fast to confirm
     green, and report which suggestion broke what.
6. Report in 5 lines or fewer: both results, what /simplify changed (file + one line each), anything
   reverted, and anything you could not verify.
