#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# stress-test-httpd-stack.sh
#
# Reproducible stress test for the C3 httpd stack watermark.
# Runs 5 waves of concurrent HTTP requests against the C3 board, recording
# the httpd_stack_watermark_bytes after each wave.
#
# USAGE:
#   bash scripts/stress-test-httpd-stack.sh [TARGET_IP]
#   Default TARGET_IP: 192.168.120.189 (C3 satellite)
#
# PREREQUISITES:
#   - Target board flashed and booted for at least 2 minutes
#   - curl and jq installed
#
# ACCEPTANCE GATE:
#   Minimum watermark across all waves must be >= 10000 bytes after the
#   C3 override fix is active.
# -----------------------------------------------------------------------------
set -euo pipefail

TARGET="${1:-192.168.120.189}"
AUTH="ESPadmin:ESPpass100"
BASE="http://${TARGET}"
WAVES=5
MIN_WM=999999

echo "-----------------------------------------------------------"
echo "  httpd Stack Watermark Stress Test"
echo "  Target: ${BASE}"
echo "  Waves:  ${WAVES} x 8 concurrent requests"
echo "-----------------------------------------------------------"
echo ""

echo "-- Pre-stress baseline --"
BASELINE=$(curl -sf -u "$AUTH" "${BASE}/api/status/full")
echo "$BASELINE" | jq '{version, httpd_stack_watermark_bytes, free_heap, min_free_heap, uptime_seconds}'
BL_WM=$(echo "$BASELINE" | jq '.httpd_stack_watermark_bytes')
echo ""

if [[ "$BL_WM" == "null" || -z "$BL_WM" ]]; then
    echo "ERROR: Could not read httpd_stack_watermark_bytes from ${BASE}/api/status/full"
    echo "       Is the board running firmware with watermark telemetry?"
    exit 1
fi

for wave in $(seq 1 "$WAVES"); do
    echo "-- Wave ${wave}/${WAVES} --"

    curl -sf -u "$AUTH" "${BASE}/history/office/temp" -o /dev/null &
    curl -sf -u "$AUTH" "${BASE}/history/office/hum" -o /dev/null &
    curl -sf -u "$AUTH" "${BASE}/history/office/temp" -o /dev/null &
    curl -sf -u "$AUTH" "${BASE}/api/status/full" -o /dev/null &
    curl -sf -u "$AUTH" "${BASE}/api/status/full" -o /dev/null &
    curl -sf -u "$AUTH" "${BASE}/api/storage-stats" -o /dev/null &
    curl -sf -u "$AUTH" "${BASE}/api/storage-stats" -o /dev/null &
    curl -sf -u "$AUTH" "${BASE}/api/storage-stats" -o /dev/null &

    wait
    sleep 2

    POST=$(curl -sf -u "$AUTH" "${BASE}/api/status/full")
    WM=$(echo "$POST" | jq '.httpd_stack_watermark_bytes')
    FH=$(echo "$POST" | jq '.free_heap')
    MFH=$(echo "$POST" | jq '.min_free_heap')
    echo "  watermark=${WM}  free_heap=${FH}  min_free_heap=${MFH}"

    if [[ "$WM" -lt "$MIN_WM" ]]; then
        MIN_WM=$WM
    fi

    if [[ "$wave" -lt "$WAVES" ]]; then
        echo "  (waiting 28s before next wave)"
        sleep 28
    fi
done

echo ""
echo "-----------------------------------------------------------"
echo "  RESULTS"
echo "  Baseline watermark:   ${BL_WM} bytes"
echo "  Minimum under stress: ${MIN_WM} bytes"
echo ""

if [[ "$MIN_WM" -ge 10000 ]]; then
    echo "  PASS - minimum watermark ${MIN_WM} >= 10000 bytes"
else
    echo "  FAIL - minimum watermark ${MIN_WM} < 10000 bytes"
    echo "         If this is still ~636, the local override is not active."
fi
echo "-----------------------------------------------------------"
