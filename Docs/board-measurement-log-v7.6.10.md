# Board Measurement Log — v7.6.10

_Phase VX measurement results. Fill after running `Docs/board-measurement-protocol-v7.6.10.md`._
_This file is consumed by `prompts/handoff/multi-phase-planning-supplement-post-vx.md` for Phase 7 planning._

---

## Measurement Conditions

- ESPHome version: 2026.4.1
- ESP-IDF version: 5.5.4
- Local component override: 16 KB httpd stack (verified by `patch-esphome-httpd-stack.sh --check`)
- Date: ___
- Firmware version: ___

---

## Compilation Results

| Board | board_id | Chip | Flash size | Binary size | RAM used | RAM % | Flash used | Flash % | Compiles |
|---|---|---|---|---|---|---|---|---|---|
| C3 SuperMini | esp32-c3-supermini | ESP32-C3 | 4 MB | ___ | ___ | ___ | ___ | ___ | ✅ |
| WROOM-32D | esp32-wroom-32d | ESP32 | 4 MB | ___ | ___ | ___ | ___ | ___ | ✅ |
| S3 DevKitC N16R8 | esp32-s3-devkitc1-n16r8 | ESP32-S3 | 16 MB | ___ | ___ | ___ | ___ | ___ | ✅ |
| S3 SuperMini | esp32-s3-supermini-4m | ESP32-S3 | 4 MB | ___ | ___ | ___ | ___ | ___ | ___ |
| C6 SuperMini | esp32-c6-supermini-4m | ESP32-C6 | 4 MB | ___ | ___ | ___ | ___ | ___ | ___ |
| C5 WROOM-1U | esp32-c5-wroom1u-8m | ESP32-C5 | 8 MB | ___ | ___ | ___ | ___ | ___ | ___ |

---

## Boot Telemetry

_Values collected ≥2 minutes after boot. All heap values in bytes unless noted._

| Board | Chip | Arch | SRAM | PSRAM | free_heap | min_free_heap | Heap frag % | httpd_stack_wm | Notes |
|---|---|---|---|---|---|---|---|---|---|
| C3 SuperMini | ESP32-C3 | RISC-V | 400 KB | None | ___ | ___ | ___ | ___ | v7.6.9.5 baseline: 57268 / 29668 / 12768 |
| WROOM-32D | ESP32 | Xtensa LX6 | 520 KB | None | ___ | ___ | ___ | ___ | v7.6.9.5 baseline: 37032 / 13616 / 13044 |
| S3 DevKitC N16R8 | ESP32-S3 | Xtensa LX7 | 512 KB | 8 MB OPI | ___ | ___ | ___ | ___ | free_heap may include PSRAM |
| S3 SuperMini | ESP32-S3 | Xtensa LX7 | 512 KB | 2 MB quad | ___ | ___ | ___ | ___ | NEW — free_heap may include PSRAM |
| C6 SuperMini | ESP32-C6 | RISC-V | 512 KB | None | ___ | ___ | ___ | ___ | NEW — first C6 |
| C5 WROOM-1U | ESP32-C5 | RISC-V | 384 KB | 8 MB quad | ___ | ___ | ___ | ___ | NEW — free_heap may include PSRAM |

---

## Stress Test Results

_Run `bash scripts/stress-test-httpd-stack.sh <IP>` for each board._

| Board | Pre-stress wm | Wave 1 wm | Wave 2 wm | Wave 3 wm | Wave 4 wm | Wave 5 wm | Min wm | Pass (≥10000)? |
|---|---|---|---|---|---|---|---|---|
| C3 SuperMini | ___ | ___ | ___ | ___ | ___ | ___ | ___ | ___ |
| WROOM-32D | ___ | ___ | ___ | ___ | ___ | ___ | ___ | ___ |
| S3 DevKitC N16R8 | ___ | ___ | ___ | ___ | ___ | ___ | ___ | ___ |
| S3 SuperMini | ___ | ___ | ___ | ___ | ___ | ___ | ___ | ___ |
| C6 SuperMini | ___ | ___ | ___ | ___ | ___ | ___ | ___ | ___ |
| C5 WROOM-1U | ___ | ___ | ___ | ___ | ___ | ___ | ___ | ___ |

_Note: Stress test requires `/api/status/full` endpoint. If board runs minimal test firmware, record "N/A — minimal firmware" and note debug sensor values instead._

---

## Placeholder Firmware Baselines (pre-v7.6.10.1)

_Values from placeholder configs (before board profiles applied). Recorded during board preparation._

| Board | Free heap (boot) | PSRAM confirmed | WiFi signal | Partition layout | Notes |
|---|---|---|---|---|---|
| S3 SuperMini | 258,132 B (252 KB) | 2,048 KB ✅ | -21 dB | ESPHome default 4 MB | Clean boot, no errors |
| C6 SuperMini | ~300,032 B (293 KB) | N/A | — | ESPHome default | 7.1% fragmentation, stable |
| C5 WROOM-1U | 184,212 B (180 KB) | 8,192 KB ✅ | -60 dB | ESPHome default 8 MB | CONFIG_XTAL_FREQ_48 applied |

---

## Observations and Anomalies

_Record anything unexpected here: crash logs, unusual heap values, compilation warnings, etc._

---

_End of measurement log._
