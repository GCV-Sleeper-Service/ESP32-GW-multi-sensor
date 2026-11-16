#!/usr/bin/env bash
# tests/lint-prompts/run-fixtures.sh - each lint rule L8 to L11 of scripts/lint-prompts.sh against its
# passing and its failing fixture in this folder, in normal mode and in --baseline mode (R5).
# The fixtures hold made-up values only. Exit 0 only if every case gives its expected result.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FX="tests/lint-prompts"
pass=0; fail=0
check() { # $1 name, $2 expected, $3 actual
  if [[ "$2" == "$3" ]]; then pass=$((pass+1)); printf 'ok    %-50s %s\n' "$1" "$3"
  else fail=$((fail+1)); printf 'FAIL  %-50s expected %s, got %s\n' "$1" "$2" "$3"; fi
}
lint() { # $1 repository root, $2 rule, then lint arguments; prints "<exit> <ERROR lines> <EXISTING lines>" of that rule
  local root="$1" rule="$2" out rc; shift 2
  out="$(bash "$root/scripts/lint-prompts.sh" "$@" 2>&1)"; rc=$?
  printf '%s %s %s\n' "$rc" "$(grep -c "^ERROR .*\[$rule\]" <<< "$out")" "$(grep -c "^EXISTING .*\[$rule\]" <<< "$out")"
}

# The L8 fixtures assume the live yield value 5 of maybe_yield_nvs_scan_().
live="$(grep -A6 '^static void maybe_yield_nvs_scan_(' "$ROOT/firmware/core/nvs-persistence.h" 2>/dev/null \
  | grep -oE 'pdMS_TO_TICKS\([0-9]+\)' | head -n 1 | grep -oE '[0-9]+' || true)"
[[ "$live" == "5" ]] || { echo "the live value of maybe_yield_nvs_scan_() is '${live}', the L8 fixtures assume 5"; exit 2; }

# ---------- normal mode: every violation is an ERROR ----------
check "L8 passing fixture"   "0 0 0" "$(lint "$ROOT" L8  "$FX/L8-pass.md")"
check "L8 failing fixture"   "1 1 0" "$(lint "$ROOT" L8  "$FX/L8-fail.md")"
check "L9 passing fixture"   "0 0 0" "$(lint "$ROOT" L9  "$FX/v0.0.0.1-agent-prompt-L9-pass.md")"
check "L9 failing fixture"   "1 1 0" "$(lint "$ROOT" L9  "$FX/v0.0.0.2-agent-prompt-L9-fail.md")"
check "L10 passing fixture"  "0 0 0" "$(lint "$ROOT" L10 "$FX/L10-pass-agent-prompt.md")"
check "L10 failing fixture"  "1 2 0" "$(lint "$ROOT" L10 "$FX/L10-fail-agent-prompt.md")"
check "L11 passing fixture"  "0 0 0" "$(lint "$ROOT" L11 "$FX/L11-pass.md")"
check "L11 failing fixture"  "1 2 0" "$(lint "$ROOT" L11 "$FX/L11-fail.md")"

# ---------- baseline mode: a violation that the baseline has is EXISTING and does not block ----------
T="$(mktemp -d)"
mkdir -p "$T/scripts" "$T/firmware/core" "$T/$FX"
cp "$ROOT/scripts/lint-prompts.sh" "$T/scripts/"
cp "$ROOT/firmware/core/nvs-persistence.h" "$T/firmware/core/"
cp "$ROOT/$FX/L8-fail.md" "$ROOT/$FX/v0.0.0.2-agent-prompt-L9-fail.md" "$ROOT/$FX/L10-fail-agent-prompt.md" "$ROOT/$FX/L11-fail.md" "$T/$FX/"
( cd "$T" && git init -q . && git config user.name t && git config user.email t@t && git add -A && git commit -qm baseline ) \
  || { echo "cannot create the baseline repository"; exit 2; }
check "L8 baseline: existing violation"  "0 0 1" "$(lint "$T" L8  --baseline HEAD "$FX/L8-fail.md")"
check "L9 baseline: existing violation"  "0 0 1" "$(lint "$T" L9  --baseline HEAD "$FX/v0.0.0.2-agent-prompt-L9-fail.md")"
check "L10 baseline: existing violations" "0 0 2" "$(lint "$T" L10 --baseline HEAD "$FX/L10-fail-agent-prompt.md")"
check "L11 baseline: existing violations" "0 0 2" "$(lint "$T" L11 --baseline HEAD "$FX/L11-fail.md")"
printf 'curl -s --user "%s:%s" http://192.0.2.11/api/status/full\n' second-user second-pass >> "$T/$FX/L11-fail.md"
check "L11 baseline: new violation beside existing" "1 1 2" "$(lint "$T" L11 --baseline HEAD "$FX/L11-fail.md")"
rm -rf "$T"

echo "----"; echo "lint fixtures: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
