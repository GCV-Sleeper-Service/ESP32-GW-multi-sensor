# Architecture Overview — Surgical Edits for v7.6.10.3

_Apply these find/replace edits to `Docs/architecture-overview.md`._

---

## Edit 1: Add new boards to Hardware Targets table (lines 20-24)

**FIND:**
```
| Board | Role | PSRAM | Max Satellites |
|-------|------|-------|----------------|
| ESP32-C3 SuperMini | Satellite only | None | N/A |
| ESP32-WROOM-32D | Satellite only | None | N/A |
| ESP32-S3-DevKitC1-N16R8 | Satellite + Aggregator | 8MB | 8 |
```

**REPLACE:**
```
| Board | Role | PSRAM | Max Satellites | Status |
|-------|------|-------|----------------|--------|
| ESP32-C3 SuperMini | Satellite only | None | N/A | Production |
| ESP32-WROOM-32D | Satellite only | None | N/A | Production |
| ESP32-S3-DevKitC1-N16R8 | Satellite + Aggregator | 8MB OPI | 8 | Production |
| ESP32-S3 SuperMini | Satellite (+ light agg ≤4) | 2MB quad | 4 | v7.6.10.1 |
| ESP32-C6 SuperMini | Satellite only | None | N/A | v7.6.10.1 |
| ESP32-C5 WROOM-1U | Satellite only | 8MB quad | N/A | v7.6.10.1 (⚠️ BLE re-test needed) |
```

---

## Edit 2: Update Phase VX version range in phase table

**FIND:**
```
| **Phase VX** | **v7.6.10.0–v7.6.10.3** | **Board onboarding sprint** | **In Progress** |
```

**REPLACE:**
```
| **Phase VX** | **v7.6.10.0–v7.6.10.4** | **Board onboarding sprint** | **In Progress** |
```

---

## Edit 3: Add board selection guide and capacity study to Active Planning Documents table

**FIND:**
```
| `Docs/esp32-board-selection-guide.md` | Board selection and capability reference |
```

**REPLACE:**
```
| `Docs/esp32-board-selection-guide.md` | Board selection guide — 6 boards, measured data (v7.6.10.0) |
| `Docs/phase-V-capacity-study.md` | Memory/flash capacity study — 6 boards, BUG-084, role variants |
| `Docs/board-measurement-log-v7.6.10.md` | Phase VX board measurement data |
```

---

_End of architecture overview edits._
