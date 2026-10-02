<!-- BEGIN equilux-testing-harness (managed by install-local.sh; edit the playbook, not this block) -->
## Testing (all projects)

Follow the Equilux testing harness playbook: the `testing-harness` skill, full text in
~/.claude/skills/testing-harness/references/testing-harness-playbook.md.

- Every behavior change ships with tests in the same change; choose them with the playbook's Part 4 matrix.
- Bug fixes start with a test that reproduces the bug and is seen failing.
- Never delete, skip or weaken a test to get green.
- Fixtures use obviously fake data only.
- Run the project's `verify` command before calling work complete, and report the real result.
- A project's own AGENTS.md / CLAUDE.md rules take precedence over this block.
<!-- END equilux-testing-harness -->
