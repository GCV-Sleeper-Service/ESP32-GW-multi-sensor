# Session Handoff — v7.6.10.0: ESPHome Upgrade Verification

_Date: 2026-04-22_
_Repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor_
_Status: Phase V COMPLETE (v7.6.9.5 merged). Phase VX started. ESPHome already upgraded to 2026.4.1._

---

## Project State Summary

Phase V is formally closed. The operator has already upgraded the ESPHome installation from 2026.2.1 to 2026.4.1 (ahead of the sprint prompt's 2026.4.0 target). ESP-IDF is now at 5.5.4 (bundled with ESPHome 2026.4.1).

**What has NOT been done yet:**
- The `scripts/patch-esphome-httpd-stack.sh` has NOT been re-run against the new ESPHome version
- The existing 3 production boards have NOT been clean-built against ESPHome 2026.4.1
- Stress tests have NOT been run post-upgrade
- VERSION still reads `7.6.9.5`

**Current board fleet (existing production boards):**

| Board | Chip | IP | Role | Last verified ESPHome |
|---|---|---|---|---|
| ESP32-C3 SuperMini | ESP32-C3 | 192.168.120.189 | Satellite | 2026.2.1 (v7.6.9.5) |
| ESP32-WROOM-32D | ESP32 | 192.168.120.190 | Satellite | 2026.2.1 (v7.6.9.5) |
| ESP32-S3-DevKitC1-N16R8 | ESP32-S3 | 192.168.120.191 | Aggregator | 2026.2.1 (v7.6.9.5) |

---

## Phase VX Progress Table

| Version | Scope | Status |
|---|---|---|
| **v7.6.10.0** | **ESPHome upgrade verification + local component re-patch** | **⬅️ Current** |
| v7.6.10.1 | Board profiles + partition tables for 3 new boards | 🔜 Queued |
| v7.6.10.2 | Flash, measure, document (operator-driven) | 🔜 Queued |
| v7.6.10.3 | Capacity study + board selection guide update (advisory) | 🔜 Queued |
| v7.6.10.4 | Dashboard auth refactor (optional) | 🔜 Queued |

---

## v7.6.10.0 Scope

### Why this step exists

ESPHome 2026.4.1 includes changes to the upstream `web_server_idf.cpp` that the project overrides with a local component. The patch script copies the new upstream and re-applies the 16 KB stack patch + HTTP_DELETE handler patch. If the upstream API changed, the patch may fail. This step verifies the patch, confirms existing boards still compile and pass stress tests, and formally opens Phase VX.

### What this step does

1. **Re-run `scripts/patch-esphome-httpd-stack.sh`** — copies new upstream from ESPHome 2026.4.1, re-applies patches
2. **Verify `--check` passes** — confirms both patches are active
3. **Clean build all 3 existing boards** — `esphome compile` for C3, WROOM, S3
4. **Update `firmware/local_components/web_server_idf/PATCH_INFO.md`** — record new ESPHome version
5. **Bump VERSION to 7.6.10.0**, update changelog
6. **Run Playwright tests** — all fixture sets green

### What this step does NOT do

- No pip install or ESPHome upgrade (already done)
- No board profile changes (v7.6.10.1 scope)
- No new partition tables
- No firmware handler changes
- No dashboard changes
- No NVS format changes

### Files modified

- `firmware/local_components/web_server_idf/web_server_idf.cpp` — refreshed from ESPHome 2026.4.1 upstream with patches re-applied
- `firmware/local_components/web_server_idf/PATCH_INFO.md` — updated ESPHome version
- `Docs/changelog.md` — v7.6.10.0 entry
- `VERSION` — bump to `7.6.10.0`

### Files NOT modified

- `scripts/patch-esphome-httpd-stack.sh` — the script itself should not change
- `firmware/core/*.h` — no firmware handler changes
- `dashboard/modules/*.js` — no dashboard changes
- Board profiles, partition tables — unchanged

---

## Device Testing

### Operator tasks after merge

1. Flash all 3 existing boards with v7.6.10.0 firmware:
   ```bash
   bash scripts/provision.sh satellite
   esphome run firmware/esp32-c3-multi-sensor.yaml
   
   bash scripts/provision.sh wroom
   esphome run firmware/esp32-wroom-32d-gw.yaml
   
   bash scripts/provision.sh aggregator
   esphome run firmware/esp32-s3-devkitc1-n16r8-gw.yaml
   
   bash scripts/provision.sh satellite  # return to CI-safe
   ```

2. Wait 2 minutes per board, then stress test:
   ```bash
   bash scripts/stress-test-httpd-stack.sh 192.168.120.189  # C3
   bash scripts/stress-test-httpd-stack.sh 192.168.120.190  # WROOM
   bash scripts/stress-test-httpd-stack.sh 192.168.120.191  # S3
   ```

3. **Acceptance:** all watermarks ≥ 10,000 bytes. No regression from v7.6.9.5 baselines:
   - C3: ~12,600 B
   - WROOM: ~13,044 B
   - S3: ~12,528 B

4. Smoke test dashboard at each IP — loads, shows data, no errors.

---

## Context That Carries Forward

### To v7.6.10.1

- ESPHome 2026.4.1 with ESP-IDF 5.5.4 is the verified build environment
- Local component override confirmed working on all 3 architectures
- Stress test baselines established on the new ESPHome version
- `SRAM_KB_BY_CHIP` in `render_sensor_config.py` still only has 3 entries — v7.6.10.1 must add `esp32c6` and `esp32c5`

---

_End of session handoff document._
