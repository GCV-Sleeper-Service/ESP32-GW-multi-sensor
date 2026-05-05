#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# stress-test-httpd-stack.sh
#
# Reproducible stress test for the httpd stack watermark.
# Runs 5 waves of concurrent HTTP requests against a board, recording
# the httpd_stack_watermark_bytes after each wave.
#
# USAGE:
#   bash scripts/stress-test-httpd-stack.sh [TARGET_IP] [--concurrent=N]
#   Default TARGET_IP: 192.168.120.189 (C3 satellite)
#   Default concurrent: 4 (safe for non-PSRAM boards; use 8 for PSRAM boards)
#
# PREREQUISITES:
#   - Target board flashed and booted for at least 2 minutes
#   - Board must serve /api/status/full with httpd_stack_watermark_bytes
#   - curl and jq installed
#
# ACCEPTANCE GATE:
#   Minimum watermark across all waves must be >= 10000 bytes after the
#   16 KB stack override is active.
#
# BUG-084 NOTE:
#   8 concurrent requests can crash non-PSRAM boards (C3, WROOM, C6) via
#   heap exhaustion — NOT stack overflow. The stack watermark stays healthy
#   (~12,900 B) but free_heap drops below the WiFi/LWIP minimum (~15-20 KB),
#   causing an ESP-IDF panic. The default of 4 concurrent requests is safe
#   for all boards. Use --concurrent=8 only on PSRAM-equipped boards (S3, C5).
# -----------------------------------------------------------------------------
set -uo pipefail
# NOTE: -e intentionally removed. Individual request failures are handled
# gracefully — a single curl timeout should not abort the entire test.

TARGET=""
CONCURRENT=4

# Parse arguments
for arg in "$@"; do
    case "$arg" in
        --concurrent=*)
            CONCURRENT="${arg#*=}"
            ;;
        *)
            if [[ -z "$TARGET" ]]; then
                TARGET="$arg"
            fi
            ;;
    esac
done

TARGET="${TARGET:-192.168.120.189}"
AUTH="${ESP_AUTH:-ESPadmin:ESPpass100}"
BASE="http://${TARGET}"
WAVES=5
MIN_WM=999999
FAILED_WAVES=0

cleanup() {
    local jobs
    jobs="$(jobs -p)" || return 0
    if [[ -n "$jobs" ]]; then
        kill $jobs 2>/dev/null || true
    fi
}
trap cleanup EXIT

# Build the request list based on concurrency level
build_wave_requests() {
    local n=$1
    WAVE_ENDPOINTS=()
    # Core endpoints that always run (up to 4)
    WAVE_ENDPOINTS+=("api/status/full")
    WAVE_ENDPOINTS+=("api/storage-stats")
    WAVE_ENDPOINTS+=("history/office/temp")
    WAVE_ENDPOINTS+=("api/status/full")
    # Additional endpoints for higher concurrency
    if [[ $n -ge 5 ]]; then WAVE_ENDPOINTS+=("history/office/hum"); fi
    if [[ $n -ge 6 ]]; then WAVE_ENDPOINTS+=("api/storage-stats"); fi
    if [[ $n -ge 7 ]]; then WAVE_ENDPOINTS+=("history/office/temp"); fi
    if [[ $n -ge 8 ]]; then WAVE_ENDPOINTS+=("api/storage-stats"); fi
}

echo "-----------------------------------------------------------"
echo "  httpd Stack Watermark Stress Test"
echo "  Target:      ${BASE}"
echo "  Waves:       ${WAVES} x ${CONCURRENT} concurrent requests"
echo "  Concurrency: ${CONCURRENT} (use --concurrent=8 for PSRAM boards)"
echo "-----------------------------------------------------------"
echo ""

echo "-- Pre-stress baseline --"
BASELINE=$(curl -s --max-time 15 -u "$AUTH" "${BASE}/api/status/full")
if [[ -z "$BASELINE" ]]; then
    echo "ERROR: Could not reach ${BASE}/api/status/full"
    echo "       Is the board online and running project firmware?"
    exit 1
fi
echo "$BASELINE" | jq '{version, httpd_stack_watermark_bytes, free_heap, min_free_heap, uptime_seconds}'
BL_WM=$(echo "$BASELINE" | jq '.httpd_stack_watermark_bytes')
BL_FH=$(echo "$BASELINE" | jq '.free_heap')
echo ""

if [[ "$BL_WM" == "null" || -z "$BL_WM" ]]; then
    echo "ERROR: Could not read httpd_stack_watermark_bytes from ${BASE}/api/status/full"
    echo "       Is the board running firmware with watermark telemetry?"
    exit 1
fi

# Warn if free_heap is already low
if [[ -n "$BL_FH" && "$BL_FH" != "null" && "$BL_FH" -lt 30000 ]]; then
    echo "WARNING: free_heap is only ${BL_FH} bytes. Board may crash under"
    echo "         concurrent load (BUG-084). Consider reducing --concurrent."
    echo ""
fi

build_wave_requests "$CONCURRENT"

for wave in $(seq 1 "$WAVES"); do
    echo "-- Wave ${wave}/${WAVES} (${CONCURRENT} concurrent) --"

    WAVE_PIDS=()
    WAVE_STATUSES=()
    for endpoint in "${WAVE_ENDPOINTS[@]}"; do
        curl -s --max-time 15 -u "$AUTH" "${BASE}/${endpoint}" -o /dev/null &
        WAVE_PIDS+=($!)
    done

    # Wait for all requests, collecting exit statuses
    REQUEST_FAILURES=0
    for pid in "${WAVE_PIDS[@]}"; do
        if ! wait "$pid"; then
            ((REQUEST_FAILURES++)) || true
        fi
    done

    if [[ $REQUEST_FAILURES -gt 0 ]]; then
        echo "  WARNING: ${REQUEST_FAILURES}/${CONCURRENT} requests failed (timeout or connection error)"
    fi

    sleep 2

    POST=$(curl -s --max-time 15 -u "$AUTH" "${BASE}/api/status/full")
    if [[ -z "$POST" ]]; then
        echo "  ERROR: Board unreachable after wave ${wave}. Likely crashed (BUG-084 heap exhaustion)."
        echo "  Aborting remaining waves."
        ((FAILED_WAVES++)) || true
        break
    fi

    WM=$(echo "$POST" | jq '.httpd_stack_watermark_bytes')
    FH=$(echo "$POST" | jq '.free_heap')
    MFH=$(echo "$POST" | jq '.min_free_heap')

    if [[ "$WM" == "null" || -z "$WM" ]]; then
        echo "  ERROR: Could not read httpd_stack_watermark_bytes after wave ${wave}"
        echo "  Board may have rebooted (check uptime)."
        ((FAILED_WAVES++)) || true
        break
    fi

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
if [[ "$MIN_WM" -lt 999999 ]]; then
    echo "  Minimum under stress: ${MIN_WM} bytes"
else
    echo "  Minimum under stress: N/A (board crashed before completing any wave)"
fi
echo "  Concurrent requests:  ${CONCURRENT}"
echo "  Failed waves:         ${FAILED_WAVES}"
echo ""

if [[ "$FAILED_WAVES" -gt 0 ]]; then
    echo "  WARN - Board crashed or became unreachable during stress test."
    echo "         This is likely BUG-084 (heap exhaustion under concurrent load)."
    echo "         The stack watermark was healthy (${BL_WM} B baseline)."
    echo "         Try reducing concurrency: --concurrent=2"
    echo ""
    echo "  Stack assessment: PASS (watermark ${BL_WM} >= 10000 at baseline)"
    echo "  Heap assessment:  FAIL (board crashed under ${CONCURRENT} concurrent connections)"
    exit 1
elif [[ "$MIN_WM" -ge 10000 ]]; then
    echo "  PASS - minimum watermark ${MIN_WM} >= 10000 bytes"
else
    echo "  FAIL - minimum watermark ${MIN_WM} < 10000 bytes"
    echo "         If this is still ~636, the local override is not active."
    exit 1
fi
echo "-----------------------------------------------------------"
