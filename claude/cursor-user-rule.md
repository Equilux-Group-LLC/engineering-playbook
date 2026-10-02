Testing (all projects): follow the Equilux testing harness playbook
(https://github.com/Equilux-Group-LLC/engineering-playbook/blob/main/playbook/testing-harness-playbook.md; local copy in
~/Developer/engineering-playbook/playbook/). Every behavior change ships with tests chosen by the playbook's
Part 4 matrix. Bug fixes start with a failing test. Never delete, skip or weaken a test to get green. Use
obviously fake data in fixtures. Run the project's `verify` command before saying work is done and report the
real result. Never call a PR ready while any check is red or pending. Project rules files take precedence.
