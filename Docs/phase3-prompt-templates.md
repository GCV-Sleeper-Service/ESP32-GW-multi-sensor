# Phase 3 — Assistant Prompts for Each Step

_Date: 2026-03-16_  
_Usage: Copy the prompt for the current step into a new conversation with the assistant._  
_Each prompt is self-contained — the assistant should be able to implement the step from scratch._

---

## Prompt for v7.5.3.0 — Pre-Phase 3 Cleanup

```
This is work regarding ESP32-BLE gateway project.
Project repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Current status:
- v7.5.2.4 is complete and merged (Phase 2 complete)
- main is green
- We are now moving to v7.5.3.0
- Current date: <INSERT DATE>

Before making any changes, first read these files fully:
- Docs/phase3-implementation-plan.md
- Docs/phase1-phase2-assessment-and-remediation.md
- Docs/bugs-and-lessons-learned.md
- Docs/changelog.md
- Docs/v7.5-v7.6-architecture-plan.md
- the latest session handoff log(s) under Docs/

Task:
- Implement v7.5.3.0 exactly according to Docs/phase3-implementation-plan.md
- Before coding, confirm your understanding of the exact v7.5.3.0 scope from the plan
- Do not proceed to any later step until v7.5.3.0 is fully implemented, documented, regenerated, and validated

Exact v7.5.3.0 scope:
- Fix bump-version.sh to include dashboard/dashboard.html update
- Create config/sensors.v2.example.json with mixed-category example (ThermoPro + ping probe)
- Add schema naming decision comment to sensor_manifest_lib.py
- Fix boot flow sequencing: loadManifestV2() must complete before loadSensorManifest() starts
- Update Docs/changelog.md with v7.5.3.0 entry
- Create a dedicated session log under Docs/ for this session
- Bump version atomically to 7.5.3.0 everywhere required by repo rules
- Regenerate all required generated artifacts
- Stop after v7.5.3.0; do not begin v7.5.3.1 or any later step

Critical rules / guardrails:
1. Operate autonomously, but if anything is unclear, ask before acting
2. Update documentation alongside code
3. Every session must create/update a dedicated session handoff Markdown log under Docs/
4. Update these documentation/process files as part of the work:
   - Docs/changelog.md
   - Docs/bugs-and-lessons-learned.md (only if new bugs/lessons discovered)
5. Add bugfixes/lessons learned in reverse chronological order (latest first), matching the existing file format
6. No documentation/comments/version/generated-artifact drift is allowed
7. Use bump-version.sh for the version bump (after fixing it first — chicken-and-egg: fix the script manually, then run it)
8. Regenerate all required generated artifacts whenever source files require it
9. Run relevant local validation/checks first before asking me to do anything
10. If you need me to perform a manual step, provide exact, ordered, detailed instructions with explanation and stop conditions
11. Keep the implementation clean, simple, and efficient — do not overcomplicate it

Validation requirements:
- Run the repo's preflight checks (bash scripts/preflight.sh)
- Run the full Playwright test suite (npx playwright test) — all 73 tests must pass
- If generation is involved, run the required generation commands and verify the repo is in sync
- If some validation cannot be executed from your side, explain exactly what was attempted, why it could not be completed, and provide exact manual steps for me

Manual instruction style requirement:
- Do not say generic things like "merge the PR"
- Instead use explicit instructions like:
  "Wait until the agent finishes all work, inspect the PR diff, approve pending workflows if needed, wait for all checks to finish, and merge only if all checks are green. If any workflow fails, stop, copy the exact failure output, send it back here, and wait for further instructions."

Expected output from you:
1. A short summary of the exact v7.5.3.0 scope from the implementation plan
2. Implementation of v7.5.3.0
3. Updated docs and session log
4. Regenerated artifacts if needed
5. Validation results
6. A PR
7. Exact manual follow-up steps for me, if any
```

---

## Prompt for v7.5.3.1 — Define SensorEntity Structs

```
This is work regarding ESP32-BLE gateway project.
Project repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Current status:
- v7.5.3.0 is complete and merged
- main is green
- We are now moving to v7.5.3.1
- Current date: <INSERT DATE>

Before making any changes, first read these files fully:
- Docs/phase3-implementation-plan.md
- Docs/bugs-and-lessons-learned.md
- Docs/changelog.md
- Docs/v7.5-v7.6-architecture-plan.md (Section 6 — Firmware Model)
- the latest session handoff log(s) under Docs/

Task:
- Implement v7.5.3.1 exactly according to Docs/phase3-implementation-plan.md
- Before coding, confirm your understanding of the exact v7.5.3.1 scope from the plan
- Do not proceed to any later step

Exact v7.5.3.1 scope:
- Add MetricDef, MetricState, SensorEntity struct definitions to dashboard/sensor_history_multi.h
- These are PASSIVE definitions — nothing references them at runtime yet
- SensorSlot remains the active runtime model, completely unchanged
- Include add_sample(), compute_averages(), mark_seen() methods on SensorEntity
- Use MAX_METRICS_PER_DEVICE = 4
- Use ::time(nullptr) in ESPHome context (per project rules)
- HistoryBuffer* pointer for optional per-metric history
- Update Docs/changelog.md with v7.5.3.1 entry
- Create a dedicated session log
- Bump version to 7.5.3.1 everywhere
- Regenerate all required generated artifacts
- Stop after v7.5.3.1

Critical rules / guardrails:
1. Operate autonomously, but if anything is unclear, ask before acting
2. Update documentation alongside code
3. Every session must create/update a dedicated session handoff Markdown log under Docs/
4. No documentation/comments/version/generated-artifact drift is allowed
5. Use bash scripts/bump-version.sh 7.5.3.1 for the version bump
6. Run relevant local validation/checks first
7. If you need me to perform a manual step, provide exact, ordered, detailed instructions

Validation requirements:
- Preflight must pass (bash scripts/preflight.sh)
- All 73+ Playwright tests must pass
- If some validation cannot be executed locally, provide exact manual steps

Device testing requirement (for me to perform after merge):
- Provide exact commands to update the repo locally with the current version
- Compile on ESPHome LXC container: esphome config firmware/esp32-c3-multi-sensor.yaml
- Compile on ESPHome LXC container: esphome compile firmware/esp32-c3-multi-sensor.yaml
- Report results back

Expected output from you:
1. Short scope summary
2. Implementation
3. Updated docs and session log
4. Validation results
5. A PR
6. Exact manual follow-up steps for me (including device compile test)
```

---

## Prompt for v7.5.3.2 — Generator Produces SensorEntity Arrays

```
This is work regarding ESP32-BLE gateway project.
Project repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Current status:
- v7.5.3.1 is complete and merged
- main is green
- We are now moving to v7.5.3.2
- Current date: <INSERT DATE>

Before making any changes, first read these files fully:
- Docs/phase3-implementation-plan.md
- Docs/bugs-and-lessons-learned.md
- Docs/changelog.md
- Docs/v7.5-v7.6-architecture-plan.md (Section 6.3 — Generated code example)
- scripts/render_sensor_config.py (understand current generation patterns)
- scripts/sensor_manifest_lib.py
- the latest session handoff log(s) under Docs/

Task:
- Implement v7.5.3.2 exactly according to Docs/phase3-implementation-plan.md
- Before coding, confirm your understanding of the exact scope

Exact v7.5.3.2 scope:
- Extend render_sensor_config.py to generate SensorEntity arrays alongside existing SensorSlot arrays
- Both SensorSlot sensors[] and SensorEntity devices[] must be present in sensor_history_multi.h
- Runtime code still uses SensorSlot — SensorEntity arrays are generated but not used yet
- History buffer variable names must be prefixed with entity_hbuf_ to avoid name conflicts
- Use NAN for initial float values
- metrics_thermopro[] array is shared across all ThermoPro devices
- Degree symbol must be encoded as \xC2\xB0 in C++ string literals
- render_sensor_config.py --check must pass
- Update Docs/changelog.md, session document, handoff document, bugs and lessons learned, if there are content for them
- Create session log
- Bump version to 7.5.3.2
- Regenerate all artifacts
- Stop after v7.5.3.2

Critical rules / guardrails:
1. Use lambda replacements in re.sub() for generated content (per BUG-034)
2. Use apply_yaml_marker_block() for YAML changes (per BUG-035/036)
3. Never use replace_marker_block() for YAML
4. Run render_sensor_config.py --check before pushing
5. Use bash scripts/bump-version.sh 7.5.3.2 for version bump
6. No drift between generated files and source manifest

Validation requirements:
- Preflight must pass
- render_sensor_config.py --check must pass
- All Playwright tests must pass
- Generated SensorEntity arrays must compile (verify in next device test)

Device testing requirement (for me to perform after merge):
- Provide exact commands to update the repo locally with the current version
- esphome config firmware/esp32-c3-multi-sensor.yaml
- esphome compile firmware/esp32-c3-multi-sensor.yaml
- Report compilation results back

Expected output: scope summary, implementation, docs, validation, PR, manual steps
```

---

## Prompt for v7.5.3.3 — Wire YAML Lambdas (Dual-Write)

```
This is work regarding ESP32-BLE gateway project.
Project repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Current status:
- v7.5.3.2 is complete and merged
- Device compile test: PASS (confirm before starting)
- main is green
- We are now moving to v7.5.3.3
- Current date: <INSERT DATE>

Before making any changes, first read these files fully:
- Docs/phase3-implementation-plan.md (v7.5.3.3 section carefully)
- Docs/bugs-and-lessons-learned.md (especially BUG-035, BUG-036 — YAML guardrails)
- Docs/changelog.md
- firmware/esp32-c3-multi-sensor.yaml (understand current lambda patterns)
- dashboard/sensor_history_multi.h (understand current compute_and_format call chain)
- the latest session handoff log(s) under Docs/

Task:
- Implement v7.5.3.3 exactly according to Docs/phase3-implementation-plan.md
- This is a DUAL-WRITE step: YAML lambdas call BOTH sensors[i].add_temp/hum() AND devices[i].add_sample()
- Do NOT remove SensorSlot calls — both models receive data in parallel

Exact v7.5.3.3 scope:
- Update YAML lambda generation in render_sensor_config.py to add devices[i].add_sample() calls alongside existing sensors[i].add_temp/hum() calls
- Add devices[i].mark_seen(::time(nullptr)) in BLE on_value lambdas
- Add devices[i].compute_averages(::time(nullptr)) in the 15-minute averaging timer lambda
- Both SensorSlot and SensorEntity receive identical data
- Update Docs/changelog.md, session document, handoff document, bugs and lessons learned, if there are content for them
- Create session log
- Bump version to 7.5.3.3
- Regenerate all artifacts
- Stop after v7.5.3.3

CRITICAL YAML guardrails:
- Use apply_yaml_marker_block() for ALL YAML changes — NEVER replace_marker_block()
- Run esphome config after generation to validate YAML structure
- Check indentation carefully — ESPHome YAML is whitespace-sensitive
- Use ::time(nullptr) not time(nullptr) in ESPHome lambdas

Validation requirements:
- Preflight must pass
- render_sensor_config.py --check must pass
- All Playwright tests must pass
- If esphome config can be run locally, run it

Device testing requirement (CRITICAL — for me to perform after merge):
- Provide exact commands to update the repo locally with the current version
- esphome compile firmware/esp32-c3-multi-sensor.yaml
- esphome run firmware/esp32-c3-multi-sensor.yaml (OTA flash)
- Verify via /api/v2/live that BOTH SensorSlot AND SensorEntity receive data
- Check /api/status for heap (record baseline)
- Let run for 30+ minutes, verify history accumulation in SensorEntity buffers
- Report all results back

Expected output: scope summary, implementation, docs, validation, PR, exact device test steps
```

---

## Prompt for v7.5.3.4 — Add `/api/v2/live` Endpoint

```
This is work regarding ESP32-BLE gateway project.
Project repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Current status:
- v7.5.3.3 is complete and merged
- Device test: PASS — dual-write confirmed working (confirm before starting)
- main is green
- We are now moving to v7.5.3.4
- Current date: <INSERT DATE>

Before making any changes, first read these files fully:
- Docs/phase3-implementation-plan.md (v7.5.3.4 section)
- Docs/bugs-and-lessons-learned.md
- Docs/changelog.md
- Docs/v7.5-v7.6-architecture-plan.md (Section 9.2 — /api/v2/live)
- dashboard/sensor_history_multi.h (understand existing endpoint patterns)
- the latest session handoff log(s) under Docs/

Task:
- Implement v7.5.3.4 exactly according to Docs/phase3-implementation-plan.md

Exact v7.5.3.4 scope:
- Add handle_api_v2_live_() method to the web handler in sensor_history_multi.h
- Add route matching in canHandle() and handleRequest() for /api/v2/live
- Endpoint reads current values from SensorEntity devices[].metric_states[]
- Returns JSON: {"timestamp":..., "devices":{"office":{"temp":23.4,"hum":45.2,...},...}}
- Include last_seen per device
- Handle invalid/NAN values as null in JSON
- Add preflight check for /api/v2/live route
- Update Docs/changelog.md, session document, handoff document, bugs and lessons learned, if there are content for them
- Create session log
- Bump version to 7.5.3.4
- Regenerate all artifacts
- Stop after v7.5.3.4

Guardrails:
- Follow existing endpoint patterns in sensor_history_multi.h (canHandle/handleRequest dispatch, add_common_headers_)
- Use beginResponseStream for JSON output
- Use bash scripts/bump-version.sh 7.5.3.4

Device testing requirement (for me to perform after merge):
- Provide exact commands to update the repo locally with the current version
- esphome compile firmware/esp32-c3-multi-sensor.yaml
- esphome run firmware/esp32-c3-multi-sensor.yaml
- curl http://192.168.120.189/api/v2/live | jq — verify valid JSON with current sensor values
- Verify all existing endpoints still work

Expected output: scope summary, implementation, docs, validation, PR, exact device test steps
```

---

## Prompt for v7.5.3.5 — Add `/api/v2/history/{device}/{metric}` Endpoint

```
This is work regarding ESP32-BLE gateway project.
Project repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Current status:
- v7.5.3.4 is complete and merged
- Device test: /api/v2/live working (confirm before starting)
- main is green
- We are now moving to v7.5.3.5
- Current date: <INSERT DATE>

Before making any changes, first read these files fully:
- Docs/phase3-implementation-plan.md (v7.5.3.5 section)
- Docs/bugs-and-lessons-learned.md
- Docs/changelog.md
- dashboard/sensor_history_multi.h (understand existing /history/{id}/temp endpoint)
- the latest session handoff log(s) under Docs/

Task:
- Implement v7.5.3.5 exactly according to Docs/phase3-implementation-plan.md

Exact v7.5.3.5 scope:
- Add handle_api_v2_history_() method for GET /api/v2/history/{device_id}/{metric_key}
- Route parsing: extract device_id and metric_key from URL path
- Look up SensorEntity by device_id, find metric index by metric_key
- Read from metric_states[index].history HistoryBuffer
- Return same epoch,value CSV format as existing /history/{id}/temp
- Return 404 for unknown device or metric
- Return 404 if metric has no history buffer (history_enabled == false)
- Add preflight check for /api/v2/history route
- Update Docs/changelog.md, session document, handoff document, bugs and lessons learned, if there are content for them
- Bump version to 7.5.3.5

Device testing requirement:
- curl http://192.168.120.189/api/v2/history/office/temp — verify returns CSV data
- diff against curl http://192.168.120.189/history/office/temp — should be identical
- Test 404 for non-existent device and metric

Expected output: scope summary, implementation, docs, validation, PR, exact device test steps
```

---

## Prompt for v7.5.3.6 — Remove SensorSlot (THE BIG SWITCHOVER)

```
This is work regarding ESP32-BLE gateway project.
Project repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Current status:
- v7.5.3.5 is complete and merged
- Device test: /api/v2/history working, data matches legacy endpoint (confirm before starting)
- main is green
- We are now moving to v7.5.3.6
- Current date: <INSERT DATE>

⚠️ THIS IS THE HIGHEST-RISK STEP IN PHASE 3 ⚠️

Before making any changes, first read these files EXTREMELY CAREFULLY:
- Docs/phase3-implementation-plan.md (v7.5.3.6 section — read twice)
- Docs/bugs-and-lessons-learned.md (ALL entries)
- Docs/changelog.md
- Docs/v7.5-v7.6-architecture-plan.md (Section 10 — History and Persistence Strategy)
- dashboard/sensor_history_multi.h (understand SensorSlot, SegmentSnapshot, NVS read/write, import/export)
- the latest session handoff log(s) under Docs/

Task:
- Implement v7.5.3.6 exactly according to Docs/phase3-implementation-plan.md
- Before coding, provide a detailed analysis of what needs to change and what risks exist
- Ask for confirmation before proceeding with implementation

Exact v7.5.3.6 scope:
- Remove SensorSlot struct and sensors[] array from sensor_history_multi.h
- Remove SensorSlot generation from render_sensor_config.py
- Remove dual-write calls from YAML lambdas (keep only devices[i].add_sample() calls)
- Update ALL API handlers to read from SensorEntity devices[] instead of SensorSlot sensors[]
- Add persistence shims: SensorEntity ↔ SegmentSnapshot bridging for NVS read/write
  - Write: SensorEntity metric_states → SegmentSnapshot temp[]/hum[] arrays
  - Read: SegmentSnapshot temp[]/hum[] arrays → SensorEntity metric_states (boot restore)
- Keep SegmentSnapshot format UNCHANGED (this is critical)
- Keep NVS key naming scheme UNCHANGED
- Keep existing CSV export/import working
- Verify /sensors.json compatibility endpoint still works
- Update Docs/changelog.md, handoff document, bugs and lessons learned, if there are content for them
- Create session log
- Bump version to 7.5.3.6

CRITICAL CONSTRAINTS:
- SegmentSnapshot format MUST NOT change (temp[NUM_SENSORS][POINTS], hum[NUM_SENSORS][POINTS])
- NVS key naming MUST NOT change
- Import/export paths MUST work (both multi-sensor and single-sensor merge)
- The persistence layer is the most sensitive code — be extremely careful
- Environmental devices (category_id == 0) persist to flash; non-environmental use RAM only

Validation requirements:
- Preflight must pass
- All Playwright tests must pass
- render_sensor_config.py --check must pass

Device testing requirement (CRITICAL — for me to perform after merge):
Full device validation checklist:
- Provide exact commands to update the repo locally with the current version
1. esphome compile firmware/esp32-c3-multi-sensor.yaml
2. esphome run firmware/esp32-c3-multi-sensor.yaml (OTA flash)
3. curl /sensors.json | jq — verify v1 compatibility response
4. curl /api/manifest | jq — verify v2 manifest
5. curl /api/status | jq — verify health, check free heap
6. curl /api/v2/live | jq — verify live values
7. curl /history/office/temp | jq — verify legacy history endpoint
8. curl /api/v2/history/office/temp | jq — verify v2 history endpoint
9. Open dashboard in browser — verify rendering
10. Wait 30+ minutes — verify history accumulation
11. Reboot device — verify NVS restore loads history
12. Export CSV — verify valid output
13. Import CSV (if test data available) — verify import works
14. Record free heap and compare with pre-v7.5.3.6 baseline

Report ALL results back. ANY failure is a blocker — do not proceed.

Expected output: 
1. Detailed risk analysis with specific concerns
2. Request for confirmation to proceed
3. After confirmation: implementation, docs, validation, PR
4. Exact device test checklist for me
```

---

## Prompt for v7.5.3.7 — Phase 3 Closure

```
This is work regarding ESP32-BLE gateway project.
Project repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Current status:
- v7.5.3.6 is complete and merged
- Device test: ALL checks PASS (confirm before starting)
- main is green
- We are now moving to v7.5.3.7 — Phase 3 Closure
- Current date: <INSERT DATE>

Before making any changes, first read these files fully:
- Docs/phase3-implementation-plan.md (v7.5.3.7 section)
- Docs/bugs-and-lessons-learned.md
- Docs/changelog.md
- Docs/v7.5-v7.6-architecture-plan.md
- the latest session handoff log(s) under Docs/

Task:
- Implement v7.5.3.7 exactly according to Docs/phase3-implementation-plan.md
- This is Phase 3 closure — validation, test coverage, documentation

Exact v7.5.3.7 scope:
- Add comprehensive Phase 3 closure Playwright tests (Group 15) covering:
  1. /api/v2/live returns valid JSON with all device IDs from manifest
  2. /api/v2/live returns metric keys matching manifest metric definitions
  3. /api/v2/history/{device}/{metric} returns CSV data
  4. Legacy /history/{id}/temp still works (backward compat)
  5. Legacy /sensors.json still works (backward compat)
  6. Dashboard renders identically with new endpoints
  7. All existing tests pass (regression gate)
- Add /api/v2/live and /api/v2/history mock routes to tests/mock-server/server.js
- Update Docs/changelog.md with v7.5.3.7 entry and Phase 3 Complete callout
- Update Docs/v7.5-v7.6-architecture-plan.md — Phase 3 Status: COMPLETE
- Create session log
- Update Docs/bugs-and-lessons-learned.md if new bugs/lessons found
- Bump version to 7.5.3.7
- Regenerate all artifacts
- Stop after v7.5.3.7 — do not begin Phase 4

Phase 3 closure must reflect actual merged state only — do not claim anything beyond what is completed.

Expected output: scope summary, implementation, docs, validation, PR, manual steps
```

---

_End of Phase 3 prompt templates._
