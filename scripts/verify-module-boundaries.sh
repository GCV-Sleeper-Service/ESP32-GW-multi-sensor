#!/usr/bin/env bash
# verify-module-boundaries.sh
# Verifies that the Phase X module cut points match the actual dashboard.js
# Run from repo root. Useful both for v7.6.5.0 prompt validation and ongoing verification.
#
# Usage: bash scripts/verify-module-boundaries.sh [--pre-split | --post-split]
#   --pre-split  (default): verify boundaries against the monolith before splitting
#   --post-split: verify that concatenating modules reproduces the monolith

set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

MODE="${1:---pre-split}"
PASS=0
FAIL=0

pass() { echo "  ✅ $1"; PASS=$((PASS+1)); }
fail() { echo "  ❌ $1"; FAIL=$((FAIL+1)); }

# Module boundaries: name:start:end:first_landmark
# Landmarks are grep patterns for the first meaningful line in each module
BOUNDARIES=(
  "00-app-shell:1:82:Multi-Sensor Gateway Dashboard"
  "01-config-state:83:193:^var FILE_FALLBACK"
  "02-sensor-defs:194:374:var SENSOR_COLORS"
  "03-history-fetch:375:591:function parseHistoryMetricLines"
  "04-manifest:592:743:function makeSensorConfig"
  "05-status-snapshot:744:809:var TELEMETRY_IDS"
  "06-ui-helpers:810:1057:function esc"
  "07-staleness-derived:1058:1180:function calcDewPoint"
  "08-custom-range:1181:1511:var CustomRange"
  "09-export:1512:1575:function exportSensorCSV"
  "10-storage-stats:1576:1676:function applyStorageStats"
  "11-suspend-resume:1677:1762:function isImportActive"
  "12-management:1763:1932:function importFetchJsonWithRetry"
  "13-import:1933:2358:function importHistoryData"
  "14-cards:2359:2628:function updateBadge"
  "15-minmax:2629:2680:function updateMinMax"
  "16-charts:2681:2880:var FREEZING_LINE_PLUGIN"
  "17-live-updates:2881:3036:function updateBattery"
  "18-transport:3037:3313:function handleState"
  "19-aggregator:3314:3821:async function detectAggregatorMode"
  "20-boot:3822:3955:function updateBoardInfo"
)

JS="dashboard/dashboard.js"

if [[ ! -f "$JS" ]]; then
  echo "ERROR: $JS not found"
  exit 1
fi

TOTAL_LINES=$(wc -l < "$JS")
echo "=== Module Boundary Verification ==="
echo "File: $JS ($TOTAL_LINES lines)"
echo "Mode: $MODE"
echo ""

if [[ "$MODE" == "--pre-split" ]]; then
  echo "--- Checking landmarks at expected positions ---"
  for spec in "${BOUNDARIES[@]}"; do
    IFS=: read -r name start end landmark <<< "$spec"
    lines=$((end - start + 1))
    # Check that the landmark appears near the start line
    actual_line=$(grep -n "$landmark" "$JS" | head -1 | cut -d: -f1)
    if [[ -z "$actual_line" ]]; then
      fail "$name: landmark '$landmark' not found in $JS"
    elif [[ "$actual_line" -ge "$start" && "$actual_line" -le $((start + 5)) ]]; then
      pass "$name: lines $start–$end ($lines lines) — landmark at line $actual_line"
    else
      fail "$name: expected landmark near line $start, found at line $actual_line (drift: $((actual_line - start)))"
    fi
  done

  # Verify total
  expected_total=0
  for spec in "${BOUNDARIES[@]}"; do
    IFS=: read -r name start end landmark <<< "$spec"
    expected_total=$((expected_total + end - start + 1))
  done
  echo ""
  if [[ "$expected_total" -eq "$TOTAL_LINES" ]]; then
    pass "Total lines: $expected_total = $TOTAL_LINES (file line count)"
  else
    fail "Total lines: expected $expected_total, file has $TOTAL_LINES"
  fi

elif [[ "$MODE" == "--post-split" ]]; then
  echo "--- Checking module files exist and concatenation reproduces original ---"
  SRC_DIR="dashboard/src"
  if [[ ! -d "$SRC_DIR" ]]; then
    echo "ERROR: $SRC_DIR not found (run after v7.6.5.0 split)"
    exit 1
  fi

  MISSING=0
  for spec in "${BOUNDARIES[@]}"; do
    IFS=: read -r name start end landmark <<< "$spec"
    f="$SRC_DIR/${name}.js"
    if [[ -f "$f" ]]; then
      lines=$(wc -l < "$f")
      expected=$((end - start + 1))
      if [[ "$lines" -eq "$expected" ]]; then
        pass "$name: $lines lines (expected $expected)"
      else
        fail "$name: $lines lines (expected $expected)"
      fi
    else
      fail "$name: file $f not found"
      MISSING=$((MISSING+1))
    fi
  done

  if [[ "$MISSING" -eq 0 ]]; then
    echo ""
    echo "--- Concatenation identity check ---"
    TMP=$(mktemp)
    trap 'rm -f "$TMP"' EXIT
    for spec in "${BOUNDARIES[@]}"; do
      IFS=: read -r name start end landmark <<< "$spec"
      cat "$SRC_DIR/${name}.js" >> "$TMP"
    done
    if diff -q "$TMP" "$JS" >/dev/null 2>&1; then
      pass "Concatenation produces byte-identical dashboard.js"
    else
      fail "Concatenation does NOT match dashboard.js"
      diff "$TMP" "$JS" | head -10
    fi
  fi
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
