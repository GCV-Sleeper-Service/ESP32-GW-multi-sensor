# Architecture Revision & Action Plan

_Date: 2026-03-24_
_Context: Post-v7.5.5.1 repo analysis, user design principles review, forward planning_
_Repo state: commit a024cac on main_

---

## 1. Repo Health Assessment

### What's working

- S3 partition table (BUG-061) is fixed — `ota_0` at `0x10000` with documentation comments
- ThermoPro indentation fix in `generate_board_yaml()` is committed
- `aggregator_config.h` is generated correctly for the C3 satellite
- Board profiles exist for C3, S3, WROOM-32D
- The `generate_board_yaml()` function is substantial (~400 lines) and handles env sensors, ping probes, aggregator task, diagnostics, sorting groups, text sensors
- Phase 5 prompts (v7.5.5.2–v7.5.5.5) are intact and the v7.5.5.2 rewrite correctly replaces `esp_http_client` with `fetch_to_buffer()`
- Phase 7 prompts are intact with appropriate addendums

### What needs repair

**BUG-060 is NOT fixed.** `import yaml` is still at line 11 of `sensor_manifest_lib.py` (top-level). The diff between `0906b3e` and `a024cac` shows zero changes to this file. Any system without PyYAML installed will crash on `import` before any function is called. This blocks the satellite workflow on clean ESPHome containers.

**Fix:** Move `import yaml` inside `load_board_profile()`:
```python
# Line 11: remove "import yaml"
# Inside load_board_profile(), add at the top:
def load_board_profile(board_id: str) -> Dict:
    import yaml  # lazy import — only needed for board profiles
    ...
```

**Two Phase 6 prompt files are corrupted:**
- `prompts/phase6/v7.5.6.0-implementation-instructions-for-coding-agent.md` — missing the first 21 lines (title, date, Sections 1–2 header). Content starts at a LESSON-OPS-068 bullet point.
- `prompts/phase6/v7.5.6.2-implementation-instructions-for-coding-agent.md` — same pattern, missing the first 22 lines.

The other three Phase 6 files (v7.5.6.1, v7.5.6.3, v7.5.6.4) are intact.

**Fix:** Restore the headers from the pre-push version. The original content exists in git at commit `0906b3e`. Run:
```bash
# Extract original headers and prepend them
git show 0906b3e:prompts/phase6/v7.5.6.0-implementation-instructions-for-coding-agent.md | head -21 > /tmp/header-6.0.md
cat /tmp/header-6.0.md prompts/phase6/v7.5.6.0-implementation-instructions-for-coding-agent.md > /tmp/fixed-6.0.md
mv /tmp/fixed-6.0.md prompts/phase6/v7.5.6.0-implementation-instructions-for-coding-agent.md

git show 0906b3e:prompts/phase6/v7.5.6.2-implementation-instructions-for-coding-agent.md | head -22 > /tmp/header-6.2.md
cat /tmp/header-6.2.md prompts/phase6/v7.5.6.2-implementation-instructions-for-coding-agent.md > /tmp/fixed-6.2.md
mv /tmp/fixed-6.2.md prompts/phase6/v7.5.6.2-implementation-instructions-for-coding-agent.md
```

**Hand-authored YAMLs committed to wrong location.** `firmware/esp32-n16r8-gw-1.yaml` (63 lines) and `firmware/esp32-wroom-32d.yaml` (49 lines) are minimal bootstrap configs used for initial board flashing. They are NOT generator output — they lack includes, on_boot lambdas, sensor blocks, persistence, and dashboard embedding. The generator would produce output to different filenames (`firmware/esp32-s3-devkitc1-n16r8-gw.yaml` and `firmware/esp32-wroom-32d-gw.yaml`).

**Risk:** A coding agent or contributor could mistake these for active firmware configs. They should either be moved to `firmware/bootstrap/` with a README explaining their purpose, or added to `.gitignore`.

**`config/aggregator.json` contains live deployment IPs.** The file has your specific satellite IP (192.168.120.189). Only `config/aggregator.example.json` should be tracked. The live config should be in `.gitignore`.

**S3 board profile has `logger.baud_rate` commented out.** The `esp32-s3-devkitc1-n16r8.yaml` profile has `#logger:` / `#  baud_rate: 0`. For USB-JTAG boards (S3 DevKit), `baud_rate: 0` is needed to avoid serial output conflicts. The generator checks for this but the value isn't accessible because it's commented out. The generated S3 YAML doesn't include `baud_rate: 0` — this may cause issues with serial debugging.

### Multi-board setup instructions (`prompts/infrastructure/multi-board-setup-instructions.md`)

This document served its purpose — PR66 was implemented from it. Two corrections needed for archival accuracy:

1. Section 5b still shows `import yaml` at the top level (propagated BUG-060)
2. The document doesn't mention the `sensors_file` gateway.json extension (Phase A from the improvement plan), which is a natural fit for the infrastructure layer it describes

No action needed since PR66 is already merged, but if this document is used as a reference for future work, these should be noted.

### Fix prompt (`Docs/fix-prompt-pr64-socket-collision.md`)

Historical reference document. The fix was already applied in PR64. Content is accurate and complete. No action needed — this is a good audit trail artifact.

---

## 2. Design Principles Codified

These derive from the user's principles document and the existing architecture plan. They supplement (not replace) the tenets in Section 4 of `v7.5-v7.6-architecture-plan.md`.

### Principle 1: Roles are capability tiers, not different products

An aggregator is a satellite with aggregation enabled. Every satellite capability (local sensors, persistence, import/export, dashboard, notifications in v8.x, cloud upload in v8.x) is available to an aggregator. The role config controls what's **active**, not what's **possible**.

**Implication for code:** No feature should be gated as "satellite-only" at the firmware level. The `AGGREGATOR_ENABLED` flag adds aggregator capabilities; it never subtracts satellite capabilities. An aggregator with zero local sensors is a valid configuration. An aggregator with local BLE sensors is also valid.

### Principle 2: Dashboard is the configuration interface

The compile-time path (edit JSON → run generator → reflash) is the developer/bootstrap path. The dashboard is the operator's interface. For satellite configuration, this means Phase D (runtime sensor management) and Phase E (captive portal setup) are core architecture goals, not nice-to-have enhancements.

**Implication for v7.5.5.3:** The aggregator dashboard must include the satellite management UI groundwork from day one. Building a dashboard without the settings panel and retrofitting it later means rewriting the dashboard structure. The panel can be read-only in v7.5.5.3 (showing compile-time satellites), with the NVS write-back added in v7.6.x (Phase D).

### Principle 3: Per-gateway identity is first-class

Each gateway has a globally unique name that flows through config filenames, dashboard content, API responses, and the manifest. The naming convention (`sat-c3-4m-office`, `agg-s3-16m-fl2`) encodes role, hardware, and location. Per-device config files use the gateway name (`sensors-sat-c3-4m-1.json`).

**Implication for config separation:** The `sensors_file` field in `gateway.json` (Phase A from the improvement plan) must be implemented before v7.5.5.2 device testing. The S3 aggregator currently inherits the C3's ThermoPro sensors — wrong board, wrong sensors.

### Principle 4: Board content correctness

The dashboard must never show information from a different board. The About card, board info, pinout diagram, and documentation must come from the board profile. For boards without images/pinout available yet, the dashboard shows the board name and basic specs from the profile. No content is better than wrong content.

**Implication:** The `generate_board_yaml()` function already produces board-specific chip info parsing in the diagnostics text sensor. The dashboard About card text ("ESP32-C3 SuperMini Gateway") comes from the `about_description` text sensor, which is populated by a lambda that parses `debug.device` output. This is chip-auto-detected and should already work correctly on the S3. The **pinout SVG and board-specific documentation** are C3-specific content compiled into `dashboard.html`. For non-C3 boards, this content should either be driven by the board profile or suppressed.

---

## 3. Phase 5 Step Revisions

### v7.5.5.2 — Aggregator API Endpoints

**Prompt status:** Rewritten, correct. The `fetch_to_buffer()` / `s_proxy_tmp` pattern is right. The `esp_http_client` removal is critical. No further changes needed to the prompt.

**Prerequisite:** The pre-v7.5.5.2 infrastructure work (Section 4 below) must be completed first so the S3 aggregator has its own sensor config and shows correct board info.

### v7.5.5.3 — Aggregator Dashboard UI

**Prompt status:** Mostly correct but needs scope expansion. The current prompt builds a gateway selector and summary view but has no satellite management UI. Per Principle 2, the settings panel groundwork should be included.

**Recommended additions to v7.5.5.3 scope:**

1. **Settings panel skeleton** — a "Satellites" tab accessible from a gear icon or settings dropdown in the aggregator dashboard. In v7.5.5.3, this panel is **read-only**: it lists configured satellites from the compile-time config, shows their status (online/offline), and displays the satellite's name, IP, firmware version, and device count. No add/remove/edit capability yet.

2. **API endpoints for future satellite management** — define (but stub with 501 Not Implemented) the endpoints that Phase D will activate: `POST /api/aggregator/add-satellite`, `DELETE /api/aggregator/satellite/{id}`, `POST /api/aggregator/test-satellite`. Defining them now reserves the URL space and documents the contract.

3. **Board-driven About card** — if the gateway is not a C3, suppress C3-specific content (pinout SVG, C3 documentation text). Show board name, chip variant, flash size, and PSRAM status from the manifest's `gateway.hardware` field.

### v7.5.5.4 — Playwright Tests

**Prompt status:** Intact, needs addendum for the settings panel tests and zero-sensor aggregator edge cases. The existing prompt already covers gateway selector, stale indicators, and satellite mode preservation.

### v7.5.5.5 — Phase 5 Closure

**Prompt status:** Intact. Needs to include updated architecture documentation reflecting the principles codified here, and explicit mention of Phase D as the next milestone.

---

## 4. Pre-v7.5.5.2 Infrastructure Work (Block 3)

These items should be done as a single infrastructure commit before any v7.5.5.2 work. No version bump.

### 4a. Config separation (`sensors_file` in gateway.json)

Extend `gateway.json` schema:
```json
{
  "board": "esp32-s3-devkitc1-n16r8",
  "esphome_name": "agg-s3-16m-1",
  "friendly_name": "S3 Aggregator",
  "wifi_address": "192.168.120.191",
  "sensors_file": "config/sensors-agg-s3-16m-1.json"
}
```

When `sensors_file` is present, the generator reads from that path instead of `config/sensors.json`. The aggregator's sensor file would contain just a ping probe (or be empty). The C3 satellite's `sensors.json` is untouched.

**Implementation:** ~15 lines in `render_sensor_config.py` main(). Also update `validate_gateway_config()` to check the path exists if specified.

Create: `config/sensors-agg-s3-16m-1.json` with:
```json
{
  "schema_version": 2,
  "sensors": [
    {
      "id": "wan_ping",
      "name": "WAN Latency",
      "category": "network",
      "adapter": "icmp_ping",
      "source": { "target": "8.8.8.8" }
    }
  ]
}
```

### 4b. Partition ota_0 preflight check

Add to `scripts/preflight.sh`:
```bash
for csv in partitions/*.csv; do
  OTA0=$(grep "ota_0" "$csv" | awk -F',' '{print $4}' | tr -d ' ')
  if [[ "$OTA0" != "0x10000" ]]; then
    echo "FATAL: $csv has ota_0 at $OTA0 (must be 0x10000)"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  else
    echo "partition_ota0_$(basename $csv .csv): PASS"
  fi
done
```

### 4c. `validate-device.sh` deployment script

Create `scripts/validate-device.sh` as specified in the aggregator improvement plan, Phase B. The script from that document is ready to use.

### 4d. Apply PR66 Codex review fixes (8 items)

The 8-item fix prompt exists but hasn't been applied. These are:
1. Missing `board:` field in generated `esp32:` block
2. Missing `baud_rate: 0` for USB-CDC boards
3. `gateway.json` with C3 board silently ignored
4. `use_address` doesn't assign static IP (needs optional `manual_ip`)
5. `load_board_profile()` crashes on empty/invalid YAML
6. `load_gateway_config()` missing JSONDecodeError catch
7. `validate_gateway_config()` doesn't validate `manual_ip.dns1`
8. Unreachable dead code branch in `generate_board_yaml()`

Items 1, 2, 5, 6, and 8 are straightforward. Items 3, 4, and 7 are lower priority but clean to do.

### 4e. BUG-062 fix (heap reporting)

`/api/status` reports `free_heap` using `esp_get_free_heap_size()` which includes PSRAM on S3 (8.4MB). Change to report both:
```json
{
  "free_heap": 32768,
  "free_heap_internal": 32768,
  "free_heap_total": 8847360
}
```

The `free_heap` field stays as internal-only for backward compatibility (existing dashboard and monitoring scripts expect this). `free_heap_total` is additive.

### 4f. BUG-060 fix (lazy yaml import)

Move `import yaml` from line 11 to inside `load_board_profile()`.

### 4g. Repair corrupted Phase 6 prompts

Restore headers to `v7.5.6.0` and `v7.5.6.2` from git history.

### 4h. Housekeeping

- Move `firmware/esp32-n16r8-gw-1.yaml` and `firmware/esp32-wroom-32d.yaml` to `firmware/bootstrap/` with a README explaining these are initial-flash-only configs
- Add `config/gateway.json` and `config/aggregator.json` to `.gitignore` (keep only `.example.json` tracked)
- Uncomment `logger.baud_rate: 0` in the S3 board profile
- Update `prompts/infrastructure/multi-board-setup-instructions.md` Section 5b to use lazy yaml import

---

## 5. Naming Convention

The recommended naming pattern from the principles document:

| Pattern | Examples |
|---------|---------|
| `sat-{chip}-{flash}m-{location}` | `sat-c3-4m-office`, `sat-s3-4m-floor1` |
| `agg-{chip}-{flash}m-{location}` | `agg-s3-16m-hq1`, `agg-pi-00m-main` |

This is a **recommendation, not enforcement**. The generator accepts any valid ESPHome name. The convention is used in all documentation examples and default configs.

**Config file naming:** `sensors-{gateway-name}.json` (e.g., `sensors-sat-c3-4m-office.json`)

**Where this is documented:** `Docs/configuring-sensors.md` multi-board section (needs update).

---

## 6. Updated Phase Roadmap

### Pre-v7.5.5.2 — Infrastructure (Block 3, this document Section 4)
Config separation, preflight ota_0 check, validate-device.sh, PR66 fixes, BUG-060/062 fixes, prompt repairs, housekeeping.

### v7.5.5.2 — Aggregator API Endpoints
No change from existing plan. Prompt is ready.

### v7.5.5.3 — Aggregator Dashboard + Settings Panel Groundwork
Expanded scope per Section 3 above. Prompt needs revision.

### v7.5.5.4 — Aggregator Playwright Tests
Expanded to cover settings panel read-only state and zero-sensor aggregator.

### v7.5.5.5 — Phase 5 Closure
Includes updated architecture documentation.

### v7.6.0.x — Runtime Satellite Management (Phase D)
NVS-persisted satellite list, `POST /api/aggregator/add-satellite`, `DELETE /api/aggregator/satellite/{id}`, dashboard add/remove/test UI, auto-discovery via `/api/manifest`. This is the bridge from "developer tool" to "product." Explicit next milestone after Phase 5.

### Phase 6 — Data Ingest and System Metrics
Unchanged. Prompt files need header repair but content is correct.

### Phase 7 — Per-Device Persistence
Unchanged. Prompts are correct with addendums.

### v8.x — Notifications, Cloud Upload, Captive Portal Setup
Per the principles document. No detailed planning yet.

---

## 7. What to Do Next

**Step 1 — You push a repair commit** containing items 4f, 4g, and the `.gitignore` additions. (10 minutes)

**Step 2 — I produce the Block 3 deliverable** as a single comprehensive coding agent prompt covering items 4a through 4e and 4h. This prompt can be given to a coding agent or executed manually. (~1 session to produce, ~1-2 sessions to execute)

**Step 3 — I revise the v7.5.5.3 prompt** to include the settings panel groundwork and board-driven About card per Section 3.

**Step 4 — Resume Phase 5 execution** starting with v7.5.5.2.

---

_End of document._
