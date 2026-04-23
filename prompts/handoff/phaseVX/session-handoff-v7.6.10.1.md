# Session Handoff — v7.6.10.1: Board Profiles and Partition Tables

_Date: 2026-04-22_
_Repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor_
_Status: v7.6.10.0 COMPLETE (ESPHome 2026.4.1 verified, local component override re-patched). Ready for board onboarding._

---

## Project State Summary

ESPHome 2026.4.1 is the verified build environment. All 3 existing boards (C3, WROOM, S3) compile and pass stress tests. The local component override (16 KB httpd stack) is confirmed active.

Three new boards are physically prepared, flashed with placeholder ESPHome configs, and responding on the network. This step creates proper board profiles, partition tables, and verifies compilation.

---

## Phase VX Progress Table

| Version | Scope | Status |
|---|---|---|
| v7.6.10.0 | ESPHome upgrade verification + local component re-patch | ✅ Complete |
| **v7.6.10.1** | **Board profiles + partition tables for 3 new boards** | **⬅️ Current** |
| v7.6.10.2 | Flash, measure, document (operator-driven) | 🔜 Queued |
| v7.6.10.3 | Capacity study + board selection guide update (advisory) | 🔜 Queued |
| v7.6.10.4 | Dashboard auth refactor (optional) | 🔜 Queued |

---

## New Board Hardware Summary

| Board | board_id | Chip | SRAM | PSRAM | Flash | IP | Serial port | esphome_board |
|---|---|---|---|---|---|---|---|---|
| ESP32-S3 SuperMini | `esp32-s3-supermini-4m` | ESP32-S3 | 512 KB | 2 MB (quad) | 4 MB | 192.168.120.192 | /dev/ttyACM1 | `esp32-s3-devkitc-1` |
| ESP32-C6 SuperMini | `esp32-c6-supermini-4m` | ESP32-C6 | 512 KB | None | 4 MB | 192.168.120.196 | /dev/ttyACM1 | `esp32-c6-devkitm-1` |
| ESP32-C5-WROOM-1U | `esp32-c5-wroom1u-8m` | ESP32-C5 | 384 KB | 8 MB (quad) | 8 MB | 192.168.120.195 | /dev/ttyACM1 | `esp32-c5-devkitc-1` |

### Board-specific notes

**ESP32-S3 SuperMini:**
- Same chip family as the existing S3 aggregator, but 4 MB flash and 2 MB PSRAM (vs 16 MB / 8 MB)
- Uses `quad` PSRAM mode at 80 MHz (not octal — the module doesn't support OPI)
- Placeholder logs: 258 KB free heap, PSRAM confirmed 2048 KB
- `esphome_board`: `esp32-s3-devkitc-1` (generic S3 DevKit — confirmed working in placeholder config)

**ESP32-C6 SuperMini:**
- First C6 in the fleet. RISC-V single core, 160 MHz max, WiFi 6 (2.4 GHz), BLE 5.3, 802.15.4
- No PSRAM
- Placeholder logs: 293 KB free heap, 7.1% fragmentation — very healthy
- `esphome_board`: `esp32-c6-devkitm-1` (confirmed working)
- ⚠️ Placeholder YAML had name typo `sat-c6-6m-1` — corrected to `sat-c6-4m-1` in board profile

**ESP32-C5-WROOM-1U (MCN8R8):**
- First C5 in the fleet. RISC-V single core, 240 MHz, WiFi 6 dual-band (2.4 + 5 GHz), BLE 5.0, 802.15.4
- 8 MB PSRAM confirmed by logs (`PSRAM: Size: 8192 KB`)
- 8 MB flash confirmed by esptool
- **Crystal: 48 MHz (not 26 MHz).** esptool misdetects as 26 MHz. Requires `CONFIG_XTAL_FREQ_48: 'y'` in sdkconfig_options
- **Bootloader offset: 0x2000** (differs from C3/C6/S3 which use 0x0) — partition table must not place data before 0x2000
- Placeholder logs: 184 KB free heap (SRAM only), 8192 KB PSRAM
- `esphome_board`: `esp32-c5-devkitc-1` (confirmed working with the xtal config)

---

## v7.6.10.1 Scope

### What this step does

For each of the 3 new boards:

1. **Board profile** at `firmware/boards/<board-id>.yaml` — follows existing schema exactly
2. **Partition table** at `partitions/<board-id>-multi-partitions.csv` — sized for the board's flash
3. **Compile verification** — `esphome compile` of a test YAML that uses the board profile

Plus infrastructure:

4. **`scripts/render_sensor_config.py`** — add `SRAM_KB_BY_CHIP` entries for `esp32c6` and `esp32c5`
5. **VERSION bump** to 7.6.10.1
6. **Changelog** update
7. **Preflight + Playwright** green

### What this step does NOT do

- No `provision.sh` changes — these boards don't have gateway/sensor configs yet
- No firmware handler changes
- No dashboard changes
- No NVS format changes
- No changes to existing board profiles or partition tables

### Partition table strategy

| Board | Flash | Base template | OTA slot size | History size | Notes |
|---|---|---|---|---|---|
| S3 SuperMini | 4 MB | `esp32-c3-multi-partitions.csv` | 0x1B0000 (1.75 MB) | 0x80000 (512 KB) | Same as C3/WROOM 4 MB layout |
| C6 SuperMini | 4 MB | `esp32-c3-multi-partitions.csv` | 0x1B0000 (1.75 MB) | 0x80000 (512 KB) | Same as C3/WROOM 4 MB layout |
| C5 WROOM-1U | 8 MB | New | 0x300000 (3 MB) | 0x100000 (1 MB) | 8 MB allows larger OTA + bigger history |

**C5 8 MB partition table design:**

```
# Name,     Type, SubType,  Offset,   Size
nvs,        data, nvs,      0x9000,   0x4000,
otadata,    data, ota,      0xD000,   0x2000,
phy_init,   data, phy,      0xF000,   0x1000,
ota_0,      app,  ota_0,    0x10000,  0x300000,
ota_1,      app,  ota_1,    ,         0x300000,
history,    data, nvs,      ,         0x100000,
coredump,   data, coredump, ,         0x10000,
```

Rationale: 3 MB OTA slots give ample room for C5 binaries (currently 948 KB). 1 MB history gives ~2x the 4 MB boards' retention. Total: 16 KB + 8 KB + 4 KB + 3 MB + 3 MB + 1 MB + 64 KB = 7.09 MB of 8 MB used. Remaining ~0.9 MB is unused flash at end.

**Critical: `ota_0` at 0x10000 in ALL partition tables** (BUG-061).

**Note on C5 bootloader offset:** The C5 places its bootloader at 0x2000 (not 0x0 like other ESP32 variants). This is handled by the ESP-IDF build system automatically — the custom partition table only defines data/app partitions starting at 0x9000. The 0x0–0x8FFF region (bootloader + partition table header) is managed by the build system. No special handling needed in the CSV.

### Compile verification approach

Since these boards don't have gateway configs yet, compilation verification uses minimal test YAMLs that reference the board profile's key fields. The agent creates temporary test YAMLs (NOT committed) that exercise:
- Correct `variant` and `esphome_board`
- Correct `framework: type: esp-idf`
- Correct partition table reference
- `external_components` block (Critical Rule 42)
- PSRAM config (where applicable)
- Board-specific sdkconfig_options

Alternatively, if `render_sensor_config.py` can generate a YAML from the board profile in satellite mode, use that.

### Files created

- `firmware/boards/esp32-s3-supermini-4m.yaml`
- `firmware/boards/esp32-c6-supermini-4m.yaml`
- `firmware/boards/esp32-c5-wroom1u-8m.yaml`
- `partitions/esp32-s3-4m-multi-partitions.csv`
- `partitions/esp32-c6-multi-partitions.csv`
- `partitions/esp32-c5-multi-partitions.csv`

### Files modified

- `scripts/render_sensor_config.py` — add `SRAM_KB_BY_CHIP` entries
- `Docs/changelog.md` — v7.6.10.1 entry
- `VERSION` — bump to 7.6.10.1

---

## Context That Carries Forward

### To v7.6.10.2

- Board profiles and partition tables are committed
- Boards need reflashing with actual project firmware (using the board profile's settings)
- Measurement protocol requires full firmware, not placeholder configs
- The operator will use the board profiles to create test firmware configs

---

_End of session handoff document._
