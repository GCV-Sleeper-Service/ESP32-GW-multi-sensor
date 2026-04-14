# Phase V — PR Review Prompts (Perplexity-Optimized, Three-Turn)

_Repo: `GCV-Sleeper-Service/ESP32-GW-multi-sensor`_  
_Date: 2026-04-13_  
_Optimized for: Perplexity AI (stateless, MCP GitHub tool access, no persistent sub-agents)_  
_Scope: PR reviewer prompts only — agent prompts are in separate files_

---

## How these prompts differ from the Claude originals

The original Step 2 review sessions were written for **Claude Code** — a stateful IDE agent that reads files interactively and maintains shell context across commands. Perplexity operates differently:

- **No shell execution.** Every file read is a GitHub MCP API call that costs context tokens.
- **No persistent state between turns.** Each turn is a discrete operation; nothing is implicitly carried forward.
- **Context is the scarcest resource.** Loading handoff files, implementation specs, and PR diffs simultaneously can consume 40–70 % of the working window before any gate verdict is formed.
- **MCP diff access is precise.** Perplexity can fetch the PR diff for exact file paths without opening the full source, which is the primary token-saving lever.

The design goal for these prompts is:

- **Inline compact context** at the top of every review section (≤ 400 tokens) so gate criteria are in high-attention positions before any file is opened.
- **Spec-first, diff-second.** Turn 1 extracts the gate contract from handoff + instructions without touching the PR. Turn 2 audits the diff and evidence. Turn 3 produces the structured verdict.
- **Evidence-first, source-last.** Only open fragment source files if the diff alone is ambiguous for a gate decision.
- **Deliverables explicit.** Every review section lists post-merge deliverables so they are never forgotten.

---

# v7.6.7.0 — Proxy 502 Fix + NAS History Disable + Logger Level

## Inline review context

```
Step: V1-A + V1-B + V1-C
Objective: Fix proxy 502 with JSON diagnostic; disable NAS history buffers (~2.3 KB SRAM gain); logger INFO→WARN.
Allowed diff scope:
  firmware/core/aggregator-runtime.h  — fetch_to_buffer() signature + body
  firmware/core/web-handler.h         — handle_aggregator_proxy_() changes
  firmware/core/data-model.h          — metrics_system[] + entity_hbuf_nas01_* deletions + devices[4]
  firmware/esp32-c3-multi-sensor.yaml — logger level change
  Docs/changelog.md · version artifact · session log
⛔ Out of scope: auth guards (V2) · import handlers (V1-D) · dashboard/sensor_history_multi.h (Rule 58)
Critical rules: Rule 27 (lwip_setsockopt) · Rule 58 (no direct monolith edit) · Rule 8 (no beginResponseStream)
Blocking gates: Rule 27 violation · Rule 58 violation · existing call sites broken
Evidence needed: preflight pass · assembly --check pass · Playwright results · heap delta log
```

## Review prompt — v7.6.7.0

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor
Read `prompts/handoff/phaseV/Perplexity-Session-Context-Protocol-Three-Turn.md` first.
Use the Shared Perplexity Review Session Protocol from that file throughout this session.

**Turn 1 reads (do not open more than these):**
- `prompts/handoff/phaseV/session-handoff-v7.6.7.0.md`
- `prompts/phaseV/v7.6.7.0-agent-prompt-gpt-codex.md`

**Turn 2 — Diff + evidence fetch:**
- PR diff for `aggregator-runtime.h`, `web-handler.h`, `data-model.h`,
  `esp32-c3-multi-sensor.yaml`, changelog, version/session log
- Agent compliance table and validation outputs from PR description or comments

**Review gates to decide explicitly:**
- `fetch_to_buffer()` has `timeout_s` (default 5) and `out_http_status` (default nullptr) in signature
- All existing `fetch_to_buffer()` call sites (~lines 246, 599, 646, 685) are unchanged (use defaults)
- Proxy returns `502` + JSON `{"error":"upstream_fetch_failed","url":"..."}` on failure — not empty body
- Proxy returns `200` + empty body when satellite has no history — not `502`
- Proxy passes `timeout_s=15` to `fetch_to_buffer()`
- `ESP_LOGW` emitted on proxy fetch failure
- `lwip_setsockopt` used — not bare `setsockopt` (Rule 27)
- `metrics_system[]` cpu/ram/disk entries have `false` for history_enabled
- Three `entity_hbuf_nas01_*` static globals deleted (grep returns 0 results)
- `devices[4]` metric_states have `history = nullptr` (no dangling pointers)
- Logger level is WARN; wifi and api are ERROR
- `assemble-sensor-history.sh --write` was run after fragment edits
- No direct edits to `dashboard/sensor_history_multi.h` (Rule 58)
- No auth guards added (V2 scope only)
- All Playwright fixture sets pass

**Turn 3 — Verdict + output**

Post findings as a PR comment on PR #<PR_NUMBER> using the standard Turn 3 format.

**Fix prompt (if NEEDS-FIX or BLOCKED)**
Generate a downloadable fix prompt in markdown that:
- Addresses ONLY the remaining failing/unclear gates
- Includes a Do-NOT list covering already-passing gates to prevent regressions
- Uses `prompts/phaseV/v7.6.7.0-agent-prompt-gpt-codex.md` as style reference

**Post-merge deliverables (if MERGE-READY)**
- Create `prompts/phaseV/v7.6.7.0-PR<NN>-consolidated-audit-and-lessons.md`
- Review and update `prompts/handoff/phaseV/session-handoff-v7.6.7.1.md`
- Review and update `prompts/phaseV/v7.6.7.1-agent-prompt-gpt-codex.md`
- Apply version tag `v7.6.7.0`
- Operator device tests to include in consolidated audit: proxy 502+JSON when satellite disconnected · proxy 200+empty when no history · NAS history endpoint returns 404 · free heap increased ~2.3 KB vs baseline

---

# v7.6.7.1 — Import Crash Fix (Rule 40 Violation)

## Inline review context

```
Step: V1-D
Objective: Fix handle_import_begin_() watchdog crash on C3 — defer build_import_epoch_map_()
           to xTaskCreate; add /api/import/status polling endpoint; fix Rule 8 violation at line ~817.
Allowed diff scope:
  firmware/core/web-handler.h  — handle_import_begin_(), new task, s_import_ready flag,
                                  /api/import/status endpoint, handle_import_data_() gate
  dashboard/core/app-shell.js (or relevant import component) — status polling loop
  Docs/changelog.md · version artifact · session log
⛔ Out of scope: other fragment files · auth guards (V2) · dashboard/sensor_history_multi.h (Rule 58)
Critical rules: Rule 8 (no beginResponseStream) · Rule 40 (NVS work ≥5ms → xTaskCreate ≥8192B stack) ·
                Rule 41 (httpd task must not block on NVS I/O)
Blocking gates: Rule 40 violation (synchronous NVS on httpd) · Rule 8 violation at line ~817 · task stack < 8192
Evidence needed: C3 device test — no watchdog on import begin · /api/import/status polling trace · Playwright pass
```

## Review prompt — v7.6.7.1

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Read `prompts/handoff/phaseV/Perplexity-Session-Context-Protocol-Three-Turn.md` first.
Use the Shared Perplexity Review Session Protocol from that file throughout this session.

**Turn 1 reads (do not open more than these):**
- `prompts/handoff/phaseV/session-handoff-v7.6.7.1.md`
- `prompts/phaseV/v7.6.7.1-agent-prompt-gpt-codex.md`

**Turn 2 diff + evidence fetch:**
- PR diff for `web-handler.h`, relevant dashboard JS import component, changelog, version/session log
- Agent compliance table and C3 device test evidence from PR description or comments

**Review gates to decide explicitly:**
- `build_import_epoch_map_()` is called inside `xTaskCreate` task — NOT on the httpd task directly (Rule 40)
- `xTaskCreate` stack size is ≥ 8192 bytes
- `s_import_ready` is declared `static volatile bool`
- `handle_import_begin_()` at line ~817 uses `beginResponse()` — not `beginResponseStream` (Rule 8)
- `handle_import_begin_()` returns `{"ok":true,"status":"queued"}` immediately without NVS blocking
- `/api/import/status` endpoint exists and returns `{"ready":false}` / `{"ready":true}`
- `/api/import/status` has NO auth guard (explicitly public — only returns boolean, no sensitive data)
- `/api/import/d/` and `/api/import/w/` gate on `s_import_ready` returning `409` when not ready
- Dashboard JS polls `/api/import/status` before sending data chunks
- `assemble-sensor-history.sh --write` was run after fragment edits
- No Rule 58 violation (no direct edit to `sensor_history_multi.h`)
- Existing Playwright import tests pass (or updated to use status polling)

**Turn 3 — Verdict + output**

Post findings as a PR comment on PR #<PR_NUMBER> using the standard Turn 3 format.

**Fix prompt (if NEEDS-FIX or BLOCKED)**
Generate a downloadable fix prompt in markdown that:
- Addresses ONLY the remaining failing/unclear gates
- Includes a Do-NOT list covering already-passing gates to prevent regressions
- Uses `prompts/phaseV/v7.6.7.1-agent-prompt-gpt-codex.md` as style reference

**Post-merge deliverables when MERGE-READY:**
- Create `prompts/phaseV/v7.6.7.1-PR<NN>-consolidated-audit-and-lessons.md`
- Review and update `prompts/handoff/phaseV/session-handoff-v7.6.7.2.md`
- Review and update `prompts/phaseV/v7.6.7.2-agent-prompt-gpt-codex.md`
- Apply version tag `v7.6.7.1`
- Operator device test to include in consolidated audit: full import sequence (begin → poll status → d/ × N → finish) completes on C3 without watchdog reset; free heap before/after import begin does not drop below 65 KB

---

# v7.6.7.2 — Version Badge + Dead Code Deletion + Import Comment

## Inline review context

```
Step: V1-E + V1-F + V1-G
Objective: Add version badge in dashboard footer (App.version); delete dead stream functions
           (stream_snapshot_series_(), HistoryBuffer::stream_to()); add import session timeout comment.
Allowed diff scope:
  dashboard/dashboard.tmpl.html           — versionBadge span
  dashboard/core/app-shell.js             — badge population in App.Boot.start()
  scripts/preflight.sh                    — dashboard_has_version_badge check
  firmware/core/nvs-persistence.h         — delete stream_snapshot_series_()
  firmware/core/data-model.h              — delete HistoryBuffer::stream_to()
  firmware/core/web-handler.h             — import session timeout comment only (no code change)
  dashboard/dashboard.js (generated)      — rebuild artifact
  dashboard/dashboard.html (generated)    — rebuild artifact
  dashboard/dashboard.h (generated)       — rebuild artifact
  Docs/changelog.md · version artifact · session log
⛔ Out of scope: auth guards (V2) · sensor history fragment content changes · Rule 47/48 violation
Critical rules: Rule 47 (never edit dashboard.js/dashboard.html directly) ·
                Rule 48 (never edit dashboard.tmpl.html as generated — edit source modules) ·
                Rule 58 (no direct monolith edit)
Blocking gates: Rule 47 violation · Rule 48 violation · dead code not fully removed
Evidence needed: grep zero-result for stream functions · preflight pass · Playwright pass · badge visible
```

## Review prompt — v7.6.7.2

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Read `prompts/handoff/phaseV/Perplexity-Session-Context-Protocol-Three-Turn.md` first.
Use the Shared Perplexity Review Session Protocol from that file throughout this session.

**Turn 1 reads (do not open more than these):**
- `prompts/handoff/phaseV/session-handoff-v7.6.7.2.md`
- `prompts/phaseV/v7.6.7.2-agent-prompt-gpt-codex.md`

**Turn 2 diff + evidence fetch:**
- PR diff for `dashboard.tmpl.html`, `app-shell.js`, `preflight.sh`, `nvs-persistence.h`, `data-model.h`, `web-handler.h`, generated dashboard artifacts, changelog, version/session log
- Agent compliance table and grep evidence from PR description or comments

**Review gates to decide explicitly:**
- `dashboard/dashboard.tmpl.html` has `<span id="versionBadge" ...>` added in footer area
- `app-shell.js` populates badge with `'v' + App.version` as the **first** action in `App.Boot.start()`
- Badge uses `App.version` — NOT a hardcoded string
- `scripts/preflight.sh` has `check_contains "dashboard_has_version_badge" "dashboard/dashboard.html" 'id="versionBadge"'`
- `grep -rn "stream_snapshot_series_\|->stream_to(" firmware/` returns zero results (agent evidence)
- `stream_snapshot_series_()` deleted from `nvs-persistence.h`
- `HistoryBuffer::stream_to()` deleted from `data-model.h`
- Pre-condition grep was confirmed before deletion (evidence in PR)
- Import session timeout comment added to `web-handler.h` (comment only — no code change)
- Four-command dashboard rebuild pipeline was run: `bundle-dashboard.sh --write` → `build-dashboard.sh` → `generate-header.sh` → `preflight.sh`
- No direct edits to `dashboard/dashboard.js` or `dashboard/dashboard.html` (Rule 47)
- `dashboard.tmpl.html` was edited as the source (Rule 48)
- No Rule 58 violation
- `assemble-sensor-history.sh --write` was run after fragment edits
- All Playwright fixture sets pass

**Turn 3 — Verdict + output**

Post findings as a PR comment on PR #<PR_NUMBER> using the standard Turn 3 format.

**Fix prompt (if NEEDS-FIX or BLOCKED)**
Generate a downloadable fix prompt in markdown that:
- Addresses ONLY the remaining failing/unclear gates
- Includes a Do-NOT list covering already-passing gates to prevent regressions
- Uses `prompts/phaseV/v7.6.7.2-agent-prompt-gpt-codex.md` as style reference

**Post-merge deliverables when MERGE-READY:**
- Create `prompts/phaseV/v7.6.7.2-PR<NN>-consolidated-audit-and-lessons.md`
- Review and update `prompts/handoff/phaseV/session-handoff-v7.6.8.0.md`
- Review and update `prompts/phaseV/v7.6.8.0-agent-prompt-gpt-codex.md`
- Apply version tag `v7.6.7.2`
- Complete V1 Operator Measurement Protocol (Steps 1–7) on physical C3 running v7.6.7.2; record results in consolidated audit before starting V2

---

# v7.6.8.0 — Auth Guards: ingest + add-satellite + aggregator reads + status field strip

## Inline review context

```
Step: V2-A + V2-B + V2-C + V2-D
Objective: Add authenticate_management_() guard to /api/ingest/, /api/aggregator/add-satellite,
           /api/aggregator/gateways, /api/aggregator/live/, /api/aggregator/proxy/;
           strip sensitive fields from public /api/status; add /api/status/full (auth-gated).
Allowed diff scope:
  firmware/core/web-handler.h         — auth guards on five handlers; /api/status/full endpoint
  firmware/core/aggregator-runtime.h  — fetch_to_buffer() basic_auth param; agg_poll_task_() → /status/full
  Docs/lessons/build-pipeline.md      — LESSON-SEC-001 + LESSON-OPS-089 resolved marker
  Docs/changelog.md · version artifact · session log
⛔ Out of scope: firmware/core fragment content changes beyond auth guards ·
                dashboard/sensor_history_multi.h · test files
Critical rules: Rule 8 (no beginResponseStream) · Rule 24 (free_heap_internal + free_heap_total separate) ·
                LESSON-OPS-110 (explicit auth comment in every handler code block)
Blocking gates: any modified handler missing authenticate_management_() as absolute first line ·
                LESSON-OPS-089 exception comment NOT removed · /api/status leaking version/heap/uptime fields
Evidence needed: curl 401 evidence for each guarded endpoint · curl 200 with credentials ·
                 /api/status stripped JSON · /api/status/full full JSON · aggregator dashboard still shows satellite heap
```

## Review prompt — v7.6.8.0

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Read `prompts/handoff/phaseV/Perplexity-Session-Context-Protocol-Three-Turn.md` first.
Use the Shared Perplexity Review Session Protocol from that file throughout this session.

**Turn 1 reads (do not open more than these):**
- `prompts/handoff/phaseV/session-handoff-v7.6.8.0.md`
- `prompts/phaseV/v7.6.8.0-agent-prompt-gpt-codex.md`
- `Docs/lessons/build-pipeline.md` — LESSON-OPS-089 and LESSON-OPS-110 entries only

**Turn 2 diff + evidence fetch:**
- PR diff for `web-handler.h`, `aggregator-runtime.h`, `build-pipeline.md`, changelog, version/session log
- Agent compliance table, curl evidence for each guarded endpoint, and aggregator dashboard test from PR description or comments

**Review gates to decide explicitly:**
- `handle_api_ingest_()`: `authenticate_management_(request)` is the absolute first line (V2-A)
- `handle_add_satellite_()`: `authenticate_management_(request)` is the absolute first line (V2-B)
- `handle_add_satellite_()`: LESSON-OPS-089 exception comment is **removed** — not commented out, removed (V2-B)
- `handle_aggregator_gateways_()`: `authenticate_management_(request)` is the absolute first line (V2-C)
- `handle_aggregator_live_()`: `authenticate_management_(request)` is the absolute first line (V2-C)
- `handle_aggregator_proxy_()`: `authenticate_management_(request)` is the absolute first line (V2-C)
- Public `/api/status` returns ONLY `ok`, `role`, `id` — fields `version`, `free_heap`, `free_heap_internal`, `uptime_s`, `wifi_rssi`, `hardware` are absent (V2-D)
- `/api/status/full` exists and requires auth; returns all fields including `free_heap_internal` separately from `free_heap_total` (Rule 24) (V2-D)
- `fetch_to_buffer()` has `basic_auth` parameter; aggregator poll task calls `/api/status/full` with credentials (V2-D)
- Every modified handler has an explicit `// Auth: REQUIRED` or `// Auth: NOT REQUIRED — [rationale]` comment (LESSON-OPS-110)
- `Docs/lessons/build-pipeline.md` has `LESSON-SEC-001` added and LESSON-OPS-089 marked resolved (V2-A/B)
- No `beginResponseStream` in any modified handler (Rule 8)
- `assemble-sensor-history.sh --write` was run after fragment edits; preflight passes

**Turn 3 — Verdict + output**

Post findings as a PR comment on PR #<PR_NUMBER> using the standard Turn 3 format.

**Fix prompt (if NEEDS-FIX or BLOCKED)**
Generate a downloadable fix prompt in markdown that:
- Addresses ONLY the remaining failing/unclear gates
- Includes a Do-NOT list covering already-passing gates to prevent regressions
- Uses `prompts/phaseV/v7.6.8.0-agent-prompt-gpt-codex.md` as style reference

**Post-merge deliverables when MERGE-READY:**
- Create `prompts/phaseV/v7.6.8.0-PR<NN>-consolidated-audit-and-lessons.md`
- Review and update `prompts/handoff/phaseV/session-handoff-v7.6.8.1.md`
- Review and update `prompts/phaseV/v7.6.8.1-agent-prompt-gpt-codex.md`
- Apply version tag `v7.6.8.0`
- Verify all external push scripts and ESPHome sensors that POST to `/api/ingest/` have been updated with auth headers; document in consolidated audit

---

# v7.6.8.1 — History Auth + Heap Cap + DoS Cooldown + SEC-ADR Commit

## Inline review context

```
Step: V2-E + V2-F + V2-G
Objective: Auth-gate history endpoints; cap csv.reserve() at 60000 bytes; add per-URL probe
           cooldown (static array, no heap alloc) to add-satellite; commit SEC-ADR-001 document.
Allowed diff scope:
  firmware/core/web-handler.h      — handle_history_() + handle_api_v2_history_() auth guard + reserve cap
  firmware/core/aggregator-runtime.h or web-handler.h — cooldown array for add-satellite probe
  Docs/decisions/SEC-ADR-001-residual-vulnerabilities.md (new file — committed as-is)
  Docs/changelog.md · version artifact · session log
⛔ Out of scope: other fragment changes · dashboard changes · test files · dashboard/sensor_history_multi.h
Critical rules: Rule 8 (no beginResponseStream) · Rule 27 (lwip_setsockopt)
Blocking gates: either history endpoint missing auth guard · SEC-ADR-001 content modified from plan draft
Evidence needed: curl 401 on history without auth · curl 200 with auth · large history request heap log ≥50KB ·
                 second rapid add-satellite returns 429 · SEC-ADR-001 file exists at correct path
```

## Review prompt — v7.6.8.1

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Read `prompts/handoff/phaseV/Perplexity-Session-Context-Protocol-Three-Turn.md` first.
Use the Shared Perplexity Review Session Protocol from that file throughout this session.

**Turn 1 reads (do not open more than these):**
- `prompts/handoff/phaseV/session-handoff-v7.6.8.1.md`
- `prompts/phaseV/v7.6.8.1-agent-prompt-gpt-codex.md`

**Turn 2 diff + evidence fetch:**
- PR diff for `web-handler.h`, `aggregator-runtime.h` (if cooldown is placed there), `SEC-ADR-001-residual-vulnerabilities.md`, changelog, version/session log
- Agent compliance table, curl auth evidence, heap-under-load log, 429 evidence from PR description or comments

**Review gates to decide explicitly:**
- `handle_history_()` has `authenticate_management_(request)` as first line (V2-E)
- `handle_api_v2_history_()` has `authenticate_management_(request)` as first line (V2-E)
- `csv.reserve()` is capped: `std::min(est_bytes, (size_t)60000)` (V2-E)
- Cooldown uses a **static array** — no `std::map`, no heap allocation (V2-F)
- Cooldown enforces 60-second window before re-probing the same URL (V2-F)
- Second rapid `add-satellite` for the same URL returns `429` with appropriate message (V2-F)
- `Docs/decisions/SEC-ADR-001-residual-vulnerabilities.md` exists at the correct path (V2-G)
- SEC-ADR-001 content was committed as-is from the plan draft — not rewritten or paraphrased (V2-G)
- No `beginResponseStream` added in any modified handler (Rule 8)
- `assemble-sensor-history.sh --write` run after fragment edits; preflight passes
- Playwright tests pass

**Turn 3 — Verdict + output**

Post findings as a PR comment on PR #<PR_NUMBER> using the standard Turn 3 format.

**Fix prompt (if NEEDS-FIX or BLOCKED)**
Generate a downloadable fix prompt in markdown that:
- Addresses ONLY the remaining failing/unclear gates
- Includes a Do-NOT list covering already-passing gates to prevent regressions
- Uses `prompts/phaseV/v7.6.8.1-agent-prompt-gpt-codex.md` as style reference

**Post-merge deliverables when MERGE-READY:**
- Create `prompts/phaseV/v7.6.8.1-PR<NN>-consolidated-audit-and-lessons.md`
- Review and update `prompts/handoff/phaseV/session-handoff-v7.6.8.2.md`
- Review and update `prompts/phaseV/v7.6.8.2-agent-prompt-gpt-codex.md`
- Apply version tag `v7.6.8.1`
- Note: V2-H/I/J (v7.6.8.2) are GATED — do not begin until V1 Operator Measurement Protocol results are confirmed and recorded

---

# v7.6.8.2 — Gated Optimisations (OPT-04 + OPT-03 + OPT-01)

## Inline review context

```
Step: V2-H + V2-I + V2-J (GATED — ship ONLY if ALL device gate measurements pass)
Objective: Right-size LWIP socket count (18→15 if gate passes); reduce ping_adapter stack
           (4096→2048 if watermark headroom ≥512B); right-size httpd task stack per decision table.
Allowed diff scope:
  firmware/esp32-c3-multi-sensor.yaml                          — CONFIG_LWIP_MAX_SOCKETS (if gate passes)
  firmware/core/ping-adapter.h                                 — xTaskCreate stack (if gate passes)
  firmware/local_components/web_server_idf/web_server_idf.cpp  — config.stack_size (if gate passes)
  scripts/patch-esphome-httpd-stack.sh                         — updated patched value (if httpd stack changed)
  Docs/changelog.md · version artifact · session log
⛔ Out of scope: any change not listed above · auth logic · fragment functional changes
HARD RULES: CONFIG_LWIP_MAX_SOCKETS never below 13 (LESSON-OPS-051) ·
            httpd stack never below measured_peak + 2048B ·
            ping_adapter stack change only if 4096 - peak ≥ 512B ·
            if ANY gate fails → corresponding change MUST NOT be present in diff
Blocking gates: any gated change present without documented passing measurement ·
                LWIP sockets set below 13 · httpd stack set below peak + 2048
Evidence needed: V1 Operator Measurement results table · 5-minute two-tab test log (no ENFILE errors) ·
                 ping_adapter watermark reading · httpd stack watermark reading · decision table applied correctly
```

## Review prompt — v7.6.8.2

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Read `prompts/handoff/phaseV/Perplexity-Session-Context-Protocol-Three-Turn.md` first.
Use the Shared Perplexity Review Session Protocol from that file throughout this session.

**Turn 1 reads (do not open more than these):**
- `prompts/handoff/phaseV/session-handoff-v7.6.8.2.md`
- `prompts/phaseV/v7.6.8.2-agent-prompt-gpt-codex.md`

**Turn 2 diff + evidence fetch:**
- PR diff for `esp32-c3-multi-sensor.yaml`, `ping-adapter.h`, `web_server_idf.cpp`, `patch-esphome-httpd-stack.sh`, changelog, version/session log
- V1 Operator Measurement results table from PR description; 5-minute two-tab test log; watermark readings for httpd and ping_adapter

**Review gates to decide explicitly:**
- V1 Operator Measurement Protocol results are documented and present before any code change (prerequisite)
- **OPT-04 (LWIP sockets):** If gate passed → `CONFIG_LWIP_MAX_SOCKETS` changed to 15; if gate failed → value is unchanged at 18; value is NEVER below 13 (LESSON-OPS-051)
- **OPT-03 (ping_adapter stack):** If watermark headroom ≥ 512 B → `xTaskCreate` stack set to 2048; if < 512 B → unchanged at 4096
- **OPT-01 (httpd stack):** New stack value matches the decision table exactly (≥6144 headroom→10240; ≥4096→12288; ≥2048→14336; <2048→no change)
- httpd stack is NEVER set below `measured_peak + 2048 B` regardless of table
- `patch-esphome-httpd-stack.sh` updated with new patched value if httpd stack was changed
- No-change paths: if a gate did NOT pass, the corresponding diff section must be absent (not commented out)
- Measurement results documented in issues #164 and #165
- `assemble-sensor-history.sh --write` run after fragment edit (ping-adapter); preflight passes

**Turn 3 — Verdict + output**

Post findings as a PR comment on PR #<PR_NUMBER> using the standard Turn 3 format.

**Fix prompt (if NEEDS-FIX or BLOCKED)**
Generate a downloadable fix prompt in markdown that:
- Addresses ONLY the remaining failing/unclear gates
- Includes a Do-NOT list covering already-passing gates to prevent regressions
- Uses `prompts/phaseV/v7.6.8.2-agent-prompt-gpt-codex.md` as style reference

**Post-merge deliverables when MERGE-READY:**
- Create `prompts/phaseV/v7.6.8.2-PR<NN>-consolidated-audit-and-lessons.md`
- Review and update `prompts/handoff/phaseV/session-handoff-v7.6.9.0.md`
- Review and update `prompts/phaseV/v7.6.9.0-agent-prompt-gpt-codex.md`
- Apply version tag `v7.6.8.2`
- Post-V2 heap measurement: confirm `free_heap_internal` at boot on C3; record value to determine if V3-F (struct audit) gate is triggered (< 65 KB triggers V3-F)

---

# v7.6.9.0 — Dashboard Device Card Cleanup (#143 + #144 + #136 + #138)

## Inline review context

```
Step: V3-A (combined — #143 version badge already shipped in v7.6.7.2; confirm not duplicated)
Objective: Device card cleanup — replace MAC with device name + firmware version (#144);
           add flash/SRAM from runtime text_sensors (#136); add PSRAM sensors on S3 / "None" on C3 (#138).
Allowed diff scope:
  dashboard/core/status-snapshot.js    — DEVICE_INFO_MAP updates (NOT in components/ subdirectory)
  dashboard/core/manifest.js           — populate di-device-name, di-firmware-version
  dashboard/dashboard.tmpl.html        — new device info row IDs
  firmware/esp32-c3-multi-sensor.yaml  — flash/SRAM/PSRAM text_sensor entities
  firmware/esp32-s3-multi-sensor.yaml  — PSRAM sensor entities
  scripts/preflight.sh                 — presence checks for new IDs
  Generated artifacts: dashboard/dashboard.js · dashboard/dashboard.html · dashboard/dashboard.h
  Docs/changelog.md · version artifact · session log
⛔ Out of scope: firmware/core fragment changes · sensor_history_multi.h · direct generated artifact edits
Critical rules: Rule 47 (never edit dashboard.js/dashboard.html directly) · Rule 48 (edit tmpl.html source) ·
                Rule 58 (no monolith direct edit)
Blocking gates: Rule 47 violation · Rule 48 violation · DEVICE_INFO_MAP in wrong file location
Evidence needed: dashboard render showing device name + firmware version · PSRAM "None" on C3 ·
                 preflight pass · Playwright pass
```

## Review prompt — v7.6.9.0

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Read `prompts/handoff/phaseV/Perplexity-Session-Context-Protocol-Three-Turn.md` first.
Use the Shared Perplexity Review Session Protocol from that file throughout this session.

**Turn 1 reads (do not open more than these):**
- `prompts/handoff/phaseV/session-handoff-v7.6.9.0.md`
- `prompts/phaseV/v7.6.9.0-agent-prompt-gpt-codex.md`

**Turn 2 diff + evidence fetch:**
- PR diff for `status-snapshot.js`, `manifest.js`, `dashboard.tmpl.html`, both YAML files, `preflight.sh`, generated artifacts, changelog, version/session log
- Agent compliance table and dashboard render screenshots or DOM evidence from PR description or comments

**Review gates to decide explicitly:**
- `DEVICE_INFO_MAP` changes are in `dashboard/core/status-snapshot.js` — NOT in a `components/` subdirectory
- `di-device-name` and `di-firmware-version` populated from `/api/manifest` gateway object in `dashboard/core/manifest.js`
- `dashboard.tmpl.html` has new row IDs (`di-device-name`, `di-firmware-version`, `di-flash`, `di-sram`)
- `firmware/esp32-c3-multi-sensor.yaml` has `text_sensor` entities for Flash and SRAM
- `firmware/esp32-s3-multi-sensor.yaml` has sensor entities for PSRAM total and free
- C3 PSRAM field shows `"None"` (no PSRAM hardware)
- `di-psram-total` and `di-psram-free` in `DEVICE_INFO_MAP`
- MAC address row is **removed** from device card (not just hidden)
- `scripts/preflight.sh` has presence checks for new IDs
- Four-command rebuild pipeline was run: `bundle-dashboard.sh --write` → `build-dashboard.sh` → `generate-header.sh` → `preflight.sh`
- No direct edits to `dashboard/dashboard.js` or `dashboard/dashboard.html` (Rule 47)
- `dashboard.tmpl.html` edited as source file (Rule 48)
- No Rule 58 violation
- All existing Playwright tests pass; no regression in env/ping/system card rendering

**Turn 3 — Verdict + output**

Post findings as a PR comment on PR #<PR_NUMBER> using the standard Turn 3 format.

**Fix prompt (if NEEDS-FIX or BLOCKED)**
Generate a downloadable fix prompt in markdown that:
- Addresses ONLY the remaining failing/unclear gates
- Includes a Do-NOT list covering already-passing gates to prevent regressions
- Uses `prompts/phaseV/v7.6.9.0-agent-prompt-gpt-codex.md` as style reference

**Post-merge deliverables when MERGE-READY:**
- Create `prompts/phaseV/v7.6.9.0-PR<NN>-consolidated-audit-and-lessons.md`
- Review and update `prompts/handoff/phaseV/session-handoff-v7.6.9.1.md`
- Review and update `prompts/phaseV/v7.6.9.1-agent-prompt-gpt-codex.md`
- Close issues #143 (version badge shipped in v7.6.7.2), #144, #136, #138 with PR references
- Apply version tag `v7.6.9.0`

---

# v7.6.9.1 — Satellite Hostname/IP in Gateway Card + CSV Role Column

## Inline review context

```
Step: V3-B + V3-C
Objective: Emit hostname + ip fields in /api/aggregator/gateways firmware response;
           update gateway panel JS to display them; add role column at CSV export position 3
           and satellite prefix in merged aggregator export.
Allowed diff scope:
  firmware/core/web-handler.h             — handle_aggregator_gateways_() hostname/ip extraction
  dashboard/components/gateway-panel/index.js — renderAllGatewaysSummary(), renderGatewaySelector(),
                                                 renderSettingsPanel() updates
  dashboard/core/sensor-defs.js           — EXPORT_SHARED_COLUMNS + getExportRole()
  dashboard/core/history.js               — buildSingleSensorCsv() + buildMergedSensorCsv()
  Generated artifacts: dashboard/dashboard.js · dashboard/dashboard.html · dashboard/dashboard.h
  Docs/changelog.md · version artifact · session log
⛔ Out of scope: firmware/core other fragment changes · sensor_history_multi.h (Rule 58) ·
                direct generated artifact edits (Rule 47)
Critical rules: Rule 47 · Rule 48 · Rule 58
Blocking gates: hostname extracted from global JSON search (must be scoped to gateway:{} object only) ·
                role column not at position 3 · Rule 47 violation
Evidence needed: curl gateways response showing hostname + ip fields · dashboard gateway card render ·
                 single-sensor CSV with role column · aggregator merged CSV with sat_slug prefix · Playwright pass
```

## Review prompt — v7.6.9.1

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Read `prompts/handoff/phaseV/Perplexity-Session-Context-Protocol-Three-Turn.md` first.
Use the Shared Perplexity Review Session Protocol from that file throughout this session.

**Turn 1 reads (do not open more than these):**
- `prompts/handoff/phaseV/session-handoff-v7.6.9.1.md`
- `prompts/phaseV/v7.6.9.1-agent-prompt-gpt-codex.md`

**Turn 2 diff + evidence fetch:**
- PR diff for `web-handler.h`, `gateway-panel/index.js`, `sensor-defs.js`, `history.js`, generated artifacts, changelog, version/session log
- Agent compliance table, curl gateways JSON, CSV export samples from PR description or comments

**Review gates to decide explicitly:**
- `handle_aggregator_gateways_()` extracts `hostname` from within the `"gateway":{...}` object **only** — not a global JSON search (prevents false matches on sensor names)
- `handle_aggregator_gateways_()` extracts `ip` from `sat.base_url` by stripping `http://` prefix
- Gateways JSON response includes `"hostname":"..."` and `"ip":"..."` fields
- `renderAllGatewaysSummary()` uses `gw.hostname || gw.name` as display name
- `renderGatewaySelector()` uses `hostname || name` as tab label
- `renderSettingsPanel()` shows hostname and IP in satellite settings cards
- `EXPORT_SHARED_COLUMNS` in `sensor-defs.js` is `['timestamp', 'sensor_id', 'role', 'metric_key', 'value', 'unit']` — role at **position 3** (index 2)
- `getExportRole()` function exists in `sensor-defs.js`
- `buildMergedSensorCsv()` applies `sensorSlug(satellite_name) + '_'` prefix to satellite columns
- Breaking change (CSV format) is documented in changelog and PR description
- Playwright tests cover both single and merged export formats
- Four-command rebuild pipeline was run; no direct edits to generated artifacts (Rule 47/48)
- `assemble-sensor-history.sh --write` run after any firmware fragment edits; preflight passes

**Turn 3 — Verdict + output**

Post findings as a PR comment on PR #<PR_NUMBER> using the standard Turn 3 format.

**Fix prompt (if NEEDS-FIX or BLOCKED)**
Generate a downloadable fix prompt in markdown that:
- Addresses ONLY the remaining failing/unclear gates
- Includes a Do-NOT list covering already-passing gates to prevent regressions
- Uses `prompts/phaseV/v7.6.9.1-agent-prompt-gpt-codex.md` as style reference

**Post-merge deliverables when MERGE-READY:**
- Create `prompts/phaseV/v7.6.9.1-PR<NN>-consolidated-audit-and-lessons.md`
- Review and update `prompts/handoff/phaseV/session-handoff-v7.6.9.2.md`
- Review and update `prompts/phaseV/v7.6.9.2-agent-prompt-gpt-codex.md`
- Close issues #170 and #166 (partial) with PR reference
- Apply version tag `v7.6.9.1`

---

# v7.6.9.2 — Manifest-Driven Export + AGG-ADR Commit

## Inline review context

```
Step: V3-D + V3-E
Gate: V1-D (import crash fix, v7.6.7.1) must be stable in production before this step.
Objective: Replace hardcoded EXPORT_SENSOR_SUFFIXES with getMetricColumnsForSensor() (manifest-driven);
           populate ping and system metrics in exports (currently blank); commit AGG-ADR-001; close #162.
Allowed diff scope:
  dashboard/core/history.js     — fetchSensorHistoryRows() iteration over manifest metrics
  dashboard/core/sensor-defs.js — replace EXPORT_SENSOR_SUFFIXES with getMetricColumnsForSensor()
  Docs/decisions/AGG-ADR-001-satellite-history-storage.md (new file — committed as-is)
  Generated artifacts: dashboard/dashboard.js · dashboard/dashboard.html · dashboard/dashboard.h
  Docs/changelog.md · version artifact · session log
⛔ Out of scope: firmware changes · sensor_history_multi.h · direct generated artifact edits (Rule 47/48)
Critical rules: Rule 47 · Rule 48
Blocking gates: EXPORT_SENSOR_SUFFIXES still present (not replaced) · AGG-ADR-001 content modified
Evidence needed: ping CSV export with ping_ms + success_pct columns populated (not blank) ·
                 system CSV with cpu_pct/ram_pct/disk_pct populated · env export unchanged ·
                 fallback ['temp','hum'] when manifest unavailable · Playwright pass
```

## Review prompt — v7.6.9.2

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Read `prompts/handoff/phaseV/Perplexity-Session-Context-Protocol-Three-Turn.md` first.
Use the Shared Perplexity Review Session Protocol from that file throughout this session.

**Turn 1 reads (do not open more than these):**
- `prompts/handoff/phaseV/session-handoff-v7.6.9.2.md`
- `prompts/phaseV/v7.6.9.2-agent-prompt-gpt-codex.md`

**Turn 2 diff + evidence fetch:**
- PR diff for `history.js`, `sensor-defs.js`, `AGG-ADR-001-satellite-history-storage.md`, generated artifacts, changelog, version/session log
- Agent compliance table, CSV export samples (ping, system, env) from PR description or comments

**Review gates to decide explicitly:**
- `EXPORT_SENSOR_SUFFIXES` static array is **removed** — replaced by `getMetricColumnsForSensor()` (V3-D)
- `getMetricColumnsForSensor()` iterates over `manifest.sensors[].measurements[]` where `history === true` (V3-D)
- Fallback `return ['temp', 'hum']` present for when manifest is unavailable (backward compatibility) (V3-D)
- `fetchSensorHistoryRows()` uses the new function — not hardcoded `key === 'temp' || key === 'hum'` (V3-D)
- Ping export CSV has `wan_ping_ping_ms` and `wan_ping_success_pct` columns **populated** (not blank) (V3-D)
- System export CSV has `nas01_cpu_pct`, `nas01_ram_pct`, `nas01_disk_pct` populated (V3-D)
- Environmental sensor export is unchanged and backward compatible (V3-D)
- `Docs/decisions/AGG-ADR-001-satellite-history-storage.md` exists at correct path (V3-E)
- AGG-ADR-001 content committed as-is — not rewritten (V3-E)
- Four-command rebuild pipeline was run; no direct edits to generated artifacts (Rule 47/48)
- Playwright tests cover ping and system export formats
- Issue #162 closed with PR reference (V3-E)
- Issue #161 closed with reference to V1-A PR (V3-E)

**Turn 3 — Verdict + output**

Post findings as a PR comment on PR #<PR_NUMBER> using the standard Turn 3 format.

**Fix prompt (if NEEDS-FIX or BLOCKED)**
Generate a downloadable fix prompt in markdown that:
- Addresses ONLY the remaining failing/unclear gates
- Includes a Do-NOT list covering already-passing gates to prevent regressions
- Uses `prompts/phaseV/v7.6.9.2-agent-prompt-gpt-codex.md` as style reference

**Post-merge deliverables when MERGE-READY:**
- Create `prompts/phaseV/v7.6.9.2-PR<NN>-consolidated-audit-and-lessons.md`
- Review and update `prompts/handoff/phaseV/session-handoff-v7.6.9.3.md`
- Review and update `prompts/phaseV/v7.6.9.3-agent-prompt-gpt-codex.md`
- Apply version tag `v7.6.9.2`
- Confirm post-V2 `free_heap_internal` at boot on C3: if < 65 KB → V3-F is triggered; if ≥ 65 KB → V3-F is skipped and closed with no-change note

---

# v7.6.9.3 — Struct Padding Audit (Conditional — V3-F)

## Inline review context

```
Step: V3-F (CONDITIONAL — execute only if post-V2 free_heap_internal at boot on C3 < 65 KB)
Objective: If gate triggered: audit SensorEntity struct for unused MetricState slots and temp string
           fields on non-env devices; implement if gain ≥ 300 B and NVS serialisation is unaffected.
           If gate NOT triggered: PR contains ONLY measurement documentation + issue #165 comment.
Allowed diff scope:
  IF EXECUTED: firmware/core/data-model.h — SensorEntity struct changes
               firmware/core/ (any fragment affected by struct change)
               Docs/changelog.md · version artifact · session log
  IF NOT EXECUTED: issue #165 comment only (no file diff required)
⛔ Out of scope: NVS format changes · partition table changes (Phase 7) · fragment boundary changes (Rule 62)
Critical rules: Rule 58 (no monolith direct edit) · Rule 62 (no fragment boundary changes)
HARD RULES: struct change MUST NOT affect NVS-persisted field offsets · gain < 300B → no code change
Blocking gates (if executed): NVS serialisation compatibility not verified · struct layout change with gain < 300B
Evidence needed: post-V2 heap measurement confirming < 65KB (to trigger) or ≥ 65KB (to skip) ·
                 if executed: gain calculation · NVS compatibility verification evidence
```

## Review prompt — v7.6.9.3

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Read `prompts/handoff/phaseV/Perplexity-Session-Context-Protocol-Three-Turn.md` first.
Use the Shared Perplexity Review Session Protocol from that file throughout this session.

**Turn 1 reads (do not open more than these):**
- `prompts/handoff/phaseV/session-handoff-v7.6.9.3.md`
- `prompts/phaseV/v7.6.9.3-agent-prompt-gpt-codex.md`

**Turn 2 diff + evidence fetch:**
- PR diff (should contain either struct changes + evidence, OR effectively no code diff with only a comment/issue reference)
- Post-V2 heap measurement result from PR description; if executed: gain calculation and NVS compatibility evidence

**Review gates to decide explicitly:**
- Post-V2 `free_heap_internal` measurement at boot on C3 is documented in PR description
- **If heap ≥ 65 KB (gate NOT triggered):** PR contains NO code changes; issue #165 has a comment documenting the measured heap and confirming V3-F skipped; verdict can be MERGE-READY immediately
- **If heap < 65 KB (gate triggered):** struct changes are present in `data-model.h`
  - Calculated SRAM gain is ≥ 300 B (if < 300 B → no code change required)
  - No NVS-persisted field offsets are changed (NVS compatibility explicitly verified)
  - Fragment boundary is unchanged (Rule 62)
  - No direct edit to `sensor_history_multi.h` (Rule 58)
  - `assemble-sensor-history.sh --write` was run; preflight passes
  - Measurement result documented in issue #165
- No partition table changes (deferred to Phase 7)

**Turn 3 — Verdict + output**

Post findings as a PR comment on PR #<PR_NUMBER> using the standard Turn 3 format.

**Fix prompt (if NEEDS-FIX or BLOCKED)**
Generate a downloadable fix prompt in markdown that:
- Addresses ONLY the remaining failing/unclear gates
- Includes a Do-NOT list covering already-passing gates to prevent regressions
- Uses `prompts/phaseV/v7.6.9.3-agent-prompt-gpt-codex.md` as style reference

**Post-merge deliverables when MERGE-READY:**
- Create `prompts/phaseV/v7.6.9.3-PR<NN>-consolidated-audit-and-lessons.md`
- Create `prompts/handoff/phaseV-results.md` (Phase V completion handoff to Phase 7)
- Apply version tag `v7.6.9.3`
- Confirm all Phase V issues (#161, #162, #163, #164, #165, #166, #170, #171, #136, #137, #138, #139, #143, #144) have been closed or explicitly deferred with notes
- Confirm `Docs/v7.7-implementation-plan.md` and `Docs/v7.7-v7.8-persistence-architecture.md` are the correct starting documents for Phase 7 planning

---

## Token budget reference

The table below estimates context usage per step for these Perplexity review prompts versus the original Claude two-step Step 2 sessions.

| Step | Claude Review (est.) | Perplexity Review (est.) | Primary saving |
|------|---------------------|--------------------------|----------------|
| v7.6.7.0 | ~45,000 | ~5,500 | Inline context replaces full file reads; diff-only audit |
| v7.6.7.1 | ~50,000 | ~6,000 | Deferred fragment read; evidence-first gates |
| v7.6.7.2 | ~40,000 | ~5,000 | Grep evidence in PR replaces shell execution |
| v7.6.8.0 | ~55,000 | ~7,000 | Five-handler audit from diff only; no full web-handler read |
| v7.6.8.1 | ~45,000 | ~5,500 | ADR committed as-is; diff-scoped audit |
| v7.6.8.2 | ~50,000 | ~6,000 | Measurement table in PR replaces interactive shell |
| v7.6.9.0 | ~55,000 | ~7,000 | Dashboard audit from diff; no full tmpl.html read |
| v7.6.9.1 | ~50,000 | ~6,500 | Firmware + JS audit from targeted diff sections |
| v7.6.9.2 | ~45,000 | ~5,500 | ADR committed as-is; export audit from diff |
| v7.6.9.3 | ~35,000 | ~3,500 | Conditional no-code path is near-zero context |
| **Total** | **~470,000** | **~57,500** | **−88%** |

Savings come from: (1) inline context headers replacing handoff re-reads on every gate check, (2) diff-first audit replacing source file traversal, (3) evidence artifacts in PR description replacing interactive output capture, (4) table-first Turn 3 output replacing prose review narratives.

Quality is preserved because: all acceptance criteria from the implementation plan are represented as explicit gates, blocking rules are front-loaded in the inline context header, and the three-turn structure prevents premature verdicts before the spec contract is extracted.

---

_End of Phase V Perplexity-optimized PR review prompts._
