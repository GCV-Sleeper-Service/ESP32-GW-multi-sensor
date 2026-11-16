# Session Log - v7.6.10.1: Board Profiles and Partition Tables

_Date: 2026-05-05_

## Context

This session implemented the first Phase VX board-onboarding infrastructure step for
three new ESP32 targets:

- `esp32-s3-supermini-4m`
- `esp32-c6-supermini-4m`
- `esp32-c5-wroom1u-8m`

Scope was intentionally limited to board profiles, partition tables, SRAM metadata,
compile verification, and release metadata. No firmware handler logic, dashboard source,
or `provision.sh` behavior was changed.

## Changes

### 1. Added board profiles

Created three new board profile files under `firmware/boards/` following the existing
schema used by the C3, S3, and WROOM references.

- `firmware/boards/esp32-s3-supermini-4m.yaml`
- `firmware/boards/esp32-c6-supermini-4m.yaml`
- `firmware/boards/esp32-c5-wroom1u-8m.yaml`

All three include the required `external_components` block so the local
`web_server_idf` override remains active (BUG-083 / Rule 42 protection).

Board-specific details:

- S3 SuperMini uses `esp32-s3-devkitc-1`, 4MB flash, and 2MB quad PSRAM.
- C6 SuperMini uses `esp32-c6-devkitm-1`, 4MB flash, and no PSRAM.
- C5 WROOM-1U uses `esp32-c5-devkitc-1`, 8MB flash, quad PSRAM, and
  `CONFIG_XTAL_FREQ_48: "y"` for the 48 MHz crystal.

### 2. Added partition tables

Created three new partition CSVs under `partitions/`.

- `partitions/esp32-s3-4m-multi-partitions.csv`
- `partitions/esp32-c6-multi-partitions.csv`
- `partitions/esp32-c5-multi-partitions.csv`

The S3 and C6 use the same 4MB flash budget as the existing C3/WROOM layout.
The C5 uses a dedicated 8MB layout with 3MB OTA slots and a 1MB history partition.

Critical invariant preserved:

- every new table keeps `ota_0` at `0x10000`

The C5 compile also confirmed the expected split between:

- bootloader offset `0x2000`
- application offset `0x10000`

### 3. Updated generator SRAM metadata and release version

Updated `scripts/render_sensor_config.py` to:

- add `esp32c5 -> 384 KB` to `SRAM_KB_BY_CHIP`
- add `esp32c6 -> 512 KB` to `SRAM_KB_BY_CHIP`
- bump generator `VERSION` to `7.6.10.1`

Also bumped the repo `VERSION` file to `7.6.10.1` and added the corresponding
changelog entry.

## Checkpoints

### Checkpoint A

- `grep -l 'external_components' firmware/boards/*.yaml | wc -l` -> `6`

### Checkpoint B

The prompt's literal command returned `7` because the existing
`partitions/esp32-s3-multi-partitions.csv` contains an explanatory comment line with
both `ota_0` and `0x10000`.

Refined verification:

- `grep '^ota_0,.*0x10000' partitions/*.csv | wc -l` -> `6`

### Checkpoint C

The prompt's literal `grep 'esp32c[56]' scripts/render_sensor_config.py` also matches
an existing chip-label mapping later in the file, so it returns more than just the SRAM
map lines.

Relevant lines added:

- `"esp32c5": "384 KB",`
- `"esp32c6": "512 KB",`

## Compile Verification

All three new boards compiled successfully with temporary YAMLs under `/tmp/`.

### ESP32-S3 SuperMini

- Command: `esphome compile /tmp/test-esp32-s3-supermini-4m.yaml`
- Result: PASS
- RAM: `11.8%` (`38612 / 327680`)
- Flash: `44.3%` (`784579 / 1769472`)
- Total image size: `784835 bytes`

### ESP32-C6 SuperMini

- Command: `esphome compile /tmp/test-esp32-c6-supermini-4m.yaml`
- Result: PASS
- RAM: `12.1%` (`39584 / 327680`)
- Flash: `50.7%` (`896874 / 1769472`)
- Total image size: `897138 bytes`

### ESP32-C5 WROOM-1U

- Command: `esphome compile /tmp/test-esp32-c5-wroom1u-8m.yaml`
- Result: PASS
- RAM: `13.6%` (`44552 / 327680`)
- Flash: `29.5%` (`927140 / 3145728`)
- Total image size: `927396 bytes`

## Notes

- Existing board profiles were not modified.
- Existing partition tables were not modified.
- Version bump regeneration is expected to touch generated dashboard, manifest,
  fixture, and firmware artifacts as a side effect of the normal pipeline.

## Gate Failures And Process Correction

Two pre-PR gate failures occurred after the initial implementation work:

### 1. Preflight failure: fixture generator version drift

`bash scripts/preflight.sh` first failed because:

- `tests/fixtures/generate-fixtures.js` still had `const VERSION = 'v7.6.10.0';`
- canonical `VERSION` and `scripts/render_sensor_config.py` had already been bumped
  to `7.6.10.1`

This was corrected by updating the fixture generator constant and rerunning fixture
generation.

### 2. Preflight failure: dashboard bundle source drift

The next preflight run failed on `dashboard_js_bundle_sync` because:

- `dashboard/core/app-shell.js` still had `App.version = 'v7.6.10.0';`
- `dashboard/dashboard.js` had already been regenerated to `v7.6.10.1`

The bundle sync check correctly reported that `dashboard/dashboard.js` no longer
matched what `bundle-dashboard.sh` would assemble from source modules. The checked-in
`dashboard/dashboard.html` also still carried `v7.6.10.0` and needed to be updated
before the final regeneration pass.

### What should have been done earlier

The version-bump work should have updated all canonical version sources before the
first regeneration and gate run:

- `VERSION`
- `scripts/render_sensor_config.py`
- `tests/fixtures/generate-fixtures.js`
- dashboard source/module version origin (`dashboard/core/app-shell.js`)
- checked-in dashboard HTML version string (`dashboard/dashboard.html`)

Only after those source-of-truth version edits should the regeneration pipeline have
been run.

### Prompt / action adjustment

To avoid this class of interruption in future version-bump sessions, the prompt or
operator checklist should explicitly require a "version source sync" step before any
preflight run:

1. update every canonical version constant
2. run the full regeneration pipeline
3. run `render_sensor_config.py --check`
4. run `preflight`
5. run Playwright

Without that explicit step, preflight correctly catches drift, but the session loses
time to avoidable gate stops.

### 3. Preflight failure: assembled history header identity drift

After the dashboard/version-source fixes, preflight next failed on:

- `firmware_core_assembly_check`

The assembly check showed that `dashboard/sensor_history_multi.h` still had
`v7.6.10.0` in non-generated identity-gated regions:

- `// config-v7.6.10.0.h ...`
- `// ── SENSOR COUNT CONFIGURATION GUIDE (v7.6.10.0) ──`

This required the standard assembled-artifact repair:

- `bash scripts/assemble-sensor-history.sh --write`
- rerun `bash scripts/assemble-sensor-history.sh --check`

### Additional process correction

One more execution mistake surfaced during recovery:

- `minify-dashboard.sh` and `generate-header.sh` were initially run in parallel

That is incorrect because `generate-header.sh` consumes `dashboard/dashboard.min.html`.
Running them in parallel let the header step read stale minified content. Those two
steps must be run sequentially:

1. `bash scripts/minify-dashboard.sh`
2. `bash scripts/generate-header.sh`

For future sessions, the prompt or operator checklist should explicitly mark:

- version-source synchronization first
- identity-gated assembly refresh when versioned assembled artifacts change
- minify/header as sequential, not parallel, steps

### 4. Preflight failure: fragment source-of-truth still on old version

After `assemble-sensor-history.sh --write`, preflight then failed on:

- `history_header_version_matches`

Root cause:

- the fragment source files still contained `v7.6.10.0`
  - `firmware/core/config.h`
  - `firmware/core/data-model.h`
- assembly correctly reproduced those old non-generated lines into
  `dashboard/sensor_history_multi.h`
- that satisfied the assembly identity gate but broke the version gate

Required fix:

1. update the fragment source files to `v7.6.10.1`
2. rerun `bash scripts/assemble-sensor-history.sh --write`
3. rerun `python3 scripts/render_sensor_config.py --write` if needed
4. rerun `bash scripts/assemble-sensor-history.sh --check`
5. rerun `bash scripts/preflight.sh`

This exposed another checklist rule for version-bump work: assembled-artifact source
fragments count as canonical version sources too, not just the assembled output.
