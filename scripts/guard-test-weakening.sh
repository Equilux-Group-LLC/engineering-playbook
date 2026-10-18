#!/usr/bin/env bash
# Claude Code PreToolUse hook for Edit|Write|MultiEdit (playbook Part 3: never weaken a test to get green).
# Reads the hook input JSON on stdin. When the target is a test file, blocks (exit 2, reason on stderr) an edit
# that adds a skip / focus / known-failure marker or leaves fewer assertion lines than it found.
# Anything else, including new test files and renamed tests, exits 0 so the normal permission flow applies.
# Installed to .harness/guard-test-weakening.sh by bootstrap-repo.sh; wired up in .claude/settings.json.
set -uo pipefail

if ! command -v python3 >/dev/null 2>&1; then
  echo "guard-test-weakening: python3 not found; test edits are not checked." >&2
  exit 0
fi

exec python3 -c '
import json, os, re, sys

TEST_DIRS = {"test", "tests", "Tests"}
TEST_NAME = re.compile(r"(\.test\.|_test\.|\.spec\.)|Tests\.swift$")
MARKERS = [
    (".skip(", re.compile(r"\.skip\(")),
    ("xit(", re.compile(r"(?<![\w.])xit\(")),
    (".only(", re.compile(r"\.only\(")),
    ("@pytest.mark.skip", re.compile(r"@pytest\.mark\.skip")),
    ("@pytest.mark.xfail", re.compile(r"@pytest\.mark\.xfail")),
    ("t.Skip(", re.compile(r"\bt\.Skip\(")),
    ("#[ignore]", re.compile(r"#\[ignore\b")),
    (".disabled(", re.compile(r"\.disabled\(")),
    ("withKnownIssue", re.compile(r"\bwithKnownIssue\b")),
    ("XCTSkip", re.compile(r"\bXCTSkip")),
]
ASSERTION = re.compile(r"#expect\b|#require\b|\bXCTAssert\w*|\bexpect\b|\bassert\w*")
# A commented-out assertion no longer runs, so it does not count. "#expect", "#require" and "#[" are Swift and
# Rust syntax, not comments.
COMMENT = re.compile(r"^\s*(//|/\*|\*|--|#(?!expect\b|require\b|\[))")


def is_test_path(path, root):
    path = path.replace("\\", "/")
    root = root.replace("\\", "/").rstrip("/")
    rel = path[len(root) + 1:] if root and path.startswith(root + "/") else path.lstrip("/")
    parts = rel.split("/")
    return any(p in TEST_DIRS for p in parts[:-1]) or bool(TEST_NAME.search(parts[-1]))


def assertion_lines(text):
    return sum(1 for line in text.splitlines() if ASSERTION.search(line) and not COMMENT.match(line))


def read(path):
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            return f.read()
    except OSError:
        return ""


def pairs(tool, ti):
    """(before, after, times) for each text replacement the call makes."""
    path = ti.get("file_path", "")
    if tool == "Write":
        return [(read(path), ti.get("content", ""), 1)]
    edits = ti.get("edits") if tool == "MultiEdit" else [ti]
    current = read(path)
    out = []
    for e in edits or []:
        old, new = e.get("old_string", ""), e.get("new_string", "")
        times = max(current.count(old), 1) if e.get("replace_all") and old else 1
        out.append((old, new, times))
    return out


try:
    hook = json.load(sys.stdin)
except ValueError:
    sys.exit(0)
tool = hook.get("tool_name", "")
ti = hook.get("tool_input") or {}
path = ti.get("file_path", "")
root = os.environ.get("CLAUDE_PROJECT_DIR") or hook.get("cwd", "")
if tool not in ("Edit", "Write", "MultiEdit") or not path or not is_test_path(path, root):
    sys.exit(0)

added, removed_asserts = [], 0
for before, after, times in pairs(tool, ti):
    for name, rx in MARKERS:
        if len(rx.findall(after)) > len(rx.findall(before)) and name not in added:
            added.append(name)
    removed_asserts += (assertion_lines(before) - assertion_lines(after)) * times

problems = []
if added:
    problems.append("adds " + ", ".join(added))
if removed_asserts > 0:
    problems.append("removes %d more assertion line%s than it adds" % (removed_asserts, "" if removed_asserts == 1 else "s"))
if not problems:
    sys.exit(0)

shown = os.path.relpath(path, root) if root and path.startswith(root) else path
sys.stderr.write(
    "Blocked by guard-test-weakening: this edit to the test file %s %s.\n"
    "The playbook forbids skipping, focusing, marking as failing or deleting assertions to get green.\n"
    "Fix the code under test instead. If the test itself is wrong, stop and tell the user why; a genuine test fix\n"
    "goes in its own commit whose message explains it, separate from the behavior change.\n" % (shown, " and ".join(problems))
)
sys.exit(2)
'
