#!/usr/bin/env bash
# Publish dotgithub/org and dotgithub/personal to the two `.github` repositories (playbook Part 11).
# Run on a Mac with GitHub access (Claude cloud sessions can't edit repositories whose names start with a dot).
#
# Usage: bash scripts/sync-dotgithub.sh [--dry-run]
# Env (for testing): DOTGITHUB_ORG_URL, DOTGITHUB_PERSONAL_URL
# The target repository is made to match the source folder exactly (files missing from the source are removed).
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dry_run=false
[[ "${1:-}" == "--dry-run" ]] && dry_run=true

org_url="${DOTGITHUB_ORG_URL:-https://github.com/Equilux-Group-LLC/.github.git}"
personal_url="${DOTGITHUB_PERSONAL_URL:-https://github.com/caobhin/.github.git}"
source_rev="$(git -C "$root" rev-parse --short HEAD 2>/dev/null || echo unknown)"

sync_one() { # sync_one <name> <url>
  local name="$1" url="$2" work
  work="$(mktemp -d)"
  git clone --quiet "$url" "$work/repo" 2>/dev/null || { echo "sync-dotgithub: cannot clone $url" >&2; rm -rf "$work"; return 1; }
  (
    cd "$work/repo"
    if git rev-parse --quiet --verify refs/remotes/origin/main >/dev/null; then
      git checkout --quiet -B main origin/main
    else
      git checkout --quiet --orphan main 2>/dev/null || true
    fi
    find . -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
    cp -R "$root/dotgithub/$name/." .
    git add -A
    if git diff --cached --quiet; then
      echo "$name: already up to date ($url)"
    elif [[ "$dry_run" == true ]]; then
      echo "$name: would update $url:"
      git diff --cached --stat | sed 's/^/  /'
    else
      git commit --quiet -m "Sync defaults from engineering-playbook@${source_rev}"
      git push --quiet origin main
      echo "$name: updated $url"
    fi
  )
  rm -rf "$work"
}

sync_one org "$org_url"
sync_one personal "$personal_url"
