#!/usr/bin/env bash
# Install the testing harness playbook on this Mac for Claude Code and Cursor (playbook Part 11).
#
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/Equilux-Group-LLC/engineering-playbook/main/scripts/install-local.sh)"
#   or, from a clone:  bash scripts/install-local.sh [--uninstall]
#
# What it does (safe to re-run; backs up anything it replaces):
#   1. Clones Equilux-Group-LLC/engineering-playbook to $HARNESS_HOME (default ~/Developer/engineering-playbook),
#      or fast-forwards it if it already exists.
#   2. Symlinks ~/.claude/skills/testing-harness -> the clone's skills/testing-harness.
#   3. Adds marked blocks to ~/.claude/CLAUDE.md: one pointing every Claude Code session at the playbook, one with
#      the issue auto-close rule for commits and pull requests.
#   4. Copies the Cursor user rule to the clipboard for you to paste into Cursor Settings -> Rules.
# Updates later:  git -C ~/Developer/engineering-playbook pull
set -euo pipefail

REPO_URL="${HARNESS_REPO_URL:-https://github.com/Equilux-Group-LLC/engineering-playbook.git}"
HARNESS_HOME="${HARNESS_HOME:-$HOME/Developer/engineering-playbook}"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SKILL_LINK="$CLAUDE_DIR/skills/testing-harness"
stamp="$(date +%Y%m%d%H%M%S)"

say() { printf '%s\n' "$*"; }

if [[ "${1:-}" == "--uninstall" ]]; then
  if [[ -L "$SKILL_LINK" ]]; then rm "$SKILL_LINK"; say "Removed $SKILL_LINK"; fi
  if [[ -f "$HARNESS_HOME/scripts/lib/managed-block.sh" && -f "$CLAUDE_DIR/CLAUDE.md" ]]; then
    # shellcheck source=lib/managed-block.sh
    source "$HARNESS_HOME/scripts/lib/managed-block.sh"
    cp "$CLAUDE_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md.bak.$stamp"
    remove_block "$CLAUDE_DIR/CLAUDE.md"
    remove_block "$CLAUDE_DIR/CLAUDE.md" equilux-issue-linking
    say "Removed the testing and issue-linking blocks from $CLAUDE_DIR/CLAUDE.md (backup: CLAUDE.md.bak.$stamp)"
  fi
  say "Left $HARNESS_HOME in place; delete it yourself if you no longer want it."
  say "Remove the rule from Cursor Settings -> Rules -> User Rules by hand."
  exit 0
fi

command -v git >/dev/null || { say "git is required. Install Xcode Command Line Tools: xcode-select --install"; exit 1; }

# 1. Clone or update
if [[ -d "$HARNESS_HOME/.git" ]]; then
  git -C "$HARNESS_HOME" pull --ff-only --quiet
  say "Updated $HARNESS_HOME"
else
  mkdir -p "$(dirname "$HARNESS_HOME")"
  git clone --quiet "$REPO_URL" "$HARNESS_HOME"
  say "Cloned $REPO_URL to $HARNESS_HOME"
fi
# shellcheck source=lib/managed-block.sh
source "$HARNESS_HOME/scripts/lib/managed-block.sh"

# 2. Claude Code skill
mkdir -p "$CLAUDE_DIR/skills"
if [[ -e "$SKILL_LINK" && ! -L "$SKILL_LINK" ]]; then
  mv "$SKILL_LINK" "$SKILL_LINK.bak.$stamp"
  say "Backed up existing $SKILL_LINK to $SKILL_LINK.bak.$stamp"
fi
ln -sfn "$HARNESS_HOME/skills/testing-harness" "$SKILL_LINK"
say "Linked Claude Code skill: $SKILL_LINK"

# 3. Global Claude Code instructions
if [[ -f "$CLAUDE_DIR/CLAUDE.md" ]]; then cp "$CLAUDE_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md.bak.$stamp"; fi
upsert_block "$CLAUDE_DIR/CLAUDE.md" "$HARNESS_HOME/claude/CLAUDE.user.md"
upsert_block "$CLAUDE_DIR/CLAUDE.md" "$HARNESS_HOME/claude/CLAUDE.issues.md" equilux-issue-linking
say "Updated $CLAUDE_DIR/CLAUDE.md (testing and issue-linking blocks)"

# 4. Cursor user rule (Cursor keeps user rules in its settings, not in a file)
if command -v pbcopy >/dev/null; then
  pbcopy < "$HARNESS_HOME/claude/cursor-user-rule.md"
  say "Copied the Cursor user rule to your clipboard. Paste it in Cursor -> Settings -> Rules -> User Rules."
else
  say "Paste the contents of $HARNESS_HOME/claude/cursor-user-rule.md into Cursor -> Settings -> Rules -> User Rules."
fi

say ""
say "Done. To add the harness to a project:  bash $HARNESS_HOME/scripts/bootstrap-repo.sh /path/to/project"
