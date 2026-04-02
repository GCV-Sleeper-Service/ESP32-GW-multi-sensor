#!/usr/bin/env bash
# =============================================================================
# Device Test Script — v7.6.0.3: POST /api/aggregator/test-satellite
# =============================================================================
# Prerequisites:
#   - S3 aggregator flashed with v7.6.0.3 firmware
#   - Device reachable at $AGG_HOST
#   - A reachable satellite at $SAT_URL (default: http://192.168.120.189)
#   - provision.sh aggregator already run (aggregator mode active)
#
# Usage:
#   bash scripts/device-test-v7.6.0.3.sh [aggregator_ip] [satellite_url]
#
# Defaults:
#   aggregator_ip  = 192.168.120.191
#   satellite_url  = http://192.168.120.189
#
# Output: Markdown table suitable for pasting into a PR comment or audit doc.
# =============================================================================

set -uo pipefail

AGG_IP="${1:-192.168.120.191}"
SAT_URL="${2:-http://192.168.120.189}"
AGG_HOST="http://${AGG_IP}"
AUTH_USER="ESPadmin"
AUTH_PASS="ESPpass100"

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
PASS_COUNT=0; FAIL_COUNT=0; SKIP_COUNT=0

record_result() {
  local name="$1" expected="$2" actual="$3" note="${4:-}"
  TEST_NAMES+=("$name"); TEST_EXPECTED+=("$expected"); TEST_ACTUAL+=("$actual"); TEST_NOTES+=("$note")
  if [[ "$expected" == "$actual" ]]; then
    TEST_MATCH_RESULTS+=("PASS"); ((PASS_COUNT++)) || true
  else
    TEST_MATCH_RESULTS+=("FAIL"); ((FAIL_COUNT++)) || true
  fi
}

record_skip() {
  local name="$1" reason="$2"
  TEST_NAMES+=("$name"); TEST_EXPECTED+=("—"); TEST_ACTUAL+=("—")
  TEST_MATCH_RESULTS+=("SKIP"); TEST_NOTES+=("$reason"); ((SKIP_COUNT++)) || true
}

# ── Curl helper ──────────────────────────────────────────────────────────────
do_curl() {
  local url="$1"; shift
  local tmpfile; tmpfile=$(mktemp)
  RESP_CODE=$(curl -s -o "$tmpfile" -w "%{http_code}" --max-time 15 "$@" "$url" 2>/dev/null) || RESP_CODE="000"
  RESP_BODY=$(cat "$tmpfile" 2>/dev/null || echo ""); rm -f "$tmpfile"
}

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

# ── Get satellite list as structured data ────────────────────────────────────
get_gateway_ids() {
  do_curl "${AGG_HOST}/api/aggregator/gateways"
  echo "$RESP_BODY" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for gw in data.get('gateways', []):
        print(f\"{gw.get('id','?')}|{gw.get('base_url','?')}|{gw.get('reachable','?')}\")
except: pass
" 2>/dev/null
}

# ── Pre-flight ───────────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║ Device Test — v7.6.0.3: POST /api/aggregator/test-satellite ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "  Aggregator : ${AGG_HOST}"
echo "  Satellite  : ${SAT_URL}"
echo ""

echo -n "Pre-flight: checking aggregator reachability... "
do_curl "${AGG_HOST}/api/status"
if [[ "$RESP_CODE" != "200" ]]; then
  echo -e "${RED}FAIL${NC} (HTTP ${RESP_CODE})"
  echo "ERROR: Aggregator not reachable at ${AGG_HOST}. Aborting."; exit 1
fi
echo -e "${GREEN}OK${NC} (HTTP 200)"
FW_VERSION=$(json_field "$RESP_BODY" "version")
echo "  Firmware version: ${FW_VERSION:-unknown}"
echo ""

# ── Diagnostics ──────────────────────────────────────────────────────────────
echo -e "${CYAN}─── Pre-flight diagnostics ───${NC}"
PRE_SATS=$(get_gateway_ids)
PRE_COUNT=$(echo "$PRE_SATS" | grep -c '|' || echo "0")
echo "  Current satellites (${PRE_COUNT}):"
while IFS='|' read -r sid surl sreachable; do
  [[ -z "$sid" ]] && continue
  echo "    - ${sid} → ${surl} (reachable=${sreachable})"
done <<< "$PRE_SATS"
echo "  (Snapshot saved for T4 side-effect check)"
echo ""

# =============================================================================
#  GROUP A: Happy path
# =============================================================================
echo -e "${CYAN}═══ Group A: Happy path ═══${NC}"
echo ""

# ── T1: Test reachable satellite ─────────────────────────────────────────────
echo -e "${CYAN}─── T1: Test reachable satellite (${SAT_URL}) ───${NC}"
do_curl "${AGG_HOST}/api/aggregator/test-satellite?url=${SAT_URL}" \
  -X POST -d 'a=1' -u "${AUTH_USER}:${AUTH_PASS}"
echo "  HTTP ${RESP_CODE}: ${RESP_BODY}"

T1_OK=false
if [[ "$RESP_CODE" == "200" ]]; then
  T1_RESULT=$(echo "$RESP_BODY" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    ok = d.get('ok', False)
    gw = d.get('gateway', {})
    gw_id = gw.get('id', '')
    gw_hw = gw.get('hardware', '')
    gw_sc = gw.get('sensor_count', 0)
    issues = []
    if not ok: issues.append('ok!=true')
    if not gw_id: issues.append('id empty')
    if not gw_hw: issues.append('hardware empty')
    if not isinstance(gw_sc, int) or gw_sc <= 0: issues.append(f'sensor_count={gw_sc}<=0')
    if issues:
        print('FAIL:' + ','.join(issues))
    else:
        print('PASS')
except Exception as e:
    print('FAIL:parse_error')
" 2>/dev/null || echo "FAIL:python_error")

  if [[ "$T1_RESULT" == "PASS" ]]; then
    T1_OK=true
    T1_GW_ID=$(echo "$RESP_BODY" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('gateway',{}).get('id',''))" 2>/dev/null || echo "")
    T1_GW_HW=$(echo "$RESP_BODY" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('gateway',{}).get('hardware',''))" 2>/dev/null || echo "")
    T1_GW_SC=$(echo "$RESP_BODY" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('gateway',{}).get('sensor_count',0))" 2>/dev/null || echo "0")
    echo -e "  ${GREEN}PASS${NC}: ok=true, id=${T1_GW_ID}, hardware=${T1_GW_HW}, sensor_count=${T1_GW_SC}"
    record_result "T1: Reachable satellite" "HTTP 200 + ok=true + gateway" "HTTP 200 + ok=true + gateway"
  else
    echo -e "  ${RED}FAIL${NC}: ${T1_RESULT}"
    record_result "T1: Reachable satellite" "HTTP 200 + ok=true + gateway" "HTTP 200 but ${T1_RESULT}"
  fi
else
  echo -e "  ${RED}FAIL${NC}: unexpected HTTP ${RESP_CODE}"
  record_result "T1: Reachable satellite" "HTTP 200 + ok=true + gateway" "HTTP ${RESP_CODE}"
fi
echo ""

# ── T4: Verify no side effects ───────────────────────────────────────────────
echo -e "${CYAN}─── T4: Verify no side effects (satellite count unchanged) ───${NC}"
POST_SATS=$(get_gateway_ids)
POST_COUNT=$(echo "$POST_SATS" | grep -c '|' || echo "0")
echo "  Satellite count before test-satellite: ${PRE_COUNT}"
echo "  Satellite count after  test-satellite: ${POST_COUNT}"
if [[ "$PRE_COUNT" == "$POST_COUNT" ]]; then
  echo -e "  ${GREEN}NO SIDE EFFECTS${NC}: count unchanged (${PRE_COUNT})"
  record_result "T4: No side effects" "count unchanged" "count unchanged"
else
  echo -e "  ${RED}SIDE EFFECT DETECTED${NC}: count changed ${PRE_COUNT} → ${POST_COUNT}"
  record_result "T4: No side effects" "count unchanged" "count changed (${PRE_COUNT}→${POST_COUNT})"
fi
echo ""

# =============================================================================
#  GROUP B: Error paths
# =============================================================================
echo -e "${CYAN}═══ Group B: Error paths ═══${NC}"
echo ""

# ── T2: Unreachable URL (use --max-time 20 — probe timeout may take ~5s) ─────
echo -e "${CYAN}─── T2: Unreachable URL (may take up to 20s — probe timeout) ───${NC}"
UNREACH_URL="http://192.168.120.250"
T2_TMPFILE=$(mktemp)
T2_START=$(date +%s)
RESP_CODE=$(curl -s -o "$T2_TMPFILE" -w "%{http_code}" --max-time 20 \
  -X POST -d 'a=1' -u "${AUTH_USER}:${AUTH_PASS}" \
  "${AGG_HOST}/api/aggregator/test-satellite?url=${UNREACH_URL}" 2>/dev/null) || RESP_CODE="000"
RESP_BODY=$(cat "$T2_TMPFILE" 2>/dev/null || echo ""); rm -f "$T2_TMPFILE"
T2_END=$(date +%s)
T2_ELAPSED=$((T2_END - T2_START))
echo "  HTTP ${RESP_CODE} (${T2_ELAPSED}s): ${RESP_BODY}"
T2_MSG=$(json_field "$RESP_BODY" "message")
if [[ "$RESP_CODE" == "400" ]] && echo "$T2_MSG" | grep -qiF "Satellite unreachable or invalid manifest"; then
  record_result "T2: Unreachable URL" "HTTP 400 + correct message" "HTTP 400 + correct message"
else
  record_result "T2: Unreachable URL" "HTTP 400 + correct message" "HTTP ${RESP_CODE}, msg='${T2_MSG}'"
fi
echo ""

# ── T3: Missing URL parameter ─────────────────────────────────────────────────
echo -e "${CYAN}─── T3: Missing URL parameter ───${NC}"
do_curl "${AGG_HOST}/api/aggregator/test-satellite" \
  -X POST -d 'a=1' -u "${AUTH_USER}:${AUTH_PASS}"
echo "  HTTP ${RESP_CODE}: ${RESP_BODY}"
T3_MSG=$(json_field "$RESP_BODY" "message")
if [[ "$RESP_CODE" == "400" ]] && echo "$T3_MSG" | grep -qiF "Missing url parameter"; then
  record_result "T3: Missing URL parameter" "HTTP 400 + correct message" "HTTP 400 + correct message"
else
  record_result "T3: Missing URL parameter" "HTTP 400 + correct message" "HTTP ${RESP_CODE}, msg='${T3_MSG}'"
fi
echo ""

# ── T5: Bad URL format (ftp://) ───────────────────────────────────────────────
echo -e "${CYAN}─── T5: Bad URL format (ftp://) ───${NC}"
do_curl "${AGG_HOST}/api/aggregator/test-satellite?url=ftp://192.168.120.189" \
  -X POST -d 'a=1' -u "${AUTH_USER}:${AUTH_PASS}"
echo "  HTTP ${RESP_CODE}: ${RESP_BODY}"
T5_MSG=$(json_field "$RESP_BODY" "message")
if [[ "$RESP_CODE" == "400" ]] && echo "$T5_MSG" | grep -qiF "URL must start with http://"; then
  record_result "T5: Bad URL format" "HTTP 400 + correct message" "HTTP 400 + correct message"
else
  record_result "T5: Bad URL format" "HTTP 400 + correct message" "HTTP ${RESP_CODE}, msg='${T5_MSG}'"
fi
echo ""

# =============================================================================
#  GROUP C: Wrong method
# =============================================================================
echo -e "${CYAN}═══ Group C: Wrong method ═══${NC}"
echo ""

# ── T6: Wrong method (GET) ────────────────────────────────────────────────────
echo -e "${CYAN}─── T6: Wrong method (GET) ───${NC}"
do_curl "${AGG_HOST}/api/aggregator/test-satellite?url=${SAT_URL}" \
  -u "${AUTH_USER}:${AUTH_PASS}"
echo "  HTTP ${RESP_CODE}: ${RESP_BODY}"
T6_MSG=$(json_field "$RESP_BODY" "message")
if [[ "$RESP_CODE" == "405" ]] && echo "$T6_MSG" | grep -qiF "Method not allowed"; then
  record_result "T6: Wrong method (GET)" "HTTP 405 + correct message" "HTTP 405 + correct message"
else
  record_result "T6: Wrong method (GET)" "HTTP 405 + correct message" "HTTP ${RESP_CODE}, msg='${T6_MSG}'"
fi
echo ""

# ── T7: Wrong method (DELETE) ─────────────────────────────────────────────────
echo -e "${CYAN}─── T7: Wrong method (DELETE) ───${NC}"
do_curl "${AGG_HOST}/api/aggregator/test-satellite?url=${SAT_URL}" \
  -X DELETE -u "${AUTH_USER}:${AUTH_PASS}"
echo "  HTTP ${RESP_CODE}: ${RESP_BODY}"
T7_MSG=$(json_field "$RESP_BODY" "message")
if [[ "$RESP_CODE" == "405" ]] && echo "$T7_MSG" | grep -qiF "Method not allowed"; then
  record_result "T7: Wrong method (DELETE)" "HTTP 405 + correct message" "HTTP 405 + correct message"
else
  record_result "T7: Wrong method (DELETE)" "HTTP 405 + correct message" "HTTP ${RESP_CODE}, msg='${T7_MSG}'"
fi
echo ""

# =============================================================================
#  RESULTS TABLE
# =============================================================================
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "## v7.6.0.3 Device Test Results"
echo ""
echo "| # | Test | Expected | Actual | Result | Notes |"
echo "|---|------|----------|--------|--------|-------|"
for i in "${!TEST_NAMES[@]}"; do
  exp="${TEST_EXPECTED[$i]}"; act="${TEST_ACTUAL[$i]}"; note="${TEST_NOTES[$i]}"
  [[ ${#exp} -gt 55 ]] && exp="${exp:0:52}..."
  [[ ${#act} -gt 55 ]] && act="${act:0:52}..."
  [[ ${#note} -gt 60 ]] && note="${note:0:57}..."
  printf "| %s | %s | %s | %s | %s | %s |\n" \
    "$((i+1))" "${TEST_NAMES[$i]}" "$exp" "$act" "${TEST_MATCH_RESULTS[$i]}" "$note"
done
echo ""
echo "**Summary:** ${PASS_COUNT} passed, ${FAIL_COUNT} failed, ${SKIP_COUNT} skipped"
echo ""
echo "**Test environment:**"
echo "- Aggregator: ${AGG_HOST}"
echo "- Satellite URL: ${SAT_URL}"
echo "- Firmware: ${FW_VERSION:-unknown}"
echo "- Initial satellites: ${PRE_COUNT}"
echo "- Date: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "- Script: scripts/device-test-v7.6.0.3.sh"
echo ""

echo "### Coverage Notes"
echo ""
echo "| Area | Status | Notes |"
echo "|------|--------|-------|"
echo "| Happy: reachable satellite | ✅ Tested | T1 (200 + ok=true + gateway object) |"
echo "| Happy: no side effects | ✅ Tested | T4 (count unchanged after test-satellite) |"
echo "| Error: unreachable URL | ✅ Tested | T2 (400 + unreachable message, max-time 20s) |"
echo "| Error: missing URL param | ✅ Tested | T3 (400 + missing url parameter message) |"
echo "| Error: bad URL format | ✅ Tested | T5 (400 + URL must start with http://) |"
echo "| Wrong method: GET | ✅ Tested | T6 (405 + Method not allowed) |"
echo "| Wrong method: DELETE | ✅ Tested | T7 (405 + Method not allowed) |"
echo ""
echo "═══════════════════════════════════════════════════════════════"

if [[ "$FAIL_COUNT" -gt 0 ]]; then exit 1; fi
exit 0
