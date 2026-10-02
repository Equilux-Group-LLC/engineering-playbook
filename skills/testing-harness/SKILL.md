---
name: testing-harness
description: Equilux testing harness playbook for any software project. Use whenever code is written or changed and needs tests, when setting up, auditing or repairing a test suite, CI checks, git hooks or coverage gates, when fixing a bug (regression test first), or when the user says "set up the testing harness", "add tests", "is this tested", or "why is CI red". Technology-agnostic; covers unit, integration, guardrail (invariant), deployment, end-to-end and smoke tests.
---

# Testing harness

The full specification is `references/testing-harness-playbook.md`. Read the parts you need before acting:
Part 4 (layers and the change-type matrix) for any code change, Part 5 (invariant catalog) when data paths,
roles or credentials change, Part 9 (bootstrap) when setting a project up, Part 8 for maintenance duties.

If the project has its own `AGENTS.md`, `CLAUDE.md` or `docs/testing-harness-playbook.md`, those take
precedence over this skill where they differ.

## On every code change

1. Classify the change with the Part 4 matrix and write the required tests in the same change:
   - business rule: unit tests for every branch and boundary
   - API route or handler: integration tests for success, bad input, unknown field rejected, each denied role
   - schema migration: previous schema + synthetic data, migrate, assert data preserved or transformed
   - new input/output field, integration, role or credential: update `test/invariants/CATALOG.yaml` and its tests
   - bug fix: a regression test that reproduces the bug, run it and see it fail, then fix
   - critical user journey: end-to-end test; deploy or CI script: script test against fakes
2. Integration tests use the real handler and a real throwaway database with every migration applied.
   Fake only third-party services.
3. Keep tests deterministic: inject the clock and randomness; no network; no order dependence.
4. Use obviously fake data (`Example Org`, `user-1`, `test@example.com`). Never real names or production data.
5. Never delete, skip, loosen or mark-as-failing an existing test to get green. If a test is wrong, fix it in
   its own commit and say why.
6. Run the project's `verify` command (Part 7) and report the actual result. Don't claim success without it.
   If `verify` doesn't exist yet, say so and offer to set up the harness.

## Setting up a project

Follow Part 9 one phase per pull request, starting with the Phase 0 inventory. Ask the owner only the
Part 9 questions. Starter files come from the Equilux-Group-LLC/engineering-playbook repository: on a machine with the
toolkit installed, run `bash ~/Developer/engineering-playbook/scripts/bootstrap-repo.sh <repo>`; otherwise create the
files described in Parts 6 to 8 directly. Shared CI lives in reusable workflows:

```yaml
uses: Equilux-Group-LLC/engineering-playbook/.github/workflows/verify.yml@v1        # also secret-scan, tests-changed, ai-review
```

## Merging

Never merge, and never tell the owner a PR is ready, while any check is red, pending or missing. On plans
where GitHub can't block the merge button, this rule is the gate.
