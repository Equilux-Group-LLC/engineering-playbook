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

# ---- issue-link.sh ----
il() { env BASE_REF="${2:-main}" DEFAULT_BRANCH=main PR_BODY="$1" bash "$root/scripts/issue-link.sh"; }
expect_status "issue-link: Closes #N passes" 0 il $'## What & why\nCloses #12'
expect_status "issue-link: Fixes owner/repo#N passes" 0 il 'Fixes Equilux-Group-LLC/engineering-playbook#3'
expect_status "issue-link: lowercase resolves passes" 0 il 'resolves #7 and more'
expect_status "issue-link: No issue with reason passes" 0 il 'No issue: typo in README'
expect_status "issue-link: empty body fails" 1 il ''
expect_status "issue-link: bare reference fails" 1 il 'Related to #12'
expect_status "issue-link: placeholder fails" 1 il 'Closes #'
expect_status "issue-link: No issue without reason fails" 1 il 'No issue:'
expect_status "issue-link: keyword inside a word fails" 1 il 'Encloses #12'
expect_status "issue-link: non-default base skips" 0 il '' release/1.x

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
out="$(bash "$root/scripts/run-contract.sh" --resolve verify "$p" 2>&1)"
[[ "$out" == "npm run verify" ]] && ok "run-contract: --resolve prints the runner without running" || bad "run-contract: --resolve prints the runner without running" "$out"
expect_status "run-contract: --resolve of a missing command exits 2" 2 bash "$root/scripts/run-contract.sh" --resolve verify:fast "$p"

# ---- guard-test-weakening.sh ----
gp="$work/guard-proj"; mkdir -p "$gp/src" "$gp/test"
guard() { CLAUDE_PROJECT_DIR="$gp" bash "$root/scripts/guard-test-weakening.sh"; }
hook() { # hook <tool> <rel-path> <tool_input JSON object>: hook input with file_path added
  python3 -c 'import json, sys; r, t, p, ti = sys.argv[1:]; ti = json.loads(ti); ti["file_path"] = r + "/" + p
print(json.dumps({"tool_name": t, "cwd": r, "tool_input": ti}))' "$gp" "$@"
}
edit() { # edit <rel-path> <old> <new>
  hook Edit "$1" "$(python3 -c 'import json, sys; print(json.dumps({"old_string": sys.argv[1], "new_string": sys.argv[2], "replace_all": False}))' "$2" "$3")"
}
blocks() { local out got; out="$(guard 2>&1 <<<"$2")"; got=$?
  if [[ "$got" == 2 && "$out" == *"own commit"* ]]; then ok "guard: blocks $1"; else bad "guard: blocks $1" "exit $got: $out"; fi; }
passes() { local out got; out="$(guard 2>&1 <<<"$2")"; got=$?
  if [[ "$got" == 0 && -z "$out" ]]; then ok "guard: allows $1"; else bad "guard: allows $1" "exit $got: $out"; fi; }
while IFS='|' read -r marker path before after; do
  blocks "adding $marker" "$(edit "$path" "$before" "$(printf '%b' "$after")")"
done <<'MARKERS'
.skip(|test/cart.test.js|it("adds", () => {|it.skip("adds", () => {
xit(|test/cart.test.js|it("adds", () => {|xit("adds", () => {
.only(|src/cart.spec.ts|describe("cart", () => {|describe.only("cart", () => {
@pytest.mark.skip|tests/test_cart.py|def test_adds():|@pytest.mark.skip(reason="later")\ndef test_adds():
@pytest.mark.xfail|tests/test_cart.py|def test_adds():|@pytest.mark.xfail\ndef test_adds():
t.Skip(|internal/cart_test.go|func TestAdds(t *testing.T) {|func TestAdds(t *testing.T) {\n\tt.Skip("later")
#[ignore]|tests/cart.rs|#[test]|#[test]\n#[ignore]
.disabled(|Tests/CartTests.swift|@Test func adds() {|@Test(.disabled("later")) func adds() {
withKnownIssue|Tests/CartTests.swift|#expect(total(1) == 1)|withKnownIssue { #expect(total(1) == 1) }
XCTSkip|App/CartTests.swift|func testAdds() throws {|func testAdds() throws {\n  throw XCTSkip("later")
MARKERS
body=$'  expect(total(1)).toBe(1)\n'
blocks "removing an assertion" "$(edit internal/cart_test.go $'assert.Equal(t, 1, total(1))\nassert.Equal(t, 2, total(2))' 'assert.Equal(t, 1, total(1))')"
blocks "commenting out an assertion" "$(edit tests/test_cart.py '    assert total(1) == 1' '    # assert total(1) == 1')"
blocks "deleting Swift #expect and #require" "$(edit Tests/CartTests.swift $'#expect(a == 1)\nlet b = try #require(c)' 'let b = c!')"
blocks "deleting an XCTAssert" "$(edit App/CartTests.swift 'XCTAssertEqual(total(1), 1)' '')"
blocks "a removal in a _test. file" "$(edit src/cart_test.py '    assert total(1) == 1' '    pass')"
blocks "a removal under a nested test/ directory" "$(edit packages/cart/test/total.js "$body" '')"
printf 'test("a", () => {\n%s%s})\n' "$body" "$body" > "$gp/test/w.test.js"
blocks "a Write that drops assertions" "$(hook Write test/w.test.js '{"content": "test(\"a\", () => {})\n"}')"
blocks "a replace_all Edit that drops every copy" "$(hook Edit test/w.test.js '{"old_string": "  expect(total(1)).toBe(1)\n", "new_string": "", "replace_all": true}')"
blocks "a MultiEdit that drops assertions" "$(hook MultiEdit test/w.test.js '{"edits": [{"old_string": "expect(total(1)).toBe(1)", "new_string": ""}]}')"
passes "a new test file" "$(hook Write test/new.test.js '{"content": "test(\"adds\", () => {\n  expect(total(1)).toBe(1)\n})\n"}')"
passes "rewriting a test file with every assertion kept" "$(hook Write test/w.test.js "$(python3 -c 'import json, sys; print(json.dumps({"content": open(sys.argv[1]).read().replace("\"a\"", "\"adds one\"")}))' "$gp/test/w.test.js")")"
passes "renaming a test" "$(edit test/cart.test.js 'it("adds", () => {' 'it("adds one item to the total", () => {')"
passes "moving assertions" "$(edit test/cart.test.js $'  expect(a).toBe(1)\n  expect(b).toBe(2)' $'  expect(b).toBe(2)\n  expect(a).toBe(1)')"
passes "adding assertions" "$(edit test/cart.test.js "$body" "$body$body")"
passes "exit( in a test helper" "$(edit test/helpers.sh 'true' 'exit(1)')"
passes "skipping in source code" "$(edit src/list.js 'items' 'items.skip(1)')"
passes "removing expect from source code" "$(edit src/check.js 'expect(x)' '')"
passes "a non-edit tool" '{"tool_name":"Bash","tool_input":{"command":"ls"}}'
passes "unparsable input" 'not json'

# ---- check-conformance.sh ----
cg() { bash "$root/scripts/check-conformance.sh" "$1"; }
good="$work/conf-good"; new_repo "$good"; mkdir -p "$good/.github/workflows" "$good/test/invariants"
printf '%s\n' '{"scripts":{"verify":"true","verify:fast":"true"}}' > "$good/package.json"
cp "$root/templates/invariants/CATALOG.yaml" "$good/test/invariants/CATALOG.yaml"
cp "$root/templates/AGENTS.testing.md" "$good/AGENTS.md"
cp "$root/templates/workflows/pr-review.yml" "$good/.github/workflows/pr-review.yml"
printf 'playbook: v1.1.0   # release\nprofile: web\ntemplate: Example-Org/web-template\ntemplate_ref: 0123456789abcdef0123456789abcdef01234567\n' > "$good/.equilux.yml"
expect_status "conformance: conforming repo passes" 0 cg "$good"
nc="$work/conf-bad"; new_repo "$nc"; mkdir -p "$nc/.github/workflows" "$nc/test/invariants"
printf '%s\n' '{"scripts":{"verify":"true"}}' > "$nc/package.json"
printf -- '- id: A\n  rule: [unclosed\n' > "$nc/test/invariants/CATALOG.yaml"
printf '# Rules\n' > "$nc/AGENTS.md"
printf 'jobs:\n  review:\n    uses: Equilux-Group-LLC/engineering-playbook/.github/workflows/ai-review.yml@main\n' > "$nc/.github/workflows/pr-review.yml"
printf 'profile: web\ntemplate: Example-Org/web-template\n' > "$nc/.equilux.yml"
out="$(cg "$nc" 2>&1)"; got=$?
[[ "$got" == 1 ]] && ok "conformance: non-conforming repo fails" || bad "conformance: non-conforming repo fails" "exit $got"
for check in "contract: verify:fast resolves" "catalog: test/invariants/CATALOG.yaml parses" "agents: testing block" \
             "review: ai-review.yml is called at @v1" ".equilux.yml: playbook names a release" ".equilux.yml: template_ref pins"; do
  [[ "$out" == *"FAIL $check"* ]] && ok "conformance: reports '$check'" || bad "conformance: reports '$check'" "$out"
done
[[ "$out" == *"ok   contract: verify resolves"* ]] && ok "conformance: still passes the checks that hold" || bad "conformance: still passes the checks that hold" "$out"
rm "$nc/.equilux.yml" "$nc/.github/workflows/pr-review.yml" "$nc/test/invariants/CATALOG.yaml"
out="$(cg "$nc" 2>&1)"
[[ "$out" == *"FAIL .equilux.yml: present"* && "$out" == *"FAIL review: a workflow calls ai-review.yml@v1"* && "$out" == *"FAIL catalog: test/invariants/CATALOG.yaml exists"* ]] \
  && ok "conformance: reports missing .equilux.yml, review caller and catalog" || bad "conformance: reports missing .equilux.yml, review caller and catalog" "$out"

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
            .github/workflows/pr-review.yml .github/workflows/pr-tests-changed.yml .github/workflows/pr-issue-link.yml lefthook.yml test/invariants/CATALOG.yaml \
            .harness/guard-test-weakening.sh .claude/settings.json; do
  [[ -e "$t/$path" ]] && ok "bootstrap: creates $path" || bad "bootstrap: creates $path"
done
[[ "$(cat "$t/.github/workflows/pr-checks.yml")" == mine ]] && ok "bootstrap: keeps existing starter" || bad "bootstrap: keeps existing starter"
[[ -x "$t/.harness/guard-test-weakening.sh" ]] && cmp -s "$t/.harness/guard-test-weakening.sh" "$root/scripts/guard-test-weakening.sh" \
  && ok "bootstrap: installs the guard as a managed, executable copy" || bad "bootstrap: installs the guard as a managed, executable copy"
t3="$work/proj-settings"; new_repo "$t3"; mkdir -p "$t3/.claude"; echo '{"permissions":{}}' > "$t3/.claude/settings.json"
out="$(bash "$root/scripts/bootstrap-repo.sh" "$t3" 2>&1)"
[[ "$(cat "$t3/.claude/settings.json")" == '{"permissions":{}}' && "$out" == *"add the hooks from templates/claude/settings.json"* && -x "$t3/.harness/guard-test-weakening.sh" ]] \
  && ok "bootstrap: keeps an existing .claude/settings.json and says to add the hooks" || bad "bootstrap: keeps an existing .claude/settings.json and says to add the hooks" "$out"
bash "$root/scripts/bootstrap-repo.sh" "$t" --force >/dev/null
grep -q 'verify.yml@v1' "$t/.github/workflows/pr-checks.yml" && ok "bootstrap: --force replaces starter" || bad "bootstrap: --force replaces starter"
grep -q 'issue-link.yml@v1' "$t/.github/workflows/pr-issue-link.yml" && grep -q 'edited' "$t/.github/workflows/pr-issue-link.yml" \
  && ok "bootstrap: issue-link starter calls the shared check on edits" || bad "bootstrap: issue-link starter calls the shared check on edits"
grep -q 'ai-review.yml@v1' "$t/.github/workflows/pr-review.yml" && grep -q 'ready_for_review' "$t/.github/workflows/pr-review.yml" \
  && ! grep -q 'ai-review.yml' "$t/.github/workflows/pr-checks.yml" \
  && ok "bootstrap: AI review is its own starter, run again when marked ready" || bad "bootstrap: AI review is its own starter, run again when marked ready"
for wf in pr-checks.yml pr-tests-changed.yml pr-issue-link.yml; do
  ! grep -q 'ready_for_review' "$t/.github/workflows/$wf" && ok "bootstrap: $wf does not re-run when marked ready" || bad "bootstrap: $wf does not re-run when marked ready"
done
t2="$work/proj-old"; new_repo "$t2"; mkdir -p "$t2/.github/workflows"
printf 'jobs:\n  review:\n    uses: Equilux-Group-LLC/engineering-playbook/.github/workflows/ai-review.yml@v1\n' > "$t2/.github/workflows/pr-checks.yml"
out="$(bash "$root/scripts/bootstrap-repo.sh" "$t2" 2>&1)"
[[ ! -e "$t2/.github/workflows/pr-review.yml" && "$out" == *"pr-checks.yml already runs the AI review"* ]] \
  && ok "bootstrap: no second AI review beside an older pr-checks.yml" || bad "bootstrap: no second AI review beside an older pr-checks.yml" "$out"
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
[[ ! -e "$fakehome/.claude/skills/equilux-design-system" && ! -L "$fakehome/.claude/skills/equilux-design-system" ]] \
  && ok "install-local: no design-system skill link" || bad "install-local: no design-system skill link"
[[ -L "$fakehome/.claude/agents/test-auditor.md" ]] && grep -q '^name: test-auditor' "$fakehome/.claude/agents/test-auditor.md" \
  && ok "install-local: test-auditor agent symlink resolves" || bad "install-local: test-auditor agent symlink resolves"
[[ "$(grep -c 'BEGIN equilux-testing-harness' "$fakehome/.claude/CLAUDE.md")" == 1 ]] && grep -q 'My own rule.' "$fakehome/.claude/CLAUDE.md" && ok "install-local: CLAUDE.md block once, user text kept" || bad "install-local: CLAUDE.md block"
[[ "$(grep -c 'BEGIN equilux-issue-linking' "$fakehome/.claude/CLAUDE.md")" == 1 ]] && grep -q 'Closes #N' "$fakehome/.claude/CLAUDE.md" && ok "install-local: CLAUDE.md issue-linking block once" || bad "install-local: CLAUDE.md issue-linking block once"
# Older installs linked the design-system skill into the clone. The update must remove that link, even though the
# update itself deletes its target, and must leave a link that points somewhere else alone.
hh="$fakehome/Developer/engineering-playbook"
ln -s "$hh/skills/equilux-design-system" "$fakehome/.claude/skills/equilux-design-system"
expect_status "install-local: update with a retired skill link" 0 run_install
[[ ! -e "$fakehome/.claude/skills/equilux-design-system" && ! -L "$fakehome/.claude/skills/equilux-design-system" ]] \
  && ok "install-local: update removes the retired design-system link" || bad "install-local: update removes the retired design-system link"
mkdir -p "$work/elsewhere"; ln -s "$work/elsewhere" "$fakehome/.claude/skills/equilux-design-system"
expect_status "install-local: update with a design-system link that points elsewhere" 0 run_install
[[ -L "$fakehome/.claude/skills/equilux-design-system" ]] && ok "install-local: keeps a design-system link that points elsewhere" || bad "install-local: keeps a design-system link that points elsewhere"
rm "$fakehome/.claude/skills/equilux-design-system"
expect_status "install-local: uninstall" 0 run_install --uninstall
[[ ! -e "$fakehome/.claude/agents/test-auditor.md" && ! -L "$fakehome/.claude/agents/test-auditor.md" ]] \
  && ok "install-local: uninstall removes the test-auditor link" || bad "install-local: uninstall removes the test-auditor link"
[[ ! -e "$fakehome/.claude/skills/testing-harness" && ! -e "$fakehome/.claude/skills/equilux-design-system" ]] && ! grep -q 'equilux-testing-harness\|equilux-issue-linking' "$fakehome/.claude/CLAUDE.md" && grep -q 'My own rule.' "$fakehome/.claude/CLAUDE.md" && ok "install-local: uninstall cleans up" || bad "install-local: uninstall cleans up"

# ---- skill zip ----
z="$work/skill.zip"
bash "$root/scripts/build-skill-zip.sh" "$z" >/dev/null
unzip -l "$z" | grep -q 'testing-harness/SKILL.md' && [[ "$(unzip -p "$z" testing-harness/references/testing-harness-playbook.md | head -1)" == "# Testing Harness Playbook" ]] \
  && ok "build-skill-zip: contains SKILL.md and real playbook text" || bad "build-skill-zip"
expect_status "build-skill-zip: unknown skill fails" 1 bash "$root/scripts/build-skill-zip.sh" "$work/x.zip" no-such-skill

# ---- consistency ----
# The settings template stays valid JSON, allows the contract commands and points both hooks at managed files.
settings_ok='import json, sys
s = json.load(open(sys.argv[1]))
want = {"Bash(.harness/run-contract.sh *)", "Bash(mise run verify*)", "Bash(git diff *)", "Bash(git status*)"}
assert want <= set(s["permissions"]["allow"])
pre = [h["command"] for m in s["hooks"]["PreToolUse"] if m["matcher"] == "Edit|Write|MultiEdit" for h in m["hooks"]]
post = [h["command"] for m in s["hooks"]["PostToolUse"] if m["matcher"] == "Edit|Write" for h in m["hooks"]]
assert any(".harness/guard-test-weakening.sh" in c for c in pre)
assert any(".harness/run-contract.sh format" in c and c.endswith("|| true") for c in post)'
python3 -c "$settings_ok" "$root/templates/claude/settings.json" 2>"$work/settings.log" \
  && ok "templates: claude/settings.json allows the contract and wires both hooks" || bad "templates: claude/settings.json allows the contract and wires both hooks" "$(tail -1 "$work/settings.log")"
frontmatter='import sys, yaml; fm = yaml.safe_load(open(sys.argv[1]).read().split("---")[1])'
tools="$(python3 -c "$frontmatter; print(fm['tools'])" "$root/claude/agents/test-auditor.md" 2>&1)"
[[ "$tools" == "Read, Grep, Glob, Bash(git diff:*), Bash(git log:*)" ]] \
  && ok "agents: test-auditor tools are read-only" || bad "agents: test-auditor tools are read-only" "$tools"
auditor_hook="$(python3 -c "$frontmatter; print(fm['hooks']['PreToolUse'][0]['hooks'][0]['command'])" "$root/claude/agents/test-auditor.md" 2>/dev/null)"
for c in 'git diff --merge-base origin/main' 'git log --oneline -5'; do
  printf '{"tool_input":{"command":"%s"}}' "$c" | bash -c "$auditor_hook" 2>/dev/null && ok "agents: test-auditor may run '$c'" || bad "agents: test-auditor may run '$c'"
done
for c in 'git diff | sh' 'git diff; touch x' 'git diff\ntouch x' 'git diff --output=x' 'git push' 'touch x'; do
  printf '{"tool_input":{"command":"%s"}}' "$c" | bash -c "$auditor_hook" 2>/dev/null; got=$?
  [[ "$got" == 2 ]] && ok "agents: test-auditor may not run '$c'" || bad "agents: test-auditor may not run '$c'" "exit $got"
done
for wf in pr-checks.yml pr-review.yml pr-tests-changed.yml pr-issue-link.yml; do
  cmp -s "$root/templates/workflows/$wf" "$root/dotgithub/org/workflow-templates/$wf" && ok "templates: $wf in sync" || bad "templates: $wf in sync"
done
for t in dotgithub/org/pull_request_template.md dotgithub/personal/pull_request_template.md; do
  cmp -s "$root/templates/pull_request_template.md" "$root/$t" && ok "templates: $t in sync" || bad "templates: $t in sync"
done
# Callers run these workflows with their own secrets, so an action tag moved upstream would run in every caller.
unpinned="$(cd "$root" && grep -nE '^[[:space:]]*(-[[:space:]]+)?uses:' .github/workflows/*.yml \
  | grep -vE 'uses:[[:space:]]+(\./|Equilux-Group-LLC/engineering-playbook/)' \
  | grep -vE '@[0-9a-f]{40}([[:space:]]|$)' || true)"
[[ -z "$unpinned" ]] && ok "workflows: third-party actions pinned to commit SHAs" \
  || bad "workflows: third-party actions pinned to commit SHAs" "pin to a full SHA with '# vX.Y.Z': ${unpinned//$'\n'/; }"
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
git --git-dir="$work/org.git" show main:workflow-templates/pr-checks.properties.json >/dev/null 2>&1 && git --git-dir="$work/org.git" show main:workflow-templates/pr-issue-link.properties.json >/dev/null 2>&1 && git --git-dir="$work/org.git" show main:workflow-templates/pr-review.yml >/dev/null 2>&1 && ok "sync-dotgithub: org repo has workflow templates" || bad "sync-dotgithub: org repo has workflow templates"
! git --git-dir="$work/personal.git" show main:stale.txt >/dev/null 2>&1 && git --git-dir="$work/personal.git" show main:README.md >/dev/null 2>&1 && ok "sync-dotgithub: personal repo mirrors source" || bad "sync-dotgithub: personal repo mirrors source"
before="$(git --git-dir="$work/org.git" rev-parse main)"
out="$(run_sync 2>&1)"
[[ "$(git --git-dir="$work/org.git" rev-parse main)" == "$before" && "$out" == *"already up to date"* ]] && ok "sync-dotgithub: second sync is a no-op" || bad "sync-dotgithub: second sync is a no-op" "$out"

# ---- python ----
if python3 -m unittest discover -s "$root/test" -p 'test_*.py' -q 2>"$work/py.log"; then ok "python unit tests"; else bad "python unit tests" "$(tail -20 "$work/py.log")"; fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ "$fail" == 0 ]]
