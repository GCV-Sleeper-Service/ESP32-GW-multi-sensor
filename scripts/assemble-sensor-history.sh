#!/usr/bin/env bash
# assemble-sensor-history.sh — Phase Y firmware module assembler
# Concatenates firmware/core/*.h fragments → dashboard/sensor_history_multi.h
#
# Usage:
#   assemble-sensor-history.sh --write     Assemble fragments → OUTPUT
#   assemble-sensor-history.sh --check     Compare assembly to committed file; exit 0/1
#   assemble-sensor-history.sh --list      Print fragment manifest
#   assemble-sensor-history.sh --dry-run   Print what --write would do

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

OUTPUT="dashboard/sensor_history_multi.h"
MODULES=(
  "firmware/core/config.h"
  "firmware/core/data-model.h"
  "firmware/core/nvs-persistence.h"
  "firmware/core/health-check.h"
  "firmware/core/deferred-management.h"
  "firmware/core/ping-adapter.h"
  "firmware/core/aggregator-runtime.h"
  "firmware/core/web-handler.h"
  "firmware/core/registration.h"
)

case "${1:-}" in
  --write)
    cat "${MODULES[@]}" > "$OUTPUT"
    echo "Assembled ${#MODULES[@]} fragments → $OUTPUT ($(wc -l < "$OUTPUT") lines)"
    ;;
  --check)
    # Generator-aware comparison: strip content between SENSOR_MANIFEST marker
    # pairs before comparing, because render_sensor_config.py writes generated
    # content into the committed file that does not exist in fragment stubs.
    strip_generated() {
      sed '/SENSOR_MANIFEST:HEADER_BEGIN/,/SENSOR_MANIFEST:HEADER_END/{ /SENSOR_MANIFEST:HEADER_BEGIN/!{ /SENSOR_MANIFEST:HEADER_END/!d; }; }' \
        | sed '/SENSOR_MANIFEST:ENTITY_BEGIN/,/SENSOR_MANIFEST:ENTITY_END/{ /SENSOR_MANIFEST:ENTITY_BEGIN/!{ /SENSOR_MANIFEST:ENTITY_END/!d; }; }'
    }
    [[ -f "$OUTPUT" ]] || { echo "ERROR: $OUTPUT not found — run --write first"; exit 1; }
    ASSEMBLED=$(cat "${MODULES[@]}" | strip_generated | sha256sum | cut -d' ' -f1)
    COMMITTED=$(strip_generated < "$OUTPUT" | sha256sum | cut -d' ' -f1)
    if [[ "$ASSEMBLED" == "$COMMITTED" ]]; then
      echo "PASS: Assembly identity verified (non-generated regions match: $ASSEMBLED)"
      exit 0
    else
      echo "FAIL: Assembly SHA-256 mismatch (non-generated regions differ)"
      echo "  Assembled: $ASSEMBLED"
      echo "  Committed: $COMMITTED"
      diff <(cat "${MODULES[@]}" | strip_generated) <(strip_generated < "$OUTPUT") | head -20
      exit 1
    fi
    ;;
  --list)
    for m in "${MODULES[@]}"; do
      echo "  $m ($(wc -l < "$m") lines)"
    done
    echo "Total: $(cat "${MODULES[@]}" | wc -l) lines"
    ;;
  --dry-run)
    echo "Would concatenate:"
    for m in "${MODULES[@]}"; do echo "  $m"; done
    echo "→ $OUTPUT"
    ;;
  *) echo "Usage: $0 [--write|--check|--list|--dry-run]"; exit 1 ;;
esac
