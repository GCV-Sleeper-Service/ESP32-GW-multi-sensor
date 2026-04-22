# Phase V Issue Sweep Results

_Sweep date: 2026-04-22_
_Swept at commit: 43c18dba92ac30799e3796fa9c197d128a06a651_
_VERSION at sweep: 7.6.9.5_
_Sweeper: GitHub Copilot Coding Agent_

---

## Summary

| Classification | Count | Issues |
|---|---|---|
| FIXED_FULLY | 0 | — |
| FIXED_PARTIALLY | 3 | #139, #166, #171 |
| NOT_ADDRESSED | 0 | — |
| SUPERSEDED | 0 | — |
| DEFERRED_INTENTIONAL | 1 | #137 |
| OUT_OF_SCOPE | 2 | #190, #196 |
| STALE | 0 | — |
| **Total open at sweep** | **6** | |

**Recommended closures this session:** 0 issues
**Recommended keep-open with updated comment:** 6 issues (all open issues)
**Flagged for phaseV-closure-analysis review (anything not cleanly classifiable):** 0 issues

---

## Per-Issue Results

### #137 — Feature: Board-type SVG diagrams for documentation and device-info card

**Classification:** DEFERRED_INTENTIONAL

**Planned in:** Plan Part 0 table — milestone `Deferred (Phase 7+)`. No sub-phase assignment; explicitly out of Phase V scope.
**Actually touched by:** None
**Changelog references:** None

**Analysis:**
The plan normalised this issue's title to `Feature: Board-type SVG diagrams for documentation and device-info card` with labels `feature`, `dashboard` and milestone `Deferred (Phase 7+)` (plan line 42). This is a design task requiring an SVG editor or board-datasheet-derived artwork for WROOM-32D and S3-DevKitC1-N16R8 boards; it has no firmware or JS dependency and cannot block Phase V. The owner's comment on 2026-04-17 confirms deferral explicitly: "no Phase V scope, will be addressed post-Phase 8 or as a standalone documentation task." No Phase V PR references this issue.

**Recommended GitHub action:**
- [ ] Keep open with comment below
- [ ] Keep open, update labels: add `feature`, `dashboard`
- [ ] Keep open, update milestone: `Deferred (Phase 7+)`

**Recommended comment (copy-paste ready):**
```
Deferred from Phase V per plan (`Docs/phase-V-implementation-plan.md`, Part 0 table, line 42).

Reason: design task with no firmware or JS dependencies; does not block Phase V delivery; SVG production requires an SVG editor or board-datasheet workflow.

Target phase: Phase 7+ (standalone documentation task, no dependency on v7.7.x architecture).

Will be addressed in: whenever documentation bandwidth is available post-Phase 7 planning.

Leaving open.
```

---

### #139 — History loading serialization for C3 boards

**Classification:** FIXED_PARTIALLY

**Planned in:** Plan Part 0 table — milestone `Partial v7.6.8.x (auth cap), partial v7.6.9.4 (adaptive cap + boot sequencing), full fix Phase 7` (plan line 44). Sub-phase V2-E (v7.6.8.1 safety net) and V4 (v7.6.9.4 addendum).
**Actually touched by:** PR #181 (v7.6.8.1), PR #193 (v7.6.9.4), PR #194 (v7.6.9.4 post-merge correction doc)
**Changelog references:** v7.6.8.1 (`std::min(..., (size_t)60000)` cap on `csv.reserve()`), v7.6.9.4 (`clamp(esp_get_free_heap_size()/3, 12000, 60000)` adaptive cap, #139 partial ×2)

**Analysis:**
Phase V delivered two successive mitigations. PR #181 (v7.6.8.1, V2-E) added a fixed 60 KB pre-allocation cap — adequate for the C3's ~68 KB free heap but sized before the WROOM crash case was discovered. PR #193 (v7.6.9.4) replaced the fixed cap with a heap-adaptive formula (`clamp(free_heap/3, 12000, 60000)`) and gated the dashboard's initial `loadHistory()` call on the first successful `loadStatusSnapshot()` with a 15 s fallback.

Post-merge, PR #194 documented BUG-082: `csv.reserve()` is only an allocation hint; the NVS scan loop appends without a hard truncation limit, so WROOM boards with ≥ 500 NVS segments (~40 KB CSV vs ~34 KB free heap) still crash via reallocation spike. The addendum (`Docs/phase-V-implementation-plan-addendum-v7.6.9.4.md`) and BUG-082 both confirm the full fix — chunked HTTP streaming — is deferred to Phase 7.

The owner's issue comment (2026-04-17) pre-dates v7.6.9.4 and incorrectly describes the issue state; the changelog and PR record are authoritative.

**Recommended GitHub action:**
- [ ] Keep open with comment below
- [ ] Keep open, update labels: add `bug`, `memory`, `esp32-c3`
- [ ] Keep open, update milestone: `Phase 7 (v7.7.x)` (Phase V partial mitigations complete)

**Recommended comment (copy-paste ready):**
```
Partial fix landed in Phase V V2-E (v7.6.8.1, PR #181) and Phase V V4 (v7.6.9.4, PR #193).

What was addressed:
- v7.6.8.1: added fixed 60 KB `csv.reserve()` cap to bound heap spike on large history responses.
- v7.6.9.4: replaced the fixed cap with a heap-adaptive formula (`clamp(esp_get_free_heap_size()/3, 12000, 60000)`) at both `handle_history_()` and `handle_api_v2_history_()` call sites.
- v7.6.9.4: gated initial dashboard `loadHistory()` on first `loadStatusSnapshot()` resolution, with a 15 s fallback timer (boot.js).

What remains:
- [ ] Server-side time-windowed chunked history response protocol (Phase 7 — requires response framing changes; `reserve()` hint does not prevent unbounded append growth past the cap — BUG-082)
- [ ] Dashboard paged history loader (Phase 7 — client stays with single full-CSV fetch per sensor in Phase V)
- [ ] Per-device NVS storage (Phase 7 — architectural rewrite v7.7.0.x)

Known limitation as of v7.6.9.4 (BUG-082, documented 2026-04-18): WROOM boards with ≥ 500 NVS segments (~40 KB CSV vs ~34 KB free heap) can still crash via reallocation past the reserved capacity. Raw NVS backup extracted 2026-04-18 via `esptool read_flash 0x370000 0x80000`. The Phase 7 chunked-streaming transport eliminates single-response CSV building entirely, making the truncation guard unnecessary.

Target for full fix: Phase 7 (v7.7.x).

Leaving open.
```

---

### #166 — Fix data export format from boards

**Classification:** FIXED_PARTIALLY

**Planned in:** Plan Part 0 table — title normalised to `Enhancement: CSV export — role column, satellite prefix, manifest-driven metrics`, labels `enhancement`, `dashboard`, milestone `v7.6.9.x` (plan line 52). Sub-phases V3-B/C (v7.6.9.1) and V3-D/E (v7.6.9.2).
**Actually touched by:** PR #184 (v7.6.9.1), PR #191 (v7.6.9.2)
**Changelog references:** v7.6.9.1 (`role` column at position 3, satellite-prefixed merged export columns, `getExportRole()` helper, #166 ×2); v7.6.9.2 (`getMetricColumnsForSensor()` manifest-driven column builder, manifest-driven `fetchSensorHistoryRows()`, single/merged CSV builders, #166 ×3)

**Analysis:**
All three Phase V deliverables for this issue shipped. PR #184 (v7.6.9.1) added the `role` column at position 3, the `{sat_slug}_{sensor_id}_{metric_key}` satellite prefix for aggregator merged exports, and the `getExportRole()` helper — as confirmed by the first issue comment (2026-04-17, referencing commit `d1db94c`). PR #191 (v7.6.9.2) replaced the static `EXPORT_SENSOR_SUFFIXES` array with `getMetricColumnsForSensor()` and made `fetchSensorHistoryRows()` manifest-driven for all metric types including ping and system. The second owner comment (2026-04-17) incorrectly states "no Phase V work was scoped to implement this" and lists the role column fix as unimplemented — this contradicts the first comment and the changelog; the PR record is authoritative. Remaining open items are Phase 7 scope: per-device CSV format with `# device_id:` / `# metrics:` comment headers (v7.7.2.0) and multi-device bundle export (v7.7.2.2).

**Recommended GitHub action:**
- [ ] Keep open with comment below
- [ ] Keep open, update labels: add `enhancement`, `dashboard`
- [ ] Keep open, update milestone: `Phase 7 (v7.7.x)`

**Recommended comment (copy-paste ready):**
```
Partial fix landed in Phase V V3-B/C (v7.6.9.1, PR #184) and Phase V V3-D/E (v7.6.9.2, PR #191).

What was addressed:
- v7.6.9.1 (PR #184): `role` column added at CSV position 3; `getExportRole()` helper returns `satellite`, `aggregator`, or `standalone`; satellite sensor columns in merged aggregator exports now use the `{sat_slug}_{sensor_id}_{metric_key}` prefix format.
- v7.6.9.2 (PR #191): static `EXPORT_SENSOR_SUFFIXES` array replaced with manifest-driven `getMetricColumnsForSensor()`; `fetchSensorHistoryRows()` now iterates all manifest metrics with `history: true` instead of hardcoding `temp`/`hum`; ping and system metrics now appear with populated columns in exports.

What remains:
- [ ] Per-device CSV export with `# device_id:` / `# metrics:` comment headers (Phase 7 v7.7.2.0)
- [ ] Multi-device bundle export with per-device section separators (Phase 7 v7.7.2.2)

Target for full fix: Phase 7 (v7.7.x).

Leaving open.
```

---

### #171 — Data export logic

**Classification:** FIXED_PARTIALLY

**Planned in:** Plan Part 0 table — title normalised to `Bug: Import POST endpoints crash ESP32-C3 (Rule 40 violation); export is client-side only`, labels `bug`, `esp32-c3`, milestone `v7.6.7.x (crash fix), v7.6.9.x (manifest-driven export)` (plan line 54). Sub-phases V1-D (v7.6.7.1) and V3-D (v7.6.9.2).
**Actually touched by:** PR #177 (v7.6.7.1), PR #191 (v7.6.9.2)
**Changelog references:** v7.6.7.1 (`handle_import_begin_()` deferred to `xTaskCreate` — Rule 40 compliance; `/api/import/status` endpoint; 409 readiness gate on data endpoints); v7.6.9.2 (`fetchSensorHistoryRows()` manifest-driven, #166 #171)

**Analysis:**
Phase V delivered both planned sub-scope items. PR #177 (v7.6.7.1, V1-D) moved `build_import_epoch_map_()` off the httpd task to an `xTaskCreate` worker (`imp_epoch`, 8192 B stack), fixing the Rule 40 crash on C3. It also added the `/api/import/status` readiness endpoint and a 409 gate on data endpoints until import prep completes. PR #191 (v7.6.9.2, V3-D) made `fetchSensorHistoryRows()` manifest-driven for all metric types, addressing gap 3 (non-environmental metrics in export).

The owner's issue comment (2026-04-17, posted at v7.6.9.3 closure) incorrectly states the import crash fix is "tracked for v7.6.7.x or equivalent standalone PR" and "no Phase V work was scoped." The timeline (v7.6.7.1 merged 2026-04-14, comment written 2026-04-17) indicates this is an oversight; the PR record is authoritative.

Remaining open items are Phase 7 scope: per-device export, per-device import v2, and multi-device bundle.

**Recommended GitHub action:**
- [ ] Keep open with comment below
- [ ] Keep open, update labels: add `bug`, `esp32-c3`
- [ ] Keep open, update milestone: `Phase 7 (v7.7.x)`

**Recommended comment (copy-paste ready):**
```
Partial fix landed in Phase V V1-D (v7.6.7.1, PR #177) and Phase V V3-D/E (v7.6.9.2, PR #191).

What was addressed:
- v7.6.7.1 (PR #177): `handle_import_begin_()` now defers `build_import_epoch_map_()` to `xTaskCreate` (worker `imp_epoch`, 8192 B stack) — Rule 40 compliant. Import POST endpoints no longer crash the C3. `/api/import/status` endpoint added for readiness polling; 409 gate on `/api/import/d/` and `/api/import/w/` until prep completes.
- v7.6.9.2 (PR #191): `fetchSensorHistoryRows()` is now manifest-driven for all metric types (ping, system, environmental) — gap 3 (non-env sensors in export) resolved.

What remains:
- [ ] Per-device CSV export with `# device_id:` / `# metrics:` comment headers (Phase 7 v7.7.2.0)
- [ ] Per-device CSV import v2 (Phase 7 v7.7.2.1)
- [ ] Multi-device bundle export (Phase 7 v7.7.2.2)

Target for full fix: Phase 7 (v7.7.x).

Leaving open.
```

---

## Issues Not in Phase V Plan's Part 0 Table

Issues opened after plan finalisation but still open at sweep time.

---

### #190 — Feature/Optimization: move Framework, ESPHome and MAC address entries output into Eventlog on dashboard

**Classification:** OUT_OF_SCOPE

**Planned in:** Post-plan issue — opened 2026-04-17, after plan finalisation (plan finalised 2026-04-12). Not in Part 0 table.
**Actually touched by:** None
**Changelog references:** None

**Analysis:**
This issue requests moving the Framework (ESP-IDF version), ESPHome version, and MAC address rows from the gateway card into the Event log section, on the rationale that these values change infrequently. Phase V V3-A (v7.6.9.0, PR #183) did address the gateway/device card — removing the MAC row and adding Device Name and Firmware rows — but did not address the Framework/ESPHome relocation specifically. The issue was opened on 2026-04-17 (during the v7.6.9.x mitigation window), has no labels, no milestone, and carries no urgency signal in its body. This is a UX enhancement with no firmware dependency, appropriate for Phase VX (v7.6.10.x) or Phase 7 dashboard work. No label or milestone is currently set.

**Recommended GitHub action:**
- [ ] Keep open with comment below
- [ ] Keep open, update labels: add `enhancement`, `dashboard`
- [ ] Keep open, update milestone: `Phase VX (v7.6.10.x)`

**Recommended comment (copy-paste ready):**
```
Outside Phase V scope — opened during the Phase V mitigation window (2026-04-17) after the plan was finalised.

Phase V V3-A (v7.6.9.0, PR #183) addressed gateway card layout (Device Name and Firmware rows added, MAC row removed) but did not scope the Framework/ESPHome/MAC-to-Eventlog relocation.

This is a dashboard-only UX enhancement with no firmware dependency. Queuing for Phase VX (v7.6.10.x).

Leaving open.
```

---

### #196 — Enhancement: Unified dashboard authentication — eliminate mid-session browser auth dialogs

**Classification:** OUT_OF_SCOPE

**Planned in:** Post-plan issue — opened 2026-04-22T03:43:27Z (day of sweep, ~15 minutes before sweep began). Not in Part 0 table. Owner assigned milestone `Phase VX (v7.6.10.x)` at creation.
**Actually touched by:** None
**Changelog references:** None

**Analysis:**
This issue was opened on the morning of the sweep date (2026-04-22) and explicitly milestoned `Phase VX (v7.6.10.x)` by the owner at creation. It describes a dashboard-side application-level credential manager (`authFetch()`, session-scoped `_authHeader`, custom re-auth dialog) to eliminate mid-session browser native auth dialogs caused by the v7.6.8.0 SEC-ADR endpoint split. The root cause (browser cached Basic Auth expiry on auth-gated `/api/status/full`, `/api/gateways`, history endpoints) is a known consequence of Phase V V2-A/V2-E security work. The issue provides a detailed design with acceptance criteria and file list; it is real and actionable, but its opening time and explicit milestone assignment place it entirely outside Phase V scope.

**Recommended GitHub action:**
- [ ] Keep open with comment below (milestone already correct; labels should be confirmed)
- [ ] Keep open, update labels: verify `enhancement`, `dashboard`, `ux`, `security` are set (issue shows these labels — already correct)

**Recommended comment (copy-paste ready):**
```
Outside Phase V scope — opened on the Phase V sweep date (2026-04-22) and milestoned Phase VX (v7.6.10.x) at creation.

Phase V (v7.6.8.0 V2-A through v7.6.9.5 V5) deliberately moved sensitive fields behind auth-gated endpoints per SEC-ADR-001 RV-03. The mid-session browser dialog issue is a documented consequence of that decision, not a Phase V defect. Phase V's auth posture is correct and intentional.

This enhancement — application-level credential management to eliminate browser-native auth dialogs — is the appropriate Phase VX follow-on. The design in the issue body (authFetch(), session-scoped _authHeader, custom re-auth dialog, 401-during-operation recovery) is well-specified and ready for Phase VX scoping.

Leaving open.
```

---

## Post-Sweep Actions

Actions for the operator to execute AFTER reviewing this document:

**Execution status as of 2026-04-22:**
- Actions 1 and 2 require **manual execution by the repository owner** — the Copilot agent token is scoped to `contents:write` only; the GitHub Issues API endpoints for labels, milestones, and comments return HTTP 403 for this token.
- Actions 3, 4, and 5 are ✅ complete (automated in this session).

---

### Action 1 — Apply label/milestone updates ⚠️ MANUAL

The following labels do not yet exist in the repo — create them first:

```bash
gh label create "feature"      --color "#a2eeef" --description "New feature request"
gh label create "memory"       --color "#e4e669" --description "Heap / SRAM related"
gh label create "esp32-c3"     --color "#c2e0c6" --description "ESP32-C3 specific"
gh label create "optimization" --color "#f9d0c4" --description "Performance / size reduction"
```

Then apply labels and milestones:

```bash
# #137 — DEFERRED_INTENTIONAL
gh issue edit 137 --add-label "feature,dashboard" --milestone "Phase 7 (v7.7.x)"

# #139 — FIXED_PARTIALLY
gh issue edit 139 --add-label "bug,memory,esp32-c3" --milestone "Phase 7 (v7.7.x)"

# #166 — FIXED_PARTIALLY
gh issue edit 166 --add-label "enhancement,dashboard" --milestone "Phase 7 (v7.7.x)"

# #171 — FIXED_PARTIALLY
gh issue edit 171 --add-label "bug,esp32-c3" --milestone "Phase 7 (v7.7.x)"

# #190 — OUT_OF_SCOPE
gh issue edit 190 --add-label "enhancement,dashboard" --milestone "Phase VX (v7.6.10.x)"

# #196 — labels already set; milestone already set — no action needed
```

---

### Action 2 — Post keep-open comments ⚠️ MANUAL

Post the exact comment text from each per-issue "Recommended comment" section above to the corresponding GitHub issue. Copy the text verbatim — do not paraphrase.

```bash
# Example (write comment text to temp files then post):
gh issue comment 137 --body-file /tmp/comment_137.md
gh issue comment 139 --body-file /tmp/comment_139.md
gh issue comment 166 --body-file /tmp/comment_166.md
gh issue comment 171 --body-file /tmp/comment_171.md
gh issue comment 190 --body-file /tmp/comment_190.md
gh issue comment 196 --body-file /tmp/comment_196.md
```

---

### Action 3 — Q5 input for phaseV-closure-analysis-prompt.md ✅ COMPLETE

Captured in this document (per-issue sections above):
- **#139 FIXED_PARTIALLY:** server-side chunked/windowed history response protocol; dashboard paged loader; per-device NVS storage; hard truncation limit in NVS scan loop (BUG-082).
- **#166 FIXED_PARTIALLY:** per-device CSV export with `# device_id:` / `# metrics:` headers (v7.7.2.0); multi-device bundle export (v7.7.2.2).
- **#171 FIXED_PARTIALLY:** per-device CSV export (v7.7.2.0); per-device CSV import v2 (v7.7.2.1); multi-device bundle export (v7.7.2.2).
- **#137 DEFERRED_INTENTIONAL:** SVG board diagrams for WROOM-32D and S3-DevKitC1-N16R8 (documentation task, no code dependency).
- **#190 OUT_OF_SCOPE:** Framework/ESPHome/MAC relocation to Eventlog (Phase VX).
- **#196 OUT_OF_SCOPE:** Unified dashboard authentication / authFetch() pattern (Phase VX v7.6.10.x).

---

### Action 4 — phaseV-results.md issues and delivery record ✅ COMPLETE

`prompts/handoff/phaseV/phaseV-results.md` rebuilt in this session:
- Delivery Record tables (V1/V2/V3): all `#___` placeholders filled in with actual PR numbers (#176–#195), Status set to Complete for all rows, Fix Cycles and Key Outcome filled in from audit files.
- Operator measurement results filled in from v7.6.8.2 audit.
- Issues Resolved table: rebuilt with Status, Classification, and Notes columns; all 13 issues covered.
- Deferred table: rebuilt with Classification and Rationale columns; all 6 open issues covered.

---

### Action 5 — Note re: erroneous owner comments ✅ COMPLETE (documented)

The owner's comments posted at v7.6.9.3 closure (2026-04-17T16:34:58Z on #166; 2026-04-17T16:35:05Z on #171) incorrectly state "no Phase V work was scoped to implement this." The changelog and PR record show otherwise. The recommended keep-open comments (Action 2 above) supersede those earlier comments and provide the accurate record.

---

## Sweep Quality Self-Check

- [x] Every open issue on GitHub at sweep time is covered in the per-issue section (6 issues: #137, #139, #166, #171, #190, #196)
- [x] No issue is classified FIXED_FULLY — none received FIXED_FULLY, so the no-PR-without-FIXED_FULLY rule is not triggered
- [x] No issue is classified FIXED_PARTIALLY without a specific tick-list of remaining work (#139: 3 items; #166: 2 items; #171: 3 items)
- [x] Every DEFERRED_INTENTIONAL classification cites a specific line of `Docs/phase-V-implementation-plan.md` (#137: line 42)
- [x] No STALE classifications — none were used
- [x] Comments are phrased matter-of-fact and technical, no hype
- [x] No comment promises a specific Phase 7 delivery date — all use "Phase 7 (v7.7.x)" as the target range
- [x] Label recommendations match the Plan Part 0 taxonomy (`bug`, `enhancement`, `feature`, `decision`, `tech-debt`, `security`, `memory`, `esp32-c3`, `dashboard`, `optimization`)
- [x] Sweep date (2026-04-22), commit SHA (43c18dba92ac30799e3796fa9c197d128a06a651), and VERSION (7.6.9.5) are recorded at the top
- [x] Known PR number discrepancy acknowledged: v7.6.9.4 primary code PR is #193; PR #194 is the post-merge correction documentation PR (BUG-082); both merged on 2026-04-18

---

_Post-sweep actions executed: 2026-04-22 by GitHub Copilot Coding Agent. Actions 3, 4, and 5 are complete. Actions 1 (labels/milestones) and 2 (keep-open comments) require manual execution by the repository owner — see Action 1 and Action 2 sections above for exact commands._

_End of Phase V Issue Sweep Results._
