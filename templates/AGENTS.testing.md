<!-- BEGIN equilux-testing-harness (managed by bootstrap-repo.sh; edit the playbook, not this block) -->
## Testing

This repository follows the testing harness playbook in `docs/testing-harness-playbook.md`
(canonical copy: https://github.com/Equilux-Group-LLC/engineering-playbook/blob/main/playbook/testing-harness-playbook.md).

- Every behavior change ships with tests in the same pull request; pick them with the playbook's Part 4 matrix.
- Never delete, skip or weaken a test to get green.
- Run `verify` before calling work complete, and report the real result.
- Project-specific "never" rules live in `test/invariants/CATALOG.yaml`.
<!-- END equilux-testing-harness -->
