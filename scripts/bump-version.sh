#!/usr/bin/env bash
# bump-version.sh — atomic version bump for ESP32-GW-multi-sensor
#
# Usage: bash scripts/bump-version.sh <new-version>
# Example: bash scripts/bump-version.sh 7.5.2.1
#
# Updates all canonical version locations atomically, regenerates all
# generated artifacts, and runs preflight to verify sync.
#
# Canonical version locations updated by this script:
#   VERSION                              (source of truth)
#   scripts/render_sensor_config.py      (VERSION constant)
#   tests/fixtures/generate-fixtures.js  (VERSION constant)
#   dashboard/dashboard.html                (App.version — newly added in v7.5.3.0)
#   dashboard/src/00-app-shell.js        (App.version in source module — added in v7.6.5.1)
#
# Generated files updated by render_sensor_config.py --write:
#   dashboard/dashboard.js               (App.version)
#   dashboard/sensor_history_multi.h     (header comment)
#   firmware/esp32-c3-multi-sensor.yaml  (header + register_history_handler)
#   src/gateway_manifest.h               (firmware_version in manifest JSON)
#   tests/fixtures/manifest.json         (version + firmware_version)
#   tests/fixtures/api-status.json       (version)
#   tests/fixtures/variants/*/           (version in all variant fixtures)
#
# Generated files updated by generate-header.sh:
#   dashboard/dashboard.h                (embedded dashboard with App.version)
#
# If dashboard/dashboard.min.html exists from a prior build, this script
# re-minifies it (if html-minifier-terser is installed) or removes it
# (to prevent generate-header.sh from embedding a stale version).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ $# -ne 1 ]]; then
  echo "Usage: bash scripts/bump-version.sh <new-version>"
  echo "Example: bash scripts/bump-version.sh 7.5.2.1"
  exit 1
fi

NEW_VER="${1#v}"  # strip leading 'v' if provided

# Validate format: N.N.N.N
if ! echo "$NEW_VER" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
  echo "✗ Invalid version format: ${NEW_VER}"
  echo "  Expected format: N.N.N.N (e.g. 7.5.2.1)"
  exit 1
fi

OLD_VER="$(tr -d '[:space:]' < VERSION)"
echo "Bumping version: ${OLD_VER} → ${NEW_VER}"

# 1. Update canonical sources
echo "→ Updating VERSION..."
echo "$NEW_VER" > VERSION

echo "→ Updating scripts/render_sensor_config.py..."
sed -i "s/^VERSION = \"[0-9.]*\"/VERSION = \"${NEW_VER}\"/" scripts/render_sensor_config.py

echo "→ Updating tests/fixtures/generate-fixtures.js..."
sed -i "s/const VERSION = 'v[0-9.]*'/const VERSION = 'v${NEW_VER}'/" tests/fixtures/generate-fixtures.js

echo "→ Updating dashboard/dashboard.html..."
sed -i "s/App\.version = 'v[0-9.]*'/App.version = 'v${NEW_VER}'/" dashboard/dashboard.html

echo "→ Updating dashboard/src/00-app-shell.js..."
sed -i "s/App\.version = 'v[0-9.]*'/App.version = 'v${NEW_VER}'/" dashboard/src/00-app-shell.js

# 2. Regenerate all generated artifacts from canonical sources
echo "→ Running bundle-dashboard.sh --write..."
bash scripts/bundle-dashboard.sh --write

echo "→ Running render_sensor_config.py --write..."
python3 scripts/render_sensor_config.py --write

# 2b. Re-minify dashboard.html if the minifier is available.
#     generate-header.sh auto-selects dashboard.min.html when it exists,
#     so a stale .min.html from a prior build would embed the OLD version.
if [[ -f "dashboard/dashboard.min.html" ]]; then
  if command -v html-minifier-terser &>/dev/null; then
    echo "→ Running minify-dashboard.sh (re-minify after version bump)..."
    bash scripts/minify-dashboard.sh
  else
    echo "→ Removing stale dashboard.min.html (html-minifier-terser not found)..."
    rm -f dashboard/dashboard.min.html
  fi
fi

echo "→ Running generate-header.sh..."
bash scripts/generate-header.sh

# 3. Verify everything is in sync
echo "→ Running preflight.sh..."
bash scripts/preflight.sh

echo ""
echo "✓ Version bumped to ${NEW_VER}. All checks passed."
echo ""
echo "Next steps:"
echo "  1. Review the changes: git diff"
echo "  2. Update Docs/changelog.md with a v${NEW_VER} entry"
echo "  3. Update Docs/bugs-and-lessons-learned.md if applicable"
echo "  4. Commit all changes together"
