# Board Measurement Log — v7.6.10

_Phase VX measurement results. Fill after running `Docs/board-measurement-protocol-v7.6.10.md`._
_This file is consumed by `prompts/handoff/multi-phase-planning-supplement-post-vx.md` for Phase 7 planning._
_Updated: 2026-05-05 — pre-filled v7.6.10.0 baselines for existing 3 boards._

---

## Measurement Conditions

- ESPHome version: 2026.4.1
- ESP-IDF version: 5.5.4
- Local component override: 16 KB httpd stack (verified by `patch-esphome-httpd-stack.sh --check`)
- Date (existing boards): 2026-04-26 (v7.6.10.0 post-flash)
- Date (new boards): ___ (v7.6.10.2)
- Firmware version: v7.6.10.0 (existing boards); v7.6.10.1 test firmware (new boards)

---

## Compilation Results

| Board | board_id | Chip | Flash size | Binary size | RAM used | RAM % | Flash used | Flash % | Compiles |
|---|---|---|---|---|---|---|---|---|---|
| C3 SuperMini | esp32-c3-supermini | ESP32-C3 | 4 MB | 1,428,928 B | 60,688 B | 18.5% | 1,428,672 B | 80.7% | ✅ |
| WROOM-32D | esp32-wroom-32d | ESP32 | 4 MB | 1,279,395 B | 72,128 B | 22.0% | 1,279,139 B | 72.3% | ✅ |
| S3 DevKitC N16R8 | esp32-s3-devkitc1-n16r8 | ESP32-S3 | 16 MB | 934,715 B | 123,640 B | 37.7% | 934,459 B | 29.7% | ✅ |
| S3 SuperMini | esp32-s3-supermini-4m | ESP32-S3 | 4 MB | ___ | ___ | ___ | ___ | ___ | ___ |
| C6 SuperMini | esp32-c6-supermini-4m | ESP32-C6 | 4 MB | ___ | ___ | ___ | ___ | ___ | ___ |
| C5 WROOM-1U | esp32-c5-wroom1u-8m | ESP32-C5 | 8 MB | ___ | ___ | ___ | ___ | ___ | ___ |

---

## Boot Telemetry

_Values collected ≥2 minutes after boot. All heap values in bytes unless noted._

| Board | Chip | Arch | SRAM | PSRAM | free_heap | min_free_heap | Heap frag % | httpd_stack_wm | Notes |
|---|---|---|---|---|---|---|---|---|---|
| C3 SuperMini | ESP32-C3 | RISC-V | 400 KB | None | 58,456 | 47,616 | — | 12,924 | v7.6.10.0 baseline (218s uptime) |
| WROOM-32D | ESP32 | Xtensa LX6 | 520 KB | None | 38,760 | 15,936 | — | 13,188 | v7.6.10.0 baseline (1070s uptime) |
| S3 DevKitC N16R8 | ESP32-S3 | Xtensa LX7 | 512 KB | 8 MB OPI | 53,432 | 8,398,704 | — | 10,036 | min_free_heap includes 8MB PSRAM |
| S3 SuperMini | ESP32-S3 | Xtensa LX7 | 512 KB | 2 MB quad | ___ | ___ | ___ | ___ | NEW — free_heap may include PSRAM |
| C6 SuperMini | ESP32-C6 | RISC-V | 512 KB | None | ___ | ___ | ___ | ___ | NEW — first C6 |
| C5 WROOM-1U | ESP32-C5 | RISC-V | 384 KB | 8 MB quad | ___ | ___ | ___ | ___ | NEW — free_heap may include PSRAM |

---

## Stress Test Results

_Run `bash scripts/stress-test-httpd-stack.sh <IP> [--concurrent=N]` for each board._
_Default concurrent=4 for non-PSRAM boards. Use --concurrent=8 for PSRAM boards._

| Board | Concurrent | Pre-stress wm | Wave 1 wm | Wave 2 wm | Wave 3 wm | Wave 4 wm | Wave 5 wm | Min wm | Result |
|---|---|---|---|---|---|---|---|---|---|
| C3 SuperMini | 8 (BUG-084) | 12,924 | 12,900 | CRASH | — | — | — | 12,900 | Stack OK, heap crash |
| WROOM-32D | 8 (BUG-084) | 12,996 | CRASH | — | — | — | — | 12,996 | Stack OK, heap crash |
| S3 DevKitC N16R8 | 8 | 10,036 | script exit | — | — | — | — | 10,036 | Board survived, script timed out |
| C3 SuperMini | 4 | ___ | ___ | ___ | ___ | ___ | ___ | ___ | ___ (re-run with fixed script) |
| WROOM-32D | 4 | ___ | ___ | ___ | ___ | ___ | ___ | ___ | ___ (re-run with fixed script) |
| S3 DevKitC N16R8 | 4 | ___ | ___ | ___ | ___ | ___ | ___ | ___ | ___ (re-run with fixed script) |
| S3 SuperMini | 4 | ___ | ___ | ___ | ___ | ___ | ___ | ___ | ___ |
| C6 SuperMini | 4 | ___ | ___ | ___ | ___ | ___ | ___ | ___ | ___ |
| C5 WROOM-1U | 8 | ___ | ___ | ___ | ___ | ___ | ___ | ___ | ___ |

_BUG-084: The concurrent=8 rows for C3 and WROOM document the crash. Re-run with concurrent=4 after script fix._
_Note: S3 at concurrent=8 — board survived but script exited due to set -e + curl timeout. Re-run with fixed script._

---

## Placeholder Firmware Baselines (pre-v7.6.10.1)

_Values from placeholder configs (before board profiles applied). Recorded during board preparation._

| Board | Free heap (boot) | PSRAM confirmed | WiFi signal | Partition layout | Notes |
|---|---|---|---|---|---|
| S3 SuperMini | 258,132 B (252 KB) | 2,048 KB ✅ | -21 dB | ESPHome default 4 MB | Clean boot, no errors |
| C6 SuperMini | ~300,032 B (293 KB) | N/A | — | ESPHome default | 7.1% fragmentation, stable |
| C5 WROOM-1U | 184,212 B (180 KB) | 8,192 KB ✅ | -60 dB | ESPHome default 8 MB | CONFIG_XTAL_FREQ_48 applied |

---

## v7.6.9.5 → v7.6.10.0 Comparison (Existing Boards)

| Board | Metric | v7.6.9.5 | v7.6.10.0 | Delta | Notes |
|---|---|---|---|---|---|
| C3 | httpd_stack_wm | 12,768 | 12,924 | +156 (noise) | |
| C3 | free_heap | 57,268 | 58,456 | +1,188 | |
| WROOM | httpd_stack_wm | 13,044 | 13,188 | +144 (noise) | |
| WROOM | free_heap | 37,032 | 38,760 | +1,728 | |
| S3 | httpd_stack_wm | 12,528 | 10,036 | **−2,492** | ESPHome 2026.4.1 SSE internals |
| S3 | free_heap | 52,792 | 53,432 | +640 | |

**S3 watermark regression**: Dropped from 12,528 to 10,036 B (still above 10,000 threshold).
Caused by ESPHome 2026.4.1's new SSE code paths. Monitor in future upgrades.

---

## Observations and Anomalies

### BUG-084: Heap exhaustion under concurrent HTTP connections (2026-05-05)

8 concurrent HTTP requests crash C3 and WROOM via heap exhaustion (NOT stack overflow).
Stack watermarks healthy (~12,900 B). The crash happens when `free_heap` drops below
WiFi/LWIP operating minimum (~15-20 KB). PSRAM-equipped boards (S3) survive.

Stress test script updated with `--concurrent=N` parameter. Default reduced to 4.

### WROOM IRAM hint (ESPHome 2026.4.1)

ESPHome 2026.4.1 suggests `sram1_as_iram: true` for WROOM. NOT recommended — would
subtract ~40 KB from DRAM, worsening BUG-084 heap pressure. See LESSON-OPS-131.

### S3 IRAM at 100%

S3 build shows `IRAM: 100.0% (16384/16384)`. Not a problem — overflow code executes
from flash (slightly slower). No configuration change helps.

---

_End of measurement log._
