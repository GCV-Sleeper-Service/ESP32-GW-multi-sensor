#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if esphome config firmware/esp32-c3-multi-sensor.yaml >/dev/null 2>&1; then
  echo "esphome_config_parse: PASS"
else
  echo "esphome_config_parse: FAIL"
  exit 1
fi
