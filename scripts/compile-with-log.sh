#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

mkdir -p build-logs
STAMP="$(date +%F-%H%M%S)"
LOG="build-logs/compile-${STAMP}.log"

echo "Compiling firmware/esp32-c3-multi-sensor.yaml"
echo "Log: $LOG"

esphome compile firmware/esp32-c3-multi-sensor.yaml 2>&1 | tee "$LOG"
