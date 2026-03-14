# Phase 2 Handoff — Fresh Start Baseline
Project: ESP32-GW-multi-sensor
Baseline version: `v7.5.0.1`
Date: 2026-03-14

## Read this first
Before changing code, review:
1. `Docs/v7.5-v7.6-architecture-plan.md`
2. `Docs/changelog.md`
3. `Docs/bugs-and-lessons-learned.md`
4. `Docs/session-log-2026-03-14-phase1-complete.md`
5. this file

## Current baseline summary
Phase 1 is complete and runtime-validated on the live device.

### Final verified baseline behaviors
- `/api/manifest` returns schema-v2 manifest data
- `/sensors.json` still returns legacy sensor metadata
- `/api/status` still returns runtime/status data including `free_heap` and `uptime_seconds`
- dashboard is operational and shows Free Heap/Uptime again
- built-in ESP web page shows Free Heap/Uptime again
- generator is currently idempotent
- compile and OTA upload succeeded from this baseline

## Important constraints for Phase 2
Do not regress:
- `/sensors.json` backward compatibility
- `/api/status`
- diagnostics on dashboard
- diagnostics on built-in ESP web page
- generator idempotence
- YAML indentation correctness
- source/generated dashboard alignment

## Recommended Phase 2 entry checklist
Before coding:
1. run `python3 scripts/render_sensor_config.py --write`
2. run `bash ./scripts/preflight.sh`
3. run `esphome compile firmware/esp32-c3-multi-sensor.yaml`
4. confirm clean baseline before introducing new changes

## Recommended Phase 2 implementation sequence
1. Re-read the architecture-plan sections immediately following the completed Phase 1 work.
2. Identify the exact delta between `v7.5.0.1` and the next architecture milestone.
3. Add/upgrade automation first where Phase 1 exposed blind spots:
   - ESPHome/YAML parse gate in preflight
   - source/generated dashboard stale-artifact detection
   - optional runtime smoke checks
4. Implement the next functional phase in small steps.
5. Update docs in the same commit/change bundle.

## Development conventions that must continue
- Keep bug fixes and lessons learned in reverse chronological order.
- Keep changelog entries aligned with actual shipped behavior.
- Keep session-log/handoff notes detailed enough for fresh-start continuity.
- If new code is delivered, deliver a full overwrite bundle unless the change is truly one-line and safe.
- Keep source-of-truth discipline:
  - fix source first
  - regenerate derived artifacts
- If the latest known-good baseline is not present, ask for the current local files rather than reconstructing from memory.

## Suggested verification set for future phases
```bash
python3 scripts/render_sensor_config.py --write
bash ./scripts/preflight.sh
esphome compile firmware/esp32-c3-multi-sensor.yaml
```

Runtime smoke set:
```bash
curl -s http://<esp-ip>/sensors.json | jq
curl -s http://<esp-ip>/api/status | jq
curl -s http://<esp-ip>/api/manifest | jq
```

UI smoke set:
- dashboard loads
- built-in ESPHome web page loads
- Free Heap visible
- Uptime visible
- no new console errors

## Known preflight gap from Phase 1
The original preflight did not catch YAML indentation corruption. A supplemental parse gate should be folded into the main preflight workflow at the start of Phase 2.
