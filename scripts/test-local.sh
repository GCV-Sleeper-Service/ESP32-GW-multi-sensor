#!/usr/bin/env bash
# test-local.sh — runs preflight + compile + summary in one shot
# Mirrors what CI does, intended for local use before commit/push.
#
# Usage:
#   ./scripts/test-local.sh           # preflight + compile
#   ./scripts/test-local.sh --quick   # preflight only (no compile)
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

QUICK=false
[[ "${1:-}" == "--quick" ]] && QUICK=true

VERSION="$(tr -d '[:space:]' < VERSION)"
STAMP="$(date +%F-%H%M%S)"
mkdir -p build-logs

SEP="────────────────────────────────────────"

echo "$SEP"
echo "ESP32 Gateway local test — v${VERSION}"
echo "Date: $(date)"
echo "$SEP"

# ── Preflight ──
echo ""
echo "▶ Running preflight..."
PREFLIGHT_LOG="build-logs/preflight-${STAMP}.log"
if bash ./scripts/preflight.sh 2>&1 | tee "$PREFLIGHT_LOG"; then
  PREFLIGHT_STATUS="PASS"
else
  PREFLIGHT_STATUS="FAIL"
  echo ""
  echo "✗ Preflight failed. See: $PREFLIGHT_LOG"
  exit 1
fi

# ── Compile (unless --quick) ──
if $QUICK; then
  echo ""
  echo "$SEP"
  echo "Quick mode — skipping compile"
  echo "Preflight: $PREFLIGHT_STATUS"
  echo "$SEP"
  exit 0
fi

echo ""
echo "▶ Compiling firmware..."
COMPILE_LOG="build-logs/compile-${STAMP}.log"
if esphome compile firmware/esp32-c3-multi-sensor.yaml 2>&1 | tee "$COMPILE_LOG"; then
  COMPILE_STATUS="PASS"
else
  COMPILE_STATUS="FAIL"
fi

# ── Summary ──
echo ""
echo "$SEP"
echo "LOCAL TEST SUMMARY — v${VERSION} @ ${STAMP}"
echo "$SEP"

PASS_COUNT=$(grep -c ': PASS' "$PREFLIGHT_LOG" 2>/dev/null || echo 0)
echo "Preflight:  ${PREFLIGHT_STATUS} (${PASS_COUNT} checks)"

if [[ -f "$COMPILE_LOG" ]]; then
  DURATION=$(grep -oP 'SUCCESS\] Took \K[0-9.]+ seconds' "$COMPILE_LOG" 2>/dev/null | tail -1 || true)
  RAM=$(grep -E '^RAM:' "$COMPILE_LOG" | tail -1 || true)
  FLASH=$(grep -E '^Flash:' "$COMPILE_LOG" | tail -1 || true)
  echo "Compile:    ${COMPILE_STATUS}"
  [[ -n "$DURATION" ]] && echo "Duration:   ${DURATION}"
  [[ -n "$RAM" ]] && echo "  ${RAM}"
  [[ -n "$FLASH" ]] && echo "  ${FLASH}"
fi

echo "$SEP"

if [[ "$COMPILE_STATUS" == "FAIL" ]]; then
  echo "✗ Compile failed. See: $COMPILE_LOG"
  exit 1
fi

echo "✓ All local checks passed. Safe to commit and push."
