#!/usr/bin/env bash
# "issue-link" check: a pull request into the default branch must close its issue through GitHub's
# automation, so its description needs a closing keyword ("Closes #12", "Fixes #12", "Resolves owner/repo#12")
# or a line "No issue: <reason>". Pull requests into other branches pass: GitHub only auto-closes on merges
# into the default branch.
#
# Usage: issue-link.sh
# Env:
#   PR_BODY         the PR description text
#   BASE_REF        branch the PR targets
#   DEFAULT_BRANCH  the repository's default branch (default: main)
set -euo pipefail

base="${BASE_REF:?BASE_REF is required}"
default="${DEFAULT_BRANCH:-main}"
body="${PR_BODY:-}"

if [[ "$base" != "$default" ]]; then
  echo "PASS: PR targets '$base', not '$default'; GitHub will not auto-close issues from it."
  echo "Use 'Related to #N' here; put 'Closes #N' on the PR that merges into '$default'."
  exit 0
fi

keyword_re='(^|[^[:alnum:]_])(close[sd]?|fix(e[sd])?|resolve[sd]?):?[[:space:]]+([[:alnum:]_.-]+/[[:alnum:]_.-]+)?#[0-9]+'
closing="$(grep -Eio "$keyword_re" <<<"$body" || true)"
if [[ -n "$closing" ]]; then
  echo "PASS: PR closes:"
  sed 's/^[^[:alpha:]]*/  /' <<<"$closing"
  exit 0
fi

reason="$(grep -Ei '^[[:space:]]*no issue:[[:space:]]*[^[:space:]]' <<<"$body" || true)"
if [[ -n "$reason" ]]; then
  echo "PASS (no issue): ${reason#"${reason%%[![:space:]]*}"}"
  exit 0
fi

echo "FAIL: the PR description does not close an issue." >&2
echo "Add a line 'Closes #<issue>' (or Fixes / Resolves), or 'No issue: <reason>' if there is none." >&2
echo "'Related to #<issue>' links without closing; use it only alongside a closing line elsewhere." >&2
exit 1
