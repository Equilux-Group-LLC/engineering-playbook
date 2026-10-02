#!/usr/bin/env bash
# Gate 3 "tests-changed" check (playbook Part 6).
# Fails when source files changed but no test files changed, unless the pull request carries the
# opt-out label AND its body contains a line "No test needed: <reason>".
#
# Usage: tests-changed.sh <base-sha> <head-sha>
# Env:
#   SOURCE_PATTERN  extended regex for source paths   (default: ^(src|lib|app|pkg|internal|public|server|client)/)
#   TEST_PATTERN    extended regex for test paths     (default: (^|/)(test|tests|spec|__tests__|e2e)/|[._-](test|spec)\.[A-Za-z0-9]+$|_test\.go$)
#   PR_LABELS       newline- or comma-separated label names on the PR
#   PR_BODY         the PR description text
#   OPT_OUT_LABEL   label name (default: no-test-needed)
set -euo pipefail

base="${1:?usage: tests-changed.sh <base-sha> <head-sha>}"
head="${2:?usage: tests-changed.sh <base-sha> <head-sha>}"
source_re="${SOURCE_PATTERN:-^(src|lib|app|pkg|internal|public|server|client)/}"
test_re="${TEST_PATTERN:-(^|/)(test|tests|spec|__tests__|e2e)/|[._-](test|spec)\.[A-Za-z0-9]+$|_test\.go$}"
label="${OPT_OUT_LABEL:-no-test-needed}"

changed="$(git diff --name-only --diff-filter=ACMR "$base" "$head")"
tests="$(grep -E "$test_re" <<<"$changed" || true)"
sources="$(grep -E "$source_re" <<<"$changed" | grep -Ev "$test_re" || true)"

if [[ -z "$sources" ]]; then
  echo "PASS: no source files changed."
  exit 0
fi
if [[ -n "$tests" ]]; then
  echo "PASS: source and test files both changed."
  printf 'Tests changed:\n%s\n' "$tests"
  exit 0
fi

labels="$(tr ',' '\n' <<<"${PR_LABELS:-}" | sed 's/^ *//; s/ *$//')"
reason="$(grep -Ei '^[[:space:]]*no test needed:[[:space:]]*[^[:space:]]' <<<"${PR_BODY:-}" || true)"
if grep -qx "$label" <<<"$labels" && [[ -n "$reason" ]]; then
  echo "PASS (opted out): label '$label' present with reason:"
  echo "  ${reason#"${reason%%[![:space:]]*}"}"
  exit 0
fi

echo "FAIL: source files changed without any test changes:" >&2
sed 's/^/  /' <<<"$sources" >&2
echo "Add tests per the playbook's change-type matrix (Part 4), or add the '$label' label and a line" >&2
echo "'No test needed: <reason>' to the PR description." >&2
exit 1
