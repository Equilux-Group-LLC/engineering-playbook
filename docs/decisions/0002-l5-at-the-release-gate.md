# ADR-0002: A release gate for L5, and the iOS profile moves its UI journeys there

**Status:** Accepted
**Date:** 2026-11-06
**Deciders:** engineering-playbook owner
**Related:** Equilux-Group-LLC/caregiverApp#47; follow-ups caregiverApp#49 and ios-app-template#38

## Context

In the iOS profile, `verify` runs every layer, the XCUITest journeys (L5) included. It runs at three points:
pre-push (Gate 2), PR Checks (Gate 3), and the run on `main` after each merge. All three use the same
self-hosted Mac, which is also the developer's machine.

caregiverApp measured where the time goes (PR Checks run 42152170949, 2026-11-06):

| Part of `verify` | Time |
| --- | --- |
| Everything before the Swift tests (lint, Edge, script tests) | about 1 min 20 s |
| `xcodebuild test` on the whole `Verify` plan, cold build | 7 min 53 s |
| ↳ 17 UI journeys (each relaunches the app and runs the accessibility audit; serial) | about 6 min |
| ↳ 418 unit and snapshot tests | about 67 s |

For one pull request pushed once, that is about 30 minutes of Mac time before the developer can install the
build. Two more causes make it worse:

- **The build cache is deleted on every run.** `actions/checkout` runs `git clean -ffdx`, which deletes
  `build/DerivedData` inside the checkout, so every CI run compiles everything from scratch.
- **The host is shared.** The runner and local development compete for the same M1 and the same disk.

The app has no TestFlight testers yet. Builds go to the Simulator or one developer iPhone. The owner wants the
expensive suite kept as the check before a build reaches anyone else, and a faster loop until then.

Part 6 already lets L5 leave Gate 2 ("otherwise L5 runs in CI only"). Moving it out of CI too needs a
place where it still runs, and a guarantee that a release cannot skip it.

## Decision

1. **The playbook gains an optional release gate** (Part 6) and an optional contract command,
   `verify:release` = `verify` + L5 (Part 7). A profile that opts in may leave L5 out of `verify`. The release
   must be structurally impossible without a green `verify:release`: the workflow that runs it is the only
   thing that creates the release.
2. **The iOS profile opts in.**
   - `verify` runs the `Verify` test plan without `AppUITests`, with coverage on and its floors unchanged.
     Without the journeys, caregiverApp's App target is at 67.1% against the 60% floor.
   - `verify:release` (`scripts/verify --release`) runs the whole plan.
   - A manual `release.yml` runs `verify:release` on the self-hosted runner and pushes the `release/<version>`
     tag that starts Xcode Cloud, only on green.
3. **The iOS build cache moves outside the checkout on CI**, so `git clean` keeps it. Gate 2 stays `verify`, now
   without the journeys.
4. **`check-conformance.sh` enforces the opt-in.** When a repository's profile names `verify:release`, the
   repository must define it.

## Options considered

- **Keep L5 in `verify`, trim it to the profile's limit of five journeys.** This is needed anyway (caregiverApp#49),
  but it still pays for L5 three times per push, and five journeys still cost about 2 minutes each time.
- **L5 in CI only (today's Part 6 escape).** This saves the pre-push run only. PR Checks and the run on `main` both
  use the same Mac, so the developer still waits for it.
- **Nightly L5.** Rejected: a nightly run would need a second scheduled workflow, and nothing stops a release
  in between.
- **`verify:fast` at pre-push.** Rejected for now: the build and the Swift tests would then first run in CI, after
  the push. The owner chose the middle tier, and asked for that choice to be revisited if more speed is needed.

## Consequences

- Easier: each push costs about 2 to 3 minutes of Mac time with a warm cache, instead of 8 to 10.
- Harder: a journey broken by a merged pull request is found at release time, not at the pull request.
  Mitigations:
  - The models and views the journeys drive have unit and snapshot tests.
  - A developer can run `mise run test:e2e` on demand.
  - The fix lands before the release tag exists.
- Template-managed files change: `scripts/verify`, `scripts/xcode-test`, `scripts/lib.sh`, `.mise.toml`,
  and the new `.github/workflows/release.yml`.

## Revisit when

- builds go to TestFlight testers on a regular cadence, so a broken journey would reach people within days; or
- the owner asks for more streamlining (the next step is `verify:fast` at pre-push); or
- the journeys are consolidated (caregiverApp#49) and L5 is fast enough to come back into `verify` (Part 6,
  Gate 2).
