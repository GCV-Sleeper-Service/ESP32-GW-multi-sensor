# Session Log - v7.6.9.0

Date: 2026-04-16
PR: #183
Branch: codex/v7.6.9.0-device-card-cleanup

## Scope Summary
- Device card cleanup for #144: replaced MAC row with Device Name and added Firmware row.
- Runtime card values for #136 and #138: Flash, SRAM, and PSRAM rows now map to runtime sensors.
- C3 and WROOM PSRAM handling: PSRAM text sensor now returns None on non-PSRAM boards.
- Added preflight guards for new device-card IDs.

## ESPHome Output
- Full ESPHome compile/run was not executed in this agent session.
- render_sensor_config.py --write and --check completed successfully.
- preflight YAML validation passed.

## Checkpoint Evidence
Checkpoint A:
- grep -c di-device-name in template: 1
- grep -c di-firmware-version in template: 1
- grep -c di-mac in template: 0
- status-snapshot contains di-device-name mapping: PASS
- manifest.js contains di-device-name and di-firmware-version population logic: PASS

Checkpoint B:
- grep -c di-flash|di-sram|di-psram in template: 3
- grep -c flash_size|sram_size|psram in status-snapshot.js: 3
- grep -c flash_size|sram_size|psram in firmware/esp32-c3-multi-sensor.yaml: 4

## Validation Evidence
Preflight:
- bash scripts/preflight.sh: PASS
- New checks PASS: device_card_has_device_name, device_card_has_firmware_version, device_card_has_flash, device_card_has_sram

Pipeline execution order:
1. bash scripts/bundle-dashboard.sh --write
2. python3 scripts/render_sensor_config.py --write
3. node tests/fixtures/generate-fixtures.js
4. python3 scripts/render_sensor_config.py --write
5. bash scripts/build-dashboard.sh --write
6. bash scripts/minify-dashboard.sh
7. bash scripts/generate-header.sh
8. python3 scripts/render_sensor_config.py --check

## Playwright Fixture Table
- FIXTURE_SET=3sensor, project=chromium: passed 99, failed 0, skipped 45
- FIXTURE_SET=3sensor, project=firefox: passed 99, failed 0, skipped 45
- FIXTURE_SET=mixed, project=chromium, grep Mixed: passed 7, failed 0, skipped 0
- FIXTURE_SET=system, project=chromium, grep System: passed 8, failed 0, skipped 0
- FIXTURE_SET=aggregator, project=chromium, grep Aggregator: passed 11, failed 0, skipped 1

## Notes
- bump-version.sh initially failed at preflight on history_header_version_matches.
- Resolved by running assemble-sensor-history.sh --write, then rerunning the required pipeline and validations.
