# Profile: iOS

Status: draft. Seeded from the "Testing harness" section of `docs/ios-vibe-coding-playbook.md` in
`Equilux-Group-LLC/ios-app-template`, corrected to that template's locked decisions
(`docs/template-build-prompt.md`, `docs/decisions/`). Where the iOS playbook still says Supabase, RLS, Tuist,
SwiftData, Docker or App Attest, this profile wins (see section 11).

## 1. Scope

Native iPhone apps with an optional small backend, built from `ios-app-template`. Locked decisions this
profile assumes:

| Area | Decision | ADR |
| --- | --- | --- |
| Toolchain | Xcode 27.x pinned in `.xcode-version`; Swift 6 mode, default MainActor isolation | 0001 |
| Minimum iOS | 26.0, iPhone only | 0002 |
| UI and state | SwiftUI, one `@Observable @MainActor` model per screen, protocol services in `@Environment` | 0003 |
| Project | **XcodeGen** from `project.yml` (`scripts/generate`); `*.xcodeproj` git-ignored; never edit `*.pbxproj` | 0005 |
| Packages | `AppShell`, `DesignSystem`, `Identity` (local SPM) + thin App target; one-way layering | 0006 |
| Local database | None: a `Persistence` protocol, `KeychainStore`, in-memory fakes | 0007 |
| Backend + auth | **Cloudflare Worker** (TypeScript, Hono) + **Better Auth** on **D1** via Drizzle, in `Edge/` | 0009 |
| Toolchain pins | mise (`.mise.toml`: Node 24, pnpm, XcodeGen, SwiftLint); Wrangler as a devDependency | 0010 |
| SDKs | No third-party analytics, crash or ad SDKs | 0011 |

## 2. Layer map

| Layer | Tools | Location | Rules beyond Part 4 |
| --- | --- | --- | --- |
| L0 Static | `swift format lint --strict`; SwiftLint `--strict` (the ban list as custom rules); Swift compiler with strict concurrency; `tsc --noEmit` for `Edge/`; `scripts/check-layering`; token drift check (`Tokens/generate.mjs --check`); `plutil -lint` on plists, entitlements and `PrivacyInfo.xcprivacy`; `check-privacy`; gitleaks; `Package.resolved` sync check | `.swift-format`, `.swiftlint.yml`, `scripts/` | Every ban-list rule has a test in `scripts/tests/test-lint-rules.sh` proving it fires |
| L1 Unit | Swift Testing (`@Test`, `#expect`, parameterized `arguments:`) on packages and `@Observable` models with fakes; Vitest for pure Worker logic | `Packages/*/Tests/**`, `Tests/AppTests/**`, `Edge/test/**` | `await model.load()`, then assert on `state`. Inject clock, UUIDs and randomness (AppShell providers). No network: stub `URLProtocol` for `EdgeClient` |
| L1 Snapshot | swift-snapshot-testing for DesignSystem components: light/dark × default/XXXL Dynamic Type, plus increased contrast | `Packages/DesignSystem/Tests/**/__Snapshots__` | Record on the pinned simulator and OS only. Re-recording needs a PR note naming why. Cleanup passes never re-record (Part 3 principle 9) |
| L2 Integration | Worker: Vitest with Cloudflare's Workers test pool (`@cloudflare/vitest-plugin`) against local D1 with every Drizzle migration applied. App: Swift Testing suites tagged `.integration` running the Live services against `wrangler dev` with a throwaway local D1. Better Auth contract tests (`Edge/test/contract`, `Edge/contract/ios-client-contract.json`) | `Edge/test/**`, `Tests/**` (`.integration`) | Fake only third parties (APNs, Apple's token revoke endpoint). Seed users are obviously fake (`test-user-a@example.invalid`). Contract tests run on every Better Auth upgrade |
| L3 Invariants | Same tools as L1/L2, catalogued in `test/invariants/CATALOG.yaml` | Tests named by each entry's `enforced_by` | See section 6. Every Worker route is on the `api` router behind `requireSession` and scopes every query to `c.var.userId`; every table with a `user_id` column is in `userOwnedTables` |
| L4 Deployment | Bash tests for `scripts/bootstrap`, `scripts/generate`, `check-layering`, lint rules, `ci_scripts/ci_post_clone.sh` | `scripts/tests/**` | Run against a temp copy of the repo; no Apple or Cloudflare credentials |
| L5 E2E | XCUITest, app launched with `-uitest` wiring every fake. Three journeys: sign-in stub, create item, delete account | `Tests/UITests/**` | Query by `accessibilityIdentifier` only; five journeys at most; each calls `try app.performAccessibilityAudit()` and suppresses a false positive only in the issue handler, with a reason |
| L6 Smoke | Worker: read-only `curl` script per Wrangler environment (health, version = deployed commit, D1 migration count, anonymous request to an `api` route returns 401). App: manual device pass before each TestFlight build (camera, BLE and other device frameworks have no simulator) | `scripts/smoke-<env>.sh` | Never sign a real account in for smoke |
| L7 Release | Worker: manual production workflow, D1 Time Travel bookmark recorded before `wrangler d1 migrations apply`, then deploy, smoke and a deployment record. App: Xcode Cloud archives, signs and uploads to TestFlight on `release/*` tags | `.github/workflows/`, Xcode Cloud workflow docs | Secrets via `wrangler secret` only, never `wrangler.toml`, `.dev.vars` or the repo |

Device frameworks (Health, Location, Bluetooth, Home, Camera, Push) sit behind protocols with scripted fakes so
L1 and L2 cover them; the manual device pass covers the real hardware.

## 3. Command map

Commands are mise tasks in `.mise.toml` wrapping `scripts/*`, found by `.harness/run-contract.sh`.

| Command | Runs | Budget |
| --- | --- | --- |
| `setup` | `mise install`, `scripts/bootstrap` (identity values, theme), `scripts/generate`, `pnpm --dir Edge install --frozen-lockfile` | Once |
| `format` / `format:check` | `xcrun swift-format format --in-place` / `lint --strict --recursive App Packages Extensions Tests` | < 10 s |
| `lint` | `swiftlint lint --strict`, `scripts/check-layering`, `plutil -lint`, `check-privacy` | < 30 s |
| `typecheck` | `pnpm --dir Edge typecheck` (Swift is type-checked by `build`) | < 30 s |
| `build` | `scripts/generate`, then `xcodebuild build-for-testing` on the pinned simulator | < 5 min |
| `test:unit` | Swift Testing unit suites + `pnpm --dir Edge test` | |
| `test:integration` | `.integration` suites against `wrangler dev` + Worker contract tests | |
| `test:deployment` | `scripts/tests/*.sh` | < 1 min |
| `test:e2e` | XCUITest journeys (part of the `Verify` test plan) | |
| `coverage` | `xcodebuild test -testPlan Verify -enableCodeCoverage YES`, then `xcrun xccov` → `build/coverage.json`, converted to Cobertura for the shared gate | |
| `verify:fast` | Toolchain check → `format:check` → `swiftlint` → `check-layering` → token drift → `typecheck` → `pnpm --dir Edge test`. No `xcodebuild` | **< 60 s** |
| `verify` | `scripts/verify`: toolchain → generate → token drift → format → lint → Edge typecheck + Vitest → layering → script and lint-rule tests → plist lint + `check-privacy` → `wrangler dev` with local D1 → `xcodebuild test` (`Verify` test plan, iPhone 17 Pro, coverage on) → coverage gate → `Package.resolved` sync → stop `wrangler` | **< 15 min** |
| `smoke:<env>` | `scripts/smoke-<env>.sh` | < 2 min |

`verify` takes longer than the playbook's 5-minute default because it builds the app and boots a simulator;
`verify:fast` is the loop the agent runs before every commit. Test plans: `Verify.xctestplan` for every PR;
`Full.xctestplan` (all journeys) before a TestFlight build.

## 4. Gates

| Gate | Where |
| --- | --- |
| 0 Agent self-check | `.claude/skills/verify/SKILL.md` (copied from `templates/claude/skills/verify/`); step 2 uses XcodeBuildMCP |
| 1 Pre-commit | lefthook: `swift format` on staged Swift, SwiftLint on staged files, `gitleaks protect --staged` |
| 2 Pre-push | `verify` |
| 3 Pull request | `pr-verify.yml` on the **self-hosted Mac mini runner** (`runs-on: [self-hosted, macOS, ARM64, ios]`) runs `scripts/verify`. GitHub-hosted Ubuntu runs `secret-scan`, `tests-changed`, `issue-link`, `ai-review` and `swift format lint`. Dependabot covers swift, npm and github-actions |
| 4 Deploy | Worker: Wrangler from GitHub Actions (development on merge; production manual). App: Xcode Cloud to TestFlight on `release/*` tags, with `ci_scripts/ci_post_clone.sh` installing mise tools and running `scripts/generate` |

A self-hosted runner executes workflow code on the owner's machine: attach it only to private repositories
the owner alone pushes to, never to a public repository or one that accepts fork PRs.

## 5. Coverage floors

| Target | Floor |
| --- | --- |
| Changed lines | ≥ 80% |
| Each local package (`AppShell`, `DesignSystem`, `Identity`) | ≥ 85% line coverage |
| App target | ≥ 60% line coverage |
| `Edge/` | ≥ 85% line coverage (Vitest V8) |
| Total | Ratchet against `.coverage-baseline`; never lower it |

The gate runs inside `scripts/verify` from `build/Verify.xcresult` (`xcrun xccov view --report --json`).

## 6. Invariant defaults

Every app inherits these entries, each with `id`, `rule`, `why`, `applies_to` and `enforced_by` (the
template's older `owner_test` key is `enforced_by` here):

| Id | Rule |
| --- | --- |
| IOS-AUTHZ-001 | User A cannot read or change user B's rows through any Worker route |
| IOS-AUTHZ-002 | Requests without a session are rejected on every `api` route (`requireSession`) |
| IOS-DATA-001 | Account deletion removes every row in `userOwnedTables` and revokes the Sign in with Apple token |
| IOS-SEC-001 | No secret, token or credential in the app bundle, xcconfig, `wrangler.toml`, `.dev.vars` or repo |
| IOS-SEC-002 | Session tokens live in the Keychain only (`afterFirstUnlockThisDeviceOnly`) |
| IOS-SEC-003 | `OfflineAccessPolicy` cannot be extended by moving the device clock |
| IOS-PRIV-001 | `PrivacyInfo.xcprivacy` declares every required-reason API used, collected data types and tracking = false |
| IOS-PRIV-002 | Every permission used has a specific usage string in Info.plist |
| IOS-PRIV-003 | Nothing user-related is logged `.public` through `AppLog` |
| IOS-UI-001 | Every theme role exists in every variant, and text contrast is ≥ 4.5:1 (UI and focus ≥ 3:1) |

## 7. Rubric additions

[`ios/review-rubric.md`](ios/review-rubric.md) holds the BLOCKER and SHOULD-FIX rules the
AI reviewer applies on top of the playbook. `ai-review.yml` appends it to the review prompt when the caller
passes `profile: ios`. `ios-app-template`'s `AGENTS.md` carries the same rules; the reviewer reads both.

## 8. Seed defects

[`ios/seeded-defect-test.md`](ios/seeded-defect-test.md) lists the seeds, the procedure and the
recorded results. It is the review layer's acceptance check (playbook Part 6 and Part 9, phase 6): the
reviewer MUST flag each seed as BLOCKER.

## 9. Agent tooling

1. **XcodeBuildMCP** (`.mcp.json`, pinned version): build, run on the simulator, tap, read logs, screenshot.
   Verify skill step 2 uses it.
2. **Apple's Xcode MCP** (`xcrun mcpbridge`, Xcode 26.3+): diagnostics, documentation search, SwiftUI
   preview rendering. Xcode asks "Allow agent to access Xcode?" for each new process.
3. **`simctl`** as the fallback: `boot`, `erase all`, `status_bar booted override --time 9:41`,
   `privacy booted grant`, `push booted <bundle-id> payload.apns`, `io booted screenshot`.
   `scripts/screenshot.sh` captures light, dark and XXXL to `build/screens`.

Every UI PR attaches before/after screenshots (light, dark, XXXL). Screenshots go to the model provider, so
never sign a real account into a simulator an agent drives. Treat unfamiliar Xcode 27 / iOS 26+ APIs as
suspect until they compile and pass a test.

## 10. Local setup

Moved here from playbook Part 10; the playbook keeps only platform-neutral steps.

1. macOS Tahoe 26.6 or later. Install Xcode 27.x from the App Store or developer.apple.com, open it once to
   install the iOS platform, then `sudo xcode-select -s /Applications/Xcode.app`. The version must match
   `.xcode-version`; `scripts/verify` fails fast otherwise.
2. `brew install mise lefthook gitleaks`, then in the repo `mise trust && mise install` (Node 24, pnpm,
   XcodeGen, SwiftLint). Leave any global Node alone; Wrangler installs per project.
3. Simulator: the pinned device is **iPhone 17 Pro** on the iOS version bundled with the pinned Xcode.
   Snapshots are recorded only there.
4. Accounts: Apple Developer Program ($99/yr) and a Cloudflare account. No Supabase, no Docker.
5. Self-hosted runner: register the Mac mini as a GitHub Actions runner with labels
   `self-hosted, macOS, ARM64, ios`, running as a non-admin user with Xcode selected and mise on `PATH`.
   Private repositories only (section 4).
6. Signing: automatic signing everywhere; Xcode Cloud uses cloud-managed signing. An App Store Connect API key
   is created only if uploads are scripted, and lives in the Keychain or a password manager.

## 11. Superseded guidance

These parts of `docs/ios-vibe-coding-playbook.md` in the template are superseded by the locked decisions and
MUST NOT be followed: Supabase (`supabase-swift`, `supabase start`, `supabase db reset`, Edge Functions), RLS
policies (replaced by `requireSession`, `c.var.userId` scoping and `userOwnedTables`), Tuist and
`Project.swift` (replaced by XcodeGen and `project.yml`), SwiftData caching (no local database), Docker, and
App Attest (deferred). The CATALOG key `owner_test` is `enforced_by`.
