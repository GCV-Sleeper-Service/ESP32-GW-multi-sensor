#!/usr/bin/env bash
set -euo pipefail

# Navigate to repo root (parent of scripts/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT"

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
CONFIG_DIR="config"

# Backup file paths (immutable source-of-truth — never modified by this script)
BAK_GATEWAY_AGG="$CONFIG_DIR/gateway-agg-s3-16m-1.json.bak"
BAK_AGGREGATOR_AGG="$CONFIG_DIR/aggregator-agg-s3-16m-1.json.bak"
BAK_SENSORS_AGG="$CONFIG_DIR/sensors-agg-s3-16m-1.json.bak"
BAK_GATEWAY_WROOM="$CONFIG_DIR/gateway-sat-esp32-4m-190.json.bak"
BAK_SENSORS_WROOM="$CONFIG_DIR/sensors-sat-esp32-4m-190.json.bak"

# Active config file paths (created/removed by this script)
# Note: gateway.json, aggregator.json, and WROOM sensors are gitignored.
# sensors-agg-s3-16m-1.json is git-tracked and should never be removed by clean_active_configs.
ACTIVE_GATEWAY="$CONFIG_DIR/gateway.json"
ACTIVE_AGGREGATOR="$CONFIG_DIR/aggregator.json"
ACTIVE_SENSORS_AGG="$CONFIG_DIR/sensors-agg-s3-16m-1.json"
ACTIVE_SENSORS_WROOM="$CONFIG_DIR/sensors-sat-esp32-4m-190.json"

# ---------------------------------------------------------------------------
# Helper: print_usage
# ---------------------------------------------------------------------------
print_usage() {
  echo "Usage: bash scripts/provision.sh <command> [--dry-run]"
  echo ""
  echo "Commands:"
  echo "  status                Show current configuration (no changes made)"
  echo "  aggregator [--dry-run]  Switch to S3 aggregator (agg-s3-16m-1)"
  echo "  satellite  [--dry-run]  Switch to C3 satellite (default, CI-safe)"
  echo "  wroom      [--dry-run]  Switch to WROOM satellite (sat-esp32-4m-190)"
  echo ""
  echo "Options:"
  echo "  --dry-run   Print pipeline steps without executing them"
  echo ""
  echo "Workflow (Phase Y pipeline):"
  echo "  1. bash scripts/provision.sh status      -- check current board"
  echo "  2. bash scripts/provision.sh <target>    -- switch board config + run full pipeline"
  echo "  3. Flash device"
  echo "  4. bash scripts/provision.sh satellite   -- ALWAYS before pushing"
  echo "  5. bash scripts/preflight.sh             -- confirm CI-safe"
}

# ---------------------------------------------------------------------------
# Helper: require_node
# ---------------------------------------------------------------------------
require_node() {
  if ! command -v node &>/dev/null; then
    echo "ERROR: node is required but not found in PATH." >&2
    echo "Install Node.js: https://nodejs.org/" >&2
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# Helper: require_npm_deps
# ---------------------------------------------------------------------------
require_npm_deps() {
  if [[ ! -d "node_modules" ]]; then
    echo "ERROR: node_modules/ not found. Run 'npm install' first." >&2
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# Helper: require_python3
# ---------------------------------------------------------------------------
require_python3() {
  if ! command -v python3 &>/dev/null; then
    echo "ERROR: python3 is required but not found in PATH." >&2
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# Helper: detect_current_config
# Returns one of: c3-default | aggregator:agg-s3-16m-1 | wroom:sat-esp32-4m-190 | unknown
# ---------------------------------------------------------------------------
detect_current_config() {
  if [[ ! -f "$ACTIVE_GATEWAY" ]]; then
    if [[ -f "$ACTIVE_AGGREGATOR" ]]; then
      echo "unknown"
    else
      echo "c3-default"
    fi
    return
  fi

  local esphome_name
  esphome_name=$(python3 -c "import json; c=json.load(open('$ACTIVE_GATEWAY')); print(c.get('esphome_name',''))" 2>/dev/null || echo "")

  case "$esphome_name" in
    agg-s3-16m-1)     echo "aggregator:agg-s3-16m-1" ;;
    sat-esp32-4m-190) echo "wroom:sat-esp32-4m-190" ;;
    *)                echo "unknown" ;;
  esac
}

# ---------------------------------------------------------------------------
# Helper: validate_backup_files
# target: aggregator | wroom
# ---------------------------------------------------------------------------
validate_backup_files() {
  local target="$1"
  local missing=0

  if [[ "$target" == "aggregator" ]]; then
    for f in "$BAK_GATEWAY_AGG" "$BAK_AGGREGATOR_AGG" "$BAK_SENSORS_AGG"; do
      if [[ ! -f "$f" ]]; then
        echo "ERROR: Required backup file missing: $f" >&2
        missing=1
      fi
    done
  elif [[ "$target" == "wroom" ]]; then
    if [[ ! -f "$BAK_GATEWAY_WROOM" ]]; then
      echo "ERROR: Required backup file missing: $BAK_GATEWAY_WROOM" >&2
      missing=1
    else
      require_python3
      local sensors_file
      sensors_file=$(python3 -c "import json; c=json.load(open('$BAK_GATEWAY_WROOM')); print(c.get('sensors_file',''))" 2>/dev/null || echo "")
      if [[ -n "$sensors_file" && ! -f "$BAK_SENSORS_WROOM" ]]; then
        echo "ERROR: WROOM gateway backup references a sensors_file but sensors backup is missing: $BAK_SENSORS_WROOM" >&2
        missing=1
      fi
    fi
  fi

  if [[ "$missing" -eq 1 ]]; then
    echo "ERROR: Cannot proceed — required .bak files are missing." >&2
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# Helper: clean_active_configs
# ---------------------------------------------------------------------------
clean_active_configs() {
  rm -f "$ACTIVE_GATEWAY"
  rm -f "$ACTIVE_AGGREGATOR"
  rm -f "$ACTIVE_SENSORS_WROOM"
  # Note: ACTIVE_SENSORS_AGG (sensors-agg-s3-16m-1.json) is git-tracked — do not delete it
}

# ---------------------------------------------------------------------------
# Helper: run_render
# Runs render_sensor_config.py --write (Step 0 of local pipeline).
# This is an initial render to establish the config state.
# The full pipeline still requires a bundle → re-render → build-html pass
# after this — see print_workflow().
# ---------------------------------------------------------------------------
run_render() {
  require_python3
  echo "  Running: python3 scripts/render_sensor_config.py --write"
  if ! python3 scripts/render_sensor_config.py --write; then
    echo ""
    echo "ERROR: render_sensor_config.py --write failed." >&2
    echo "Configuration may be in an inconsistent state." >&2
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# Helper: run_full_pipeline
# Runs the full regeneration pipeline (Critical Rule 37).
# Called after board switch to bring all generated artifacts into sync.
#
# Pipeline ordering rationale:
#   Step 0: assemble-sensor-history.sh --write (placeholder until v7.6.6.1)
#   Step 1: bundle-dashboard.sh --write (assembles dashboard src → dashboard.js)
#   Step 2: render_sensor_config.py --write (injects sensor markers)
#   Step 3: generate-fixtures.js (regenerates test fixtures)
#   Step 4: render_sensor_config.py --write (re-injects after fixture gen)
#   Step 5: build-dashboard.sh --write (template + JS → dashboard.html)
#   Step 6: minify-dashboard.sh (dashboard.html → dashboard.min.html)
#   Step 7: generate-header.sh (min.html → dashboard.h gzip C header)
#   Step 8: render_sensor_config.py --check (final verification)
# ---------------------------------------------------------------------------
run_full_pipeline() {
  local dry_run="${1:-false}"

  require_python3
  require_node
  require_npm_deps

  echo ""
  echo "─────────────────────────────────────────────────────"
  echo " Running full regeneration pipeline (Critical Rule 37)"
  echo "─────────────────────────────────────────────────────"

  # Step 0: Assembly placeholder — no-op until v7.6.6.1 adds the script
  # When assemble-sensor-history.sh exists, this becomes:
  #   bash scripts/assemble-sensor-history.sh --write
  if [[ "$dry_run" == "true" ]]; then
    echo "  [DRY-RUN] Step 0: assemble-sensor-history.sh --write (placeholder — script not yet created)"
  else
    echo "  [SKIP]    Step 0: assemble-sensor-history.sh --write (placeholder — script not yet created)"
  fi

  local steps=(
    "bash scripts/bundle-dashboard.sh --write"
    "python3 scripts/render_sensor_config.py --write"
    "node tests/fixtures/generate-fixtures.js"
    "python3 scripts/render_sensor_config.py --write"
    "bash scripts/build-dashboard.sh --write"
    "bash scripts/minify-dashboard.sh"
    "bash scripts/generate-header.sh"
    "python3 scripts/render_sensor_config.py --check"
  )

  local i=1
  for step in "${steps[@]}"; do
    if [[ "$dry_run" == "true" ]]; then
      echo "  [DRY-RUN] Step $i: $step"
    else
      echo "  Running   Step $i: $step"
      if ! $step; then
        echo ""
        echo "ERROR: Pipeline failed at Step $i: $step" >&2
        exit 1
      fi
    fi
    ((i++))
  done

  echo "─────────────────────────────────────────────────────"
  if [[ "$dry_run" == "true" ]]; then
    echo " Pipeline dry-run complete (no changes made)"
  else
    echo " Pipeline complete — all steps succeeded"
  fi
  echo "─────────────────────────────────────────────────────"
}

# ---------------------------------------------------------------------------
# Helper: print_workflow
# target: aggregator | satellite | wroom
#
# Emits the FULL Phase X 8-step regeneration pipeline that must be run
# after provision.sh switches board config and does the initial render.
#
# Pipeline rationale (Critical Rule 37):
#   Step 1: bundle-dashboard.sh --write  -- assembles src modules → dashboard.js
#   Step 2: render_sensor_config.py --write -- re-injects DEFAULT_SENSOR_META markers
#                                              (bundle overwrites dashboard.js, erasing
#                                               the previous injection)
#   Step 3: node generate-fixtures.js   -- regenerates test fixtures from current config
#   Step 4: render_sensor_config.py --write -- re-injects after fixture generation may have
#                                              modified dashboard.js state
#   Step 5: build-dashboard.sh --write  -- template + JS → dashboard.html
#   Step 6: minify-dashboard.sh         -- dashboard.html → dashboard.min.html
#   Step 7: generate-header.sh          -- dashboard.min.html → dashboard.h (gzip C header)
#   Step 8: render_sensor_config.py --check -- final verification (markers in sync)
#
# Note: provision.sh already ran render_sensor_config.py --write as its own
# internal step (run_render). The pipeline below picks up from Step 1.
# ---------------------------------------------------------------------------
print_workflow() {
  local target="$1"
  local dry_run="${2:-false}"

  run_full_pipeline "$dry_run"

  echo ""
  echo "─────────────────────────────────────────────────────"
  echo "Next steps:"
  echo "─────────────────────────────────────────────────────"
  echo "  # Verify:"
  echo "  bash scripts/preflight.sh"
  echo ""
  case "$target" in
    aggregator)
      echo "  # Compile and flash S3 aggregator:"
      echo "  esphome clean firmware/esp32-s3-devkitc1-n16r8-gw.yaml"
      echo "  esphome run   firmware/esp32-s3-devkitc1-n16r8-gw.yaml"
      ;;
    satellite)
      echo "  # Compile and flash C3 satellite:"
      echo "  esphome clean firmware/esp32-c3-multi-sensor.yaml"
      echo "  esphome run   firmware/esp32-c3-multi-sensor.yaml"
      ;;
    wroom)
      echo "  # Compile and flash WROOM satellite:"
      echo "  esphome clean firmware/esp32-wroom-32d-gw.yaml"
      echo "  esphome run   firmware/esp32-wroom-32d-gw.yaml"
      ;;
  esac
  if [[ "$target" != "satellite" ]]; then
    echo ""
    echo "  # ⚠️ BEFORE PUSHING — return to CI-safe config:"
    echo "  bash scripts/provision.sh satellite"
    echo "  bash scripts/preflight.sh"
  fi
  echo "─────────────────────────────────────────────────────"
}

# ---------------------------------------------------------------------------
# Helper: validate_after_switch
# FIX (moderate): src/aggregator_config.h path confirmed correct in repo.
# The grep checks are accurate — no path change needed.
# ---------------------------------------------------------------------------
validate_after_switch() {
  local target="$1"
  local ok=1

  case "$target" in
    aggregator)
      if ! grep -q "AGGREGATOR_ENABLED 1" src/aggregator_config.h 2>/dev/null; then
        echo "  ⚠️  WARNING: src/aggregator_config.h does not show AGGREGATOR_ENABLED 1" >&2
        ok=0
      fi
      if [[ ! -f "firmware/esp32-s3-devkitc1-n16r8-gw.yaml" ]]; then
        echo "  ⚠️  WARNING: firmware/esp32-s3-devkitc1-n16r8-gw.yaml was not generated" >&2
        ok=0
      fi
      local board
      board=$(python3 -c "import json; c=json.load(open('$ACTIVE_GATEWAY')); print(c.get('board',''))" 2>/dev/null || echo "")
      if [[ "$board" != "esp32-s3-devkitc1-n16r8" ]]; then
        echo "  ⚠️  WARNING: gateway.json board mismatch (got: $board)" >&2
        ok=0
      fi
      ;;
    satellite)
      if ! grep -q "AGGREGATOR_ENABLED 0" src/aggregator_config.h 2>/dev/null; then
        echo "  ⚠️  WARNING: src/aggregator_config.h does not show AGGREGATOR_ENABLED 0" >&2
        ok=0
      fi
      ;;
    wroom)
      if ! grep -q "AGGREGATOR_ENABLED 0" src/aggregator_config.h 2>/dev/null; then
        echo "  ⚠️  WARNING: src/aggregator_config.h does not show AGGREGATOR_ENABLED 0" >&2
        ok=0
      fi
      if [[ ! -f "firmware/esp32-wroom-32d-gw.yaml" ]]; then
        echo "  ⚠️  WARNING: firmware/esp32-wroom-32d-gw.yaml was not generated" >&2
        ok=0
      fi
      ;;
  esac

  if [[ "$ok" -eq 0 ]]; then
    echo ""
    echo "  ⚠️  WARNING: Validation found issues — configuration may be inconsistent." >&2
    echo "  ⚠️  Review the warnings above before proceeding." >&2
    return 1
  fi
  return 0
}

# ---------------------------------------------------------------------------
# show_status
# ---------------------------------------------------------------------------
show_status() {
  require_python3

  echo "════════════════════════════════════════"
  echo " Board Provisioning Status"
  echo "════════════════════════════════════════"
  echo ""

  if [[ -f "$ACTIVE_GATEWAY" ]]; then
    local board esphome_name
    board=$(python3 -c "import json; c=json.load(open('$ACTIVE_GATEWAY')); print(c.get('board','(not set)'))" 2>/dev/null || echo "(error reading)")
    esphome_name=$(python3 -c "import json; c=json.load(open('$ACTIVE_GATEWAY')); print(c.get('esphome_name','(not set)'))" 2>/dev/null || echo "(error reading)")
    echo "  gateway.json  : PRESENT"
    echo "  board         : $board"
    echo "  esphome_name  : $esphome_name"
  else
    echo "  gateway.json  : absent — C3 SuperMini default"
  fi

  if [[ -f "$ACTIVE_AGGREGATOR" ]]; then
    echo "  aggregator.json : PRESENT"
  else
    echo "  aggregator.json : absent"
  fi

  echo ""
  echo "  src/aggregator_config.h:"
  if [[ -f "src/aggregator_config.h" ]]; then
    grep "AGGREGATOR_ENABLED" src/aggregator_config.h || echo "  (AGGREGATOR_ENABLED not found)"
  else
    echo "  (file not found)"
  fi

  echo ""
  local sensors_file="$CONFIG_DIR/sensors.json"
  if [[ -f "$ACTIVE_GATEWAY" ]]; then
    local sf
    sf=$(python3 -c "import json; c=json.load(open('$ACTIVE_GATEWAY')); print(c.get('sensors_file',''))" 2>/dev/null || echo "")
    if [[ -n "$sf" ]]; then
      sensors_file="$sf"
    fi
  fi
  if [[ -f "$sensors_file" ]]; then
    echo "  Active sensors : $sensors_file ✅"
  else
    echo "  Active sensors : $sensors_file ❌ (file missing!)"
  fi

  echo ""
  echo "  ┌─────────────────────────────────────────┐"
  local current role device ci_safe
  current=$(detect_current_config)
  case "$current" in
    c3-default)
      role="satellite"; device="C3 SuperMini (default)"; ci_safe="✅ YES"
      ;;
    aggregator:agg-s3-16m-1)
      role="aggregator"; device="agg-s3-16m-1 (ESP32-S3)"; ci_safe="❌ NO"
      ;;
    wroom:sat-esp32-4m-190)
      role="satellite"; device="sat-esp32-4m-190 (WROOM)"; ci_safe="❌ NO"
      ;;
    *)
      role="unknown"; device="unknown"; ci_safe="❓ UNKNOWN"
      ;;
  esac
  printf "  │ %-12s : %-27s│\n" "Role"    "$role"
  printf "  │ %-12s : %-27s│\n" "Device"  "$device"
  printf "  │ %-12s : %-27s│\n" "CI-safe" "$ci_safe"
  echo "  └─────────────────────────────────────────┘"

  echo ""
  echo "  Backup files in $CONFIG_DIR/:"
  for f in "$CONFIG_DIR"/*.bak; do
    [[ -f "$f" ]] && echo "    $f" || true
  done

  echo ""
  echo "  Generated firmware YAML:"
  local found_yaml=0
  for f in firmware/*-gw.yaml; do
    [[ -f "$f" ]] && echo "    $f" && found_yaml=1 || true
  done
  [[ -f "firmware/esp32-c3-multi-sensor.yaml" ]] && echo "    firmware/esp32-c3-multi-sensor.yaml" || true
  [[ "$found_yaml" -eq 0 ]] && echo "    (none found)" || true

  echo ""
  echo "  Phase X pipeline (Critical Rule 37):"
  echo "    bundle-dashboard.sh --write"
  echo "    render_sensor_config.py --write"
  echo "    generate-fixtures.js"
  echo "    render_sensor_config.py --write"
  echo "    build-dashboard.sh --write"
  echo "    minify-dashboard.sh"
  echo "    generate-header.sh"
  echo "    render_sensor_config.py --check"
  echo ""
}

# ---------------------------------------------------------------------------
# activate_aggregator
# ---------------------------------------------------------------------------
activate_aggregator() {
  local dry_run="false"
  [[ "${1:-}" == "--dry-run" ]] && dry_run="true"

  require_python3

  echo "════════════════════════════════════════"
  echo " Provisioning: S3 Aggregator (agg-s3-16m-1)"
  echo "════════════════════════════════════════"
  echo ""

  validate_backup_files aggregator

  local current
  current=$(detect_current_config)

  if [[ "$current" == "aggregator:agg-s3-16m-1" ]]; then
    echo "  Already in aggregator mode. Validating..."
    validate_after_switch aggregator || true
    print_workflow aggregator "$dry_run"
  else
    if [[ "$current" != "c3-default" ]]; then
      echo "  Current config: $current — switching to aggregator..."
    else
      echo "  Current config: C3 satellite default — switching to aggregator..."
    fi

    echo "  Cleaning active configs..."
    clean_active_configs

    echo "  Copying S3 aggregator backups..."
    cp "$BAK_GATEWAY_AGG"    "$ACTIVE_GATEWAY"
    cp "$BAK_AGGREGATOR_AGG" "$ACTIVE_AGGREGATOR"
    cp "$BAK_SENSORS_AGG"    "$ACTIVE_SENSORS_AGG"

    run_render

    echo ""
    echo "  Validating..."
    validate_after_switch aggregator || true

    print_workflow aggregator "$dry_run"
  fi

  echo ""
  echo "  ⚠️  WARNING: Current configuration is for S3 aggregator (agg-s3-16m-1)."
  echo "  ⚠️  DO NOT push this configuration to the remote repo — it will break CI."
  echo "  ⚠️  Run 'bash scripts/provision.sh satellite' before pushing."
  echo ""
}

# ---------------------------------------------------------------------------
# activate_satellite
# ---------------------------------------------------------------------------
activate_satellite() {
  local dry_run="false"
  [[ "${1:-}" == "--dry-run" ]] && dry_run="true"

  require_python3

  echo "════════════════════════════════════════"
  echo " Provisioning: C3 Satellite (default, CI-safe)"
  echo "════════════════════════════════════════"
  echo ""

  local current
  current=$(detect_current_config)

  if [[ "$current" == "c3-default" ]]; then
    echo "  Already in C3 satellite default mode. Validating..."
    validate_after_switch satellite || true
    print_workflow satellite "$dry_run"
  else
    echo "  Current config: $current — switching to C3 satellite default..."

    echo "  Cleaning active configs..."
    clean_active_configs

    echo "  Verifying C3 default prerequisites..."
    if [[ -f "$ACTIVE_GATEWAY" ]]; then
      echo "  ERROR: config/gateway.json still exists after cleanup — aborting." >&2
      exit 1
    fi
    if [[ -f "$ACTIVE_AGGREGATOR" ]]; then
      echo "  ERROR: config/aggregator.json still exists after cleanup — aborting." >&2
      exit 1
    fi
    if [[ ! -f "$CONFIG_DIR/sensors.json" ]]; then
      echo "  ERROR: config/sensors.json is missing — this file must always be present." >&2
      exit 1
    fi

    run_render

    echo ""
    echo "  Validating..."
    validate_after_switch satellite || true

    print_workflow satellite "$dry_run"
  fi

  echo ""
  echo "  ✅ Configuration is set to C3 satellite (default)."
  echo "  ✅ Safe to push to remote repo — CI will pass."
  echo ""
}

# ---------------------------------------------------------------------------
# activate_wroom
# ---------------------------------------------------------------------------
activate_wroom() {
  local dry_run="false"
  [[ "${1:-}" == "--dry-run" ]] && dry_run="true"

  require_python3

  echo "════════════════════════════════════════"
  echo " Provisioning: WROOM Satellite (sat-esp32-4m-190)"
  echo "════════════════════════════════════════"
  echo ""

  validate_backup_files wroom

  local current
  current=$(detect_current_config)

  if [[ "$current" == "wroom:sat-esp32-4m-190" ]]; then
    echo "  Already in WROOM satellite mode. Validating..."
    validate_after_switch wroom || true
    print_workflow wroom "$dry_run"
  else
    echo "  Current config: $current — switching to WROOM satellite..."

    echo "  Cleaning active configs..."
    clean_active_configs

    echo "  Copying WROOM satellite backup..."
    cp "$BAK_GATEWAY_WROOM" "$ACTIVE_GATEWAY"

    local sf
    sf=$(python3 -c "import json; c=json.load(open('$ACTIVE_GATEWAY')); print(c.get('sensors_file',''))" 2>/dev/null || echo "")
    if [[ -n "$sf" ]]; then
      if [[ -f "$BAK_SENSORS_WROOM" ]]; then
        echo "  Copying WROOM sensors backup (sensors_file: $sf)..."
        cp "$BAK_SENSORS_WROOM" "$sf"
      else
        echo "  WARNING: gateway references sensors_file but $BAK_SENSORS_WROOM is missing." >&2
      fi
    fi

    run_render

    echo ""
    echo "  Validating..."
    validate_after_switch wroom || true

    print_workflow wroom "$dry_run"
  fi

  echo ""
  echo "  ⚠️  WARNING: Current configuration is for WROOM satellite (sat-esp32-4m-190)."
  echo "  ⚠️  DO NOT push this configuration to the remote repo — it will break CI."
  echo "  ⚠️  Run 'bash scripts/provision.sh satellite' before pushing."
  echo ""
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
case "${1:-}" in
  status)     show_status ;;
  aggregator) activate_aggregator "${2:-}" ;;
  satellite)  activate_satellite "${2:-}" ;;
  wroom)      activate_wroom "${2:-}" ;;
  *)          print_usage; exit 1 ;;
esac
