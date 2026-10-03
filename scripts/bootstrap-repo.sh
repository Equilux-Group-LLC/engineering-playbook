#!/usr/bin/env bash
# Add the testing harness starter files to a repository (playbook Part 11).
# Usage: bootstrap-repo.sh [target-repo-dir] [--force]
#   Managed files (playbook copy, runner, Cursor rule, AGENTS.md/CLAUDE.md block) are always refreshed.
#   Starter files (CI callers, lefthook.yml, invariant catalog) are created only if absent, or with --force.
# Run it from your local clone of Equilux-Group-LLC/engineering-playbook (install-local.sh puts one in ~/Developer).
set -euo pipefail

toolkit="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/managed-block.sh
source "$toolkit/scripts/lib/managed-block.sh"

target="."
force=false
for arg in "$@"; do
  case "$arg" in
    --force) force=true ;;
    -h|--help) sed -n '2,7p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) target="$arg" ;;
  esac
done
target="$(cd "$target" && pwd)"
if ! git -C "$target" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "bootstrap-repo: $target is not a git repository." >&2
  exit 1
fi
if [[ "$target" == "$toolkit" ]]; then
  echo "bootstrap-repo: run this against a project repository, not the toolkit itself." >&2
  exit 1
fi

version="$(git -C "$toolkit" describe --tags --always 2>/dev/null || echo unknown)"
created=() refreshed=() skipped=()

refresh() { # refresh <src> <dest>
  mkdir -p "$(dirname "$target/$2")"
  cp "$1" "$target/$2"
  refreshed+=("$2")
}
starter() { # starter <src> <dest>
  if [[ -e "$target/$2" && "$force" != true ]]; then skipped+=("$2"); return; fi
  mkdir -p "$(dirname "$target/$2")"
  cp "$1" "$target/$2"
  created+=("$2")
}

# Managed copies
mkdir -p "$target/docs"
{
  echo "<!-- Synced copy of Equilux-Group-LLC/engineering-playbook playbook/testing-harness-playbook.md ($version)."
  echo "     Do not edit here; propose changes upstream, then re-run bootstrap-repo.sh. -->"
  echo
  cat "$toolkit/playbook/testing-harness-playbook.md"
} > "$target/docs/testing-harness-playbook.md"
refreshed+=("docs/testing-harness-playbook.md")
refresh "$toolkit/scripts/run-contract.sh" ".harness/run-contract.sh"
chmod +x "$target/.harness/run-contract.sh"
refresh "$toolkit/templates/cursor/testing.mdc" ".cursor/rules/testing.mdc"

upsert_block "$target/AGENTS.md" "$toolkit/templates/AGENTS.testing.md"
refreshed+=("AGENTS.md (testing block)")
if [[ -f "$target/CLAUDE.md" ]] && ! grep -q "AGENTS.md" "$target/CLAUDE.md"; then
  upsert_block "$target/CLAUDE.md" "$toolkit/templates/AGENTS.testing.md"
  refreshed+=("CLAUDE.md (testing block)")
fi

# Starters
starter "$toolkit/templates/workflows/pr-checks.yml" ".github/workflows/pr-checks.yml"
starter "$toolkit/templates/workflows/pr-tests-changed.yml" ".github/workflows/pr-tests-changed.yml"
starter "$toolkit/templates/workflows/pr-issue-link.yml" ".github/workflows/pr-issue-link.yml"
starter "$toolkit/templates/lefthook.yml" "lefthook.yml"
starter "$toolkit/templates/invariants/CATALOG.yaml" "test/invariants/CATALOG.yaml"

echo "Testing harness files ($version) in $target"
for f in "${refreshed[@]}"; do echo "  refreshed  $f"; done
for f in "${created[@]+"${created[@]}"}"; do echo "  created    $f"; done
for f in "${skipped[@]+"${skipped[@]}"}"; do echo "  kept       $f (exists; use --force to replace)"; done
cat <<'NEXT'

Next:
  1. Review the changes with `git diff`, then commit them on a branch and open a pull request.
  2. Add the repository secret CLAUDE_CODE_OAUTH_TOKEN (from `claude setup-token`) for the AI review.
  3. In Cursor or Claude Code, ask: "Set up the testing harness per docs/testing-harness-playbook.md, Part 9."
NEXT
