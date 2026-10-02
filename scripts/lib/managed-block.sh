# shellcheck shell=bash
# Insert, replace or remove the block between the equilux-testing-harness markers in a text file.
# The block file itself must contain the BEGIN and END marker lines.

HARNESS_BEGIN='<!-- BEGIN equilux-testing-harness'
HARNESS_END='<!-- END equilux-testing-harness -->'

# upsert_block <target-file> <block-file>
upsert_block() {
  local target="$1" block="$2" tmp
  if [[ -f "$target" ]] && grep -qF "$HARNESS_BEGIN" "$target"; then
    tmp="$(mktemp)"
    awk -v bf="$block" -v b0="$HARNESS_BEGIN" -v e0="$HARNESS_END" '
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

# remove_block <target-file>
remove_block() {
  local target="$1" tmp
  [[ -f "$target" ]] && grep -qF "$HARNESS_BEGIN" "$target" || return 0
  tmp="$(mktemp)"
  awk -v b0="$HARNESS_BEGIN" -v e0="$HARNESS_END" '
    index($0, b0) == 1 { skip = 1; next }
    skip && index($0, e0) == 1 { skip = 0; next }
    !skip { print }
  ' "$target" > "$tmp"
  cat "$tmp" > "$target"
  rm -f "$tmp"
}
