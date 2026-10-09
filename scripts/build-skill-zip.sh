#!/usr/bin/env bash
# Package a skill from skills/ as a zip for upload to claude.ai (Settings -> Capabilities -> Skills).
# Symlinks are followed, so the zip contains the real playbook text.
# Usage: build-skill-zip.sh [output.zip] [skill]   (defaults: dist/<skill>-skill.zip, skill testing-harness)
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
skill="${2:-testing-harness}"
[[ -f "$root/skills/$skill/SKILL.md" ]] || { echo "No skill at skills/$skill" >&2; exit 1; }
out="${1:-$root/dist/$skill-skill.zip}"
case "$out" in /*) ;; *) out="$PWD/$out" ;; esac
mkdir -p "$(dirname "$out")"
rm -f "$out"
(cd "$root/skills" && zip -qr "$out" "$skill" -x '*.DS_Store')
echo "Wrote $out"
