#!/usr/bin/env bash
# Run a command from the playbook's command contract (Part 7) using whatever task runner the
# repository uses. Usage: run-contract.sh <command> [repo-dir]
#   e.g. run-contract.sh verify
# Detection order: mise tasks, package.json scripts, justfile, Makefile, Taskfile.
# Exits 2 if no runner defines the command.
set -euo pipefail

cmd="${1:?usage: run-contract.sh <command> [repo-dir]}"
dir="${2:-.}"
cd "$dir"

has_mise_task() {
  local f
  for f in mise.toml .mise.toml; do
    [[ -f "$f" ]] && grep -Eq "^\[tasks\.\"?${cmd//:/\\:}\"?\]" "$f" && return 0
  done
  return 1
}

has_package_script() {
  [[ -f package.json ]] || return 1
  node -e 'const s=require("./package.json").scripts||{}; process.exit(s[process.argv[1]]?0:1)' "$cmd" 2>/dev/null
}

package_runner() {
  if   [[ -f pnpm-lock.yaml ]]; then echo pnpm
  elif [[ -f yarn.lock ]];      then echo yarn
  elif [[ -f bun.lockb || -f bun.lock ]]; then echo bun
  else echo npm
  fi
}

if has_mise_task; then
  exec mise run "$cmd"
elif has_package_script; then
  exec "$(package_runner)" run "$cmd"
elif [[ -f justfile || -f Justfile ]] && just --summary 2>/dev/null | tr ' ' '\n' | grep -qx "$cmd"; then
  exec just "$cmd"
elif [[ -f Makefile ]] && grep -Eq "^${cmd//:/\\:}:" Makefile; then
  exec make "$cmd"
elif [[ -f Taskfile.yml || -f Taskfile.yaml ]] && task --list-all 2>/dev/null | grep -Eq "^\* ${cmd}:"; then
  exec task "$cmd"
fi

echo "run-contract: no task runner in $(pwd) defines '$cmd'." >&2
echo "Add it to package.json scripts, mise.toml [tasks], justfile, Makefile or Taskfile (playbook Part 7)." >&2
exit 2
