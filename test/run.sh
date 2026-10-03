#!/usr/bin/env bash
# Toolkit self-tests. Usage: test/run.sh   (exit 0 = all pass)
set -uo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
pass=0 fail=0
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

ok()   { pass=$((pass + 1)); printf 'ok   %s\n' "$1"; }
bad()  { fail=$((fail + 1)); printf 'FAIL %s\n' "$1"; [[ -n "${2:-}" ]] && printf '     %s\n' "$2"; }
expect_status() { # expect_status <name> <expected> <cmd...>
  local name="$1" want="$2"; shift 2
  local out; out="$("$@" 2>&1)"; local got=$?
  if [[ "$got" == "$want" ]]; then ok "$name"; else bad "$name" "exit $got, want $want: $out"; fi
}
new_repo() { # new_repo <dir>
  git init -q "$1" && git -C "$1" config user.email t@example.com && git -C "$1" config user.name Test
  git -C "$1" commit -q --allow-empty -m init
}

# ---- tests-changed.sh ----
r="$work/tc"; new_repo "$r"; base="$(git -C "$r" rev-parse HEAD)"
tc() { (cd "$r" && bash "$root/scripts/tests-changed.sh" "$base" HEAD); }
mkdir -p "$r/docs"; echo x > "$r/docs/a.md"; git -C "$r" add -A; git -C "$r" commit -qm docs
expect_status "tests-changed: docs-only change passes" 0 tc
mkdir -p "$r/src"; echo x > "$r/src/app.js"; git -C "$r" add -A; git -C "$r" commit -qm src
expect_status "tests-changed: source without tests fails" 1 tc
expect_status "tests-changed: label without reason still fails" 1 env PR_LABELS="bug,no-test-needed" bash -c "cd '$r' && bash '$root/scripts/tests-changed.sh' $base HEAD"
expect_status "tests-changed: label plus reason passes" 0 env PR_LABELS="no-test-needed" PR_BODY=$'Intro\nNo test needed: log message wording only' bash -c "cd '$r' && bash '$root/scripts/tests-changed.sh' $base HEAD"
expect_status "tests-changed: reason without label fails" 1 env PR_BODY="No test needed: because" bash -c "cd '$r' && bash '$root/scripts/tests-changed.sh' $base HEAD"
echo x > "$r/src/app.test.js"; git -C "$r" add -A; git -C "$r" commit -qm test
expect_status "tests-changed: co-located test file counts" 0 tc
r2="$work/tc2"; new_repo "$r2"; b2="$(git -C "$r2" rev-parse HEAD)"
mkdir -p "$r2/internal" "$r2/tests"; echo x > "$r2/internal/x.go"; echo x > "$r2/tests/x_test.go"; git -C "$r2" add -A; git -C "$r2" commit -qm go
expect_status "tests-changed: tests/ directory counts" 0 bash -c "cd '$r2' && bash '$root/scripts/tests-changed.sh' $b2 HEAD"

# ---- run-contract.sh ----
p="$work/rc-npm"; mkdir -p "$p"; echo '{"scripts":{"verify":"echo ran-npm-verify"}}' > "$p/package.json"
out="$(bash "$root/scripts/run-contract.sh" verify "$p" 2>&1)"
[[ "$out" == *ran-npm-verify* ]] && ok "run-contract: package.json script" || bad "run-contract: package.json script" "$out"
p="$work/rc-make"; mkdir -p "$p"; printf 'verify:\n\t@echo ran-make-verify\n' > "$p/Makefile"
out="$(bash "$root/scripts/run-contract.sh" verify "$p" 2>&1)"
[[ "$out" == *ran-make-verify* ]] && ok "run-contract: Makefile target" || bad "run-contract: Makefile target" "$out"
p="$work/rc-none"; mkdir -p "$p"
expect_status "run-contract: missing command exits 2" 2 bash "$root/scripts/run-contract.sh" verify "$p"
p="$work/rc-fail"; mkdir -p "$p"; echo '{"scripts":{"verify":"exit 7"}}' > "$p/package.json"
expect_status "run-contract: propagates failure" 7 bash "$root/scripts/run-contract.sh" verify "$p"

# ---- managed-block.sh ----
# shellcheck source=../scripts/lib/managed-block.sh
source "$root/scripts/lib/managed-block.sh"
f="$work/AGENTS.md"; printf '# Rules\n\nKeep me.\n' > "$f"
upsert_block "$f" "$root/templates/AGENTS.testing.md"; upsert_block "$f" "$root/templates/AGENTS.testing.md"
n="$(grep -c 'BEGIN equilux-testing-harness' "$f")"
[[ "$n" == 1 ]] && grep -q 'Keep me.' "$f" && ok "managed-block: idempotent upsert keeps user text" || bad "managed-block: idempotent upsert" "blocks=$n"
upsert_block "$f" "$root/claude/CLAUDE.issues.md" equilux-issue-linking; upsert_block "$f" "$root/claude/CLAUDE.issues.md" equilux-issue-linking
[[ "$(grep -c 'BEGIN equilux-issue-linking' "$f")" == 1 && "$(grep -c 'BEGIN equilux-testing-harness' "$f")" == 1 ]] \
  && ok "managed-block: named block sits beside the testing block" || bad "managed-block: named block sits beside the testing block"
remove_block "$f" equilux-issue-linking
! grep -q 'equilux-issue-linking' "$f" && grep -q 'BEGIN equilux-testing-harness' "$f" && ok "managed-block: remove named block only" || bad "managed-block: remove named block only"
remove_block "$f"
! grep -q 'equilux-testing-harness' "$f" && grep -q 'Keep me.' "$f" && ok "managed-block: remove" || bad "managed-block: remove"

# ---- bootstrap-repo.sh ----
t="$work/proj"; new_repo "$t"; mkdir -p "$t/.github/workflows"; echo "mine" > "$t/.github/workflows/pr-checks.yml"
expect_status "bootstrap: runs" 0 bash "$root/scripts/bootstrap-repo.sh" "$t"
for path in docs/testing-harness-playbook.md .harness/run-contract.sh .cursor/rules/testing.mdc AGENTS.md \
            .github/workflows/pr-tests-changed.yml lefthook.yml test/invariants/CATALOG.yaml; do
  [[ -e "$t/$path" ]] && ok "bootstrap: creates $path" || bad "bootstrap: creates $path"
done
[[ "$(cat "$t/.github/workflows/pr-checks.yml")" == mine ]] && ok "bootstrap: keeps existing starter" || bad "bootstrap: keeps existing starter"
bash "$root/scripts/bootstrap-repo.sh" "$t" --force >/dev/null
grep -q 'verify.yml@v1' "$t/.github/workflows/pr-checks.yml" && ok "bootstrap: --force replaces starter" || bad "bootstrap: --force replaces starter"
[[ "$(grep -c 'BEGIN equilux-testing-harness' "$t/AGENTS.md")" == 1 ]] && ok "bootstrap: re-run keeps one AGENTS block" || bad "bootstrap: re-run keeps one AGENTS block"
expect_status "bootstrap: refuses non-git dir" 1 bash "$root/scripts/bootstrap-repo.sh" "$work"

# ---- install-local.sh (against a local clone, fake HOME) ----
src="$work/toolkit-src"; cp -R "$root" "$src"; rm -rf "$src/.git"; new_repo "$src" >/dev/null; git -C "$src" add -A; git -C "$src" commit -qm toolkit
fakehome="$work/home"; mkdir -p "$fakehome/.claude"; printf 'My own rule.\n' > "$fakehome/.claude/CLAUDE.md"
run_install() { env HOME="$fakehome" CLAUDE_CONFIG_DIR="$fakehome/.claude" HARNESS_REPO_URL="$src" HARNESS_HOME="$fakehome/Developer/engineering-playbook" PATH="/usr/bin:/bin:$PATH" bash "$root/scripts/install-local.sh" "$@"; }
expect_status "install-local: first run" 0 run_install
expect_status "install-local: second run (update)" 0 run_install
[[ -L "$fakehome/.claude/skills/testing-harness" && -f "$fakehome/.claude/skills/testing-harness/SKILL.md" ]] && ok "install-local: skill symlink resolves" || bad "install-local: skill symlink resolves"
[[ -s "$fakehome/.claude/skills/testing-harness/references/testing-harness-playbook.md" ]] && ok "install-local: playbook reachable through skill" || bad "install-local: playbook reachable through skill"
[[ "$(grep -c 'BEGIN equilux-testing-harness' "$fakehome/.claude/CLAUDE.md")" == 1 ]] && grep -q 'My own rule.' "$fakehome/.claude/CLAUDE.md" && ok "install-local: CLAUDE.md block once, user text kept" || bad "install-local: CLAUDE.md block"
[[ "$(grep -c 'BEGIN equilux-issue-linking' "$fakehome/.claude/CLAUDE.md")" == 1 ]] && grep -q 'Closes #N' "$fakehome/.claude/CLAUDE.md" && ok "install-local: CLAUDE.md issue-linking block once" || bad "install-local: CLAUDE.md issue-linking block once"
expect_status "install-local: uninstall" 0 run_install --uninstall
[[ ! -e "$fakehome/.claude/skills/testing-harness" ]] && ! grep -q 'equilux-testing-harness\|equilux-issue-linking' "$fakehome/.claude/CLAUDE.md" && grep -q 'My own rule.' "$fakehome/.claude/CLAUDE.md" && ok "install-local: uninstall cleans up" || bad "install-local: uninstall cleans up"

# ---- skill zip ----
z="$work/skill.zip"
bash "$root/scripts/build-skill-zip.sh" "$z" >/dev/null
unzip -l "$z" | grep -q 'testing-harness/SKILL.md' && [[ "$(unzip -p "$z" testing-harness/references/testing-harness-playbook.md | head -1)" == "# Testing Harness Playbook" ]] \
  && ok "build-skill-zip: contains SKILL.md and real playbook text" || bad "build-skill-zip"

# ---- consistency ----
for wf in pr-checks.yml pr-tests-changed.yml; do
  cmp -s "$root/templates/workflows/$wf" "$root/dotgithub/org/workflow-templates/$wf" && ok "templates: $wf in sync" || bad "templates: $wf in sync"
done
for t in dotgithub/org/pull_request_template.md dotgithub/personal/pull_request_template.md; do
  cmp -s "$root/templates/pull_request_template.md" "$root/$t" && ok "templates: $t in sync" || bad "templates: $t in sync"
done
cmp -s "$root/playbook/testing-harness-playbook.md" "$root/skills/testing-harness/references/testing-harness-playbook.md" \
  && ok "skill: playbook copy matches canonical" || bad "skill: playbook copy matches canonical" "copy playbook/testing-harness-playbook.md to skills/testing-harness/references/"

# ---- sync-dotgithub.sh (against local bare repos) ----
git init -q --bare "$work/org.git"; git init -q --bare "$work/personal.git"
seed="$work/seed"; git clone -q "$work/personal.git" "$seed" 2>/dev/null
(cd "$seed" && git checkout -q -B main && echo stale > stale.txt && git add -A && git -c user.email=t@example.com -c user.name=T commit -qm seed && git push -q origin main)
# shellcheck disable=SC2120  # called with --dry-run through expect_status
run_sync() { env DOTGITHUB_ORG_URL="$work/org.git" DOTGITHUB_PERSONAL_URL="$work/personal.git" bash "$root/scripts/sync-dotgithub.sh" "$@"; }
expect_status "sync-dotgithub: dry run" 0 run_sync --dry-run
[[ -z "$(git --git-dir="$work/org.git" rev-parse -q --verify refs/heads/main)" ]] && ok "sync-dotgithub: dry run pushes nothing" || bad "sync-dotgithub: dry run pushes nothing"
expect_status "sync-dotgithub: first sync (empty and existing repos)" 0 run_sync
git --git-dir="$work/org.git" show main:workflow-templates/pr-checks.properties.json >/dev/null 2>&1 && ok "sync-dotgithub: org repo has workflow templates" || bad "sync-dotgithub: org repo has workflow templates"
! git --git-dir="$work/personal.git" show main:stale.txt >/dev/null 2>&1 && git --git-dir="$work/personal.git" show main:README.md >/dev/null 2>&1 && ok "sync-dotgithub: personal repo mirrors source" || bad "sync-dotgithub: personal repo mirrors source"
before="$(git --git-dir="$work/org.git" rev-parse main)"
out="$(run_sync 2>&1)"
[[ "$(git --git-dir="$work/org.git" rev-parse main)" == "$before" && "$out" == *"already up to date"* ]] && ok "sync-dotgithub: second sync is a no-op" || bad "sync-dotgithub: second sync is a no-op" "$out"

# ---- python ----
if python3 -m unittest discover -s "$root/test" -p 'test_*.py' -q 2>"$work/py.log"; then ok "python unit tests"; else bad "python unit tests" "$(tail -20 "$work/py.log")"; fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ "$fail" == 0 ]]
