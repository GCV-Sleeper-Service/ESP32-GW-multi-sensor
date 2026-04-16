#!/usr/bin/env bash
# system-metrics-exporter.sh — Push system metrics to ESP32 gateway
#
# Usage:
#   ./system-metrics-exporter.sh [gateway-url] [device-id]
#
# Defaults:
#   gateway-url = http://192.168.10.20
#   device-id   = nas01
#
# Setup: Add to crontab for periodic collection:
#   * * * * * /path/to/system-metrics-exporter.sh
#
# The gateway must have a matching device in config/sensors.json
# with category "system" and adapter "external_push".

set -euo pipefail

# NOTE: pipefail means any command failure in a pipeline propagates.
# Every metric collection line MUST have || echo "0" to prevent script abort.
# Do NOT remove the fallback clauses.

GATEWAY_URL="${1:-http://192.168.10.20}"
DEVICE_ID="${2:-nas01}"

# Optional management credentials for /api/ingest auth.
# Supports positional args 3/4 or env vars METRICS_USER/METRICS_PASS.
METRICS_USER="${METRICS_USER:-${3:-}}"
METRICS_PASS="${METRICS_PASS:-${4:-}}"

CURL_AUTH_ARGS=()
if [ -n "${METRICS_USER}" ] && [ -n "${METRICS_PASS}" ]; then
  BASIC_TOKEN="$(printf '%s:%s' "${METRICS_USER}" "${METRICS_PASS}" | base64 | tr -d '\r\n')"
  CURL_AUTH_ARGS=(-H "Authorization: Basic ${BASIC_TOKEN}")
fi

# Optional one-time warning when auth is not configured.
if [ ${#CURL_AUTH_ARGS[@]} -eq 0 ]; then
  echo "[WARN] No METRICS_USER/METRICS_PASS provided; /api/ingest may return 401 on secured gateways" >&2
fi

# Collect metrics
CPU_PCT=$(LC_ALL=C top -bn1 | grep "Cpu(s)" | awk '{print $2}' || echo "0")
RAM_PCT=$(free | awk '/Mem:/ {printf "%.1f", $3/$2 * 100.0}' || echo "0")
DISK_PCT=$(df / | awk 'NR==2 {gsub(/%/,""); print $5}' || echo "0")
UPTIME_HRS=$(awk '{printf "%.1f", $1/3600}' /proc/uptime || echo "0")

# Push to gateway (silent, ignore errors for cron usage)
for METRIC in "cpu_pct=${CPU_PCT}" "ram_pct=${RAM_PCT}" "disk_pct=${DISK_PCT}" "uptime_hrs=${UPTIME_HRS}"; do
  KEY="${METRIC%%=*}"
  VAL_RAW="${METRIC#*=}"
  # Strip any non-numeric characters (e.g., '%', 'us,' from top output variations)
  VAL="$(printf '%s' "${VAL_RAW}" | sed 's/[^0-9.+-]//g')"
  if [ -z "${VAL}" ]; then
    VAL="0"
  fi
  curl -s -X POST "${GATEWAY_URL}/api/ingest/${DEVICE_ID}/${KEY}?val=${VAL}" \
    "${CURL_AUTH_ARGS[@]}" -o /dev/null --max-time 5 || true
done

# ⚠️ Shell compatibility note: The top output format varies across Linux distributions
# (Debian/Ubuntu show %Cpu(s), CentOS shows Cpu(s), BusyBox doesn't have top -bn1).
# The || echo "0" fallback handles all these cases — CPU_PCT will be "0" on
# incompatible systems. Do NOT attempt to make the script work on all distros.

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Attempted push: cpu=${CPU_PCT}% ram=${RAM_PCT}% disk=${DISK_PCT}% uptime=${UPTIME_HRS}h → ${GATEWAY_URL}"
