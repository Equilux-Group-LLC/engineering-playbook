# Profile: web

Status: draft. Seeded from the playbook's defaults (Part 4 locations, the Part 7 JavaScript / TypeScript
row, the Part 6 thresholds). There is no web platform template yet; the first one adopts this profile and
fixes it where reality differs.

## 1. Scope

Browser front ends and HTTP back ends in JavaScript or TypeScript, with a SQL database. Choices marked "or"
are settled once by the platform template and recorded in its ADRs; an app repo does not re-decide them.

## 2. Layer map

| Layer | Tools | Location | Rules beyond Part 4 |
| --- | --- | --- | --- |
| L0 Static | Prettier or Biome (format); ESLint or Biome (lint); `tsc --noEmit` (or JSDoc + `checkJs`); gitleaks; `npm audit` / `pnpm audit` at `high` | Config at repo root | `// eslint-disable` and `@ts-expect-error` need a reason on the same line |
| L1 Unit | Vitest or the Node test runner | Co-located `*.test.ts` or `test/unit/**` (pick one) | Inject the clock (`vi.useFakeTimers` or a clock parameter), never `Date.now()` in logic |
| L2 Integration | Same runner; the real app handler called in-process (`app.request()`, `supertest` or `fetch` against an ephemeral port) | `test/integration/**`, builders in `test/support/**` | Real database: SQLite in-memory, Testcontainers Postgres or the platform's local emulator, every migration applied; fake only third-party HTTP |
| L3 Invariants | Same runner | `test/invariants/**` | Authorization matrix, unknown-field probe, canary egress scan, secret-leak and revocation tests (Part 5) |
| L4 Deployment | Same runner, or `bats` for shell | `test/deployment/**` | Scripts run against a temp dir and a fake HTTP server |
| L5 E2E | Playwright (Chromium headless; mobile viewport if mobile-first) | `test/e2e/**` | `getByRole` / `getByLabel` only; trace and screenshot on failure |
| L6 Smoke | Playwright request context or `curl` script | `scripts/smoke-<env>.*` | Read-only; bounded retries |
| L7 Release | The host's deploy CLI behind a manual GitHub Actions workflow | `.github/workflows/deploy-production.yml` | Backup or restore point before migrate |

## 3. Command map

Commands are package scripts (`package.json`), found by `.harness/run-contract.sh`.

| Command | Runs | Budget |
| --- | --- | --- |
| `setup` | Install pinned Node (mise), `pnpm install --frozen-lockfile`, `lefthook install`, copy `.env.example` | Once |
| `format` / `format:check` | Prettier or Biome | < 10 s |
| `lint` | ESLint or Biome, `--max-warnings 0` | < 30 s |
| `typecheck` | `tsc --noEmit` | < 60 s |
| `build` | The framework's production build | |
| `test:unit` | L1 | < 30 s |
| `test:integration` | L2 + L3 | < 3 min |
| `test:deployment` | L4 | < 1 min |
| `test:e2e` | L5 | < 3 min |
| `test` | L1 to L4 | |
| `coverage` | `test` with V8 coverage, writes `coverage/lcov.info` | |
| `verify:fast` | `format:check` → `lint` → `typecheck` → `test:unit` | **< 60 s** |
| `verify` | `format:check` → `lint` → `typecheck` → `build` → `coverage` | **< 5 min** (playbook default) |
| `smoke:<env>` | L6 | < 2 min |

## 4. Gates

| Gate | Where |
| --- | --- |
| 0 Agent self-check | `.claude/skills/verify/SKILL.md` (copied from `templates/claude/skills/verify/`), before every commit |
| 1 Pre-commit | lefthook: formatter on staged files, lint on staged files, `gitleaks protect --staged` |
| 2 Pre-push | lefthook: `verify` |
| 3 Pull request | GitHub-hosted Ubuntu: the shared `secret-scan`, `verify`, `tests-changed`, `issue-link` and `ai-review` workflows; `test:e2e` as its own job |
| 4 Deploy | GitHub Actions: development on merge; production manual (Part 6) |

## 5. Coverage floors

- Changed lines: ≥ 80% (`verify.yml` input `changed-line-coverage`).
- Total: ratchet against `.coverage-baseline`; never lower it.
- No per-target floors by default.
- Report: LCOV at `coverage/lcov.info`.

## 6. Invariant defaults

The five entries in `templates/invariants/CATALOG.yaml` (AUTHZ-001, DATA-001, DATA-002, SEC-001, SEC-002),
plus:

```yaml
- id: WEB-001
  rule: Every route except the public allow-list rejects anonymous requests.
  why: A route added without an auth check is the most common way data leaks.
  applies_to: [all routes]
  enforced_by: [test/invariants/anonymous-denied.test.*]
- id: WEB-002
  rule: Responses set the security headers the template defines (CSP, HSTS, X-Content-Type-Options).
  why: Headers are dropped silently when middleware is reordered.
  applies_to: [all HTML and API responses]
  enforced_by: [test/invariants/security-headers.test.*]
```

## 7. Rubric additions

**BLOCKER**

- A route or server action without an authorization check, or one that reads or writes another tenant's rows.
- SQL built by string concatenation or template literals with user input.
- User input rendered as HTML (`dangerouslySetInnerHTML`, `v-html`, `innerHTML`) without sanitizing.
- A secret in client-bundled code or a `NEXT_PUBLIC_` / `VITE_` variable.
- `console.log` of a user identifier, token or request body.
- A new `test.skip`, `it.only`, `describe.skip` or `.todo` on an existing test.

**SHOULD-FIX**

- Icon-only button without an accessible name; selectors in E2E tests by CSS class.
- `any` without a reason; floating promises.
- Hard-coded colors or fonts where the design system has tokens.

## 8. Seed defects

`scripts/seed-defects.sh` in the platform template plants these on a throwaway branch; Claude Review MUST
flag each as BLOCKER:

1. A route handler with no auth check.
2. A query built with a template literal from `req.query`.
3. A hard-coded API key in a client component.
4. `console.log(user.email)`.
5. `dangerouslySetInnerHTML` with request data.
6. An existing test changed to `test.skip`.
7. A write route that accepts an unknown body field.
8. A `fetch` to a third-party host in a unit test.

## 9. Agent tooling

- Run the app with the repository's `/run` recipe (a project skill that starts the dev server and seeds the
  synthetic database), then exercise the changed path in a headless browser.
- Playwright traces and screenshots stay local unless attached to a PR. Never sign a real account into a
  browser an agent drives.

## 10. Local setup

Playbook Part 10, plus: Node pinned in `mise.toml`, pnpm via Corepack or mise, Docker Desktop or OrbStack only
if Testcontainers is used, `pnpm exec playwright install chromium` in `setup`.

## 11. Superseded guidance

None yet.
