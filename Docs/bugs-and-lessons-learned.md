# Bugs and Lessons Learned

> Reverse chronological order. Latest first.

## 2026-03-14 — YAML indentation bug in generated marker-managed sections
### Symptom
`esphome compile firmware/esp32-c3-multi-sensor.yaml` failed with:
- `expected <block end>, but found '<scalar>'`
- reported near line 135 after generator runs.

### Root cause
The YAML generation path reinserted block content without preserving the indentation level of the marker location. The content was semantically correct but structurally invalid YAML inside:
- lambda block scalar sections
- `web_server.sorting_groups`
- `sensor`
- `text_sensor`

### Fix
- Restored an indentation-safe YAML generation path.
- Recovered the generated YAML to a compile-clean state.
- Revalidated idempotence with `python3 scripts/render_sensor_config.py --write`.

### Lesson learned
Generator correctness for YAML requires **both**:
1. idempotent marker replacement
2. indentation preservation relative to the marker line

Content-only sync checks are not enough.

---

## 2026-03-14 — Preflight gap: generated files could be in sync yet YAML could still be invalid
### Symptom
Preflight passed, but ESPHome YAML parsing still failed.

### Root cause
The existing preflight focused on:
- version drift
- generator drift
- fixture drift
- manifest route/fallback presence

It did **not** run an ESPHome/YAML parse gate.

### Fix / Recommendation
Add a supplemental preflight step that runs:
- `esphome config firmware/esp32-c3-multi-sensor.yaml`

This should fail the pipeline before compile if YAML structure is broken.

### Lesson learned
For this repo, preflight should validate:
- sync/idempotence
- source/generated artifact alignment
- ESPHome config parse

---

## 2026-03-14 — Generator version stamping drift after version bump
### Symptom
After bumping to `v7.5.0.1`, preflight failed on `dashboard_js_version_matches`.

### Root cause
A version hotfix updated output files but did not update the generator script that rewrites `dashboard/dashboard.js`.

### Fix
- Updated generator version constant to `v7.5.0.1`.
- Re-ran generator and preflight.

### Lesson learned
Any version bump in this repo must include **all generators** that stamp generated artifacts, not just the generated files themselves.

---

## 2026-03-14 — Dashboard runtime regression despite successful manifest/status APIs
### Symptom
- `/api/manifest` worked
- `/api/status` worked
- `/sensors.json` worked
- but dashboard temporarily lost Free Heap and Uptime
- built-in ESPHome web page also lost Free Heap and Uptime

### Root cause
This was actually two separate regressions:
1. YAML had lost the diagnostics sensors needed for the built-in ESPHome web page.
2. Dashboard artifacts were out of sync; source and generated assets did not reflect the same status-field handling.

### Fix
- Restored Free Heap, Uptime, and Loop Time in YAML.
- Updated source dashboard logic to hydrate Free Heap and Uptime from `/api/status`.
- Regenerated `dashboard.min.html` and `dashboard.h` from source.
- Verified the values reappeared on both dashboard and built-in web page.

### Lesson learned
Never treat generated dashboard artifacts as primary source. Fix source first, then regenerate.

---

## 2026-03-14 — Brittle local patch scripts against compacted source files
### Symptom
Multiple patch-script attempts failed when applied to local files even though the intended logic was correct.

### Root cause
Several repo files are compacted or serialized in a way that makes exact-string patching fragile, especially:
- `dashboard/sensor_history_multi.h`
- generator-managed outputs

### Fix
- Switched to direct file recovery from uploaded local state.
- Avoided continued blind patching once local drift was clear.

### Lesson learned
For this repo:
- exact-text patching is fragile
- function-anchor / regex / brace-aware patching is safer
- when local drift becomes nontrivial, patch the real uploaded files instead of inferred repo state

---

## 2026-03-13 — Python `re.sub()` replacement-string escape issue
### Symptom
`render_sensor_config.py --write` failed with:
- `bad escape \x`

### Root cause
Generated text containing backslashes (for example `\xC2\xB0`) was passed as a raw replacement string into `re.sub()`, which interprets backslashes in replacement strings.

### Fix
Use lambda replacements:
- `pattern.sub(lambda _m: replacement, text, count=1)`

### Lesson learned
For generator scripts in this repo, literal generated content should be inserted with lambda replacement functions, not raw regex replacement strings.
