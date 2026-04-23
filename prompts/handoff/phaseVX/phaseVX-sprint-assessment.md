# Phase VX — Sprint Assessment and Corrections

_Date: 2026-04-22_
_Source: `prompts/handoff/phaseVX/phaseVX-board-onboarding-sprint-prompt.md` (original)_
_Purpose: Document deviations between the sprint prompt assumptions and actual hardware/software state, and record corrected step scope._

---

## 1. ESPHome Version

| Item | Sprint prompt assumed | Actual |
|---|---|---|
| Current version | 2026.2.1 | 2026.4.1 (already upgraded) |
| Target version | 2026.4.0 | 2026.4.1 (already at target) |
| ESP-IDF version | 5.5.2 → TBD | 5.5.4 (bundled with ESPHome 2026.4.1) |

**Impact on v7.6.10.0:** The `pip install` / ESPHome upgrade is already done. Step reduces to: re-run `patch-esphome-httpd-stack.sh`, verify existing boards compile/flash/pass stress test, bump VERSION, update changelog. Significantly smaller scope.

---

## 2. Board Inventory Corrections

The sprint prompt listed 4 new boards. Only 3 are physically prepared:

| Board | Sprint assumed | Actual state | Status |
|---|---|---|---|
| ESP32-S3 SuperMini | 512 KB SRAM, 2 MB PSRAM, 4 MB flash | **Confirmed.** Flashed, booted, 258 KB free heap, PSRAM 2048 KB. IP 192.168.120.192. | ✅ Ready |
| ESP32-C6 SuperMini | 512 KB SRAM, no PSRAM, 4 MB flash | **Confirmed.** Flashed, booted, 293 KB free heap. IP 192.168.120.196. | ✅ Ready |
| ESP32-C6-DevKitC-1 | 512 KB SRAM, no PSRAM, 16 MB flash | **Not available.** Board not prepared. | ❌ Deferred |
| ESP32-C5 | 384 KB SRAM, optional PSRAM, 4 MB flash | **Differs.** ESP32-C5-WROOM-1U (MCN8R8): **8 MB flash, 8 MB PSRAM confirmed by logs.** IP 192.168.120.195. | ✅ Ready (specs differ) |

### C5 board details

The C5 board label reads "ESP32-C5-Wroom-1U" with "MCN8R8" at bottom. The logs confirm:
- `PSRAM: Available: YES, Size: 8192 KB` → **8 MB PSRAM**
- `Detected flash size: 8MB` → **8 MB flash**
- `Features: Wi-Fi 6 (dual-band), BT 5 (LE), IEEE802.15.4, Single Core + LP Core, 240MHz`
- Crystal: 26 MHz (esptool reports 0.58 MHz warning — cosmetic, does not affect operation)
- Workaround applied: `CONFIG_XTAL_FREQ_48: 'y'` in sdkconfig_options eliminates compile/upload warnings
- Bootloader offset: **0x2000** (differs from C3/C6/S3 which use 0x0)

### C6 naming issue

The placeholder YAML has `name: sat-c6-6m-1` — the "6m" is a typo. The board has 4 MB flash and the intended name is `sat-c6-4m-1`. The final board profile will use the correct name. The currently running firmware identifies as `sat-c6-6m-1` at IP 192.168.120.196; this will be overwritten when the proper firmware is flashed.

### C5 naming issue

The esphome build output and hostname show `sat-c3-8m-1` (from an earlier yaml revision). The attached yaml says `sat-c5-8m-1` (correct). The board will need reflashing with the corrected name once the proper board profile firmware is built.

---

## 3. Technical Findings from Placeholder Firmware

### Compilation success (all 3 boards)

| Board | Binary size | RAM usage | Flash usage | Build time |
|---|---|---|---|---|
| S3 SuperMini | 802 KB | 11.9% (38,884 B / 327,680 B) | 43.7% | 251 s |
| C6 SuperMini | 911 KB | 12.1% (39,808 B / 327,680 B) | 49.7% | 148 s |
| C5 | 948 KB | 13.7% (44,824 B / 327,680 B) | 24.1% (of 8 MB) | 250 s |

### Boot telemetry from placeholder configs

| Board | Free heap (boot) | Heap fragmentation | PSRAM | WiFi signal | Notes |
|---|---|---|---|---|---|
| S3 SuperMini | 258,132 B (252 KB) | — | 2,048 KB | -21 dB | Strong signal, very healthy heap |
| C6 SuperMini | ~300,032 B (293 KB) | 7.1% | None | — | Stable across multiple readings |
| C5 | 184,212 B (180 KB) | — | 8,192 KB | -60 dB | Lower SRAM heap expected (384 KB silicon) |

### Partition tables from placeholder configs

| Board | Partition layout | ota_0 offset | ota_0 size | nvs size | Notes |
|---|---|---|---|---|---|
| S3 SuperMini | app0+app1+nvs | 0x10000 ✅ | 0x1C0000 (1.75 MB) | 0x6D000 (436 KB) | Standard 4 MB layout |
| C6 SuperMini | app0+app1 | 0x10000 ✅ | — | — | Default ESPHome layout |
| C5 | app0+app1+nvs | 0x10000 ✅ | 0x3C0000 (3.75 MB) | 0x70000 (448 KB) | ESPHome default 8 MB layout |

### C5 bootloader offset difference

The C5's factory.bin layout starts bootloader at offset **0x2000**, not 0x0:
```
Offset   | File
0x2000   | bootloader.bin
0x8000   | partitions.bin
0x9000   | ota_data_initial.bin
0x10000  | firmware.bin
```

This is an ESP32-C5 platform requirement. The custom partition table must NOT place any data at 0x0–0x1FFF. The `ota_0` offset at 0x10000 is preserved (Critical Rule — BUG-061).

---

## 4. Infrastructure Gaps Identified

### render_sensor_config.py — SRAM_KB_BY_CHIP

The `SRAM_KB_BY_CHIP` map (line 61) only contains entries for `esp32`, `esp32c3`, `esp32s3`. Adding boards with `chip_variant: "esp32c6"` or `"esp32c5"` will crash the renderer:

```python
SRAM_KB_BY_CHIP = {
    "esp32": "520 KB",
    "esp32c3": "400 KB",
    "esp32s3": "512 KB",
}
```

**Required additions:**
```python
    "esp32c6": "512 KB",
    "esp32c5": "384 KB",
```

### provision.sh — new targets

The existing targets are `satellite` (C3), `aggregator` (S3), `wroom`. New boards need provision targets, but since they're satellite-only and don't have gateway/sensor configs yet, they can't use the full pipeline. Options:
1. Add lightweight provision targets that only compile (no config switching)
2. Defer provision.sh integration until a gateway config exists for each board

**Recommendation:** Option 2. These boards won't run full firmware in Phase VX — they'll run minimal test configs for measurement. The `provision.sh` update belongs in Phase 7 when boards get actual sensor assignments.

### preflight.sh — external_components check

The current preflight check (line 299+) hardcodes the C3 template path and iterates board profiles. New board profiles will automatically be checked if they're in `firmware/boards/`. But new boards won't have generated gateway YAMLs yet — the check for gateway YAMLs should skip boards without configs.

---

## 5. Corrected Step Breakdown

### v7.6.10.0 — ESPHome Upgrade Verification (reduced scope)

Since ESPHome 2026.4.1 is already installed, this step verifies the upgrade didn't break anything:
1. Re-run `scripts/patch-esphome-httpd-stack.sh` against ESPHome 2026.4.1
2. Verify `--check` passes
3. Clean build all 3 existing boards (C3, WROOM, S3)
4. Operator: flash + stress test after merge
5. Bump VERSION to 7.6.10.0, changelog, docs

### v7.6.10.1 — Board Profiles for 3 New Boards

For each of the 3 available boards:
1. Board profile YAML in `firmware/boards/`
2. Partition table CSV in `partitions/`
3. `SRAM_KB_BY_CHIP` update in `render_sensor_config.py`
4. `esphome compile` verification
5. Docs: changelog, board selection guide stub entries

**No provision.sh changes** — boards don't have gateway configs yet.

### v7.6.10.2 — Flash, Measure, Document (operator-driven)

Unchanged from sprint prompt, but only 3 boards (not 4). The operator flashes boards with the project's full test firmware, collects measurements, runs stress tests.

### v7.6.10.3 — Capacity Study and Board Selection Guide Update

Claude advisory session — unchanged scope, but measurements from 6 boards total (3 existing + 3 new), not 7.

### v7.6.10.4 — Dashboard Auth Refactor (optional)

Unchanged from sprint prompt.

---

## 6. Pre-Planning-Session Updates

After Phase VX completes, before running the multi-phase planning session:

1. `prompts/handoff/multi-phase-planning-supplement-post-vx.md` — needs board table updated to reflect 3 boards (not 4), C5 specs corrected (8 MB flash, 8 MB PSRAM)
2. `prompts/prompt-index-and-workflow.md` — needs Phase VX step index added (Phase V skipped this — must not recur)
3. `Docs/board-measurement-log-v7.6.10.md` — must be populated with actual measurements before the planning session

---

_End of sprint assessment._
