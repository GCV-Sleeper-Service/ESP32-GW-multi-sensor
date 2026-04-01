#!/usr/bin/env bash
# =============================================================================
# Device Test Script — v7.6.0.1: POST /api/aggregator/add-satellite
# =============================================================================
# Prerequisites:
#   - S3 aggregator flashed with v7.6.0.1 firmware
#   - Device reachable at $AGG_HOST
#   - At least one real satellite reachable at $SAT_URL for happy-path tests
#
# Usage:
#   bash scripts/device-test-v7.6.0.1.sh [aggregator_ip] [satellite_url]
#
# Defaults:
#   aggregator_ip  = 192.168.120.191
#   satellite_url  = http://192.168.120.189
#
# Output: Markdown table suitable for pasting into a PR comment or audit doc.
# =============================================================================

# No set -e — all tests must run even if some fail
set -uo pipefail

AGG_IP="${1:-192.168.120.191}"
SAT_URL="${2:-http://192.168.120.189}"
AGG_HOST="http://${AGG_IP}"
REBOOT_USER="ESPadmin"
REBOOT_PASS="ESPpass100"
REBOOT_WAIT=40          # seconds to wait after reboot
POLL_WAIT=35            # seconds to wait for poll cycle pickup

# Colours (disabled if not a terminal)
if [[ -t 1 ]]; then
  GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
else
  GREEN=''; RED=''; YELLOW=''; CYAN=''; NC=''
fi

# ── Result tracking ──────────────────────────────────────────────────────────
declare -a TEST_NAMES=()
declare -a TEST_EXPECTED=()
declare -a TEST_ACTUAL=()
declare -a TEST_MATCH_RESULTS=()
declare -a TEST_NOTES=()
PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

record_result() {
  local name="$1" expected="$2" actual="$3" note="${4:-}"
  TEST_NAMES+=("$name")
  TEST_EXPECTED+=("$expected")
  TEST_ACTUAL+=("$actual")
  TEST_NOTES+=("$note")

  if [[ "$expected" == "$actual" ]]; then
    TEST_MATCH_RESULTS+=("PASS")
    ((PASS_COUNT++)) || true
  else
    TEST_MATCH_RESULTS+=("FAIL")
    ((FAIL_COUNT++)) || true
  fi
}

record_skip() {
  local name="$1" reason="$2"
  TEST_NAMES+=("$name")
  TEST_EXPECTED+=("—")
  TEST_ACTUAL+=("—")
  TEST_MATCH_RESULTS+=("SKIP")
  TEST_NOTES+=("$reason")
  ((SKIP_COUNT++)) || true
}

# ── Curl helper ──────────────────────────────────────────────────────────────
# Sets: RESP_CODE (HTTP status), RESP_BODY (body text)
do_curl() {
  local url="$1"
  shift
  local tmpfile
  tmpfile=$(mktemp)
  RESP_CODE=$(curl -s -o "$tmpfile" -w "%{http_code}" --max-time 15 "$@" "$url" 2>/dev/null) || RESP_CODE="000"
  RESP_BODY=$(cat "$tmpfile" 2>/dev/null || echo "")
  rm -f "$tmpfile"
}

# ── JSON field extractor (requires python3) ──────────────────────────────────
json_field() {
  local body="$1" field="$2"
  echo "$body" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('$field', ''))
except: print('')
" 2>/dev/null || echo ""
}

# ── Pre-flight: is the aggregator reachable? ────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  Device Test — v7.6.0.1: POST /api/aggregator/add-satellite ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "  Aggregator : ${AGG_HOST}"
echo "  Satellite  : ${SAT_URL}"
echo ""

echo -n "Pre-flight: checking aggregator reachability... "
do_curl "${AGG_HOST}/api/status"
if [[ "$RESP_CODE" != "200" ]]; then
  echo -e "${RED}FAIL${NC} (HTTP ${RESP_CODE})"
  echo "ERROR: Aggregator not reachable at ${AGG_HOST}. Aborting."
  exit 1
fi
echo -e "${GREEN}OK${NC} (HTTP 200)"

FW_VERSION=$(json_field "$RESP_BODY" "version")
echo "  Firmware version: ${FW_VERSION:-unknown}"
echo ""

# ── Diagnostics: current satellite state ────────────────────────────────────
echo -e "${CYAN}─── Pre-flight diagnostics ───${NC}"
do_curl "${AGG_HOST}/api/aggregator/gateways"
GATEWAY_BODY="$RESP_BODY"
GATEWAY_COUNT=$(echo "$GATEWAY_BODY" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    gw = data.get('gateways', [])
    print(len(gw))
except: print('?')
" 2>/dev/null || echo "?")

# List current satellites
echo "  Current satellites (${GATEWAY_COUNT}):"
echo "$GATEWAY_BODY" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for gw in data.get('gateways', []):
        print(f\"    - {gw.get('id','?')} → {gw.get('base_url','?')} (reachable={gw.get('reachable','?')})\")
except: print('    (parse error)')
" 2>/dev/null || echo "    (parse error)"

# Check if test satellite is already configured
TEST_SAT_EXISTS=false
if echo "$GATEWAY_BODY" | grep -qF "$SAT_URL"; then
  TEST_SAT_EXISTS=true
  echo -e "  Test satellite (${SAT_URL}): ${YELLOW}already present${NC}"
else
  echo -e "  Test satellite (${SAT_URL}): not present"
fi

# Determine capacity — can we add a satellite?
# We don't know MAX_SATELLITES from the API, so we try to detect it:
# If runtime_satellite_count == gateway count and adding returns 409 "Satellite list full",
# then we know we're at capacity.
CAN_ADD=unknown
echo ""

# =============================================================================
#  GROUP A: Error-path tests (work regardless of satellite capacity)
# =============================================================================
echo -e "${CYAN}═══ Group A: Error-path validation (capacity-independent) ═══${NC}"
echo ""

# ── TEST 1: Missing URL parameter ────────────────────────────────────────────
echo -e "${CYAN}─── Test 1: Missing URL parameter ───${NC}"
do_curl "${AGG_HOST}/api/aggregator/add-satellite" -d 'a=1'
echo "  HTTP ${RESP_CODE}: ${RESP_BODY}"
T1_MSG=$(json_field "$RESP_BODY" "message")
if [[ "$RESP_CODE" == "400" ]] && echo "$T1_MSG" | grep -qiF "Missing url parameter"; then
  record_result "T1: Missing URL param" "HTTP 400 + correct message" "HTTP 400 + correct message"
else
  record_result "T1: Missing URL param" "HTTP 400 + correct message" "HTTP ${RESP_CODE}, msg='${T1_MSG}'"
fi
echo ""

# ── TEST 2: Bad URL format ───────────────────────────────────────────────────
echo -e "${CYAN}─── Test 2: Bad URL format (ftp://) ───${NC}"
do_curl "${AGG_HOST}/api/aggregator/add-satellite?url=ftp://bad" -d 'a=1'
echo "  HTTP ${RESP_CODE}: ${RESP_BODY}"
T2_MSG=$(json_field "$RESP_BODY" "message")
if [[ "$RESP_CODE" == "400" ]] && echo "$T2_MSG" | grep -qiF "URL must start with http://"; then
  record_result "T2: Bad URL format" "HTTP 400 + correct message" "HTTP 400 + correct message"
else
  record_result "T2: Bad URL format" "HTTP 400 + correct message" "HTTP ${RESP_CODE}, msg='${T2_MSG}'"
fi
echo ""

# ── TEST 3: URL too long (>127 chars) ────────────────────────────────────────
echo -e "${CYAN}─── Test 3: URL too long (>127 chars) ───${NC}"
LONG_URL="http://$(python3 -c "print('x' * 122)")"   # 129 chars total (http:// = 7, + 122 = 129)
do_curl "${AGG_HOST}/api/aggregator/add-satellite?url=${LONG_URL}" -d 'a=1'
echo "  HTTP ${RESP_CODE}: ${RESP_BODY}"
T3_MSG=$(json_field "$RESP_BODY" "message")
if [[ "$RESP_CODE" == "400" ]] && echo "$T3_MSG" | grep -qiF "URL too long"; then
  record_result "T3: URL too long" "HTTP 400 + correct message" "HTTP 400 + correct message"
else
  record_result "T3: URL too long" "HTTP 400 + correct message" "HTTP ${RESP_CODE}, msg='${T3_MSG}'" \
    "Expected JSON with 'URL too long' message"
fi
echo ""

# ── TEST 4: Wrong HTTP method (GET instead of POST) ─────────────────────────
echo -e "${CYAN}─── Test 4: Wrong HTTP method (GET) ───${NC}"
do_curl "${AGG_HOST}/api/aggregator/add-satellite?url=http://test" -X GET
echo "  HTTP ${RESP_CODE}: ${RESP_BODY}"
T4_MSG=$(json_field "$RESP_BODY" "message")
if [[ "$RESP_CODE" == "405" ]] && echo "$T4_MSG" | grep -qiF "Method not allowed"; then
  record_result "T4: GET rejected" "HTTP 405 + correct message" "HTTP 405 + correct message"
else
  record_result "T4: GET rejected" "HTTP 405 + correct message" "HTTP ${RESP_CODE}, msg='${T4_MSG}'"
fi
echo ""

# ── TEST 5: Unreachable URL (may take ~5s) ───────────────────────────────────
echo -e "${CYAN}─── Test 5: Unreachable URL (expect ~5s timeout) ───${NC}"
do_curl "${AGG_HOST}/api/aggregator/add-satellite?url=http://192.168.120.250" -d 'a=1'
echo "  HTTP ${RESP_CODE}: ${RESP_BODY}"
T5_MSG=$(json_field "$RESP_BODY" "message")
if [[ "$RESP_CODE" == "400" ]] && echo "$T5_MSG" | grep -qiF "Satellite unreachable or invalid manifest"; then
  record_result "T5: Unreachable URL" "HTTP 400 + correct message" "HTTP 400 + correct message"
else
  record_result "T5: Unreachable URL" "HTTP 400 + correct message" "HTTP ${RESP_CODE}, msg='${T5_MSG}'"
fi
echo ""

# ── TEST 6: Duplicate URL rejection ──────────────────────────────────────────
echo -e "${CYAN}─── Test 6: Duplicate URL rejection ───${NC}"
# Use one of the already-configured satellite URLs
EXISTING_URL=$(echo "$GATEWAY_BODY" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    gws = data.get('gateways', [])
    if gws: print(gws[0].get('base_url', ''))
    else: print('')
except: print('')
" 2>/dev/null || echo "")

if [[ -n "$EXISTING_URL" ]]; then
  do_curl "${AGG_HOST}/api/aggregator/add-satellite?url=${EXISTING_URL}" -d 'a=1'
  echo "  HTTP ${RESP_CODE}: ${RESP_BODY}"
  T6_MSG=$(json_field "$RESP_BODY" "message")
  # Accept either "URL already configured" (409) or "Satellite list full" (409)
  # because both are valid — capacity check runs before duplicate check in the code
  if [[ "$RESP_CODE" == "409" ]]; then
    if echo "$T6_MSG" | grep -qiF "URL already configured"; then
      record_result "T6: Duplicate URL" "HTTP 409 + 'URL already configured'" "HTTP 409 + 'URL already configured'"
    elif echo "$T6_MSG" | grep -qiF "Satellite list full"; then
      record_result "T6: Duplicate URL" "HTTP 409 + 'URL already configured'" "HTTP 409 + 'Satellite list full'" \
        "Capacity check fires before duplicate check (at-capacity). Both are correct 409s."
    else
      record_result "T6: Duplicate URL" "HTTP 409 + 'URL already configured'" "HTTP 409, msg='${T6_MSG}'"
    fi
  else
    record_result "T6: Duplicate URL" "HTTP 409" "HTTP ${RESP_CODE}, msg='${T6_MSG}'"
  fi
else
  record_skip "T6: Duplicate URL" "No existing satellites found to duplicate"
fi
echo ""

# =============================================================================
#  GROUP B: Capacity-dependent tests (add satellite)
# =============================================================================
echo -e "${CYAN}═══ Group B: Add-satellite happy path (capacity-dependent) ═══${NC}"
echo ""

# Probe capacity by trying to add a non-existent satellite
# If we get "Satellite list full", we know MAX_SATELLITES == gateway count
echo "  Probing capacity..."
do_curl "${AGG_HOST}/api/aggregator/add-satellite?url=http://192.168.120.254&name=capacity-probe" -d 'a=1'
PROBE_MSG=$(json_field "$RESP_BODY" "message")
PROBE_CODE="$RESP_CODE"

if echo "$PROBE_MSG" | grep -qiF "Satellite list full"; then
  CAN_ADD=false
  echo -e "  ${YELLOW}At capacity${NC}: MAX_SATELLITES=${GATEWAY_COUNT} and ${GATEWAY_COUNT} configured."
  echo "  Cannot test add-satellite happy path without increasing MAX_SATELLITES."
  echo "  To fix: edit config/aggregator.json to add placeholder entries (or remove one),"
  echo "  then run: python3 scripts/render_sensor_config.py --write"
  echo "  This will increase MAX_SATELLITES in src/aggregator_config.h."
  echo ""
fi

# ── TEST 7: Satellite list full (only valid when at capacity) ────────────────
if [[ "$CAN_ADD" == "false" ]]; then
  echo -e "${CYAN}─── Test 7: Satellite list full ───${NC}"
  # We already have the probe result
  echo "  HTTP ${PROBE_CODE}: msg='${PROBE_MSG}'"
  if [[ "$PROBE_CODE" == "409" ]] && echo "$PROBE_MSG" | grep -qiF "Satellite list full"; then
    record_result "T7: Satellite list full" "HTTP 409 + 'Satellite list full'" "HTTP 409 + 'Satellite list full'"
  else
    record_result "T7: Satellite list full" "HTTP 409 + 'Satellite list full'" "HTTP ${PROBE_CODE}, msg='${PROBE_MSG}'"
  fi
  echo ""

  # Skip add/verify/reboot/cleanup tests
  record_skip "T8: Add satellite (happy path)" "At capacity (MAX_SATELLITES=${GATEWAY_COUNT})"
  record_skip "T9: Verify in gateways" "Depends on T8"
  record_skip "T10: Reboot persistence" "Depends on T8"
else
  # ── TEST 7: (skipped — not at capacity) ──────────────────────────────────
  record_skip "T7: Satellite list full" "Not at capacity — cannot test 'list full' rejection"

  # ── TEST 8: Add satellite (happy path) ─────────────────────────────────────
  echo -e "${CYAN}─── Test 8: Add satellite (happy path) ───${NC}"
  if [[ "$TEST_SAT_EXISTS" == "true" ]]; then
    record_skip "T8: Add satellite" "Test satellite already present"
  else
    do_curl "${AGG_HOST}/api/aggregator/add-satellite?url=${SAT_URL}&name=Test+Satellite" -d 'a=1'
    echo "  HTTP ${RESP_CODE}: ${RESP_BODY}"
    T8_OK=$(json_field "$RESP_BODY" "ok")
    if [[ "$RESP_CODE" == "200" ]] && [[ "$T8_OK" == "True" || "$T8_OK" == "true" ]]; then
      record_result "T8: Add satellite" "HTTP 200 + ok=true" "HTTP 200 + ok=true"
      ADDED_SAT=true
    else
      T8_MSG=$(json_field "$RESP_BODY" "message")
      record_result "T8: Add satellite" "HTTP 200 + ok=true" "HTTP ${RESP_CODE}, ok=${T8_OK}, msg='${T8_MSG}'"
      ADDED_SAT=false
    fi
  fi
  echo ""

  # ── TEST 9: Verify in gateways list ────────────────────────────────────────
  echo -e "${CYAN}─── Test 9: Verify in gateways list ───${NC}"
  if [[ "${ADDED_SAT:-false}" == "true" ]]; then
    echo "  Waiting ${POLL_WAIT}s for poll cycle pickup..."
    sleep "$POLL_WAIT"
  fi
  do_curl "${AGG_HOST}/api/aggregator/gateways"
  if echo "$RESP_BODY" | grep -qF "$SAT_URL"; then
    echo -e "  ${GREEN}FOUND${NC}: ${SAT_URL} in gateways list"
    record_result "T9: In gateways list" "found" "found"
  else
    echo -e "  ${RED}NOT FOUND${NC}: ${SAT_URL} missing"
    record_result "T9: In gateways list" "found" "not_found"
  fi
  echo ""

  # ── TEST 10: Reboot persistence ────────────────────────────────────────────
  echo -e "${CYAN}─── Test 10: Reboot persistence ───${NC}"
  echo "  Triggering reboot..."
  do_curl "${AGG_HOST}/api/reboot" -d 'a=1' -u "${REBOOT_USER}:${REBOOT_PASS}"
  if [[ "$RESP_CODE" == "200" || "$RESP_CODE" == "000" ]]; then
    echo "  Reboot triggered (HTTP ${RESP_CODE}). Waiting ${REBOOT_WAIT}s..."
    sleep "$REBOOT_WAIT"

    echo -n "  Waiting for device to come back"
    BACK=false
    for i in $(seq 1 12); do
      do_curl "${AGG_HOST}/api/status"
      if [[ "$RESP_CODE" == "200" ]]; then
        BACK=true
        echo -e " ${GREEN}UP${NC} (attempt ${i})"
        break
      fi
      echo -n "."
      sleep 5
    done

    if [[ "$BACK" == "true" ]]; then
      sleep 5
      do_curl "${AGG_HOST}/api/aggregator/gateways"
      if echo "$RESP_BODY" | grep -qF "$SAT_URL"; then
        echo -e "  ${GREEN}FOUND${NC}: Satellite persisted across reboot"
        record_result "T10: Reboot persistence" "found" "found"
      else
        echo -e "  ${RED}NOT FOUND${NC}: Satellite missing after reboot"
        record_result "T10: Reboot persistence" "found" "not_found"
      fi
    else
      echo -e " ${RED}TIMEOUT${NC}"
      record_result "T10: Reboot persistence" "found" "timeout" "Device did not come back within 60s"
    fi
  else
    record_skip "T10: Reboot persistence" "Reboot request failed: HTTP ${RESP_CODE}"
  fi
  echo ""
fi

# =============================================================================
#  RESULTS TABLE
# =============================================================================
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "## v7.6.0.1 Device Test Results"
echo ""
echo "| # | Test | Expected | Actual | Result | Notes |"
echo "|---|------|----------|--------|--------|-------|"
for i in "${!TEST_NAMES[@]}"; do
  exp="${TEST_EXPECTED[$i]}"
  act="${TEST_ACTUAL[$i]}"
  [[ ${#exp} -gt 55 ]] && exp="${exp:0:52}..."
  [[ ${#act} -gt 55 ]] && act="${act:0:52}..."
  note="${TEST_NOTES[$i]}"
  [[ ${#note} -gt 60 ]] && note="${note:0:57}..."
  printf "| %s | %s | %s | %s | %s | %s |\n" \
    "$((i+1))" \
    "${TEST_NAMES[$i]}" \
    "$exp" \
    "$act" \
    "${TEST_MATCH_RESULTS[$i]}" \
    "$note"
done
echo ""
echo "**Summary:** ${PASS_COUNT} passed, ${FAIL_COUNT} failed, ${SKIP_COUNT} skipped"
echo ""
echo "**Test environment:**"
echo "- Aggregator: ${AGG_HOST}"
echo "- Firmware: ${FW_VERSION:-unknown}"
echo "- Satellite: ${SAT_URL}"
echo "- Gateway count: ${GATEWAY_COUNT}"
echo "- Date: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "- Script: scripts/device-test-v7.6.0.1.sh"
echo ""

# ── Diagnostic Notes ─────────────────────────────────────────────────────────
if [[ "$CAN_ADD" == "false" ]]; then
  echo "### ⚠️  Capacity Constraint Detected"
  echo ""
  echo "MAX_SATELLITES=${GATEWAY_COUNT} and all slots are filled. Tests 8–10 (add + verify + reboot)"
  echo "cannot run. To enable full testing:"
  echo ""
  echo "1. Edit \`config/aggregator.json\` — add a 3rd placeholder satellite entry"
  echo "2. Run: \`python3 scripts/render_sensor_config.py --write\`"
  echo "3. Verify: \`grep MAX_SATELLITES src/aggregator_config.h\` → should show 3+"
  echo "4. Rebuild and flash the firmware"
  echo "5. Rerun this script"
  echo ""
fi

echo "### Coverage Notes"
echo ""
echo "| Area | Status | Notes |"
echo "|------|--------|-------|"
echo "| Error: missing URL | ✅ Tested | T1 |"
echo "| Error: bad URL format | ✅ Tested | T2 |"
echo "| Error: URL too long | ✅ Tested | T3 (Fix 5 from review) |"
echo "| Error: wrong method | ✅ Tested | T4 |"
echo "| Error: unreachable | ✅ Tested | T5 |"
echo "| Error: duplicate URL | ✅ Tested | T6 (uses pre-existing satellite) |"
echo "| Error: list full | Conditional | T7 (only when at capacity) |"
echo "| Happy: add satellite | Conditional | T8 (requires free slot) |"
echo "| Happy: gateways verify | Conditional | T9 (depends on T8) |"
echo "| Happy: reboot persist | Conditional | T10 (depends on T8) |"
echo "| NVS rollback on failure | ❌ Untestable | Fix 4 — requires NVS corruption |"
echo "| Custom poll param | ❌ Not tested | Requires free slot + second satellite |"
echo ""
echo "═══════════════════════════════════════════════════════════════"

# Exit code reflects test results (SKIP does not count as failure)
if [[ "$FAIL_COUNT" -gt 0 ]]; then
  exit 1
fi
exit 0