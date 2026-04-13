# Phase V — Perplexity Review Prompts

_Consolidated review prompts for all Phase V steps. Use with GitHub MCP connected._

---

## How to Use

For each step, run the three turns below in a single Perplexity session with GitHub MCP connected. Replace `{version}` with the step version (e.g., `v7.6.7.0`) and `{pr_number}` with the PR number.

---

## Step: v7.6.7.0 (V1-A + V1-B + V1-C)

### Turn 1 — Extract Gate Checklist

Read the implementation prompt at `prompts/phaseV/v7.6.7.0-agent-prompt-gpt-codex.md` in the ESP32-GW-multi-sensor repo. Extract every acceptance criterion from §6 and every checkpoint from §5. List them as a numbered checklist.

### Turn 2 — Fetch and Verify

Fetch the PR #{pr_number} diff from the repo. Also read the agent's compliance table from the PR description. For each checklist item from Turn 1, mark PASS or FAIL with evidence.

Additional focus areas for this PR:
- Verify `fetch_to_buffer()` signature change is backward-compatible (all existing call sites use default parameters)
- Verify proxy returns 200 with empty body for zero-length satellite response (not 502)
- Verify NAS history buffer deletions: grep for `entity_hbuf_nas01_` should return zero results
- Verify `lwip_setsockopt` (not `setsockopt`) for timeout — Rule 27
- Verify `assemble-sensor-history.sh --write` was run after fragment edits

### Turn 3 — Verdict

Produce a structured verdict:
```
## PR #{pr_number} Review Verdict — v7.6.7.0

### Status: [APPROVED / APPROVED WITH FIXES / NEEDS REWORK]

### Checklist Results: X/Y passed

### Issues Found:
- [severity] [description]

### Carries Forward:
- [context needed for next step v7.6.7.1]
```

---

## Step: v7.6.7.1 (V1-D)

### Turn 1 — Extract Gate Checklist
Read `prompts/phaseV/v7.6.7.1-agent-prompt-gpt-codex.md`. Extract all acceptance criteria and checkpoints.

### Turn 2 — Fetch and Verify
Fetch PR #{pr_number} diff. Verify each checklist item.

Additional focus areas:
- CRITICAL: Verify `build_import_epoch_map_()` runs in xTaskCreate (not on httpd task) — Rule 40
- Verify `beginResponseStream` at line ~817 is replaced with `beginResponse()` — Rule 8
- Verify `/api/import/status` has NO auth guard (intentionally public)
- Verify import data endpoints (`/api/import/d/`, `/api/import/w/`) gate on `s_import_ready`
- Verify task stack is ≥ 8192 bytes
- Check: does `s_import_ready` use `volatile` qualifier?

### Turn 3 — Verdict
Same structure as v7.6.7.0.

---

## Step: v7.6.7.2 (V1-E + V1-F + V1-G)

### Turn 1 — Extract Gate Checklist
Read `prompts/phaseV/v7.6.7.2-agent-prompt-gpt-codex.md`.

### Turn 2 — Fetch and Verify

Additional focus areas:
- Verify version badge uses `App.version` (not hardcoded string)
- Verify dead code deletion: `grep -rn "stream_snapshot_series_\|->stream_to(" firmware/` returns zero
- Verify no direct edits to dashboard/dashboard.js or dashboard/dashboard.html — Rule 47
- Verify dashboard rebuild pipeline was run (4 commands)

### Turn 3 — Verdict

---

## Step: v7.6.8.0 (V2-A + V2-B + V2-C + V2-D)

### Turn 1 — Extract Gate Checklist
Read `prompts/phaseV/v7.6.8.0-agent-prompt-gpt-codex.md`.

### Turn 2 — Fetch and Verify

Additional focus areas:
- CRITICAL: Every modified handler must have `authenticate_management_()` as absolute first line — verify for each
- Verify LESSON-OPS-089 exception comment is REMOVED from handle_add_satellite_()
- Verify `/api/status` public response contains ONLY `ok`, `role`, `id` — no `version`, `free_heap`, `uptime_s`
- Verify `/api/status/full` requires auth and returns all fields
- Verify `fetch_to_buffer()` basic_auth parameter added correctly if aggregator polls `/api/status/full`
- Auth decision (LESSON-OPS-110): every endpoint handler code block should have explicit auth comment

### Turn 3 — Verdict

---

## Step: v7.6.8.1 (V2-E + V2-F + V2-G)

### Turn 1 — Extract Gate Checklist
Read `prompts/phaseV/v7.6.8.1-agent-prompt-gpt-codex.md`.

### Turn 2 — Fetch and Verify

Additional focus areas:
- Verify history endpoints (`/history/` and `/api/v2/history/`) both have auth guards
- Verify `csv.reserve()` is capped at `std::min(est_bytes, (size_t)60000)`
- Verify DoS cooldown uses static array (no heap allocation)
- Verify SEC-ADR-001 document is committed as-is (no modifications to content)

### Turn 3 — Verdict

---

## Step: v7.6.8.2 (V2-H + V2-I + V2-J)

### Turn 1 — Extract Gate Checklist
Read `prompts/phaseV/v7.6.8.2-agent-prompt-gpt-codex.md`.

### Turn 2 — Fetch and Verify

Additional focus areas:
- CRITICAL: Every change is GATED — verify measurement results are documented before code changes
- If any gate did NOT pass: verify the corresponding change was NOT made (no-change path)
- Verify httpd stack is never set below measured_peak + 2048
- Verify ping_adapter stack is never set below measured_peak + 512
- Verify LWIP socket count is never reduced below 13 (LESSON-OPS-051)
- Verify `patch-esphome-httpd-stack.sh` updated if httpd stack value changed

### Turn 3 — Verdict

---

## Step: v7.6.9.0 (V3-A)

### Turn 1 — Extract Gate Checklist
Read `prompts/phaseV/v7.6.9.0-agent-prompt-gpt-codex.md`.

### Turn 2 — Fetch and Verify

Additional focus areas:
- Verify DEVICE_INFO_MAP changes are in `dashboard/core/status-snapshot.js` (NOT in a components/ subdirectory)
- Verify manifest population is in `dashboard/core/manifest.js`
- Verify new text_sensor entities in YAML for flash/SRAM/PSRAM
- Verify dashboard rebuild pipeline (4 commands) was run
- Verify no direct edits to generated artifacts — Rule 47, 48

### Turn 3 — Verdict

---

## Step: v7.6.9.1 (V3-B + V3-C)

### Turn 1 — Extract Gate Checklist
Read `prompts/phaseV/v7.6.9.1-agent-prompt-gpt-codex.md`.

### Turn 2 — Fetch and Verify

Additional focus areas:
- Verify hostname/IP extraction from manifest uses gateway object only (not global search)
- Verify CSV `role` column is at position 3 (after timestamp, sensor_id)
- Verify backward-compatibility break is documented in changelog/PR description
- Verify Playwright tests cover both single and merged export formats

### Turn 3 — Verdict

---

## Step: v7.6.9.2 (V3-D + V3-E)

### Turn 1 — Extract Gate Checklist
Read `prompts/phaseV/v7.6.9.2-agent-prompt-gpt-codex.md`.

### Turn 2 — Fetch and Verify

Additional focus areas:
- Verify `EXPORT_SENSOR_SUFFIXES` is replaced with `getMetricColumnsForSensor()` (manifest-driven)
- Verify fallback to ['temp', 'hum'] when manifest is unavailable
- Verify AGG-ADR-001 document committed as-is
- Verify ping and system metrics appear in export (not blank columns)

### Turn 3 — Verdict

---

## Step: v7.6.9.3 (V3-F — conditional)

### Turn 1 — Extract Gate Checklist
Read `prompts/phaseV/v7.6.9.3-agent-prompt-gpt-codex.md`.

### Turn 2 — Fetch and Verify

Additional focus areas:
- If heap ≥ 65 KB: verify NO code changes, only a comment documenting the measurement
- If heap < 65 KB: verify struct changes do NOT affect NVS serialisation compatibility
- Verify measurement result is documented in issue #165

### Turn 3 — Verdict

---

_End of Phase V Perplexity review prompts._
