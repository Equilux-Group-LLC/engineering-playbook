#!/usr/bin/env bash
# Package skills/testing-harness as a zip for upload to claude.ai (Settings -> Capabilities -> Skills).
# Symlinks are followed, so the zip contains the real playbook text.
# Usage: build-skill-zip.sh [output.zip]   (default: dist/testing-harness-skill.zip)
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
out="${1:-$root/dist/testing-harness-skill.zip}"
case "$out" in /*) ;; *) out="$PWD/$out" ;; esac
mkdir -p "$(dirname "$out")"
rm -f "$out"
(cd "$root/skills" && zip -qr "$out" testing-harness -x '*.DS_Store')
echo "Wrote $out"
