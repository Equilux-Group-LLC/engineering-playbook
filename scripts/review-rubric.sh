#!/usr/bin/env bash
# Prints a platform profile's review rubric for ai-review.yml to append to the review prompt.
# Usage: review-rubric.sh <toolkit-dir> <profile>
#   base           prints nothing (the playbook's own rubric only)
#   <platform>     prints profiles/<platform>/review-rubric.md
# Exit 1 for a profile that is malformed or has no rubric, so a typo in a caller fails the review loudly
# instead of silently reviewing without the platform rules.
set -euo pipefail

toolkit="${1:?usage: review-rubric.sh <toolkit-dir> <profile>}"
profile="${2:?usage: review-rubric.sh <toolkit-dir> <profile>}"

[[ "$profile" == base ]] && exit 0
# A bare lower-case name only: no path separators or dots, and no case variants that a case-insensitive
# filesystem (macOS) would resolve to another profile.
if [[ ! "$profile" =~ ^[a-z][a-z0-9-]*$ ]]; then
  echo "review-rubric: invalid profile '$profile' (use base or a directory name under profiles/)" >&2
  exit 1
fi

rubric="$toolkit/profiles/$profile/review-rubric.md"
if [[ ! -f "$rubric" ]]; then
  echo "review-rubric: no rubric for profile '$profile' (expected profiles/$profile/review-rubric.md)" >&2
  exit 1
fi
cat "$rubric"
