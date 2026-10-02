# Testing Harness Playbook

A portable, technology-agnostic specification for an automated test harness that an AI coding agent
(Cursor, Claude Code, or similar) can **set up once and then keep current on every change**.

Version 1.0.0 (2026-10-02). The canonical copy lives at
<https://github.com/Equilux-Group-LLC/engineering-playbook/blob/main/playbook/testing-harness-playbook.md>. Every other copy
(your Mac, your Claude account skill, individual repositories) is a pointer or a synced copy of that file.
Propose changes there by pull request; don't fork the rules per project. Project-specific rules belong in
the project's own invariant catalog (Part 5) and AGENTS.md.

- **Audience 1: the product owner.** You direct the work but do not write code. Read Parts 1 and 2. Every
  rule has a plain-language reason.
- **Audience 2: the AI agent.** You implement and maintain the harness. Parts 3 to 9 are normative.
  "MUST", "SHOULD", and "MAY" have their usual meaning.
- **Target platform:** macOS laptop, Cursor as the editor/agent, GitHub for code, pull requests, and CI.
  Any language, framework, database, or host.

---

## Part 1: How to use this file

### For the product owner (3 steps)

1. In the project folder on your Mac, run the bootstrap script once (Part 11). It copies this playbook to
   `docs/testing-harness-playbook.md`, adds the Cursor and Claude rules, the PR template, git hooks and a
   CI workflow that calls the shared org checks.
2. In Cursor (or Claude Code), open the agent chat and paste the **Kickoff prompt** below. If you
   installed the Claude skill (Part 11), saying "set up the testing harness" is enough.
3. Review the pull requests it opens. Merge only when every check is green (Part 6).

After setup, you don't need to ask for tests. The rules files the agent creates (Part 8) make it write and
update tests as part of every change, and CI rejects changes that skip them.

### Kickoff prompt (paste into the agent)

```text
Read docs/testing-harness-playbook.md in full. Implement the harness it describes for this repository by
following Part 9 (Bootstrap procedure) one phase at a time. For each phase:
- open a separate branch and draft pull request,
- make the phase's acceptance checks pass locally with the `verify` command,
- stop and ask me only for the decisions listed in Part 9 "Questions to ask the owner".
Do not weaken or skip any existing test. Do not add real personal data to fixtures.
When all phases are merged, confirm that the maintenance rules in Part 8 are installed.
```

### Maintenance prompt (use any time the suite feels stale)

```text
Audit the test harness against docs/testing-harness-playbook.md. Report gaps as a checklist grouped by
Part (layers, invariants, gates, speed, flakiness, coverage). Then fix them in small pull requests,
starting with anything that lets untested code merge.
```

---

## Part 2: The model in plain language

Think of tests as a set of **nets at different heights**. Each net catches a different kind of mistake,
and cheaper nets sit closer to you.

| Net | Plain-language job | Runs | Typical speed |
| --- | --- | --- | --- |
| **Static checks** | Spell-check and grammar-check for code. Catches typos, wrong types, and style drift before anything runs. | Every save, every commit | Seconds |
| **Unit tests** | Checks one small piece of logic by itself, like "is this date a weekday?" | Every commit | Milliseconds each |
| **Integration tests** | Runs the real app engine and a real (temporary, throwaway) database together and sends it requests like a user would. | Every push and PR | Seconds |
| **Guardrail tests** (invariants) | Proves the rules that must *never* break: who can see what, what data is forbidden, which secrets must never leak. | Every push and PR | Seconds |
| **Deployment tests** | Rehearses the deploy scripts against fake servers so a broken deploy script is caught before a real deploy. | Every PR | Seconds |
| **End-to-end tests** (when applicable) | A robot clicks through the real UI in a browser for the few flows that matter most. | Every PR (small set) | Under 2 minutes |
| **Smoke tests** | Right after a deploy, pings the live site to confirm it is up and wired correctly. Read-only. | After each deploy | Under 1 minute |
| **Post-deploy verification and rollback** | For production: take a backup first, deploy, verify, and record what happened so it can be undone. | Production releases | Minutes |

Three more ideas hold it together:

- **One button.** Every project has one command, `verify`, that runs all the pre-merge nets. If `verify`
  is green on your laptop, CI should be green too.
- **Gates.** Code must pass nets at four checkpoints: on your laptop before commit, before push, on the
  pull request, and during deploy. Each later gate re-checks the earlier ones.
- **Independent review.** A second AI reviewer, which did not write the code, reviews every pull request
  against the project's written rules.

---

## Part 3: Principles (normative)

Each principle has a rule for the agent and a reason for the owner.

1. **Every behavior change ships with a test in the same pull request.**
   *Why:* tests written "later" are usually never written.
2. **Bug fixes start with a failing test.** The agent MUST write a test that reproduces the bug, see it
   fail, then fix the code.
   *Why:* this is proof the bug is actually fixed and will stay fixed.
3. **Test behavior, not implementation.** Assert on inputs and outputs a user or API client can observe,
   not on private internals.
   *Why:* tests that break every time code is tidied get deleted.
4. **Use real parts where it is cheap; fake only the outside world.** Integration tests MUST use the
   real request handler and a real database engine (in-memory or a disposable container), with the real
   schema migrations applied. Only third-party services (email, payments, identity providers, cloud APIs)
   are faked.
   *Why:* most real bugs live in the seams between parts. Mocking the database hides them.
5. **Never, ever rules get guardrail tests on every path in and every path out.** (Part 5.)
   *Why:* security and privacy failures are the ones you can't undo.
6. **Deterministic or deleted.** Tests MUST NOT depend on the wall clock, random values, test order,
   network access, or shared state. Inject a clock and a seeded random source.
   *Why:* a flaky test teaches everyone to ignore red.
7. **Fast by default.** The pre-merge suite SHOULD finish in under 5 minutes in CI, and unit tests
   in under 30 seconds locally.
   *Why:* slow suites get skipped.
8. **Synthetic data only.** Fixtures MUST use obviously fake values (`Example Org`, `user-1`,
   `test@example.com`). Never copy production data, real names, or real contact details into tests.
   *Why:* test files end up in many places (logs, CI, AI context). They must be safe to leak.
9. **Never weaken a test to get green.** The agent MUST NOT delete, skip, loosen, or mark a test as
   expected-to-fail to make a change pass. If a test is wrong, fix it in its own commit and explain why
   in the pull request.
10. **Discovery, not lists.** Test runners MUST find tests by file-name pattern. Don't maintain a
    hand-written list of test files.
    *Why:* a new test file that's missing from the list silently never runs.

---

## Part 4: Test layers (normative)

Each project MUST implement layers L0 to L4 and L6. L5 applies only when the project has a browser or mobile
UI with user flows. L7 applies only when there is a production environment.

### L0: Static checks

| | |
| --- | --- |
| **Includes** | Formatter check, linter, type checker (or the strictest type-annotation mode the language supports), syntax/compile check, secret scanner, dependency vulnerability audit. |
| **Real vs fake** | Nothing runs; it's all analysis. |
| **Rules** | Zero warnings policy on CI (warnings are errors). New `ignore` / `disable` comments MUST include a reason. |
| **Location** | Tool config files at repository root. |

### L1: Unit tests

| | |
| --- | --- |
| **Covers** | Pure business logic: validation, calculations, date and recurrence rules, permission decisions, formatting, parsing. |
| **Real vs fake** | No database, no network, no filesystem. Time and randomness injected. |
| **Rules** | One behavior per test; test name states the behavior ("rejects end time before start time"). Table-driven tests for rule matrices. Each test < 50 ms. |
| **Location** | `test/unit/**` mirroring `src/**`, or co-located `*.test.*` files. Pick one and keep to it. |

### L2: Integration tests

| | |
| --- | --- |
| **Covers** | Each API route or entry point end to end inside the process: request → auth → validation → business logic → database → response. Schema migrations. Background jobs and queue consumers. |
| **Real vs fake** | Real app handler invoked in-process. Real database engine (in-memory or throwaway container) created fresh per test or per file, with **every migration applied in order**. External services replaced by fakes that record what they were sent. |
| **Rules** | For every route: one happy path, one test per role that must be denied, one invalid-input test, one unknown-field test. For every migration: apply all previous migrations, seed realistic synthetic rows, apply the new migration, assert data was preserved or transformed as intended. |
| **Location** | `test/integration/**`. Shared builders in `test/support/**` (e.g., `createTestDatabase()`, `signInAs(role)`, `makeEvent(overrides)`). |

### L3: Guardrail (invariant) tests

| | |
| --- | --- |
| **Covers** | The project's non-negotiable rules: authorization matrix, data-boundary rules (fields that must never be accepted or emitted), secret handling, tenant isolation. |
| **Real vs fake** | Same as L2. |
| **Rules** | Defined by the invariant catalog (Part 5). Every entry point that accepts data and every output that emits data MUST be covered. Guardrail tests live in their own files so they are easy to find and hard to delete by accident. |
| **Location** | `test/invariants/**`. |

### L4: Deployment and tooling tests

| | |
| --- | --- |
| **Covers** | Deploy, migrate, backup, and smoke scripts; CI helper scripts; configuration validators. |
| **Real vs fake** | Scripts executed for real against a temporary directory and a fake HTTP server or stubbed CLI. No real cloud credentials. |
| **Rules** | Each script: success path, each failure path exits non-zero with a clear message, and it never prints secrets or credential-bearing URLs. |
| **Location** | `test/deployment/**`. |

### L5: End-to-end tests (when applicable)

| | |
| --- | --- |
| **Covers** | 3 to 10 critical user journeys only (sign in, create the core record, the one screen that makes money or prevents harm). Mobile viewport if the product is mobile-first. |
| **Real vs fake** | Real browser (headless) against the app running locally with a seeded synthetic database. External services faked. |
| **Rules** | Select elements by accessible role or label, not CSS classes. No fixed sleeps; wait on visible state. Capture screenshot and trace on failure as CI artifacts. |
| **Location** | `test/e2e/**`. |

### L6: Smoke tests (per deployed environment)

| | |
| --- | --- |
| **Covers** | After every deploy: health endpoint returns OK, the build/version matches the commit just deployed, database schema version matches the latest migration, static assets load, protected routes still refuse anonymous access. |
| **Real vs fake** | Real deployed environment. **Read-only**: never create, change, or delete data. |
| **Rules** | Retries with a bounded timeout (deploys take time to propagate). Output never includes tokens or full credential URLs. |
| **Location** | `scripts/smoke-<environment>.*`, tested by L4. |

### L7: Production release checks

| | |
| --- | --- |
| **Covers** | Before: source is the protected release branch at an expected commit; required config and secrets exist (names only, never values). During: backup or restore point, deploy, migrate. After: smoke plus access-control checks; write a deployment record (commit, time, migrations applied, backup id). |
| **Rules** | Production deploys are manual (a person clicks "run"). Any failed step stops the pipeline and prints the rollback instructions. |

### Change-type → required tests matrix

The agent MUST use this table to decide which tests a change needs.

| Change | Required tests |
| --- | --- |
| New or changed business rule | L1 table-driven tests covering each branch and boundary |
| New or changed API route / handler | L2: happy path, invalid input, unknown field rejected, each denied role; L3 entries if it reads or writes guarded data |
| Database schema migration | L2 migration test (previous schema + seeded data → new schema); update test database builder |
| New data field (input or output) | L3: confirm it's allowed by the data-boundary catalog; add it to the catalog's allow-list, or reject it |
| Permission or role change | L3 authorization matrix rows for every affected role × action |
| Bug fix | Regression test at the lowest layer that reproduces it, written first |
| UI logic (formatting, state, view helpers) | L1 |
| Critical UI journey added or changed | L5 |
| Deploy, CI, or ops script | L4 |
| New external integration (email, SMS, calendar feed, analytics, AI) | L2 with a recording fake; L3 egress test proving only allowed fields are sent |
| Dependency upgrade | Full `verify`; no new tests unless behavior changed |
| Docs or comments only | None |

---

## Part 5: Invariant catalog (template)

Every project MUST keep a machine-readable or clearly structured catalog of its "never" rules at
`test/invariants/CATALOG.yaml`. Each entry has an id, a plain-language rule, the
paths it applies to, and the test files that enforce it. The agent MUST add or update an entry whenever
a change adds a new data path.

```yaml
- id: AUTHZ-001
  rule: A user can modify only records owned by their own organization.
  applies_to: [all write routes]
  enforced_by: [test/invariants/authorization-matrix.test.*]
- id: DATA-001
  rule: Write APIs reject any field not on the allow-list.
  applies_to: [all routes that accept a body]
  enforced_by: [test/invariants/unknown-fields.test.*]
- id: DATA-002
  rule: Prohibited sensitive fields never appear in any output.
  applies_to: [API responses, exports, feeds, emails, SMS, logs, queue messages, backups]
  enforced_by: [test/invariants/egress-scan.test.*]
- id: SEC-001
  rule: Tokens, passwords, and credential URLs never appear in logs, errors, or responses.
  applies_to: [all routes, all scripts]
  enforced_by: [test/invariants/secret-leak.test.*, CI secret scan]
- id: SEC-002
  rule: Revoked credentials stop working immediately.
  applies_to: [sessions, invite links, feed tokens, API keys]
  enforced_by: [test/invariants/revocation.test.*]
```

Standard guardrail test techniques the agent SHOULD use:

- **Authorization matrix.** A table of `role × action × resource-owner → allowed/denied`, run as one
  parameterized test. Adding a role or action means adding rows, and a missing row fails the test.
- **Unknown-field probe.** For every write route, send a valid body plus one extra field. Expect
  rejection and no database change.
- **Canary egress scan.** Seed records containing unique canary strings in every field that must not leak.
  Call every output path (each API route as each role, each export, feed, notification fake, log capture,
  queue fake) and assert no canary appears in any output.
- **Log capture.** Route logs to an in-memory sink during tests and assert on its contents.

---

## Part 6: Gates (normative)

### Gate 1: Pre-commit (laptop, seconds)

Formatter (auto-fix staged files), linter on staged files, secret scan on staged changes.

### Gate 2: Pre-push (laptop, under 2 minutes)

`verify` (all of L0 to L4, plus L5 if it's fast enough; otherwise L5 runs in CI only).

### Gate 3: Pull request (GitHub Actions)

Implemented by the shared reusable workflows in Part 11; a repository adopts them with two short caller
files. Required checks, all of which MUST pass:

| Check | What it does |
| --- | --- |
| `secrets` | Secret scan over the commits the PR adds |
| `verify` | The same `verify` command as the laptop, with `CI=true` |
| `coverage` | Line coverage of changed lines ≥ 80%; total coverage must not decrease (ratchet) |
| `tests-changed` | Fails if source files changed but no test files changed, unless the PR has the `no-test-needed` label **and** a one-line reason in the PR body |
| `e2e` | L5 suite (when applicable) |
| `review` | Independent AI review against the project rules file; verdict must be READY or every finding dismissed with a reason |

### Gate 4: Deploy (GitHub Actions)

- **Development / staging:** on merge to the integration branch: `verify` → deploy → migrate → L6 smoke.
  The run MUST NOT be cancelled mid-migration (serialize runs, no cancel-in-progress).
- **Production:** manual trigger only, from the release branch: L7 pre-checks → backup → deploy →
  migrate → L6 smoke + access checks → deployment record.

### Making gates actually block merges

| GitHub plan / repo visibility | Enforcement |
| --- | --- |
| Public repo (any plan), or private repo on Pro / Team / Enterprise | Add a **branch ruleset** on `main` (and `develop` if used): require a pull request, require the Gate 3 checks by name, require branches to be up to date, block force-pushes and deletions. |
| Private repo on GitHub Free (rulesets and required checks unavailable) | Checks still run but can't lock the merge button. Compensate with: (a) Gate 1 and Gate 2 hooks installed by a setup command so they can't be forgotten; (b) a rule in the agent rules file: *"Never merge, and never tell the owner a PR is ready, while any check is red, missing, or pending"*; (c) the PR template checklist; (d) the production deploy workflow re-runs `verify` and refuses to deploy a commit whose PR checks weren't green. |

---

## Part 7: The command contract (normative)

Every project MUST expose these commands through its native task runner (package scripts, `Makefile`,
`justfile`, `Taskfile`, `mise` tasks, etc.). Names are fixed so humans, hooks, CI, and agents all speak the
same language. `.harness/run-contract.sh <command>` (installed by the bootstrap script) finds and runs the
command through whichever runner the repository uses; the shared CI and git hooks call it.

| Command | Runs | Must finish |
| --- | --- | --- |
| `setup` | Installs toolchain and dependencies, installs git hooks, creates local env file from example | Once |
| `format` / `format:check` | Formatter (write / check only) | < 10 s |
| `lint` | Linter, zero warnings | < 30 s |
| `typecheck` | Type checker | < 60 s |
| `test:unit` | L1 | < 30 s |
| `test:integration` | L2 + L3 | < 3 min |
| `test:deployment` | L4 | < 1 min |
| `test:e2e` | L5 | < 3 min |
| `test` | L1 + L2 + L3 + L4 | |
| `coverage` | `test` with coverage, writes `coverage/lcov.info` (LCOV or Cobertura format) | |
| `verify` | `format:check` → `lint` → `typecheck` → `build` → `coverage` (fail-fast) | < 5 min |
| `smoke:<env>` | L6 against `<env>` | < 2 min |

Illustrative tool choices (pick the idiomatic ones for the stack; these are examples, not requirements):

| Stack | Format / Lint / Types | Unit + Integration runner | Real DB for tests | E2E |
| --- | --- | --- | --- | --- |
| JavaScript / TypeScript | Prettier or Biome / ESLint or Biome / `tsc --noEmit` or JSDoc + `checkJs` | Node test runner, Vitest | SQLite in-memory, Testcontainers Postgres, platform local emulators | Playwright |
| Python | Ruff / Ruff / mypy or pyright | pytest | SQLite in-memory, Testcontainers | Playwright |
| Go | gofmt / golangci-lint / compiler | `go test` | Testcontainers | Playwright |
| Ruby | RuboCop / RuboCop / Sorbet (optional) | RSpec or Minitest | Transactional fixtures, Testcontainers | Capybara or Playwright |
| Swift / Kotlin (mobile) | swift-format, ktlint / SwiftLint, detekt / compiler | XCTest, JUnit | In-memory store | XCUITest, Espresso |

Language-neutral tools: **lefthook** (git hooks), **gitleaks** (secret scan), **diff-cover** or a
coverage service (changed-line coverage), **Testcontainers** (throwaway databases), **mise** or **asdf**
(pinned tool versions).

---

## Part 8: Rules files that keep the harness maintained

The bootstrap MUST create these so that every future agent session follows the harness without being asked.

### `.cursor/rules/testing.mdc`

```markdown
---
description: Testing rules for every code change
globs:
alwaysApply: true
---
- Follow docs/testing-harness-playbook.md. Use its Part 4 change-type matrix to decide which tests to add.
- Every behavior change includes tests in the same commit. Bug fixes start with a failing test.
- Integration tests use the real handler and a real throwaway database with all migrations applied.
  Fake only third-party services.
- If a change adds a new input field, output, integration, or role, update test/invariants/CATALOG and its tests.
- Never delete, skip, weaken, or mark-as-failing an existing test to get green. If a test is wrong, say why.
- Fixtures use obviously fake data only.
- Run `verify` before saying work is done. Report the actual result; never claim green without running it.
- Never merge, and never say a PR is ready, while any check is red, pending, or missing.
```

### `AGENTS.md` (or `CLAUDE.md`), testing section

Add a short section pointing to the playbook and repeating the three hardest rules: tests with every
change, never weaken tests, run `verify` before completion. Keep the details in the playbook.

### `.github/pull_request_template.md`

Include a checklist: risk areas touched (auth, sensitive data, schema, deploy config); tests added per
the matrix; invariant catalog updated if needed; `verify` green; AI review READY or findings dismissed
with reasons.

### Ongoing maintenance duties (agent)

| When | Duty |
| --- | --- |
| Every change | Apply the Part 4 matrix. Update test builders when the schema changes. |
| Every failing CI run | Root-cause it. "Flaky" isn't a root cause: make the test deterministic in the same PR or open a tracked issue with the failing seed/log. |
| Monthly (or on the maintenance prompt) | Remove dead tests for deleted code; raise the coverage ratchet if coverage rose; list the 10 slowest tests and speed them up; confirm every invariant catalog entry still has a passing test; update tool versions. |

---

## Part 9: Bootstrap procedure (for the agent)

Do one phase per pull request. Each phase ends with its acceptance check passing via `verify`.

| Phase | Work | Acceptance check |
| --- | --- | --- |
| 0. Inventory | Detect languages, frameworks, database, hosting, existing tests and CI. Write `docs/testing-inventory.md` listing what exists, what is missing per layer, and the proposed tools. | Owner approves the inventory PR |
| 1. Command contract | Add all Part 7 commands (stubs allowed for layers not yet built, which print "not configured" and exit 0 only until their phase). Pin tool versions. Add `setup`. | `setup` then `verify` succeed on a clean clone |
| 2. Static checks | Formatter, linter, type checker, secret scan. Fix or explicitly baseline existing violations (baseline file with a count that may only go down). | `verify` fails if a lint error is introduced |
| 3. Unit tests | Test discovery by pattern. Add a clock/random injection seam. Cover the core business rules. | Coverage report produced |
| 4. Integration tests | Test database builder that applies all migrations; request helper with `signInAs(role)`; fakes for each external service. One test per route per the matrix. Migration tests. | Every route has at least one integration test |
| 5. Invariants | Write `test/invariants/CATALOG` with the owner. Build the authorization matrix, unknown-field probe, canary egress scan, secret-leak and revocation tests. | Every catalog entry names a passing test |
| 6. CI gates | Workflows for Gate 3 (all checks in Part 6), including `tests-changed` and changed-line coverage. Configure the ruleset, or the Free-private fallback. | A deliberately test-less PR is rejected |
| 7. Local hooks | lefthook (or equivalent) for Gates 1 and 2, installed by `setup`. | Committing a file with a planted fake secret is blocked |
| 8. Deploy checks | L4 tests for deploy scripts; L6 smoke per environment; L7 production pipeline if production exists. | Smoke passes after a development deploy |
| 9. End-to-end (if UI) | Headless browser suite for the owner-approved critical journeys; mobile viewport if mobile-first. | Suite passes in CI in < 3 min |
| 10. Rules files | Part 8 files. Link the playbook from the README. | A new agent session, asked to "add a field", adds tests without being told |

### Questions to ask the owner (only these)

1. Which user journeys are critical enough for end-to-end tests? (List 3 to 10.)
2. What are the "never" rules for this product: roles and what each may see or change, and data that must
   never be stored or shared? (Seeds the invariant catalog.)
3. Which environments exist (local, development, staging, production), and which branch deploys where?
4. Is the repository public or private, and which GitHub plan is it on? (Decides enforcement in Part 6.)
5. Any business rule where the correct behavior is unclear. Never guess; ask.

---

## Part 10: macOS local setup reference

```text
1. Install Homebrew (https://brew.sh) and then: brew install git mise lefthook gitleaks
2. Install the playbook for Claude Code and Cursor on this Mac (once; see Part 11):
     bash -c "$(curl -fsSL https://raw.githubusercontent.com/Equilux-Group-LLC/engineering-playbook/main/scripts/install-local.sh)"
3. Install Cursor and sign in to GitHub (Cursor → Settings → GitHub, or `gh auth login` if gh is installed).
4. Clone the project, open it in Cursor, then in the terminal run:  <task-runner> setup
5. Before pushing: <task-runner> verify   (the pre-push hook also runs it)
6. If a container database is used (Testcontainers), install Docker Desktop or OrbStack.
```

Apple Silicon note: prefer tools with native arm64 builds; pin versions in `.tool-versions` / `mise.toml`
so the laptop and CI use the same versions.

---

## Part 11: Where the playbook lives and how each place uses it

One canonical source, everything else points to it or syncs from it.

| Place | What is there | How it stays current |
| --- | --- | --- |
| **`Equilux-Group-LLC/engineering-playbook`** (public, canonical) | This playbook; reusable CI workflows; caller and starter templates; the Claude skill; the install, bootstrap and sync scripts; and the source of the files in both `.github` repositories (`dotgithub/`) | Changes land by pull request, from any machine or Claude session; releases are tagged `v1.x.y` and the moving tag `v1` points at the latest compatible release |
| **`Equilux-Group-LLC/.github`** (public) | Only what GitHub requires to live there: the default PR template for every org repository, the "New workflow" templates, and a README pointing here | `bash scripts/sync-dotgithub.sh` from a Mac clone. Claude cloud sessions can't edit repositories whose names start with a dot, so this one step is local |
| **Other `Equilux-Group-LLC` repositories** | `docs/testing-harness-playbook.md` (synced copy), `.cursor/rules/testing.mdc`, an AGENTS.md testing block, CI callers pinned to `@v1`, `lefthook.yml`, `test/invariants/CATALOG.yaml`. The PR template is inherited from `Equilux-Group-LLC/.github` | Re-run `bootstrap-repo.sh`; managed files refresh, project-owned starters are left alone. CI picks up fixes to `@v1` automatically |
| **`caobhin/.github`** (public) | Default PR template for personal repositories and a README pointing here. Personal repositories call the same `Equilux-Group-LLC/engineering-playbook` reusable workflows | Same `sync-dotgithub.sh` run |
| **This Mac** | A clone at `~/Developer/engineering-playbook`; `~/.claude/skills/testing-harness` symlinked into it; a marked block in `~/.claude/CLAUDE.md`; a Cursor user rule | `git -C ~/Developer/engineering-playbook pull` (or re-run `install-local.sh`) |
| **Claude account (claude.ai, Claude Code on the web)** | The `testing-harness` skill uploaded as a zip | Re-upload `dist/testing-harness-skill.zip` (built by `scripts/build-skill-zip.sh`) after a playbook release |

### Shared reusable workflows

| Workflow | Gate 3 check | Key inputs |
| --- | --- | --- |
| `secret-scan.yml` | `secrets` | `gitleaks-version` |
| `verify.yml` | `verify`, `coverage` | `verify-command` (default `verify`), `setup-command`, `coverage-report`, `changed-line-coverage` (default 80), `toolkit-ref` |
| `tests-changed.yml` | `tests-changed` | `source-pattern`, `test-pattern`, `opt-out-label` (default `no-test-needed`) |
| `ai-review.yml` | `review` | `rules-file` (default `AGENTS.md`); secret `CLAUDE_CODE_OAUTH_TOKEN` |

`verify.yml` installs the toolchain from `mise.toml` / `.tool-versions` when present (any language), and
otherwise detects Node, Python and Go. Coverage gates read LCOV or Cobertura reports. The total-coverage
ratchet compares against a committed `.coverage-baseline` file (raise it when coverage rises; never lower it).

### Adopting in a repository

1. `bash ~/Developer/engineering-playbook/scripts/bootstrap-repo.sh /path/to/project`
2. Commit the result on a branch and open a pull request.
3. Add the repository secret `CLAUDE_CODE_OAUTH_TOKEN` and install the Claude GitHub App on the repository.
4. Create the label `no-test-needed`.
5. Where the plan allows, add a branch ruleset requiring the checks `secrets`, `verify`, `tests-changed` and
   `review`.
6. Ask the agent to run Part 9.

### Changing the playbook

Edit `playbook/testing-harness-playbook.md` in `Equilux-Group-LLC/engineering-playbook` by pull request (also refresh the
skill's copy in `skills/testing-harness/references/`; the self-test fails if they differ). If the PR template or
workflow templates changed, run `bash scripts/sync-dotgithub.sh` on a Mac after merging. Release by running
the **Release** workflow with a version number: backward-compatible changes bump the minor version and move
the `v1` tag; a change that breaks callers (renamed inputs, new required checks) is a new major version (`v2`)
that repositories adopt deliberately.

---

## Glossary

- **Assertion:** the line in a test that says "this must be true".
- **CI (continuous integration):** GitHub's servers running the checks on every pull request.
- **Coverage:** the percentage of code lines that ran during tests. Useful as a floor, not a goal.
- **Fake / mock:** a stand-in for an outside service that records what was sent to it.
- **Fixture / builder:** code that creates standard fake test data.
- **Flaky test:** a test that sometimes passes and sometimes fails with no code change.
- **Invariant:** a rule that must always hold, no matter what change is made.
- **Migration:** a script that changes the database structure.
- **Ratchet:** a threshold that can only move in one direction (coverage may go up, never down).
- **Regression test:** a test that proves a fixed bug stays fixed.
- **Ruleset / branch protection:** GitHub settings that block merging until required checks pass.
- **Smoke test:** a quick check that a freshly deployed site is alive and wired correctly.

---
