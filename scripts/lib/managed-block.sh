# shellcheck shell=bash
# Insert, replace or remove a marked block in a text file. Blocks are delimited by
# "<!-- BEGIN <name>" and "<!-- END <name> -->" lines; the block file itself must contain both marker lines.
# <name> defaults to equilux-testing-harness.

HARNESS_BLOCK='equilux-testing-harness'

# upsert_block <target-file> <block-file> [name]
upsert_block() {
  local target="$1" block="$2" name="${3:-$HARNESS_BLOCK}" tmp
  local b0="<!-- BEGIN $name" e0="<!-- END $name -->"
  if [[ -f "$target" ]] && grep -qF "$b0" "$target"; then
    tmp="$(mktemp)"
    awk -v bf="$block" -v b0="$b0" -v e0="$e0" '
      BEGIN { while ((getline line < bf) > 0) body = body line "\n" }
      index($0, b0) == 1 { printf "%s", body; skip = 1; next }
      skip && index($0, e0) == 1 { skip = 0; next }
      !skip { print }
    ' "$target" > "$tmp"
    cat "$tmp" > "$target"
    rm -f "$tmp"
  else
    mkdir -p "$(dirname "$target")"
    { if [[ -s "$target" ]]; then printf '\n'; fi; cat "$block"; } >> "$target"
  fi
}

# remove_block <target-file> [name]
remove_block() {
  local target="$1" name="${2:-$HARNESS_BLOCK}" tmp
  local b0="<!-- BEGIN $name" e0="<!-- END $name -->"
  [[ -f "$target" ]] && grep -qF "$b0" "$target" || return 0
  tmp="$(mktemp)"
  awk -v b0="$b0" -v e0="$e0" '
    index($0, b0) == 1 { skip = 1; next }
    skip && index($0, e0) == 1 { skip = 0; next }
    !skip { print }
  ' "$target" > "$tmp"
  cat "$tmp" > "$target"
  rm -f "$tmp"
}
