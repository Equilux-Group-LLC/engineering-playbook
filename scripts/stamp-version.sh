#!/usr/bin/env bash
# Stamp the playbook's version line in both copies (canonical and skill) so they stay identical.
# The release workflow runs this from the tag before building the skill zip; the committed copies say "unreleased".
# Usage: stamp-version.sh <X.Y.Z> [YYYY-MM-DD]   (date defaults to today, UTC)
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version="${1:-}" day="${2:-$(date -u +%F)}"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Version must look like 1.2.3 (got '$version')" >&2; exit 1; }
[[ "$day" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || { echo "Date must look like 2026-01-31 (got '$day')" >&2; exit 1; }
line='^Version .*\. The canonical copy lives at$'
files=("$root/playbook/testing-harness-playbook.md" "$root/skills/testing-harness/references/testing-harness-playbook.md")
# Check every copy before writing any, so a failure never leaves the two copies different.
for f in "${files[@]}"; do
  n="$(grep -c "$line" "$f" || true)"
  [[ "$n" == 1 ]] || { echo "$f: expected one version line, found $n" >&2; exit 1; }
done
for f in "${files[@]}"; do
  sed "s/$line/Version $version ($day). The canonical copy lives at/" "$f" > "$f.tmp" && mv "$f.tmp" "$f"
done
echo "Stamped playbook $version ($day)"
