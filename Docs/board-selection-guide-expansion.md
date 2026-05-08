# Expanded Board Selection Guide — Use-Case Matrix

_Generated: 2026-05-07 (Rev 2 — corrected retention, added C6 8MB, binary dedup)_
_Source: `Docs/board-measurement-log-v7.6.10.md` (2026-05-05)_

---

## Measured Data

| Board | Chip | SRAM | PSRAM | Flash | free_heap | min_free_heap | httpd_wm | OTA % |
|---|---|---|---|---|---|---|---|---|
| C3 SuperMini | ESP32-C3 | 400 KB | — | 4 MB | 58,456 B | 47,616 B | 12,924 B | 80.7% |
| WROOM-32D | ESP32 | 520 KB | — | 4 MB | 38,760 B | 15,936 B | 13,188 B | 72.3% |
| S3 DevKitC | ESP32-S3 | 512 KB | 8 MB OPI | 16 MB | 53,432 B | 8,398,704 B | 10,036 B | 29.7% |
| S3 SuperMini | ESP32-S3 | 512 KB | 2 MB quad | 4 MB | 123,156 B | 2,209,636 B | 12,512 B | 73.7% |
| C6 4MB | ESP32-C6 | 512 KB | — | 4 MB | 150,332 B | 152,820 B | 12,820 B | 91.6% |
| C6 8MB | ESP32-C6 | 512 KB | — | 8 MB | ~150 KB est. | — | ~12,800 est. | ~52% est. |
| C5 WROOM-1U | ESP32-C5 | 384 KB | 8 MB quad | 8 MB | 32,908 B | 8,420,784 B | 12,728 B | 52.8% |

## Per-Device Retention (Phase 7 planned partition sizes)

| Partition | Boards | 4 devices | 6 devices | 8 devices |
|---|---|---|---|---|
| 640 KB | C3, WROOM, S3-4M | 21 days | 14 days | 10 days |
| 480 KB | C6 4MB (binary) | 17 days (nominal) | 12 days (months w/ dedup) | — |
| 1 MB | C6 8MB, C5 | 34 days | 22 days | 17 days |
| 4 MB | S3 DevKitC 16MB | 135 days | 90 days | 67 days |

## Capability Matrix

| Board | Role | Notifications/TLS | Cloud | Max sensors |
|---|---|---|---|---|
| C3 SuperMini | Satellite | ❌ | ❌ | 3-4 |
| WROOM-32D | Satellite | ❌ | ❌ | 3-4 |
| C6 4MB | Binary-sensor satellite | ✅ | ✅ | 6-10 binary |
| C6 8MB | Standard satellite | ✅ | ✅ | 6-7 |
| S3 SuperMini | Satellite / ≤4 sat aggregator | ✅ | ✅ | 12+ |
| S3 DevKitC | ≤8 sat aggregator | ✅ | ✅ | 20+ |
| C5 WROOM-1U | Satellite (BLE pending A-004) | ✅ | ✅ | 8+ |
