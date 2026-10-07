# Equilux engineering playbook

Engineering defaults for **Equilux-Group-LLC** and personal `caobhin` repositories: the testing harness
playbook, the shared CI checks that enforce it, and the rules that make AI coding agents (Claude Code, Cursor)
follow it on every change.

This repository is public so that any repository, including personal ones, can call its reusable workflows
and the Mac installer can download without credentials. It contains general practice only, never project
details or secrets.

The two `.github` repositories ([org](https://github.com/Equilux-Group-LLC/.github),
[personal](https://github.com/caobhin/.github)) hold only what GitHub requires to live there. Their source is
[`dotgithub/`](dotgithub) in this repository; publish changes with `bash scripts/sync-dotgithub.sh` from a Mac.

## What's here

| Path | What it is |
| --- | --- |
| [`playbook/testing-harness-playbook.md`](playbook/testing-harness-playbook.md) | **The playbook.** Canonical, technology-agnostic testing architecture and agent instructions |
| [`.github/workflows/`](.github/workflows) | Reusable workflows: `secret-scan`, `verify`, `tests-changed`, `issue-link`, `ai-review` (plus this repo's own `self-test`, `pr-issue-link` and `release`) |
| [`dotgithub/`](dotgithub) | Source of both `.github` repositories: default PR template, README, and the "Equilux PR Checks" / "Equilux PR Review" / "Equilux PR Tests Changed" / "Equilux PR Issue Link" workflow templates |
| [`templates/`](templates) | Starter files the bootstrap script copies into a project |
| [`skills/testing-harness/`](skills/testing-harness) | Claude skill (Claude Code on your Mac and your claude.ai account) |
| [`claude/`](claude) | Global Claude Code blocks (testing, issue auto-close) and Cursor user rule |
| [`scripts/`](scripts) | `install-local.sh` (Mac), `bootstrap-repo.sh` (per project), `sync-dotgithub.sh`, CI helpers, `build-skill-zip.sh` |
| [`AGENTS.md`](AGENTS.md) | Rules for agents working in this repository, including issue auto-close keywords |
| [`test/`](test) | Self-tests for every script (`bash test/run.sh`) |

## Set up, once per place

**Your Mac** (Claude Code and Cursor):

```sh
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Equilux-Group-LLC/engineering-playbook/main/scripts/install-local.sh)"
```

This clones this repository to `~/Developer/engineering-playbook`, links the skill into `~/.claude/skills`, adds
marked blocks to `~/.claude/CLAUDE.md` (testing, and the issue auto-close rule for commits and PRs), and copies a Cursor user rule to your clipboard to paste into
**Cursor → Settings → Rules → User Rules**. Update later with `git -C ~/Developer/engineering-playbook pull`.
Undo with `bash ~/Developer/engineering-playbook/scripts/install-local.sh --uninstall`.

**Your Claude account** (claude.ai and Claude Code on the web): download `testing-harness-skill.zip` from the
[latest release](../../releases/latest) and upload it under **Settings → Capabilities → Skills**. Re-upload after
each release.

**A project repository:**

```sh
bash ~/Developer/engineering-playbook/scripts/bootstrap-repo.sh /path/to/project
```

Then follow the "Adopting in a repository" steps in Part 11 of the playbook.

**Calling the shared checks directly:**

```yaml
jobs:
  verify:
    uses: Equilux-Group-LLC/engineering-playbook/.github/workflows/verify.yml@v1
    with:
      toolkit-ref: v1
      coverage-report: coverage/lcov.info
```

## Changing anything here

You need to open a pull request. `Self Test` must pass: it lints every script and workflow and runs `test/run.sh`.
To release, run **Actions → Release → Run workflow** on `main` with a version such as `1.2.0`. It runs the
self-tests, tags `v1.2.0`, publishes a release with the skill zip attached, and moves the `v1` tag. Breaking
changes for callers go to a new major version (`2.0.0` creates `v2`).
