# ADR-0001: Profile status, and the initial state of the iOS profile

**Status:** Accepted
**Date:** 2026-10-18
**Deciders:** engineering-playbook owner

## Context

`profiles/ios.md` says `Status: draft`, but nothing in this repository says what "draft" means or what moves a
profile out of it. The profile was seeded from `ios-app-template`'s iOS playbook, which the template has since
retired in favor of this profile (template commit `eb94db2`). The template adopted the playbook harness in its
ADR 0020.

The profile was checked line by line against `ios-app-template` at `59b2a9d` (its `main` on 2026-10-18) and
against playbook Parts 6, 7 and 9. Two kinds of gap turned up:

- **Drift**, where the template is right and the profile is stale: the UI test folder (`Tests/AppUITests`, not
  `Tests/UITests`), test plans (`Screenshots.xctestplan`; there is no `Full.xctestplan`), Gate 1 and Gate 3
  wiring (`pr-checks.yml` calling the shared workflows, `gitleaks git --staged`), template ADRs 0012 to 0020
  missing from Scope, the `verify` checks added in template ADRs 0015 to 0017, the catalog's 101+ numbering
  for template additions, and a seeded-defect test still marked "planned" although `scripts/seed-defects.sh`
  now exists.
- **Gaps**, where the profile and the template disagree and either could move:
  1. `scripts/verify-fast` runs `xcodebuild test` on changed packages. Part 7 says simulators stay out of
     `verify:fast`, and the profile says "No `xcodebuild`".
  2. `.mise.toml` defines only `verify` and `verify:fast`. Part 9 phase 1 requires every Part 7 command.
     Because `format:check` and `lint` are missing, lefthook's pre-commit gets `run-contract.sh` exit 2,
     treats it as a pass (`|| [ $? -eq 2 ]`), and Gate 1 checks nothing.
  3. The template has no `scripts/smoke-<env>.sh` (L6) and no Worker deploy workflow (L7).
  4. The `Edge/` 85% coverage floor is not enforced: `coverage-gate` covers the three packages and the App only.
  5. Nothing defines the draft exit.

Outside both repositories: playbook v1.4.0 is stamped in `VERSION` but not tagged, so `v1` is still v1.3.0.
That release has neither `ai-review.yml`'s `profile` input nor `conformance.yml`, so the template's PR Review
and PR Conformance fail until it ships.

## Decision

1. **`verify:fast` stays as Part 7 says.** The template removes the changed-package `xcodebuild test` stage
   from `scripts/verify-fast`. Package tests run only in `verify`. The profile already says this.
2. **The template defines every Part 7 command** as a mise task wrapping its existing scripts. That turns
   Gate 1 on. The profile's command map gains the `test` row and `setup` gains `lefthook install`.
3. **The template ships L6 and L7 skeletons:** `scripts/smoke-development.sh` and a manual Worker deploy
   workflow, as profile section 2 describes, so every app inherits them.
4. **The `Edge/` floor is enforced.** The template's coverage gate reads Edge's Vitest V8 report and requires
   85%. Measure first so the gate does not start red.

   **Amended 2026-10-18: 80%, recorded but not gated (template ADR 0022).** Measuring showed two things.
   Cloudflare's Workers Vitest pool can't produce V8 coverage, so gating Edge needs `@vitest/coverage-istanbul`,
   a new devDependency. And Edge was at 81.67% (214 of 262 lines), with nearly all the gap in
   `src/integration.ts`, the test-only Worker entry. The owner chose an 80% floor exception over adding the
   dependency. The profile now says 80% with the Istanbul provider and names the floor as a gap in its status
   line. Ending the exception means approving the dependency, covering `src/integration.ts` from Vitest, and
   gating Edge at 85%. That is the condition for this item to stop holding the profile in Draft.
5. **A profile has two states, Draft and Active,** defined in `profiles/README.md` ("Profile status") for
   every profile. A profile becomes Active when all of these hold:
   - every concrete claim (paths, commands, workflows, floors) matches its platform template at a named commit;
   - the template's `verify` passes on its CI runner at that commit;
   - the seeded-defect test passes and its result is recorded in `<platform>/results/`;
   - the change that marks it Active ships in a tagged playbook release.

   An Active profile that falls out of line with its template goes back to Draft in the same change that
   finds the gap.

Under this rule the profile keeps describing the target. Where the template has not caught up, the profile's
status line names the gap and links here.

## Options considered

### `verify:fast` with a simulator stage

| Option | Assessment |
| --- | --- |
| Move package tests to `verify` (chosen) | Matches Part 7 as written. Changed package tests now run at push, not at every commit |
| Keep the stage if measured under 60 s | Bends a rule the playbook spelled out; the timing on the Mac mini varies with simulator state |
| Amend Part 7 | Possible later, if the slower feedback hurts. Needs evidence first |

### Missing commands

| Option | Assessment |
| --- | --- |
| Template adds all (chosen) | Thin mise tasks over existing scripts. Fixes Gate 1 |
| Shrink the profile | Breaks Part 9 phase 1 and leaves Gate 1 a no-op. Not allowed |

### L6 and L7

| Option | Assessment |
| --- | --- |
| Template ships skeletons (chosen) | One-time template work; apps inherit a working smoke and deploy path |
| Each app adds them at first deploy | Every app redoes the same work, and the first deploy is when it is least likely to be done carefully |

### `Edge/` floor

| Option | Assessment |
| --- | --- |
| Enforce in the template (first choice) | Makes the profile true; the current coverage needs measuring first |
| Drop the floor | Leaves Edge with only the shared changed-line and ratchet gates, which are also off (no Cobertura report yet) |
| Keep and mark pending | Leaves an unenforced number in the profile indefinitely |
| 80% exception, recorded not gated (chosen after measuring) | No new dependency. The profile tells the truth and names the gap, which keeps it Draft until the exception ends |

### Draft exit

| Option | Assessment |
| --- | --- |
| Full checklist (chosen) | "Active" then means the profile is true, enforced and released. Slowest to reach |
| Two stages (Confirmed, then Active) | Shows progress, but adds a state every profile and script would have to know |
| Seeded-defect test only | Fast, but proves the review layer only, not that the profile describes a real template |

## Consequences

- `ios.md` stays Draft until the template work below lands. Its status line names what is outstanding.
- `web.md` cannot become Active until a web platform template exists. That is intended: a profile with no
  implementation is a proposal.
- Changed package tests now run at push (`verify`), not at commit (`verify:fast`). Revisit if that hurts the
  edit loop.
- **To revisit:** template invariants `IOS-SEC-101` (bearer tokens only, no stored cookies) and `IOS-SEC-102`
  (no ATS exception in any configuration) look right for every iOS app. They could become profile defaults.

## Action items

This repository (this change):

1. [x] `profiles/README.md`: add "Profile status" and update the status table.
2. [x] `profiles/ios.md`: fix the drift; name the outstanding gaps in its status line.
3. [x] `profiles/ios/seeded-defect-test.md`: mark the test ready to run; align the procedure with
   `scripts/seed-defects.sh`.

This repository, later:

4. [ ] Tag playbook v1.4.0 so `v1` has the `profile` input and `conformance.yml`.

`ios-app-template`:

5. [ ] Remove the `xcodebuild` stage from `scripts/verify-fast`.
6. [ ] Add every Part 7 command as a mise task; check that lefthook's pre-commit now runs format and lint.
7. [ ] Add `scripts/smoke-development.sh` and a manual Worker deploy workflow.
8. [x] Measure `Edge/` coverage: 81.67%. The floor is set at 80% by exception and not gated (decision 4,
   amended; template ADR 0022).
   - [ ] To end the exception: approve `@vitest/coverage-istanbul`, cover `src/integration.ts` from Vitest,
     and gate Edge at 85%.
9. [ ] Write a Cobertura report from `scripts/verify` and pass it to PR Checks.
10. [ ] Add `CLAUDE_CODE_OAUTH_TOKEN` and install the Claude GitHub App; delete `pr-verify.yml` once PR Checks
    is green on the Mac mini.
11. [ ] Run the seeded-defect test and record the result in `profiles/ios/results/`.

Then: re-check `ios.md` against the template commit that has all of the above, and mark it Active in a
tagged release.
