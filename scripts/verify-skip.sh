#!/usr/bin/env bash
# Decides whether verify.yml may skip its expensive steps for a pull request. The verify job still runs and
# reports success when they are skipped, so a required "verify" check never waits for a status that never comes.
#
# Skips when, and only when, the event is a pull request and either:
#   - the PR is a draft and SKIP_DRAFTS is true ("draft"), or
#   - every changed path matches DOCS_PATTERN and none matches DOCS_EXCLUDE_PATTERN ("docs-only").
# Anything else, including an empty or unreadable file list, runs the full verify.
#
# Usage: git diff --name-only --no-renames A B | verify-skip.sh
# Env:
#   EVENT_NAME            github.event_name; only pull_request can skip
#   IS_DRAFT              github.event.pull_request.draft (true | false)
#   SKIP_DRAFTS           true to skip drafts (default: false)
#   DOCS_PATTERN          extended regex for docs paths; empty = never skip for docs
#   DOCS_EXCLUDE_PATTERN  extended regex for paths that always verify even though DOCS_PATTERN matches
# Prints to stdout, in GITHUB_OUTPUT form:
#   skip=true|false
#   reason=<one line>
set -euo pipefail

changed="$(grep -v '^$' || true)"
docs_re="${DOCS_PATTERN:-}"
exclude_re="${DOCS_EXCLUDE_PATTERN:-}"

result() { printf 'skip=%s\nreason=%s\n' "$1" "$2"; exit 0; }
# grep exits 2 on a bad regex; the `|| true` below would read that as "no match" and skip, so check first.
for re in "$docs_re" "$exclude_re"; do
  st=0; grep -Eq -- "$re" <<<"" 2>/dev/null || st=$?
  (( st < 2 )) || { echo "verify-skip: invalid regex: $re" >&2; exit 2; }
done

[[ "${EVENT_NAME:-}" == pull_request ]] || result false "event '${EVENT_NAME:-}' always runs the full verify"
if [[ "${IS_DRAFT:-false}" == true && "${SKIP_DRAFTS:-false}" == true ]]; then
  result true "draft pull request, verify skipped; marking it ready for review runs the full verify"
fi
[[ -n "$changed" ]] || result false "no changed files listed; running the full verify"
[[ -n "$docs_re" ]] || result false "docs-pattern is empty; running the full verify"

not_docs="$(grep -Ev -m1 -- "$docs_re" <<<"$changed" || true)"
[[ -z "$not_docs" ]] || result false "non-docs change: $not_docs"
if [[ -n "$exclude_re" ]]; then
  excluded="$(grep -E -m1 -- "$exclude_re" <<<"$changed" || true)"
  [[ -z "$excluded" ]] || result false "docs change that verify reads: $excluded"
fi
result true "docs-only change ($(wc -l <<<"$changed" | tr -d ' ') files), verify skipped"
