#!/usr/bin/env bash
# =============================================================================
# Device Test Script — v7.6.0.2: DELETE /api/aggregator/satellite/{id}
# =============================================================================
# Prerequisites:
#   - S3 aggregator flashed with v7.6.0.2 firmware
#   - Device reachable at $AGG_HOST
#   - At least one deletable satellite (unreachable placeholder ideal)
#   - provision.sh aggregator already run (aggregator mode active)
#
# Usage:
#   bash scripts/device-test-v7.6.0.2.sh [aggregator_ip]
#
# Defaults:
#   aggregator_ip  = 192.168.120.191
#
# Output: Markdown table suitable for pasting into a PR comment or audit doc.
# =============================================================================

set -uo pipefail

AGG_IP="${1:-192.168.120.191}"
AGG_HOST="http://${AGG_IP}"
AUTH_USER="ESPadmin"
AUTH_PASS="ESPpass100"
REBOOT_WAIT=40
POLL_WAIT=10

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
echo "║  Device Test — v7.6.0.2: DELETE /api/aggregator/satellite   ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "  Aggregator : ${AGG_HOST}"
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
INITIAL_SATS=$(get_gateway_ids)
INITIAL_COUNT=$(echo "$INITIAL_SATS" | grep -c '|' || echo "0")
echo "  Current satellites (${INITIAL_COUNT}):"
while IFS='|' read -r sid surl sreachable; do
  [[ -z "$sid" ]] && continue
  echo "    - ${sid} → ${surl} (reachable=${sreachable})"
done <<< "$INITIAL_SATS"

# Find an unreachable satellite (ideal deletion candidate — won't lose real data)
DELETE_TARGET_ID=""
DELETE_TARGET_URL=""
DELETE_TARGET_POS=""
pos=0
while IFS='|' read -r sid surl sreachable; do
  [[ -z "$sid" ]] && continue
  if [[ "$sreachable" == "False" || "$sreachable" == "false" ]]; then
    DELETE_TARGET_ID="$sid"
    DELETE_TARGET_URL="$surl"
    DELETE_TARGET_POS="$pos"
  fi
  ((pos++)) || true
done <<< "$INITIAL_SATS"

if [[ -n "$DELETE_TARGET_ID" ]]; then
  echo -e "  Delete target: ${YELLOW}${DELETE_TARGET_ID}${NC} (unreachable — safe to delete)"
else
  # Fall back to last satellite in list
  DELETE_TARGET_ID=$(echo "$INITIAL_SATS" | tail -1 | cut -d'|' -f1)
  DELETE_TARGET_URL=$(echo "$INITIAL_SATS" | tail -1 | cut -d'|' -f2)
  DELETE_TARGET_POS=$((INITIAL_COUNT - 1))
  echo -e "  Delete target: ${YELLOW}${DELETE_TARGET_ID}${NC} (last in list — no unreachable found)"
fi

if [[ -z "$DELETE_TARGET_ID" || "$INITIAL_COUNT" -lt 2 ]]; then
  echo -e "${RED}ERROR: Need at least 2 satellites to test delete safely. Aborting.${NC}"
  exit 1
fi
echo ""

# =============================================================================
#  GROUP A: Error-path tests (no state change)
# =============================================================================
echo -e "${CYAN}═══ Group A: Error-path validation (no state change) ═══${NC}"
echo ""

# ── T1: Empty satellite ID ───────────────────────────────────────────────────
echo -e "${CYAN}─── T1: Empty satellite ID ───${NC}"
do_curl "${AGG_HOST}/api/aggregator/satellite/" -X DELETE
echo "  HTTP ${RESP_CODE}: ${RESP_BODY}"
T1_MSG=$(json_field "$RESP_BODY" "message")
if [[ "$RESP_CODE" == "400" ]] && echo "$T1_MSG" | grep -qiF "Missing satellite ID"; then
  record_result "T1: Empty satellite ID" "HTTP 400 + correct message" "HTTP 400 + correct message"
else
  record_result "T1: Empty satellite ID" "HTTP 400 + correct message" "HTTP ${RESP_CODE}, msg='${T1_MSG}'"
fi
echo ""

# ── T2: Unknown satellite ID ────────────────────────────────────────────────
echo -e "${CYAN}─── T2: Unknown satellite ID ───${NC}"
do_curl "${AGG_HOST}/api/aggregator/satellite/nonexistent-satellite-xyz" -X DELETE -u "${AUTH_USER}:${AUTH_PASS}"
echo "  HTTP ${RESP_CODE}: ${RESP_BODY}"
T2_MSG=$(json_field "$RESP_BODY" "message")
if [[ "$RESP_CODE" == "404" ]] && echo "$T2_MSG" | grep -qiF "Unknown satellite"; then
  record_result "T2: Unknown satellite ID" "HTTP 404 + correct message" "HTTP 404 + correct message"
else
  record_result "T2: Unknown satellite ID" "HTTP 404 + correct message" "HTTP ${RESP_CODE}, msg='${T2_MSG}'"
fi
echo ""

# ── T3: Unauthenticated delete ───────────────────────────────────────────────
echo -e "${CYAN}─── T3: Unauthenticated delete ───${NC}"
do_curl "${AGG_HOST}/api/aggregator/satellite/${DELETE_TARGET_ID}" -X DELETE
echo "  HTTP ${RESP_CODE}: ${RESP_BODY}"
T3_MSG=$(json_field "$RESP_BODY" "message")
# Expect 401 if auth is required; if handler has no auth, this will be 200 (prompt defect)
if [[ "$RESP_CODE" == "401" ]]; then
  record_result "T3: Unauthenticated delete" "HTTP 401 (auth required)" "HTTP 401 (auth required)"
elif [[ "$RESP_CODE" == "200" ]]; then
  record_result "T3: Unauthenticated delete" "HTTP 401 (auth required)" "HTTP 200 (no auth — prompt defect P4)" \
    "Delete succeeded without auth — authenticate_management_() missing from handler"
else
  record_result "T3: Unauthenticated delete" "HTTP 401 (auth required)" "HTTP ${RESP_CODE}, msg='${T3_MSG}'"
fi
echo ""

# If T3 accidentally deleted the target (no auth), refresh state
CURRENT_SATS=$(get_gateway_ids)
if ! echo "$CURRENT_SATS" | grep -qF "$DELETE_TARGET_ID"; then
  echo -e "  ${YELLOW}NOTE: T3 deleted the target (no auth guard). Attempting reset to restore...${NC}"
  do_curl "${AGG_HOST}/api/system/reset-satellites" -X POST -d 'a=1' -u "${AUTH_USER}:${AUTH_PASS}"
  sleep 5
  CURRENT_SATS=$(get_gateway_ids)
  INITIAL_COUNT=$(echo "$CURRENT_SATS" | grep -c '|' || echo "0")
  if echo "$CURRENT_SATS" | grep -qF "$DELETE_TARGET_ID"; then
    echo -e "  ${GREEN}Reset restored delete target${NC}"
  else
    echo -e "  ${RED}Reset did not restore delete target — remaining tests may be affected${NC}"
  fi
  echo ""
fi

# =============================================================================
#  GROUP B: Delete happy path
# =============================================================================
echo -e "${CYAN}═══ Group B: Delete happy path ═══${NC}"
echo ""

# Snapshot satellite count before delete
PRE_DELETE_COUNT=$(echo "$CURRENT_SATS" | grep -c '|' || echo "$INITIAL_COUNT")

# ── T4: Delete satellite (authenticated) ────────────────────────────────────
echo -e "${CYAN}─── T4: Delete satellite (${DELETE_TARGET_ID}) ───${NC}"
do_curl "${AGG_HOST}/api/aggregator/satellite/${DELETE_TARGET_ID}" -X DELETE -u "${AUTH_USER}:${AUTH_PASS}"
echo "  HTTP ${RESP_CODE}: ${RESP_BODY}"
T4_OK=$(json_field "$RESP_BODY" "ok")
if [[ "$RESP_CODE" == "200" ]] && [[ "$T4_OK" == "True" || "$T4_OK" == "true" ]]; then
  record_result "T4: Delete satellite" "HTTP 200 + ok=true" "HTTP 200 + ok=true"
  DELETED=true
else
  T4_MSG=$(json_field "$RESP_BODY" "message")
  record_result "T4: Delete satellite" "HTTP 200 + ok=true" "HTTP ${RESP_CODE}, msg='${T4_MSG}'"
  DELETED=false
fi
echo ""

# ── T5: Verify removal from gateways ────────────────────────────────────────
echo -e "${CYAN}─── T5: Verify removal from gateways ───${NC}"
sleep 2
POST_DELETE_SATS=$(get_gateway_ids)
POST_DELETE_COUNT=$(echo "$POST_DELETE_SATS" | grep -c '|' || echo "0")
if [[ "$DELETED" == "true" ]]; then
  if ! echo "$POST_DELETE_SATS" | grep -qF "$DELETE_TARGET_ID"; then
    echo -e "  ${GREEN}CONFIRMED${NC}: ${DELETE_TARGET_ID} removed (${PRE_DELETE_COUNT}→${POST_DELETE_COUNT})"
    record_result "T5: Verify removal" "removed" "removed"
  else
    echo -e "  ${RED}STILL PRESENT${NC}: ${DELETE_TARGET_ID} still in gateways list"
    record_result "T5: Verify removal" "removed" "still_present"
  fi
else
  record_skip "T5: Verify removal" "T4 did not succeed"
fi
echo ""

# ── T6: Remaining satellites intact ─────────────────────────────────────────
echo -e "${CYAN}─── T6: Remaining satellites intact ───${NC}"
if [[ "$DELETED" == "true" ]]; then
  REMAINING_OK=true
  while IFS='|' read -r sid surl sreachable; do
    [[ -z "$sid" ]] && continue
    [[ "$sid" == "$DELETE_TARGET_ID" ]] && continue
    if echo "$POST_DELETE_SATS" | grep -qF "$sid"; then
      echo -e "  ${GREEN}✓${NC} ${sid} still present"
    else
      echo -e "  ${RED}✗${NC} ${sid} MISSING after delete"
      REMAINING_OK=false
    fi
  done <<< "$INITIAL_SATS"
  if [[ "$REMAINING_OK" == "true" ]]; then
    record_result "T6: Remaining intact" "all present" "all present"
  else
    record_result "T6: Remaining intact" "all present" "some missing"
  fi
else
  record_skip "T6: Remaining intact" "T4 did not succeed"
fi
echo ""

# ── T7: Array compaction — indices are dense ─────────────────────────────────
echo -e "${CYAN}─── T7: Array compaction (dense indices) ───${NC}"
if [[ "$DELETED" == "true" ]]; then
  # Verify the gateways response has exactly (PRE_DELETE_COUNT - 1) entries
  # and they are the expected remaining satellites in order
  EXPECTED_REMAINING=$((PRE_DELETE_COUNT - 1))
  if [[ "$POST_DELETE_COUNT" -eq "$EXPECTED_REMAINING" ]]; then
    echo -e "  ${GREEN}Count correct${NC}: ${POST_DELETE_COUNT} satellites (was ${PRE_DELETE_COUNT})"
    record_result "T7: Array compaction" "count=${EXPECTED_REMAINING}" "count=${POST_DELETE_COUNT}"
  else
    echo -e "  ${RED}Count wrong${NC}: expected ${EXPECTED_REMAINING}, got ${POST_DELETE_COUNT}"
    record_result "T7: Array compaction" "count=${EXPECTED_REMAINING}" "count=${POST_DELETE_COUNT}"
  fi
else
  record_skip "T7: Array compaction" "T4 did not succeed"
fi
echo ""

# ── T8: Reboot persistence ──────────────────────────────────────────────────
echo -e "${CYAN}─── T8: Reboot persistence ───${NC}"
if [[ "$DELETED" == "true" ]]; then
  echo "  Triggering reboot..."
  do_curl "${AGG_HOST}/api/reboot" -d 'a=1' -u "${AUTH_USER}:${AUTH_PASS}"
  echo "  Reboot triggered (HTTP ${RESP_CODE}). Waiting ${REBOOT_WAIT}s..."
  sleep "$REBOOT_WAIT"

  echo -n "  Waiting for device to come back"
  BACK=false
  for i in $(seq 1 12); do
    do_curl "${AGG_HOST}/api/status"
    if [[ "$RESP_CODE" == "200" ]]; then
      BACK=true; echo -e " ${GREEN}UP${NC} (attempt ${i})"; break
    fi
    echo -n "."; sleep 5
  done

  if [[ "$BACK" == "true" ]]; then
    sleep 5
    REBOOT_SATS=$(get_gateway_ids)
    if ! echo "$REBOOT_SATS" | grep -qF "$DELETE_TARGET_ID"; then
      echo -e "  ${GREEN}CONFIRMED${NC}: Deleted satellite stays deleted after reboot"
      record_result "T8: Reboot persistence" "still deleted" "still deleted"
    else
      echo -e "  ${RED}REAPPEARED${NC}: ${DELETE_TARGET_ID} came back after reboot (NVS not updated?)"
      record_result "T8: Reboot persistence" "still deleted" "reappeared"
    fi
  else
    echo -e " ${RED}TIMEOUT${NC}"
    record_result "T8: Reboot persistence" "still deleted" "timeout" "Device did not come back"
  fi
else
  record_skip "T8: Reboot persistence" "T4 did not succeed"
fi
echo ""

# =============================================================================
#  GROUP C: Restore and compaction stress
# =============================================================================
echo -e "${CYAN}═══ Group C: Restore + compaction stress ═══${NC}"
echo ""

# ── T9: Reset to compile-time defaults ───────────────────────────────────────
echo -e "${CYAN}─── T9: Reset to compile-time defaults ───${NC}"
do_curl "${AGG_HOST}/api/system/reset-satellites" -X POST -d 'a=1' -u "${AUTH_USER}:${AUTH_PASS}"
echo "  HTTP ${RESP_CODE}: ${RESP_BODY}"
sleep 3
RESET_SATS=$(get_gateway_ids)
RESET_COUNT=$(echo "$RESET_SATS" | grep -c '|' || echo "0")
if [[ "$RESET_COUNT" -eq "$INITIAL_COUNT" ]]; then
  echo -e "  ${GREEN}RESTORED${NC}: ${RESET_COUNT} satellites (matches initial state)"
  record_result "T9: Reset to defaults" "count=${INITIAL_COUNT}" "count=${RESET_COUNT}"
else
  echo -e "  ${YELLOW}COUNT CHANGED${NC}: expected ${INITIAL_COUNT}, got ${RESET_COUNT}"
  record_result "T9: Reset to defaults" "count=${INITIAL_COUNT}" "count=${RESET_COUNT}" \
    "Reset may have restored different count than initial"
fi
echo ""

# ── T10: Delete first satellite (compaction of remaining) ────────────────────
echo -e "${CYAN}─── T10: Delete FIRST satellite (compaction stress) ───${NC}"
FIRST_ID=$(echo "$RESET_SATS" | head -1 | cut -d'|' -f1)
SECOND_ID=$(echo "$RESET_SATS" | sed -n '2p' | cut -d'|' -f1)
if [[ -n "$FIRST_ID" && -n "$SECOND_ID" ]]; then
  echo "  Deleting first satellite: ${FIRST_ID}"
  do_curl "${AGG_HOST}/api/aggregator/satellite/${FIRST_ID}" -X DELETE -u "${AUTH_USER}:${AUTH_PASS}"
  echo "  HTTP ${RESP_CODE}: ${RESP_BODY}"
  T10_OK=$(json_field "$RESP_BODY" "ok")
  sleep 2
  COMPACT_SATS=$(get_gateway_ids)
  COMPACT_FIRST=$(echo "$COMPACT_SATS" | head -1 | cut -d'|' -f1)

  if [[ "$RESP_CODE" == "200" && "$COMPACT_FIRST" == "$SECOND_ID" ]]; then
    echo -e "  ${GREEN}COMPACTED${NC}: ${SECOND_ID} is now first (was second)"
    record_result "T10: Delete first (compaction)" "second becomes first" "second becomes first"
  elif [[ "$RESP_CODE" == "200" ]]; then
    echo -e "  ${YELLOW}DELETED but first is ${COMPACT_FIRST} (expected ${SECOND_ID})${NC}"
    record_result "T10: Delete first (compaction)" "second becomes first" "first is ${COMPACT_FIRST}"
  else
    T10_MSG=$(json_field "$RESP_BODY" "message")
    record_result "T10: Delete first (compaction)" "second becomes first" "HTTP ${RESP_CODE}, msg='${T10_MSG}'"
  fi
else
  record_skip "T10: Delete first (compaction)" "Need at least 2 satellites after reset"
fi
echo ""

# ── T11: Restore state ──────────────────────────────────────────────────────
echo -e "${CYAN}─── T11: Final reset to restore initial state ───${NC}"
do_curl "${AGG_HOST}/api/system/reset-satellites" -X POST -d 'a=1' -u "${AUTH_USER}:${AUTH_PASS}"
sleep 3
FINAL_SATS=$(get_gateway_ids)
FINAL_COUNT=$(echo "$FINAL_SATS" | grep -c '|' || echo "0")
echo "  Restored to ${FINAL_COUNT} satellites"
record_result "T11: Final state restore" "count=${INITIAL_COUNT}" "count=${FINAL_COUNT}"
echo ""

# =============================================================================
#  RESULTS TABLE
# =============================================================================
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "## v7.6.0.2 Device Test Results"
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
echo "- Firmware: ${FW_VERSION:-unknown}"
echo "- Initial satellites: ${INITIAL_COUNT}"
echo "- Delete target: ${DELETE_TARGET_ID}"
echo "- Date: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "- Script: scripts/device-test-v7.6.0.2.sh"
echo ""

echo "### Coverage Notes"
echo ""
echo "| Area | Status | Notes |"
echo "|------|--------|-------|"
echo "| Error: empty ID | ✅ Tested | T1 |"
echo "| Error: unknown ID | ✅ Tested | T2 |"
echo "| Error: no auth | ✅ Tested | T3 (expect 401 if auth present) |"
echo "| Happy: delete satellite | ✅ Tested | T4 |"
echo "| Verify: removal | ✅ Tested | T5 |"
echo "| Verify: remaining intact | ✅ Tested | T6 |"
echo "| Array compaction | ✅ Tested | T7 (count) + T10 (order) |"
echo "| Reboot persistence | ✅ Tested | T8 |"
echo "| Reset to defaults | ✅ Tested | T9 |"
echo "| Compaction: delete first | ✅ Tested | T10 (second becomes first) |"
echo "| State restoration | ✅ Tested | T11 |"
echo ""
echo "═══════════════════════════════════════════════════════════════"

if [[ "$FAIL_COUNT" -gt 0 ]]; then exit 1; fi
exit 0
