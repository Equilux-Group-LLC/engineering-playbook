## What & why
<!-- 1-3 sentences. Link the issue. -->

## Risk: check everything this PR touches
- [ ] Authentication / authorization / permissions
- [ ] Personal or sensitive data (fields, logs, exports, feeds)
- [ ] Database schema or migration
- [ ] Deploy config, secrets, workflows, cloud bindings
- [ ] None of the above

## Tests (testing harness playbook, Part 4)
- [ ] Tests added or updated for every behavior change
- [ ] Bug fix: a regression test was written first and seen failing
- [ ] Invariant catalog updated if this adds an input, output, integration, role or credential
- [ ] No existing test deleted, skipped or weakened

<!-- Only if no tests are needed: add the `no-test-needed` label and one line below. -->
<!-- No test needed: <reason> -->

## Before merge
- [ ] `verify` is green locally and every PR check is green (never merge on red or pending)
- [ ] AI review ran; verdict READY, or every finding fixed or dismissed with a one-line reason below

## Dismissed findings
<!-- finding -> reason. Leave empty if none. -->
