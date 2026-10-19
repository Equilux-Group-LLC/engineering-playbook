# Platform profiles

The playbook (`playbook/testing-harness-playbook.md`) says **what** every repository must test and gate. A
profile says **how** for one platform: which tools implement each layer and command, what the AI reviewer
looks for beyond the playbook, and which numbers (time budgets, coverage floors) apply.

```text
Tier 1  playbook + profiles + neutral machinery   Equilux-Group-LLC/engineering-playbook (this repo)
Tier 2  platform template                          one repo per profile (web, iOS), implements its profile
Tier 3  app repos                                  created from a template; add product rules only
```

A platform template implements exactly one profile, and an app repo names its profile in `.equilux.yml`
(playbook Part 11). Profiles never relax a playbook rule (MUST stays MUST). They choose tools, set the numbers
the playbook delegates to them, and add rules.

| Profile | Platform template | Status |
| --- | --- | --- |
| [`web.md`](web.md) | Not yet created | Draft, seeded from the playbook's defaults. Review rubric scored 6/6 on its seeded-defect test (2026-09-22). Cannot become Active until a web template exists |
| [`ios.md`](ios.md) | `Equilux-Group-LLC/ios-app-template` | Draft. Checked against the template at `59b2a9d` (2026-10-18); template work and the seeded-defect test outstanding ([ADR 0001](../docs/decisions/0001-profile-status-and-ios-initial-state.md)) |

## What a profile MUST define

Every profile has these sections, in this order, so profiles can be compared side by side.

| # | Section | Contents |
| --- | --- | --- |
| 1 | **Scope** | The platform, the platform template that implements it, and the stack decisions it assumes (with links to the template's ADRs where they exist). |
| 2 | **Layer map** | One row per Part 4 layer, L0 to L7, plus any platform sub-layer (for example snapshot tests): tool, location, and rules beyond Part 4. A layer that does not apply says why. |
| 3 | **Command map** | One row per Part 7 command, including `verify:fast` and `verify`: what it runs and its time budget. It MUST give `verify`'s budget (Part 7 default: 5 minutes) and list exactly which stages `verify:fast` runs (budget: under 60 seconds). Say how `.harness/run-contract.sh` finds the commands (mise tasks, package scripts, Makefile...). |
| 4 | **Gates** | Where Gates 0 to 4 (Part 6) run on this platform: hooks, CI runners, deploy pipeline, and anything that cannot run on GitHub-hosted runners. |
| 5 | **Coverage floors** | Changed-line floor, total-coverage ratchet, and any per-target floors (Part 6). The coverage report format and where it is written. |
| 6 | **Invariant defaults** | Starter `CATALOG.yaml` entries (Part 5) every app on this platform inherits, with a `why` for each. |
| 7 | **Rubric additions** | BLOCKER and SHOULD-FIX rules the AI reviewer applies on top of the playbook, kept in `<platform>/review-rubric.md` and linked from here. `ai-review.yml` appends that file to the review prompt when the caller passes `profile: <platform>`; the platform template also copies the rules into its `AGENTS.md`. |
| 8 | **Seed defects** | `<platform>/seeded-defect-test.md`: known violations planted on a throwaway branch, the procedure, and the recorded results (`<platform>/results/`). The reviewer MUST flag each one as BLOCKER. This is the review layer's acceptance check and its regression test; re-run it when the rubric, the review prompt or the review model changes. |
| 9 | **Agent tooling** | How an agent runs the app and exercises a changed path (verify skill step 2), and any tool that sends data off the machine. |
| 10 | **Local setup** | Platform toolchain, simulators/emulators, and runners. Platform-specific setup lives here, not in playbook Part 10. |
| 11 | **Superseded guidance** | Older platform documents or defaults this profile overrides, so agents do not follow them. |

## Profile status

A profile is **Draft** or **Active**, stated on its first line after the title and in the table above.

A profile becomes **Active** when all of these hold, and the change that says so names the template commit:

1. Every concrete claim (paths, commands, workflows, floors, budgets) matches its platform template at that
   commit. A profile with no template stays Draft.
2. The template's `verify` passes on its CI runner at that commit.
3. The seeded-defect test passes (every seed reported at BLOCKER) and the result is recorded in
   `<platform>/results/`.
4. The change ships in a tagged playbook release.

While Draft, a profile describes the target and its status line names what the template does not yet do. An
Active profile found out of line with its template goes back to Draft in the same change that finds the gap.
Why: [ADR 0001](../docs/decisions/0001-profile-status-and-ios-initial-state.md).

## Rules for profiles

- A profile MAY tighten a playbook number (a higher coverage floor, a shorter budget) or raise it where Part 6
  or Part 7 says the profile sets it (`verify`'s time budget, coverage floors). It MUST NOT drop a layer, a
  gate or a rule.
- Every tool named is mainstream, pinned by the template, and runs headlessly from `verify`.
- When the platform template's own docs disagree with its profile, fix one of them in the same change.
  The template's locked decisions (ADRs) win over the profile's tool choices; the playbook wins over both on
  rules.
- Changing a profile follows "Changing the playbook" in Part 11: pull request here, then the platform template
  picks the change up, then app repos pick up the template change.
