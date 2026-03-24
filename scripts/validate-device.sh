#!/usr/bin/env bash
# Validate a deployed ESP32 gateway device.
# Usage: bash scripts/validate-device.sh <device-ip> [satellite|aggregator]
set -euo pipefail

DEVICE_IP="${1:-}"
ROLE="${2:-satellite}"

if [[ -z "$DEVICE_IP" ]]; then
  echo "Usage: bash scripts/validate-device.sh <device-ip> [satellite|aggregator]"
  exit 1
fi

PASS=0
FAIL=0
TOTAL=0

check() {
  TOTAL=$((TOTAL + 1))
  local name="$1" expected="$2" actual="$3"
  if [[ "$actual" == *"$expected"* ]]; then
    echo "  ✓ $name"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $name — expected '$expected', got '$(echo "$actual" | head -c 120)'"
    FAIL=$((FAIL + 1))
  fi
}

echo "Validating $ROLE at $DEVICE_IP..."
echo ""

# ── Connectivity ─────────────────────────────────────────────────
echo "→ Connectivity"
PING_RESULT=$(ping -c 1 -W 2 "$DEVICE_IP" 2>&1 || true)
check "ping" "1 received" "$PING_RESULT"

# ── API status ───────────────────────────────────────────────────
echo "→ API status"
STATUS=$(curl -sf --max-time 5 "http://$DEVICE_IP/api/status" 2>&1 || echo "CURL_FAILED")
check "api/status responds" '"ok":true' "$STATUS"
check "version present" '"version":' "$STATUS"

if [[ "$STATUS" != "CURL_FAILED" ]]; then
  VERSION=$(echo "$STATUS" | python3 -c "import sys,json; print(json.load(sys.stdin).get('version','?'))" 2>/dev/null || echo "?")
  HEAP=$(echo "$STATUS" | python3 -c "import sys,json; print(json.load(sys.stdin).get('free_heap',0))" 2>/dev/null || echo "0")
  SENSORS=$(echo "$STATUS" | python3 -c "import sys,json; print(json.load(sys.stdin).get('sensor_count',0))" 2>/dev/null || echo "0")
  echo "  → version=$VERSION heap=$HEAP sensors=$SENSORS"
  HEAP_OK=$(python3 -c "print('true' if int('$HEAP') > 20000 else 'false')" 2>/dev/null || echo "false")
  check "heap > 20KB" "true" "$HEAP_OK"
fi

# ── Manifest ─────────────────────────────────────────────────────
echo "→ Manifest"
MANIFEST=$(curl -sf --max-time 5 "http://$DEVICE_IP/api/manifest" 2>&1 || echo "CURL_FAILED")
if [[ "$MANIFEST" == "CURL_FAILED" ]]; then
  check "api/manifest responds" '"schema_version"' "$MANIFEST"
else
  MANIFEST_SCHEMA_VERSION=$(echo "$MANIFEST" | python3 -c "import sys,json; print(json.load(sys.stdin).get('schema_version','?'))" 2>/dev/null || echo "?")
  check "api/manifest schema_version==2" "2" "$MANIFEST_SCHEMA_VERSION"
fi

# ── Dashboard ────────────────────────────────────────────────────
echo "→ Dashboard"
DASH_CODE=$(curl -sf -o /dev/null -w "%{http_code}" --max-time 5 "http://$DEVICE_IP/dashboard" 2>&1 || echo "000")
check "dashboard serves (200)" "200" "$DASH_CODE"

# ── Role-specific checks ────────────────────────────────────────
if [[ "$ROLE" == "aggregator" ]]; then
  echo "→ Aggregator endpoints"
  AGG=$(curl -sf --max-time 5 "http://$DEVICE_IP/api/aggregator/gateways" 2>&1 || echo "CURL_FAILED")
  if [[ "$AGG" == "CURL_FAILED" ]]; then
    echo "  ⊘ aggregator/gateways: not yet implemented (expected pre-v7.5.5.2)"
  else
    check "aggregator/gateways responds" '"gateways"' "$AGG"
  fi
fi

if [[ "$ROLE" == "satellite" ]]; then
  echo "→ Satellite endpoints"
  LIVE=$(curl -sf --max-time 5 "http://$DEVICE_IP/api/v2/live" 2>&1 || echo "CURL_FAILED")
  check "api/v2/live responds" '"devices"' "$LIVE"
fi

# ── Heap stability (10s window) ──────────────────────────────────
echo "→ Heap stability (10s)"
HEAP1=$(curl -sf --max-time 5 "http://$DEVICE_IP/api/status" 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('free_heap',0))" 2>/dev/null || echo "0")
sleep 10
HEAP2=$(curl -sf --max-time 5 "http://$DEVICE_IP/api/status" 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('free_heap',0))" 2>/dev/null || echo "0")
DRIFT=$((HEAP1 - HEAP2))
DRIFT_ABS=${DRIFT#-}
DRIFT_OK=$(python3 -c "print('true' if int('$DRIFT_ABS') < 10000 else 'false')" 2>/dev/null || echo "false")
check "heap drift < 10KB" "true" "$DRIFT_OK"
echo "  → heap: $HEAP1 → $HEAP2 (drift: $DRIFT bytes)"

# ── Summary ──────────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════"
echo "  $PASS passed, $FAIL failed, $TOTAL total"
if [[ $FAIL -gt 0 ]]; then
  echo "  ✗ VALIDATION FAILED"
  exit 1
else
  echo "  ✓ ALL CHECKS PASSED"
fi
