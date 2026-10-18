#!/usr/bin/env bash
# Check that a repository follows the harness's structural rules (playbook Parts 5, 7, 8 and 11).
# Usage: check-conformance.sh [repo-dir]      exit 0 = conforms, 1 = at least one check failed
#   1. `verify` and `verify:fast` resolve through run-contract.sh (nothing is run)
#   2. the invariant catalog parses as a YAML list: test/invariants/CATALOG.yaml, or the first */CATALOG.yaml path
#      named in profiles/<profile>.md when .equilux.yml names a profile this toolkit has
#   3. AGENTS.md (or CLAUDE.md) has the equilux-testing-harness block
#   4. a workflow calls ai-review.yml@v1, and none calls it at another ref
#   5. .equilux.yml names the playbook version and profile (and template_ref when it names a template)
set -uo pipefail

toolkit="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repo="$(cd "${1:-.}" && pwd)"
failed=0
ok()  { printf 'ok   %s\n' "$1"; }
bad() { failed=1; printf 'FAIL %s\n' "$1"; [[ -n "${2:-}" ]] && printf '     %s\n' "$2"; return 0; }

# Value of a top-level `key: value` line in .equilux.yml, without quotes or a trailing comment.
equilux() {
  [[ -f "$repo/.equilux.yml" ]] || return 0
  sed -nE "s/^$1:[[:space:]]*([^#]*).*/\\1/p" "$repo/.equilux.yml" | head -1 | sed -E 's/[[:space:]]+$//; s/^["'\'']//; s/["'\'']$//'
}

# 1. Command contract
for cmd in verify verify:fast; do
  if runner="$(bash "$toolkit/scripts/run-contract.sh" --resolve "$cmd" "$repo" 2>&1)"; then
    ok "contract: $cmd resolves ($runner)"
  else
    bad "contract: $cmd resolves" "add '$cmd' to the repository's task runner (playbook Part 7)"
  fi
done

# 2. Invariant catalog
profile="$(equilux profile)"
catalog="test/invariants/CATALOG.yaml"
if [[ -n "$profile" && -f "$toolkit/profiles/$profile.md" ]]; then
  named="$(grep -oE '`[^` ]*CATALOG\.yaml`' "$toolkit/profiles/$profile.md" | head -1 | tr -d '`')"
  [[ -n "$named" ]] && catalog="$named"
fi
parse_list() { # parse_list <file>: exit 0 if the file is a YAML list
  if python3 -c 'import yaml' 2>/dev/null; then
    python3 -c 'import sys, yaml; d = yaml.safe_load(open(sys.argv[1])); sys.exit(0 if isinstance(d, list) else 3)' "$1"
  elif command -v ruby >/dev/null; then
    ruby -ryaml -e 'exit(YAML.safe_load(File.read(ARGV[0])).is_a?(Array) ? 0 : 3)' "$1"
  else
    echo "no YAML parser (python3 with PyYAML, or ruby)"; return 4
  fi
}
if [[ ! -f "$repo/$catalog" ]]; then
  bad "catalog: $catalog exists" "copy templates/invariants/CATALOG.yaml there (playbook Part 5)"
elif err="$(parse_list "$repo/$catalog" 2>&1)"; then
  ok "catalog: $catalog parses"
else
  bad "catalog: $catalog parses as a list of entries" "${err##*$'\n'}"
fi

# 3. AGENTS testing block
if grep -qs 'BEGIN equilux-testing-harness' "$repo/AGENTS.md" "$repo/CLAUDE.md"; then
  ok "agents: testing block present"
else
  bad "agents: testing block present" "run bootstrap-repo.sh to add it to AGENTS.md"
fi

# 4. AI review caller
calls="$(grep -hoE 'ai-review\.yml@[^[:space:]"'\'']+' "$repo"/.github/workflows/*.y*ml 2>/dev/null | sort -u)"
others="$(grep -v '^ai-review\.yml@v1$' <<<"$calls" || true)"
if [[ -z "$calls" ]]; then
  bad "review: a workflow calls ai-review.yml@v1" "add .github/workflows/pr-review.yml from templates/workflows/"
elif [[ -n "$others" ]]; then
  bad "review: ai-review.yml is called at @v1" "found ${others//$'\n'/, }"
else
  ok "review: a workflow calls ai-review.yml@v1"
fi

# 5. Provenance
if [[ ! -f "$repo/.equilux.yml" ]]; then
  bad ".equilux.yml: present" "add it with playbook: and profile: (playbook Part 11, Provenance)"
else
  playbook="$(equilux playbook)"
  [[ "$playbook" =~ ^v[0-9]+(\.[0-9]+){0,2}$ ]] && ok ".equilux.yml: playbook version $playbook" \
    || bad ".equilux.yml: playbook names a release (vX.Y.Z)" "got '${playbook}'"
  [[ -n "$profile" ]] && ok ".equilux.yml: profile $profile" || bad ".equilux.yml: names a profile"
  if [[ -n "$(equilux template)" ]]; then
    [[ "$(equilux template_ref)" =~ ^[0-9a-f]{7,40}$ ]] && ok ".equilux.yml: template_ref pins the template" \
      || bad ".equilux.yml: template_ref pins the template to a commit" "got '$(equilux template_ref)'"
  fi
fi

exit "$failed"
