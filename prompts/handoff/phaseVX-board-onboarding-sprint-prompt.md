# Phase VX — Board Onboarding Sprint (v7.6.10.x)

_Self-contained prompt for a fresh Claude session within this project._
_Purpose: Upgrade ESPHome, onboard 4 new boards into the provisioning pipeline, collect measurements, update capacity study and board selection guide._
_Prerequisite: Phase V formally closed (all closure documents produced). VERSION ≥ 7.6.9.6._

---

## Instructions for the Advisor

You are the architectural advisor for the ESP32-GW Multi-Sensor Gateway project. The operator has four new boards to add to the project's provisioning pipeline, and the ESPHome version needs upgrading. Your job is to produce agent prompts for this sprint.

This is an **infrastructure and measurement** phase, not a feature phase. No firmware logic changes, no dashboard changes, no NVS changes. The outputs are: board profiles, partition tables, updated scripts, and a measurement dataset that feeds the multi-phase planning session.

### ⚠️ Read Before Responding

```
git clone https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor
cd ESP32-GW-multi-sensor
git checkout main && git pull
cat VERSION
```

### Mandatory Reading

1. `firmware/boards/` — read all three existing board profiles to understand the schema
2. `partitions/` — read all three partition table CSVs
3. `scripts/provision.sh` — understand how board targets are configured
4. `scripts/render_sensor_config.py` — understand code generation from board profiles
5. `scripts/patch-esphome-httpd-stack.sh` — must be re-run after ESPHome upgrade
6. `scripts/stress-test-httpd-stack.sh` — used for stack watermark measurements
7. `config/sensors.json` — sensor manifest (can be reused for test boards)
8. `Docs/esp32-board-selection-guide.md` — current guide to be expanded
9. `Docs/phase-V-capacity-study.md` — capacity study to be expanded
10. `Docs/lessons/firmware.md` — LESSON-OPS on RISC-V vs Xtensa stack (from v7.6.9.5)
11. `firmware/local_components/web_server_idf/PATCH_INFO.md` — conditional stack sizing docs

### Hardware Inventory

**Existing boards (in production):**

| Board | Chip | Architecture | SRAM | PSRAM | Flash | Current role | IP |
|---|---|---|---|---|---|---|---|
| ESP32-C3 SuperMini | ESP32-C3 | RISC-V | 400 KB | None | 4 MB | Satellite | 192.168.120.189 |
| ESP32-WROOM-32D | ESP32 | Xtensa LX6 | 520 KB | None | 4 MB | Satellite | 192.168.120.190 |
| ESP32-S3-DevKitC1-N16R8 | ESP32-S3 | Xtensa LX7 | 512 KB | 8 MB OPI | 16 MB | Aggregator | 192.168.120.191 |

**New boards (to onboard):**

| Board | Chip | Architecture | SRAM | PSRAM | Flash | Planned role | Notes |
|---|---|---|---|---|---|---|---|
| ESP32-S3 SuperMini | ESP32-S3 | Xtensa LX7 | 512 KB | 2 MB | 4 MB | Satellite (PSRAM) | Tests small-PSRAM satellite |
| ESP32-C6 SuperMini | ESP32-C6 | RISC-V | 512 KB | None | 4 MB | Satellite (Zigbee-capable) | First C6 in fleet |
| ESP32-C6-DevKitC-1 | ESP32-C6 | RISC-V | 512 KB | None | 16 MB | Satellite (large flash) | Tests C6 with large flash |
| ESP32-C5 | ESP32-C5 | RISC-V | 384 KB | Optional | 4 MB | Satellite (5 GHz WiFi) | Dual-band WiFi 6 |

---

## Step Breakdown

### v7.6.10.0 — ESPHome Upgrade (2026.2.1 → 2026.4.0)

**Why:** ESPHome 2026.4.0 provides mature C6/C5 support, better RISC-V crash diagnostics, performance improvements, and custom partition table support. The upgrade must happen before onboarding C6/C5 boards.

**Scope:**
- Upgrade ESPHome installation from 2026.2.1 to 2026.4.0
- Re-run `scripts/patch-esphome-httpd-stack.sh` (upstream `web_server_idf.cpp` changes with each version)
- Verify the conditional stack patch (20 KB RISC-V / 16 KB Xtensa) applies cleanly
- Verify the HTTP_DELETE handler patch (Patch 2) applies cleanly
- Clean build + flash all three existing boards
- Run `stress-test-httpd-stack.sh` on C3 — confirm watermark not regressed
- Smoke test all three boards: `/api/status/full`, history fetch, dashboard load

**Breaking changes to watch for (from ESPHome 2026.4.0 release notes):**
- Default CPU frequency increased to 240 MHz on ESP32/S2/S3/C5 — may affect power consumption. Add `cpu_frequency: 160MHz` to board profiles if needed.
- Partition layout changes — project uses custom partition tables so default change should not apply, but verify.
- NVS moved to end of flash with increased size — verify existing NVS data survives the upgrade (OTA preserves by name, not position).

**Acceptance gate:**
- `esphome version` shows 2026.4.0
- `bash scripts/patch-esphome-httpd-stack.sh --check` passes
- All three boards compile, flash, and serve dashboard
- C3 stress test watermark ≥ 2000 bytes (v7.6.9.5 baseline preserved)
- Playwright green (all fixture sets)

**Risk:** MEDIUM — ESPHome upgrades can introduce build failures if the local component override API changed. The patch script has a verification step that catches this. If the patch fails, manual inspection of the new upstream `web_server_idf.cpp` is needed.

### v7.6.10.1 — Board Profiles and Partition Tables

**Why:** Each new board needs a profile YAML, a partition table CSV, and `provision.sh` support before it can be compiled and flashed.

**Scope per new board:**

For each of the 4 new boards, produce:
1. **Board profile** at `firmware/boards/<board-id>.yaml` — follow existing schema exactly
2. **Partition table** at `partitions/<board-id>-multi-partitions.csv` — size for the board's flash
3. **provision.sh target** — new case in the target switch

**Board profile schema (from existing boards):**
```yaml
board_id: "<unique-id>"
chip_variant: "<esp32c6|esp32c5|esp32s3>"
esphome_board: "<esphome-board-name>"
flash_size: "<4MB|16MB>"
partitions: "../partitions/<partition-file>.csv"
framework:
  type: "esp-idf"
sdkconfig_options:
  CONFIG_LWIP_MAX_SOCKETS: "15"  # satellite default
capabilities:
  ble: true
  psram: <true|false>
  dual_core: <true|false>
  ram_kb: <320|384|512>
external_components:
  - source:
      type: local
      path: local_components
    components: [web_server_idf]
```

**Partition tables:**
- 4 MB flash boards: base on `esp32-c3-multi-partitions.csv` (known to work with 4 MB)
- 16 MB flash boards: base on `esp32-s3-multi-partitions.csv` (known to work with 16 MB)
- `ota_0` MUST be at `0x10000` (BUG-061 rule — all boards)

**C6/C5 specific considerations:**
- C6 and C5 require `framework: type: esp-idf` (no Arduino support)
- C6 has WiFi 6 (2.4 GHz only) + BLE 5.3 + 802.15.4 (Zigbee/Thread)
- C5 has WiFi 6 (dual-band 2.4 + 5 GHz) + BLE 5.0 + 802.15.4
- ESPHome `esphome_board` names: check `esphome/components/esp32/boards.py` for valid board identifiers
- C6/C5 may need additional sdkconfig_options — check ESPHome C6/C5 documentation

**Acceptance gate per board:**
- `esphome compile firmware/<board-yaml>.yaml` succeeds (clean compile)
- Generated YAML is well-formed
- `provision.sh <target>` switches config correctly
- `provision.sh status` reports the new board

**If a board fails to compile:** Document the error. Do NOT spend time debugging ESPHome internals. Flag it as "compilation blocked" and exclude from measurement. The board can be revisited when ESPHome support matures.

### v7.6.10.2 — Flash, Measure, Document

**Why:** The whole point of onboarding is to get real measurements for the capacity study and board selection guide.

**Operator tasks (not agent-driven):**

For each board that compiled successfully in v7.6.10.1:

1. Flash the board: `esphome run firmware/<board-yaml>.yaml`
2. Wait 2 minutes for boot stabilisation
3. Collect baseline telemetry:
   ```bash
   curl -s -u ESPadmin:ESPpass100 http://<BOARD_IP>/api/status/full | jq '{
     version, httpd_stack_watermark_bytes, free_heap, min_free_heap,
     uptime_seconds, psram_size, flash_size
   }'
   ```
4. Run stress test:
   ```bash
   bash scripts/stress-test-httpd-stack.sh <BOARD_IP>
   ```
5. Record results in `Docs/board-measurement-log-v7.6.10.md`

**Measurement table template:**

```markdown
| Board | Chip | Arch | SRAM | PSRAM | Flash | free_heap | min_free_heap | httpd_stack_wm | Stress min_wm | Compiles | Notes |
|---|---|---|---|---|---|---|---|---|---|---|---|
| C3 SuperMini | ESP32-C3 | RISC-V | 400K | None | 4M | 69896 | 52592 | 636→[new] | [stress] | ✅ | Existing baseline |
| WROOM-32D | ESP32 | Xtensa | 520K | None | 4M | 37032 | 13616 | 13044 | [stress] | ✅ | Existing baseline |
| S3 DevKitC N16R8 | ESP32-S3 | Xtensa | 512K | 8M | 16M | 52460 | 8434304 | 13760 | [stress] | ✅ | Existing (aggregator) |
| S3 SuperMini | ESP32-S3 | Xtensa | 512K | 2M | 4M | | | | | | NEW |
| C6 SuperMini | ESP32-C6 | RISC-V | 512K | None | 4M | | | | | | NEW — first C6 |
| C6 DevKitC-1 | ESP32-C6 | RISC-V | 512K | None | 16M | | | | | | NEW |
| C5 | ESP32-C5 | RISC-V | 384K | TBD | 4M | | | | | | NEW — dual-band WiFi |
```

### v7.6.10.3 — Capacity Study and Board Selection Guide Update

**Agent-driven:** Claude session reads the measurement log and produces updated documents.

**Capacity study updates (`Docs/phase-V-capacity-study.md`):**
- Expand the executive summary table with all 7 boards
- Update the SRAM breakdown section with per-board figures
- Add a new subsection "§X — Architecture-Dependent Task Stack Sizing" with the full measurement dataset
- Revise the "Max persistent metrics (safe heap)" column based on actual free_heap measurements
- Add PSRAM scaling observations (S3 SuperMini 2MB vs S3 DevKitC 8MB)

**Board selection guide updates (`Docs/esp32-board-selection-guide.md`):**
- Add a new section "Architecture-Dependent Stack Sizing" documenting the RISC-V vs Xtensa finding
- Expand §1 chip family table with measured stack/heap data
- Add a comprehensive use-case matrix:

  | Board class | PSRAM | Flash | Max persistent metrics | Max sensors | Standalone viable | Satellite viable | Aggregator viable | Notes |
  |---|---|---|---|---|---|---|---|---|

  Populate from measured data, with specific guidance:
  - What can a C3 (no PSRAM, 400K SRAM) do? How many sensors/metrics?
  - What changes if the board runs standalone (no aggregator code)?
  - What does 2MB PSRAM buy vs 8MB vs none?
  - Which RISC-V boards (C6, C5) match the C3's satellite role? With what constraints?

- Update the "Summary Decision Matrix" with new boards

---

## Deliverable Format

The advisor should produce:

**For v7.6.10.0 (ESPHome upgrade):**
- Single agent prompt: `prompts/phaseVX/v7.6.10.0-esphome-upgrade-prompt.md`
- Session handoff: `prompts/handoff/phaseVX/session-handoff-v7.6.10.0.md`

**For v7.6.10.1 (board profiles):**
- Single agent prompt: `prompts/phaseVX/v7.6.10.1-board-profiles-prompt.md`
- May split into two PRs if C6/C5 compilation issues need isolation

**For v7.6.10.2 (measurement):**
- Operator instruction document (not an agent prompt): `Docs/board-measurement-protocol-v7.6.10.md`
- Measurement log template: `Docs/board-measurement-log-v7.6.10.md`

**For v7.6.10.3 (documentation):**
- Claude advisory session instructions (not an agent prompt): produce capacity study and board guide updates as zip deliverables

---

## Scope Guards

- Do NOT modify any firmware handler code (`firmware/core/*.h`) — infrastructure only
- Do NOT modify dashboard source files
- Do NOT modify NVS format, storage engine, or partition layout of existing boards
- Do NOT change the provisioning pipeline's existing board behavior — only add new targets
- Do NOT upgrade to ESP-IDF 6.0 independently — let ESPHome manage its IDF version
- Do NOT start Phase 7 work — this is infrastructure, not features
- Do NOT change the existing three boards' partition tables during the ESPHome upgrade
- If a new board fails to compile, document and skip — do not debug ESPHome internals

---

## ESPHome Upgrade Risks

The ESPHome 2026.4.0 upgrade has specific risks:

1. **Partition table breaking change:** ESPHome 2026.4.0 changed default partition layouts. This project uses custom partition tables via board profiles, so the default change should not apply. But verify by checking that the compiled firmware's partition table matches the board profile's CSV.

2. **CPU frequency change:** Default increased to 240 MHz for ESP32/S2/S3/C5. The C3 stays at 160 MHz (max for the chip). If power consumption increases noticeably on existing boards, add `cpu_frequency: 160MHz` to the board profiles.

3. **Local component override:** The `web_server_idf` local component override was copied from ESPHome 2026.2.1's upstream. After upgrading to 2026.4.0, the upstream file may have changed. `patch-esphome-httpd-stack.sh` copies the new upstream and re-applies the patches. If the upstream API changed (new methods, renamed parameters), the patch may fail. The script's verification step catches this — if it fails, manual inspection is needed.

4. **Build size changes:** ESPHome 2026.2.0 significantly reduced build sizes. 2026.4.0 continues this trend. Existing boards should see equal or smaller firmware. But new boards (C6, C5) may have different baseline sizes — verify `ota_0` partition is large enough.

---

_End of Phase VX board onboarding sprint prompt._
