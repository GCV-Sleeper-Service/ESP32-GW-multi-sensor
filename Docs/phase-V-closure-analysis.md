# Phase V Comprehensive Closure Analysis

_Generated: 2026-04-22_
_Repository: GCV-Sleeper-Service/ESP32-GW-multi-sensor_
_Phase: Phase V — v7.6.7.0–v7.6.9.5 (security hardening, dashboard enhancements, heap mitigation, and C3 stack investigation)_

---

## Q1 — Plan vs Delivery

**Overall verdict: All originally planned deliverables shipped; Phase V expanded from 3 sub-phases (V1–V3, 10 steps) to 6 sub-phases (V1–V6, 13 versions) due to mid-phase discoveries during v7.6.9.0 device testing, governed by a formally documented addendum.**

### Version coverage table

| Planned version | Sub-phase | Actual merge SHA | Merge date | PR # | Match? |
|---|---|---|---|---|---|
| v7.6.7.0 | V1-A/B/C | `004541b604e5939a55c02d67cad2442534d3f4c9` | 2026-04-14 | #176 | ✅ |
| v7.6.7.1 | V1-D | (not recorded in audit) | 2026-04-14 | #177 | ✅ |
| v7.6.7.2 | V1-E/F/G | (not recorded in audit) | 2026-04-14 | #178 | ✅ |
| v7.6.7.3 | V1-H ⚠️ unplanned | (not recorded) | 2026-04-14 | #179 | ⚠️ |
| v7.6.8.0 | V2-A/B/C/D | (not recorded in audit) | 2026-04-15 | #180 | ✅ |
| v7.6.8.1 | V2-E/F/G | (not recorded in audit) | 2026-04-15 | #181 | ✅ |
| v7.6.8.2 | V2-H/I/J | (not recorded in audit) | 2026-04-15 | #182 | ⚠️ V2-I/J blocked |
| v7.6.9.0 | V3-A | (not recorded in PR #183 audit) | 2026-04-16 | #183 | ✅ |
| v7.6.9.1 | V3-B/C | `d1db94c8de7d05c2126f33909d33b75ebcb5c869` | 2026-04-16 | #184 | ✅ |
| v7.6.9.2 | V3-D/E | `974901693e31b51f1e9519fc8027886c9b809352` | 2026-04-16 | #191 | ✅ |
| v7.6.9.3 | V3-F (conditional) | `2a775188cbdfd2c58be048bf45b1bc22df1d394b` | 2026-04-17 | #192 | ✅ |
| v7.6.9.4 | V4 (addendum) | (code PR #193 + docs PR #194) | 2026-04-17/18 | #193/#194 | ⚠️ BUG-082 |
| v7.6.9.5 | V5 (addendum) | (first attempt failed device gate) | 2026-04-20 | #195 | ✅ |
| v7.6.9.6 | V6 (addendum) | — DROPPED — | — | — | ⚠️ self-resolved |

**Deviations explained:**

- **v7.6.7.3 (unplanned):** The plan specified V1 as exactly 3 steps across v7.6.7.0–v7.6.7.2. v7.6.7.3 (PR #179, "Operational Telemetry in `/api/status`") was added between V1 and V2 because the V2-H/I/J gated optimization decisions required on-device `httpd_stack_watermark_bytes` and `ping_stack_watermark_bytes` readable via HTTP (no serial cable). Adding permanent telemetry fields was preferable to temporary instrumentation. No session log or consolidated audit exists for v7.6.7.3 — the only Phase V session log gap.

- **v7.6.8.2 V2-I/J blocked:** The plan conditioned V2-I (ping stack reduction) and V2-J (httpd stack reduction) on measurement results. V2-I measured 112 B margin (gate requires ≥ 2,048 B); V2-J measured 260 B unused on a 16,384 B stack (reducing would leave negative margin). Both correctly stayed absent from the diff. This is not a delivery failure — the gate design explicitly covered the no-reduction path.

- **v7.6.9.6 dropped:** The addendum planned v7.6.9.6 as the "actual Phase V closure step" (narrow `/api/status` un-strip + SEC-ADR RV-03 amendment). Dropped after BUG-078 in v7.6.0.1 fixed `init_response_()` HTTP status mapping (500 → 401). With the correct 401, browsers display the native auth dialog and the Cloudflare Tunnel polling issue self-resolved. v7.6.9.5 became the actual Phase V closure version.

- **v7.6.9.4 BUG-082:** Both GitHub Copilot and OpenAI Codex automated reviewers independently flagged that `csv.reserve()` is an allocation hint, not a size cap — the NVS scan loop grows the string past the reserved capacity through unbounded `.append()`. Decision: merge as-is; Phase 7 chunked streaming is the only correct fix. PR #194 (docs) recorded BUG-082 and LESSON-OPS-127.

- **PR number gap:** v7.6.9.2 is PR #191, skipping #185–#190. Those PRs cover issues, other work, or were opened and closed during Phase V execution. v7.6.9.4 uses two PRs (#193 code, #194 docs-only post-merge correction).

---

### Sub-phase deliverable tables

#### V1 — Critical Fixes (v7.6.7.0–v7.6.7.3)

Plan stated deliverables: V1-A — Proxy 502 diagnostic/timeout (issue #161); V1-B — NAS history disable, OPT-02 (~2.3 KB heap gain, issue #165); V1-C — Logger level INFO→WARN, OPT-05 (issue #165); V1-D — Import crash fix, xTaskCreate deferred task (Rule 40, issue #171); V1-E — Dashboard footer version badge (issue #143); V1-F — Dead code deletion (`stream_snapshot_series_()`, `HistoryBuffer::stream_to()`); V1-G — Import session lifetime comment.

| Step | Plan deliverable | Delivered | Status |
|---|---|---|---|
| V1-A | `fetch_to_buffer()` timeout + HTTP status; proxy 502+JSON / 200+empty-body | ✅ PR #176 round 2 (`004541b`) | ✅ |
| V1-B | NAS history disable; three `HistoryBuffer` statics deleted; ~2.3 KB heap | ✅ PR #176 | ✅ |
| V1-C | Logger WARN; wifi/api ERROR | ✅ PR #176 | ✅ |
| V1-D | `xTaskCreate` deferred task; `/api/import/status`; 409 gate | ✅ PR #177 | ✅ |
| V1-E | Dashboard footer version badge | ✅ PR #178 | ✅ |
| V1-F | Dead code removal | ✅ PR #178 | ✅ |
| V1-G | Import session lifetime comment | ✅ PR #178 | ✅ |
| V1-H (unplanned) | `min_free_heap`, `httpd_stack_watermark_bytes`, `ping_stack_watermark_bytes` in `/api/status` | ✅ PR #179 | ⚠️ unplanned |

**V1 fix cycle count:** v7.6.7.0 required 2 rounds (Round 1 commit `9d033d0`, fix commit `004541b`). v7.6.7.1, v7.6.7.2, v7.6.7.3 all had 0 fix cycles. V1 total: 2.

#### V2 — Security Hardening (v7.6.8.0–v7.6.8.2)

Plan stated deliverables: V2-A — `/api/ingest/` auth guard; V2-B — `/api/aggregator/add-satellite` auth; V2-C — aggregator topology endpoints (gateways, live, proxy) auth; V2-D — `/api/status/full` split; V2-E — `/history/` and `/api/v2/history/` auth + 60 KB heap cap; V2-F — per-URL DoS cooldown on add-satellite probe; V2-G — `SEC-ADR-001-residual-vulnerabilities.md` committed; V2-H — `CONFIG_LWIP_MAX_SOCKETS` 18→15 (gated on measurement); V2-I — ping stack reduction (gated, ≥ 2,048 B margin required); V2-J — httpd stack reduction (gated, ≥ 2,048 B margin required).

| Step | Plan deliverable | Delivered | Status |
|---|---|---|---|
| V2-A | `/api/ingest/` auth guard | ✅ PR #180 | ✅ |
| V2-B | `/api/aggregator/add-satellite` auth | ✅ PR #180 | ✅ |
| V2-C | Aggregator topology endpoints auth (gateways, live, proxy) | ✅ PR #180 | ✅ |
| V2-D | `/api/status/full` split; public `/api/status` stripped | ✅ PR #180 | ✅ |
| V2-E | History endpoints auth + 60 KB `csv.reserve()` cap | ✅ PR #181 (code); ⚠️ auth removed in v7.6.9.0 | ⚠️ |
| V2-F | Per-URL DoS cooldown (60 s, static arrays) | ✅ PR #181 | ✅ |
| V2-G | `Docs/decisions/SEC-ADR-001-residual-vulnerabilities.md` | ✅ PR #181 | ✅ |
| V2-H | `CONFIG_LWIP_MAX_SOCKETS` 18→15 | ✅ PR #182 | ✅ |
| V2-I | ping stack reduction | ⛔ BLOCKED (112 B margin < 2,048 B gate) | ⚠️ |
| V2-J | httpd stack reduction | ⛔ BLOCKED (260 B unused, negative headroom if reduced) | ⚠️ |

**V2-E history auth note:** V2-E shipped auth guards on both history handlers (v7.6.8.1). The v7.6.9.0 PR (#183) audit (FINDING-V769-04) documents that during V3-A development, the history endpoints were found to not have `authenticate_management_()` — the audit classified this as a deliberate trade-off ("read-only history is exposed publicly for operational convenience") accepted by Copilot review. `SEC-ADR-001` was not updated. The current code (post-v7.6.9.5) confirms: neither `handle_history_()` nor `handle_api_v2_history_()` appear among the 14 auth-gated handler call sites (verified by grep against `firmware/core/web-handler.h`). This is a code-vs-ADR mismatch tracked in Q2.

**V2 fix cycle count:** v7.6.8.0 required 1 CI remediation cycle (BUG-043 assertion + aggregator fixture + Firefox headless). v7.6.8.1 and v7.6.8.2: 0 fix cycles. V2 total: 1.

#### V3 — Dashboard Enhancements (v7.6.9.0–v7.6.9.3)

Plan stated deliverables: V3-A — Gateway device card cleanup (#144/#136/#138); V3-B — Satellite hostname/ip in `/api/aggregator/gateways` (#170); V3-C — CSV export role column at position 3 + satellite prefix (#166); V3-D — Manifest-driven `getMetricColumnsForSensor()` (#166); V3-E — `AGG-ADR-001-satellite-history-storage.md` (#162); V3-F — Conditional struct audit (trigger: heap < 65 KB).

| Step | Plan deliverable | Delivered | Status |
|---|---|---|---|
| V3-A | Device card: Device Name, Firmware, PSRAM, Flash/SRAM; MAC removed | ✅ PR #183 | ✅ |
| V3-B | Satellite `hostname`/`ip` in `/api/aggregator/gateways` | ✅ PR #184 | ✅ |
| V3-C | CSV `role` column at position 3; satellite slug prefix | ✅ PR #184 | ✅ |
| V3-D | `getMetricColumnsForSensor()` manifest-driven; `EXPORT_SENSOR_SUFFIXES` removed | ✅ PR #191 | ✅ |
| V3-E | `Docs/decisions/AGG-ADR-001-satellite-history-storage.md` | ✅ PR #191 | ✅ |
| V3-F | Struct audit (conditional) | ✅ No-code-change path: heap 70,952 B ≥ 65 KB gate | ✅ |

V3 fix cycles: v7.6.9.0 had 1 fix round (2 hotfixes pre-merge). v7.6.9.1 had 1 fix cycle (`bump-version.sh` failed because assembled header had not been regenerated). v7.6.9.2 and v7.6.9.3: 0 fix cycles. V3 total: 2.

#### V4 — Heap-Adaptive History Cap (v7.6.9.4)

Plan (addendum): heap-adaptive cap `clamp(free_heap/3, 12000, 60000)` at both history handlers; status-gated initial `loadHistory()` with 15 s fallback.

Delivered: ✅ both sites. Client-side: `_v7_9_4_kickHistoryOnce()` gate on first `loadStatusSnapshot()` + 15 s fallback timer.
Deviation: BUG-082 (`reserve()` does not truncate — unbounded `.append()` growth). Merged as-is per operator decision; Phase 7 chunked streaming is the full fix. Device gate explicitly skipped by operator request.
Fix cycles: 1 (PR #193 code + PR #194 post-merge docs).

#### V5 — C3 httpd Stack Override Fix (v7.6.9.5)

Plan (addendum): C3 httpd stack watermark investigation.
Delivered: BUG-083 root-caused and fixed — missing `external_components` block in `firmware/esp32-c3-multi-sensor.yaml` meant the 16 KB httpd stack override was inactive on C3 since v7.6.8.0. First PR #195 attempt failed device gate (incorrect YAML syntax); rework succeeded. All three boards now run 16 KB httpd stack; uniform watermark ~12.8 KB after stress test.
Fix cycles: 1 (rework after device gate failure).

#### V6 — Polling Telemetry Fix (v7.6.9.6)

Not delivered. Dropped because BUG-078 (v7.6.0.1) resolved the underlying browser auth dialog issue independently. The SEC-ADR RV-03 amendment originally planned for v7.6.9.6 was appended directly to `SEC-ADR-001`. Auth UX enhancement deferred to Phase VX as issue #196.

---

### Addendum fidelity

`Docs/phase-V-implementation-plan-addendum-v7.6.9.4.md` governed the final three steps of Phase V (V4, V5, V6).

**Did v7.6.9.4 stay within the addendum's narrow scope?** Mostly. The addendum explicitly excluded: chunked HTTP responses, per-device NVS storage, paged history loader, and URL schema changes — all confirmed absent from PR #193. BUG-082 was discovered by automated review, not produced by scope creep. The post-merge correction (PR #194) documented BUG-082 within the addendum (the "Post-Merge Correction" section). The `_v7_9_4_` prefix was a harmless autonomous agent namespacing decision.

**Did the v7.6.9.5 carve-out resolve as described?** Yes, and more significantly than anticipated. The addendum described "C3 httpd_stack_watermark_bytes near-overflow investigation." The actual finding (BUG-083) was that the C3 was running on a stock 4 KB httpd stack (not the expected 16 KB) because `external_components` was missing from its YAML template since v7.6.8.0. Post-fix watermark: 12,768 B on a 16 KB stack (peak ~3,460 B).

**Did v7.6.9.6 drop cleanly?** Yes. BUG-078 (pre-existing in v7.6.0.1) resolved the underlying auth mechanism issue. The `SEC-ADR-001` RV-03 update captures the post-Phase V resolution. The residual auth UX enhancement (#196) was correctly created as a new issue.

**Four line-level amendments to the implementation plan (from addendum §Changelog impact):** The v7.6.9.4 changelog confirms "Updated the Phase V implementation plan with the v7.6.9.4 carve-out, issue-table annotation, V2-E mitigation note, and version-table row." The `phaseV-results.md` milestone column for issue #139 matches the updated text the addendum specified. The amendments are confirmed applied on the basis of changelog attestation and the presence of the addendum's post-merge correction section in the committed file.

---

### Closure deliverables table

| Deliverable | Plan | Status | Evidence |
|---|---|---|---|
| Consolidated audit: v7.6.7.0 | ✅ | ✅ Present | `prompts/phaseV/v7.6.7.0-PR176-consolidated-audit-and-lessons.md` |
| Consolidated audit: v7.6.7.1 | ✅ | ✅ Present | `prompts/phaseV/v7.6.7.1-PR177-consolidated-audit-and-lessons.md` |
| Consolidated audit: v7.6.7.2 | ✅ | ✅ Present | `prompts/phaseV/v7.6.7.2-PR178-consolidated-audit-and-lessons.md` |
| Consolidated audit: v7.6.7.3 | ⚠️ none in phaseV/ | ❌ Missing | No audit file for PR #179 in `prompts/phaseV/` |
| Consolidated audit: v7.6.8.0 | ✅ | ✅ Present | `prompts/phaseV/v7.6.8.0-PR180-consolidated-audit-and-lessons.md` |
| Consolidated audit: v7.6.8.1 | ✅ | ✅ Present | `prompts/phaseV/v7.6.8.1-PR181-consolidated-audit-and-lessons.md` |
| Consolidated audit: v7.6.8.2 | ✅ | ✅ Present | `prompts/phaseV/v7.6.8.2-PR182-consolidated-audit-and-lessons.md` |
| Consolidated audit: v7.6.9.0 | ✅ | ✅ Present | `prompts/phaseV/v7.6.9.0-PR183-consolidated-audit-and-lessons.md` |
| Consolidated audit: v7.6.9.1 | ✅ | ✅ Present | `prompts/phaseV/v7.6.9.1-PR184-consolidated-audit-and-lessons.md` |
| Consolidated audit: v7.6.9.2 | ✅ | ✅ Present | `prompts/phaseV/v7.6.9.2-PR191-consolidated-audit-and-lessons.md` |
| Consolidated audit: v7.6.9.3 | ✅ | ✅ Present | `prompts/phaseV/v7.6.9.3-PR192-consolidated-audit-and-lessons.md` |
| Consolidated audit: v7.6.9.4 | ✅ | ✅ Present | `prompts/phaseV/v7.6.9.4-PR193-consolidated-audit-and-lessons.md` |
| Consolidated audit: v7.6.9.5 | ✅ | ✅ Present | `prompts/phaseV/v7.6.9.5-PR195-consolidated-audit-and-lessons.md` |
| Session log: v7.6.7.0 | ✅ | ✅ Present | `Docs/session-log-2026-04-14-v7.6.7.0.md` |
| Session log: v7.6.7.1 | ✅ | ✅ Present | `Docs/session-log-2026-04-14-v7.6.7.1.md` |
| Session log: v7.6.7.2 | ✅ | ✅ Present | `Docs/session-log-2026-04-14-v7.6.7.2.md` |
| Session log: v7.6.7.3 | ✅ | ❌ Missing | No file matching `session-log-*-v7.6.7.3.md` found |
| Session log: v7.6.8.0 | ✅ | ✅ Present | `Docs/session-log-2026-04-15-v7.6.8.0.md` |
| Session log: v7.6.8.1 | ✅ | ✅ Present | `Docs/session-log-2026-04-15-v7.6.8.1.md` |
| Session log: v7.6.8.2 | ✅ | ✅ Present | `Docs/session-log-2026-04-15-v7.6.8.2.md` |
| Session log: v7.6.9.0 | ✅ | ✅ Present (×2) | `Docs/session-log-2026-04-16-v7.6.9.0.md` + `…-v7.6.9.0-hotfix.md` |
| Session log: v7.6.9.1 | ✅ | ✅ Present | `Docs/session-log-2026-04-16-v7.6.9.1.md` |
| Session log: v7.6.9.2 | ✅ | ✅ Present | `Docs/session-log-2026-04-16-v7.6.9.2.md` |
| Session log: v7.6.9.3 | ✅ | ✅ Present | `Docs/session-log-2026-04-17-v7.6.9.3.md` |
| Session log: v7.6.9.4 | ✅ | ✅ Present | `Docs/session-log-2026-04-17-v7.6.9.4.md` |
| Session log: v7.6.9.5 | ✅ | ✅ Present | `Docs/session-log-2026-04-20-v7.6.9.5.md` |
| `SEC-ADR-001-residual-vulnerabilities.md` | ✅ V2-G | ✅ Present | `Docs/decisions/SEC-ADR-001-residual-vulnerabilities.md` |
| `AGG-ADR-001-satellite-history-storage.md` | ✅ V3-E | ✅ Present | `Docs/decisions/AGG-ADR-001-satellite-history-storage.md` |
| `phaseV-results.md` filled in | ✅ | ✅ Complete | Rebuilt by sweep agent 2026-04-22 |
| `phaseV-issue-sweep-results.md` | ✅ | ✅ Complete | `prompts/handoff/phaseV/phaseV-issue-sweep-results.md` (2026-04-22) |
| `phaseV-conclusion-assessment.md` | ✅ template present | ⚠️ Partial | Template present; delivery table rows and metrics table unfilled |
| Critical Rule 63 added | ✅ | ✅ | `prompts/prompt-index-and-workflow.md` Rule 63 (Phase Y→V transition) |
| Critical Rule 64 added | ✅ | ✅ | `prompts/prompt-index-and-workflow.md` Rule 64; LESSON-OPS-126 / v7.6.9.4 |
| Changelog v7.6.7.0–v7.6.9.5 | ✅ | ✅ All 13 entries present | `Docs/changelog.md` |
| `Docs/phase-V-capacity-study.md` | ✅ | ✅ Present | Per-metric cost model, Phase 7 partition recommendations |
| `Docs/phase-V-implementation-plan-addendum-v7.6.9.4.md` | ✅ | ✅ Present | Includes post-merge correction section |

---

## Q2 — Implementation Quality

### Auth coverage table — post-V2 actual state vs SEC-ADR-001

Cross-referencing `firmware/core/web-handler.h` `handleRequest()` routing (lines 108–266) and `authenticate_management_()` call sites (confirmed at lines 591, 665, 674, 873, 936, 1150, 1373, 1595, 1726, 1762, 1883, 2062, 2145, 2242) against SEC-ADR-001 auth coverage table:

| Endpoint | Method | Auth required? (SEC-ADR-001) | Auth in code? | Match? |
|---|---|---|---|---|
| `/api/ingest/` | POST | ✅ Yes (V2-A) | ✅ Yes (line 591) | ✅ |
| `/api/import/begin` | POST | ✅ Yes (pre-existing) | ✅ Yes (line 873) | ✅ |
| `/api/import/d/` | POST | ✅ Yes (pre-existing) | ✅ Yes (line 936) | ✅ |
| `/api/import/w/` | POST | ✅ Yes (pre-existing) | ✅ Yes (line 936) | ✅ |
| `/api/import/finish` | POST | ✅ Yes (pre-existing) | ✅ Yes (line 1150) | ✅ |
| `/api/import/status` | GET | ❌ Public (intentional) | ❌ Public (line 227 no auth) | ✅ |
| `/api/aggregator/add-satellite` | POST | ✅ Yes (V2-B) | ✅ Yes (line 1883) | ✅ |
| `/api/aggregator/satellite/{id}` | DELETE | ✅ Yes (pre-existing) | ✅ Yes (lines 2062, 2145, 2242) | ✅ |
| `/api/aggregator/test-satellite` | POST | ✅ Yes (pre-existing) | ✅ Yes | ✅ |
| `/api/aggregator/gateways` | GET | ✅ Yes (V2-C) | ✅ Yes (line 1595) | ✅ |
| `/api/aggregator/live` | GET | ✅ Yes (V2-C) | ✅ Yes (line 1726) | ✅ |
| `/api/aggregator/proxy/{...}` | GET | ✅ Yes (V2-C) | ✅ Yes (line 1762) | ✅ |
| `/history/` | GET | ✅ Yes (V2-E, SEC-ADR) | ❌ No auth in code | **⚠️ MISMATCH** |
| `/api/v2/history/` | GET | ✅ Yes (V2-E, SEC-ADR) | ❌ No auth in code | **⚠️ MISMATCH** |
| `/api/status` | GET | ❌ Public (intentional, RV-03) | ❌ Public (line 1351) | ✅ |
| `/api/status/full` | GET | ✅ Yes (V2-D) | ✅ Yes (line 1373) | ✅ |
| `/api/v2/live` | GET | ❌ Public (intentional, RV-07) | ❌ Public | ✅ |
| `/api/manifest` | GET | ❌ Public (intentional, RV-06) | ❌ Public | ✅ |
| `/sensors.json` | GET | ❌ Public (intentional, RV-06) | ❌ Public | ✅ |
| `/api/reboot` | POST | ✅ Yes (pre-existing) | ✅ Yes (line 665) | ✅ |
| `/api/delete-data` | POST | ✅ Yes (pre-existing) | ✅ Yes (line 674) | ✅ |
| `/api/storage-stats` | GET | ✅ Yes (pre-existing) | ✅ Yes | ✅ |

**Two mismatches on history endpoints.** SEC-ADR-001 (committed in v7.6.8.1 as V2-G) states both history endpoints are auth-gated. The v7.6.8.1 audit confirms auth was added. The v7.6.9.0 PR #183 audit (FINDING-V769-04) documents that the auth was subsequently removed — "deliberate decision — read-only history is exposed publicly for operational convenience" — and explicitly notes "SEC-ADR not updated." The current code confirms no auth guard on either handler. Phase 7 must either restore auth (with dashboard credential wiring per issue #196) or formally update `SEC-ADR-001` to document the revised posture.

---

### History-endpoint mitigation trajectory — issue #139

The mitigation for #139 (history loading heap exhaustion) went through four successive layers across Phase V:

**v7.6.8.1 (PR #181, V2-E):** Added auth to `/history/` and `/api/v2/history/` as a first-pass mitigation — anonymous heap exhaustion prevented. Added `csv.reserve(std::min(est_bytes, (size_t)60000))` — fixed 60 KB pre-allocation cap.

**v7.6.9.0 hotfix 1+2 (PR #183):** Auth removed from history GET handlers (FINDING-V769-04; accepted trade-off). This was not a heap-safety regression (the 60 KB cap remained) but it did partially reverse a V2-E security deliverable without updating the ADR.

**v7.6.9.4 (PR #193):** Replaced fixed 60 KB cap with `clamp(esp_get_free_heap_size()/3, 12000, 60000)`. Client-side: gated initial `loadHistory()` on `loadStatusSnapshot()` success with 15 s fallback. Post-merge: BUG-082 documented — `reserve()` is an allocation hint only; the NVS scan loop appends unbounded data past the reserved capacity. WROOM boards with ≥ 500 NVS segments still crash via reallocation spike.

**Additive trajectory assessment:** Steps 1, 3 were additive (no heap regression). Step 2 (auth removal) was not additive from a security perspective but was additive from an operational usability perspective. Step 4 (adaptive cap) was additive as a server-side improvement but did not fix BUG-082. Phase 7 retains the full fix: chunked HTTP streaming eliminates single-response CSV building. v7.6.9.4 did NOT restore history endpoint auth. v7.6.9.5 did NOT address the auth gap.

---

### Dashboard pipeline fidelity

Phase V dashboard pipeline rules: Rule 47 (never edit `dashboard.js`/`dashboard.html` directly), Rule 48 (`dashboard.tmpl.html` is the source), Rule 58 (never hand-edit `sensor_history_multi.h`).

Near-misses caught in PR reviews across Phase V:

| PR | Rule | Finding | Severity | Resolved? |
|---|---|---|---|---|
| #176 (v7.6.7.0) | R58 | Agent ran `render_sensor_config.py` despite prompt exclusion — generator output in diff | Medium (AD-4) | ✅ Back-ported to future prompts |
| #178 (v7.6.7.2) | R47 | `.esphome/build/` grep hits erroneously flagged as source violations | Low | ✅ LESSON-REVIEW-001 added |
| #180 (v7.6.8.0) | R47/48 | Dashboard JS auth-header wiring not listed in §3 scope — appeared as out-of-scope | Low | ✅ Documented; back-ported |
| #184 (v7.6.9.1) | R47/48 | F-03: `bump-version.sh` failed because assembled header not regenerated before bump | Low | ✅ Lesson: assemble before bump |

No Rule 58 violation (direct edit of `sensor_history_multi.h`) was committed in any Phase V PR. Assembly SHA-256 identity was checked at every merge.

---

### Hotfix pattern — v7.6.9.0 analysis

v7.6.9.0 (PR #183, V3-A) had the most complex delivery trajectory of any Phase V step:

- **Fix cycles:** 1 pre-merge fix round (Round 1 → Round 2 with FINDING-V769-01 resolution: `update_interval: never` → `60s`).
- **Post-merge hotfixes:** 2 hotfixes applied within the same PR branch before merge:
  - Hotfix 1: Reverted broken polling additions in `status-snapshot.js` (polling telemetry regression — `free_heap` and `uptime_seconds` were being double-polled).
  - Hotfix 2: Made Flash/SRAM silicon constants and fixed `loadStatusSnapshot()` to call `/api/status/full` with `credentials: 'same-origin'`.
- **Separate session log:** `Docs/session-log-2026-04-16-v7.6.9.0-hotfix.md` alongside the main session log.
- **Sequence reproducible?** Yes — the hotfix session log documents commands and checkpoint evidence.
- **Did hotfixes cleanly layer?** The two hotfixes addressed different code areas and did not conflict. The final state is correct. The pre-merge hotfix sequence is less obvious from the PR commit history alone.

**Comparison to Phase Y:** Phase Y's highest-friction step (v7.6.6.1) required multiple review rounds and added +1 line via a security fix. Phase Y never had a step requiring two post-initial-commit hotfixes within a single branch before merge. v7.6.9.0 is the most complex Phase V delivery by fix-cycle complexity and autonomous agent decision scope.

---

### Test coverage evolution

| Sub-phase | Last version | Fixture sets | Tests total | Notes |
|---|---|---|---|---|
| Baseline (Phase Y close) | v7.6.6.8 | 5 sets (3sensor×2, mixed, system, aggregator) | ~315 passing | Phase Y "402/0" counts passing only |
| V1 close | v7.6.7.2 | 5 sets | ~315 | NAS history fixture URLs removed; count stable |
| V2 close | v7.6.8.2 | 5 sets | ~315 | Auth wiring + fixture shape changes; count stable |
| V3-B/C close | v7.6.9.1 | 5 sets | 99+99+7+8+11 pass; 45+45+0+0+1 skip | CSV role column: breaking fixture update |
| V3-D/E close | v7.6.9.2 | 6 sets (+ ping) | +6 tests | Ping fixture set added |
| V5 close (final) | v7.6.9.5 | 5 sets | 232 pass / 95 skip | 0 failures throughout Phase V |

Note: Phase V's 95 skipped tests are in the 3sensor fixture sets (47 per browser) and represent tests that apply to device-specific features not exercised by the mock server fixture. Test quality is stable — 0 failures throughout Phase V.

---

## Q3 — Documentation Quality

### Consolidated audits

| Step | Audit file | Present? | Lines | Quality |
|---|---|---|---|---|
| v7.6.7.0 PR #176 | `v7.6.7.0-PR176-consolidated-audit-and-lessons.md` | ✅ | 160 | Full: 2 review rounds, device tests, AD-1–5 |
| v7.6.7.1 PR #177 | `v7.6.7.1-PR177-consolidated-audit-and-lessons.md` | ✅ | 139 | Full: 12 gate checks, device tests, heap baseline |
| v7.6.7.2 PR #178 | `v7.6.7.2-PR178-consolidated-audit-and-lessons.md` | ✅ | 152 | Full: 17 gate checks, baseline table, 4 lessons |
| v7.6.7.3 PR #179 | — | ❌ **Missing** | — | No audit for this unplanned step |
| v7.6.8.0 PR #180 | `v7.6.8.0-PR180-consolidated-audit-and-lessons.md` | ✅ | ~160 | Full: 15 acceptance criteria, external reviewer findings |
| v7.6.8.1 PR #181 | `v7.6.8.1-PR181-consolidated-audit-and-lessons.md` | ✅ | 205 | Full: 3 gate-by-gate sections, 5 lessons, do-NOT list |
| v7.6.8.2 PR #182 | `v7.6.8.2-PR182-consolidated-audit-and-lessons.md` | ✅ | ~160 | Full: blocked-gate pattern, 4 lessons |
| v7.6.9.0 PR #183 | `v7.6.9.0-PR183-consolidated-audit-and-lessons.md` | ✅ | 128 | Full: 19 gate results, 4 findings, 2 prompt defects |
| v7.6.9.1 PR #184 | `v7.6.9.1-PR184-consolidated-audit-and-lessons.md` | ✅ | 133 | Full: 13 gate results, 3 findings, breaking-change record |
| v7.6.9.2 PR #191 | `v7.6.9.2-PR191-consolidated-audit-and-lessons.md` | ✅ | 117 | Full: 14 gate results, clean (F-01: no findings) |
| v7.6.9.3 PR #192 | `v7.6.9.3-PR192-consolidated-audit-and-lessons.md` | ✅ | 153 | Full: 15 gate results, NVS safety review, heap margin analysis |
| v7.6.9.4 PR #193 | `v7.6.9.4-PR193-consolidated-audit-and-lessons.md` | ✅ | 62 | ⚠️ Thin: internal audit format, BUG-082 documented, device tests NOT VERIFIED |
| v7.6.9.5 PR #195 | `v7.6.9.5-PR195-consolidated-audit-and-lessons.md` | ✅ | 64 | ⚠️ Thin: internal audit format, clean acceptance criteria |

**Missing audit:** v7.6.7.3 (PR #179) has no consolidated audit. Since v7.6.7.3 also has no session log, this is a double gap. The step is well-documented in the changelog but there is no peer-review record. Recommend backfilling a brief retrospective audit.

**Thin audits:** v7.6.9.4 and v7.6.9.5 use the "internal audit" format (62 and 64 lines) rather than the Perplexity three-turn protocol format used in V1–V3. This is an accepted pattern shift for V4/V5 — the addendum steps had tighter scope and the device gate skip for v7.6.9.4 legitimately reduced the attestable material.

---

### Session logs

| Version | Session log | Present? | Notes |
|---|---|---|---|
| v7.6.7.0 | `session-log-2026-04-14-v7.6.7.0.md` | ✅ | |
| v7.6.7.1 | `session-log-2026-04-14-v7.6.7.1.md` | ✅ | |
| v7.6.7.2 | `session-log-2026-04-14-v7.6.7.2.md` | ✅ | |
| v7.6.7.3 | — | ❌ **Required — missing** | Unplanned step; no session log exists (Critical Rule 20 violation) |
| v7.6.8.0 | `session-log-2026-04-15-v7.6.8.0.md` | ✅ | |
| v7.6.8.1 | `session-log-2026-04-15-v7.6.8.1.md` | ✅ | |
| v7.6.8.2 | `session-log-2026-04-15-v7.6.8.2.md` | ✅ | |
| v7.6.9.0 | `session-log-2026-04-16-v7.6.9.0.md` | ✅ | |
| v7.6.9.0-hotfix | `session-log-2026-04-16-v7.6.9.0-hotfix.md` | ✅ | Correct practice: separate hotfix log |
| v7.6.9.1 | `session-log-2026-04-16-v7.6.9.1.md` | ✅ | |
| v7.6.9.2 | `session-log-2026-04-16-v7.6.9.2.md` | ✅ | |
| v7.6.9.3 | `session-log-2026-04-17-v7.6.9.3.md` | ✅ | |
| v7.6.9.4 | `session-log-2026-04-17-v7.6.9.4.md` | ✅ | |
| v7.6.9.5 | `session-log-2026-04-20-v7.6.9.5.md` | ✅ | |

**Missing session log:** v7.6.7.3 — same gap as the missing audit. Critical Rule 20 ("every step must produce a session log as a MANDATORY deliverable"). Phase Y had the identical pattern for v7.6.6.8 — its closure analysis flagged it as "Required." The same flag applies here.

---

### Changelog quality

| Version | Fixed | Changed | Added | Issues cited | Known limitations |
|---|---|---|---|---|---|
| v7.6.7.0 | ✅ | ✅ | ✅ | #161, #165 | — |
| v7.6.7.1 | ✅ | — | ✅ | #171 | — |
| v7.6.7.2 | — | ✅ | ✅ | #143 | — |
| v7.6.7.3 | — | — | ✅ | Implicit | — |
| v7.6.8.0 | — | ✅ | — | #163 | — |
| v7.6.8.1 | — | ✅ | — | #163, #139 | — |
| v7.6.8.2 | — | ✅ | — | — | V2-I/J blocked |
| v7.6.9.0 | ✅ (hotfix 1+2) | ✅ | ✅ | #144, #136, #138 | C3 stack watermark note |
| v7.6.9.1 | — | ✅ | ✅ | #170, #166 | Breaking CSV format change |
| v7.6.9.2 | — | ✅ | ✅ | #162, #166, #171 | — |
| v7.6.9.3 | — | ✅ | — | #165 | No-code-change path explained |
| v7.6.9.4 | — | ✅ | — | #139 | ✅ BUG-082 explicitly documented |
| v7.6.9.5 | ✅ | — | ✅ | Implicit | C3 retroactive stack note |

**Issue coverage:** All 14 Part 0 issues are referenced in at least one changelog entry. The v7.6.8.2 changelog does not cite an issue number for the LWIP socket reduction (tied to V2-H measurement, issues #164/#165 indirectly).

**Known limitations:** v7.6.9.4 has the strongest known-limitation documentation of any Phase V entry — BUG-082 gets its own titled subsection with explicit statement that the WROOM crash persists and a raw NVS partition backup path.

---

### Lessons categorisation

The `Docs/lessons/index.md` (last updated 2026-04-22) lists all BUG and LESSON-OPS entries with their domain file.

Phase V additions confirmed in index:

| Entry | Domain file per index | Correct? |
|---|---|---|
| BUG-082 (`csv.reserve()` truncation) | `firmware.md` | ✅ |
| BUG-083 (C3 missing `external_components`) | `firmware.md` | ✅ |
| LESSON-OPS-126 (checkpoint grep derivation) | `operations.md` | ✅ |
| LESSON-OPS-127 (`reserve()` is allocation hint) | `operations.md` | ✅ |
| LESSON-OPS-128 (verify config equivalence before theorizing) | `firmware.md` | ✅ |
| LESSON-SEC-001 (all write endpoints require auth) | `build-pipeline.md` | ✅ |

All 6 Phase V entries are listed in the index and routed to domain files consistent with their content.

---

### Critical Rules

| Rule # | Description | Source |
|---|---|---|
| 63 | Session log is a **pre-merge acceptance criterion** (§6), not a post-merge deliverable (§9). Required sections: ESPHome output, Playwright fixture table, evidence summary. | Phase Y closure analysis — 44% omission rate when placed in §9 |
| 64 | Checkpoint grep assertions in agent prompts must be mechanically derived from the replacement block in the same prompt — never estimated from memory or a prior session. Mismatched counts cause agents to loop on phantom failures or silently accept wrong state. | LESSON-OPS-126 / v7.6.9.4 |

Both rules confirmed present in `prompts/prompt-index-and-workflow.md`.

**Numbering check:** Phase Y added Rules 58–62 (5 rules). Rule 63 was added at the Phase Y→V transition. Rule 64 was added mid-Phase V (v7.6.9.4). Sequential, no gaps, no duplicates from 58 to 64.

**Comparison to Phase Y:** Phase Y added 5 Critical Rules (58–62) covering assembly/source discipline. Phase V added 2 Critical Rules (63–64): one about process discipline (session log placement) and one about prompt craftsmanship (checkpoint assertion derivation). Phase V's rules address the human/AI process layer rather than codebase mechanics.

---

### Plan fidelity — amendments applied

The addendum specified four line-level amendments to `Docs/phase-V-implementation-plan.md`. The v7.6.9.4 changelog confirms "Updated the Phase V implementation plan with the v7.6.9.4 carve-out, issue-table annotation, V2-E mitigation note, and version-table row." The `phaseV-results.md` milestone column for issue #139 matches the updated text the addendum specified. Amendments confirmed applied on the basis of changelog attestation and the presence of the addendum's post-merge correction section.

---

## Q4 — Bugs, Lessons, Rules

### Bugs discovered during Phase V

| BUG ID | Version surfaced | Root cause | Fixed in | Documented in |
|---|---|---|---|---|
| (proxy empty-body) | v7.6.7.0 pre-merge | `fetch_to_buffer()` returned false for HTTP 200 / zero-byte body | v7.6.7.0 PR #176 round 2 | v7.6.7.0 audit AD-1 |
| (NAS manifest contract) | v7.6.7.0 pre-merge | Disabled NAS history in runtime but left history URLs in manifest/fixtures | v7.6.7.0 PR #176 round 2 | v7.6.7.0 audit AD-2 |
| FINDING-V769-01 | v7.6.9.0 pre-merge | `update_interval: never` → ESPHome does not publish initial state; blank fields | v7.6.9.0 PR #183 (changed to `60s`) | v7.6.9.0 audit |
| FINDING-V769-02 | v7.6.9.0 pre-merge | `heap_caps_get_total_size(MALLOC_CAP_INTERNAL)` returns allocator budget, not total SRAM | v7.6.9.0 PR #183 (static strings) | v7.6.9.0 audit |
| FINDING-V769-03 | v7.6.9.0 device/production | `credentials: 'same-origin'` rejects cross-origin cookies on Cloudflare Tunnel | BUG-078 (pre-Phase V); v7.6.9.6 dropped (self-resolved) | v7.6.9.0 audit FINDING-V769-03 |
| FINDING-V769-04 (history auth) | v7.6.9.0 | History auth deliberately removed as trade-off; SEC-ADR not updated | No fix; trade-off accepted | v7.6.9.0 audit; open ADR mismatch |
| SEC-04 regression (polling mode) | v7.6.9.0 post-merge | v7.6.8.0 moved `free_heap`/`uptime_seconds` to `/api/status/full`; polling still calling stripped `/api/status` | v7.6.9.0 hotfix 2 | v7.6.9.0 changelog hotfix 2; hotfix session log |
| BUG-083 signal | v7.6.9.0 device testing | C3 running on stock 4 KB httpd stack — `external_components` missing since v7.6.8.0 | v7.6.9.5 PR #195 | `Docs/lessons/firmware.md` BUG-083 |
| BUG-082 | v7.6.9.4 post-merge | `csv.reserve()` is allocation hint; NVS scan loop appends unbounded past cap; WROOM crashes | Deferred to Phase 7 (chunked streaming) | addendum post-merge section; `Docs/lessons/firmware.md` BUG-082; LESSON-OPS-127 |
| BUG-083 | v7.6.9.5 investigation | `render_sensor_config.py` C3 in-place path (`render_yaml_file()`) never reads `external_components` from board profile | v7.6.9.5 PR #195 (added block to C3 template) | `Docs/lessons/firmware.md` BUG-083; LESSON-OPS-128 |

**Detection breakdown:**
- Pre-merge review (automated/LLM): proxy empty-body, NAS manifest, FINDING-V769-01, FINDING-V769-02, BUG-082 (flagged by both Copilot and Codex independently).
- Pre-merge device testing: BUG-083 signal (C3 watermark 636 B in v7.6.9.0 device tests).
- Post-merge device testing: SEC-04 regression (polling mode broken), BUG-082 WROOM crash (confirmed by addendum).
- In-production / operator-reported: FINDING-V769-03 (Cloudflare Tunnel auth failure).

---

### LESSON-OPS entries added during Phase V

| Lesson # | Topic | Source version | Lessons file |
|---|---|---|---|
| LESSON-OPS-126 | Checkpoint grep assertions must be validated against the actual replacement block in the same prompt — never estimated from memory or a prior session | v7.6.9.4 | `Docs/lessons/operations.md` |
| LESSON-OPS-127 | `std::string::reserve()` is an allocation hint, not a size constraint — does not prevent unbounded `.append()` growth | v7.6.9.4 / BUG-082 | `Docs/lessons/operations.md` |
| LESSON-OPS-128 | Verify configuration equivalence before theorizing about measurement discrepancies | v7.6.9.5 / BUG-083 | `Docs/lessons/firmware.md` |
| LESSON-SEC-001 | All write/management endpoints require `authenticate_management_()` as their absolute first executable line | v7.6.8.0 | `Docs/lessons/build-pipeline.md` |

All four confirmed in `Docs/lessons/index.md` (last updated 2026-04-22).

---

### Critical Rules added (same table as Q3, for Q4 completeness)

| Rule # | Description | Source |
|---|---|---|
| 63 | Session log is a pre-merge acceptance criterion (§6), not post-merge deliverable (§9). | Phase Y closure analysis |
| 64 | Checkpoint grep assertions must be mechanically derived from replacement blocks in the same prompt. | LESSON-OPS-126 / v7.6.9.4 |

---

## Q5 — Outstanding Issues

**This section is authoritative from `prompts/handoff/phaseV/phaseV-issue-sweep-results.md` (sweep date 2026-04-22, VERSION 7.6.9.5).**

### Sweep summary

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

---

### FIXED_PARTIALLY issues — full specification of what Phase 7 inherits

**#139 — Bug: History loading heap exhaustion on ESP32-C3**

Phase V delivered two partial mitigations: (1) v7.6.8.1 fixed 60 KB `csv.reserve()` cap; (2) v7.6.9.4 heap-adaptive cap `clamp(free_heap/3, 12000, 60000)` + status-gated `loadHistory()` boot. BUG-082 documented that `reserve()` does not truncate.

Remaining work Phase 7 inherits:
- [ ] Server-side chunked HTTP streaming for `/history/` and `/api/v2/history/` — eliminates single-response CSV building, fixes BUG-082 root cause
- [ ] Per-device NVS storage (`SegmentSnapshot`, per-device namespaces) — prerequisite for chunk-by-time-window responses
- [ ] Dashboard paged history loader — client-side pagination instead of full-CSV fetch
- [ ] Hard truncation limit in NVS scan loop (interim measure if chunked streaming is delayed)

**#166 — Enhancement: CSV export format**

Phase V delivered: `role` column at position 3 (v7.6.9.1), satellite slug prefix for merged export (v7.6.9.1), manifest-driven `getMetricColumnsForSensor()` (v7.6.9.2), ping/system metrics in export (v7.6.9.2).

Remaining work Phase 7 inherits:
- [ ] Per-device CSV export with `# device_id: <id>` and `# metrics: <list>` comment header lines (v7.7.2.0)
- [ ] Multi-device bundle export — single download with all device CSVs concatenated (v7.7.2.2)

**#171 — Bug: Data export logic / import POST crash**

Phase V delivered: Import POST crash fixed via `xTaskCreate` deferred task (v7.6.7.1, Rule 40); `/api/import/status` endpoint; 409 gate on data endpoints; manifest-driven `fetchSensorHistoryRows()` (v7.6.9.2).

Remaining work Phase 7 inherits:
- [ ] Per-device CSV import v2 — protocol that reads `# device_id:` / `# metrics:` headers and routes data to correct device NVS namespace (v7.7.2.1)
- [ ] Per-device CSV export (v7.7.2.0) — shared with #166
- [ ] Multi-device bundle export (v7.7.2.2) — shared with #166

---

### DEFERRED_INTENTIONAL — full specification

**#137 — Feature: Board-type SVG diagrams**

Target: Phase 7+ (owner comment 2026-04-17 confirms post-Phase 8 or standalone documentation task).
Rationale: Design task requiring SVG editor / board-datasheet-derived artwork. No firmware or JS dependency.
Preconditions on Phase 7: none. Fully independent of the persistence engine work.

---

### Issues Phase 7 MUST address before its own closure

From FIXED_PARTIALLY:
- **#139:** Full chunked streaming fix (BUG-082). The WROOM is crash-prone on any `/history/` request with large NVS. Phase 7's per-device persistence engine is a prerequisite.
- **#166:** Per-device CSV export format with comment headers (v7.7.2.0). Depends on per-device persistence engine.
- **#171:** Per-device import v2 (v7.7.2.1). Depends on per-device persistence engine.

---

### Issues Phase 7 SHOULD address but may defer further

- **#137:** Board-type SVG diagrams. Owner confirmed deferral to Phase 7+ or a standalone documentation task. No functional or architectural dependency.

---

### Post-Phase-V issues opened during execution

| Issue | Opened | Classification | Phase 7 candidate? |
|---|---|---|---|
| #190 | During v7.6.9.x window | OUT_OF_SCOPE | Phase VX (v7.6.10.x) — UX enhancement, no firmware dependency |
| #196 | 2026-04-22 (day of sweep) | OUT_OF_SCOPE | Phase VX (v7.6.10.x) — `authFetch()` / unified credential manager; milestoned at creation |

Neither #190 nor #196 is a Phase 7 candidate. #196 is directly caused by the v7.6.8.0 SEC-ADR endpoint split (auth on `/api/status/full` causes mid-session browser re-prompt over Cloudflare Tunnel) and will recur on every Cloudflare Tunnel session until resolved.

---

### Are any outstanding issues blockers for Phase 7?

No issue is a technical blocker for Phase 7 planning to begin. Phase 7's primary deliverable (per-device persistence engine) is independent of all open Phase V issues. However:

**BUG-082 (WROOM history crash)** is a live production impact. The WROOM does not crashloop in normal operation; the crash occurs only when the dashboard or curl fetches `/history/{id}/{metric}` with large NVS history. A raw NVS partition backup was extracted 2026-04-18 (`esptool read_flash 0x370000 0x80000`, offline-parsed by `scripts/parse_nvs_history.py`). Phase 7 should treat #139 as its first-priority deliverable.

**History auth gap** (SEC-ADR-001 mismatch): not a functional blocker, but the ADR inconsistency means the Phase 7 plan author inherits a document claiming auth is required on history endpoints when it is not. Phase 7 must either restore auth or formally update `SEC-ADR-001`.

---

## Q6 — Meta-Level Lessons

### Process and prompt-engineering lessons from the full Phase V arc

**Lesson 1: Unplanned version slots need the same deliverable discipline as planned ones.**
v7.6.7.3 was added between V1 and V2 for a valid reason. It received no session log and no consolidated audit — the same double-gap pattern as Phase Y's v7.6.6.8. The fix: any unplanned step approved by the operator mid-phase must carry a mandatory "(unplanned, added YYYY-MM-DD, reason: …)" annotation in the session log's scope block, and the session log must follow the same checklist as planned steps.

**Lesson 2: Pre-merge device testing is the single highest-leverage missing gate in Phase V.**
v7.6.9.0 shipped with a polling mode regression invisible to Playwright. The two hotfixes required additional commits to the PR branch after initial CI pass. The v7.6.9.4 addendum explicitly made device testing a pre-merge gate in response. For any PR touching `/api/status*` response shape, polling mode, or SSE boot sequence, a real-device test is mandatory pre-merge, not post-merge. LESSON-OPS-051 already states this for dashboard scheduling changes; Phase V extended it to any firmware response shape change that affects the polling path.

**Lesson 3: ADR amendments must co-merge with the code change they track.**
FINDING-V769-04 (history auth removal) was accepted as a deliberate trade-off but `SEC-ADR-001` was not updated. The ADR now describes a security posture the code does not implement. Rule for Phase 7: if a code change reverses or amends a recorded ADR decision, the ADR amendment must be in the same PR or the immediately following one. Every ADR should carry an explicit `Last verified: <version>` field.

**Lesson 4: The plan addendum pattern works but requires a machine-checkable closure gate.**
The v7.6.9.4 addendum was a novel artifact — formal deviation document with scope, alternatives-considered, closure definition, and post-merge correction section. The closure gate checklist (7 items) was not mechanically verified before Phase V was declared closed. Future plan addendums should include a script-checkable closure gate rather than relying on manual review.

**Lesson 5: `csv.reserve()` is not a buffer cap — BUG-082 must inform all future heap-protection patterns.**
The `reserve()` pattern had been in production since v7.6.8.1 without a test detecting unbounded growth. It was caught by two automated reviewers independently at v7.6.9.4. LESSON-OPS-127 documents this. Phase 7 prompts should state explicitly: "never use `reserve()` alone as a heap protection mechanism; pair with a hard append limit or use chunked responses."

**Lesson 6: Multi-LLM scope discipline — v7.6.9.4 held the "no Phase 7 work" invariant cleanly.**
The addendum's controlling invariant was respected. v7.6.9.4 did not touch `SegmentSnapshot`, `HistoryMeta`, `PERSIST_SLOTS`, `HISTORY_HOURS`, `HISTORY_INTERVAL_MINUTES`, or partition tables. The boundary was maintained even under device testing pressure (WROOM crash). The addendum's "three alternatives considered and rejected" section demonstrates that both operator and agent understood the phase boundary.

**Lesson 7: SEC-ADR written as "final state" but Phase V was not the final state.**
`SEC-ADR-001` was committed in v7.6.8.1 with status "Accepted" and a resolution tracking table. Within the same phase, v7.6.9.0 changed the auth posture of two endpoints without updating the ADR. Going forward: every ADR must carry an explicit amendment log header so subsequent changes can be tracked inline rather than requiring a closure analysis to discover mismatches.

**Lesson 8: Checkpoint grep assertion quality is the highest-leverage prompt improvement from Phase V.**
Critical Rule 64 (LESSON-OPS-126) came from v7.6.9.4. The lesson generalizes: every quantified checkpoint claim in a prompt ("this grep should return N") must be derived from the actual code change being specified in the same prompt block. A prompt author should verify the count by running the grep against the target code before publishing the prompt. This is now a Critical Rule and should be in the standard prompt review checklist.

---

### What should change for Phase 7 prompts

**Always include:**
- Explicit device test gate: pre-merge, not post-merge, for any firmware change affecting HTTP response shape, polling cadence, or boot sequence
- ADR amendment clause: "if this PR changes behavior described in any existing ADR, the same PR must include an ADR update or open an ADR amendment issue"
- Checkpoint grep derivation certification: each ⛔ CHECKPOINT must include the search pattern and expected count derived from the same prompt's code block
- "No Phase 8 work" invariant restated explicitly if Phase 7 has adjacent Phase 8 scope
- Unplanned step protocol: any step added after plan finalisation must include reason annotation in session log scope block and all standard deliverables

**Never include:**
- Estimated checkpoint counts from memory or a prior session summary
- "SEC-ADR not updated (trade-off documented elsewhere)" as a disposition — it is not a disposition, it is a deferral that must be tracked
- "Device tests pending operator" for a step where device validation is the core acceptance criterion
- Any assumption that `reserve()` alone caps string allocation

**Prompt structure changes:**
- Move session log from §9 (post-merge deliverable) to §6 (pre-merge acceptance criterion) per Critical Rule 63
- Add a mandatory "Does this PR amend any ADR? If yes, list ADR and amendment" checkbox to the Instruction Compliance Output table
- For addendum-governed steps: add an addendum-closure-gate section that explicitly checks the addendum's own closure checklist items one by one

---

### Agent behaviour patterns — summary

| Problem pattern | Frequency (Phase V) | Guardrail that worked |
|---|---|---|
| Missing session log / audit for unplanned step | 1 occurrence (v7.6.7.3) | None worked — gap persisted to closure |
| Instruction Compliance Output table absent from PR | 2 PRs (#180, #181) | Carry-forward as ⛔ PRE-PR GATE to #182 — worked in #182 |
| Checkpoint grep count estimated from memory | ≥1 occurrence (v7.6.9.4) | Critical Rule 64 added post-incident |
| Dashboard JS scope not listed in §3 but implicitly required | 1 occurrence (#180) | Back-port note added to subsequent prompts |
| `reserve()` used as size constraint | 1 occurrence (BUG-082, v7.6.9.4) | Caught by automated review (Copilot + Codex), not prevented pre-merge |
| ADR not updated when code diverges from ADR | 1 occurrence (v7.6.9.0 history auth) | None — gap persisted to closure |
| Version bump before assembled header regenerated | 1 occurrence (#184, v7.6.9.1) | Lesson added to carry-forward; pipeline order clarified |
| Agent disabled feature without updating manifest/fixtures | 1 occurrence (v7.6.7.0, AD-2) | Caught in Round 1 review; fixed in Round 2 |
| `update_interval: never` producing blank static fields | 1 occurrence (v7.6.9.0 pre-merge) | Caught in PR review (FINDING-V769-01); fixed before merge |
| First PR attempt failed device gate | 1 occurrence (v7.6.9.5) | Stress-test script added to prevent recurrence |

---

### Guardrails that worked reliably

- **Perplexity Three-Turn review protocol** (V1–V3): Multi-turn format caught every blocking issue pre-merge in the main sub-phases.
- **Blocked gate → absent diff pattern** (V2-H/I/J): When a gated step was BLOCKED by measurement, the correct response was zero diff, not a commented-out change.
- **Instruction Compliance Output table as ⛔ PRE-PR GATE** (v7.6.8.2 onwards): After two PRs shipped without it, making it a pre-PR gate worked — it appeared in all subsequent PRs.
- **Multiple automated reviewers on same PR** (v7.6.9.4): GitHub Copilot and OpenAI Codex independently identified BUG-082. Agreement escalated the finding's documentation even though the decision was to merge-as-is.
- **Conditional gate design** (V2-H/I/J, V3-F): Pre-specifying the no-change path with explicit measurement thresholds eliminated ambiguity when gates were BLOCKED.
- **`assemble-sensor-history.sh --check` SHA-256 identity gate**: Verified at every merge. No Rule 58 violation reached main.

---

### Meta-lesson (highest leverage)

The single highest-leverage improvement available for Phase 7 is **pre-merge device testing as a mandatory gate for any firmware change affecting HTTP response shape, auth policy, or boot sequence**. Phase V demonstrated that Playwright fixtures, while comprehensive, do not exercise: (1) polling mode auth credential flows (the v7.6.9.0 SEC-04 regression was invisible to Playwright), (2) heap-pressure behavior under real NVS load (BUG-082 / WROOM crash), (3) ESPHome YAML configuration equivalence (BUG-083 / C3 missing `external_components`). In all three cases, the gap was discovered after merge — requiring hotfixes, post-merge documentation corrections, and a separate v7.6.9.5 investigation step. A 10-minute device smoke test (3 endpoints × 3 boards) would have caught all three before merge. The v7.6.9.4 addendum explicitly made device testing a pre-merge gate; Phase 7 should extend this to all firmware-touching steps and define the minimum smoke test protocol as a reusable checklist in the Phase 7 plan.

---

## Appendix — Per-PR Review Comment Summary

### V1 (PRs #176–#179)

| PR # | Source | Comment summary | Severity | Fixed? | Current state |
|---|---|---|---|---|---|
| #176 | Codex + GPT Round 1 | `fetch_to_buffer()` returned false for HTTP 200 / zero-byte body | Blocking | ✅ Round 2 (`004541b`) | Resolved |
| #176 | Codex + GPT Round 1 | NAS history URLs still in manifest after runtime disable | High | ✅ Round 2 | Resolved |
| #176 | Codex + GPT Round 1 | Proxy JSON error in fixed 192-byte buffer with unescaped URL | Medium | ✅ Round 2 | Resolved |
| #176 | Codex + GPT Round 1 | `strtol(sp+1, …)` on non-null-terminated header buffer | Low | ✅ Round 2 | Resolved |
| #176 | GPT Round 1 | Missing changelog + session log deliverables | Medium | ✅ Round 2 | Resolved |
| #177 | Perplexity | No findings — all 12 gates passed | — | N/A | Clean |
| #178 | Perplexity | D1: Badge fires before `App.Boot.start()` (actually better per LESSON-REVIEW-002) | Informational | ✅ Accepted deviation | Documented |
| #178 | Perplexity | D2: `check_contains_regex` used instead of `check_contains` (more resilient) | Informational | ✅ Accepted deviation | Documented |
| #179 | (no audit) | — | — | — | Unverifiable |

### V2 (PRs #180–#182)

| PR # | Source | Comment summary | Severity | Fixed? | Current state |
|---|---|---|---|---|---|
| #180 | Perplexity Turn 3 | Instruction Compliance Output table absent from PR | Low | No — post-merge observation | Carried to #181 as ⛔ GATE |
| #180 | Perplexity Turn 3 | Dashboard JS scope not named in §3 | Low | No — post-merge | Back-ported to next prompt |
| #180 | CI | BUG-043 assertion: `/api/manifest` no longer first request | Blocking | ✅ Remediation commit | Resolved |
| #180 | CI | Aggregator fixture missing `role: "aggregator"` | Blocking | ✅ Remediation commit | Resolved |
| #180 | CI | Firefox headless auth modal blocked `_aggregatorReady` | Blocking | ✅ `bootAggregatorDashboard()` helper | Resolved |
| #181 | Perplexity | OBS-1: ICO table absent (carried from #180) | Medium | No — post-merge; carried to #182 | Resolved in #182 |
| #181 | Perplexity | OBS-2: Process gate evidence not attached to PR | Medium | No — post-merge | Carried to #182 |
| #181 | Perplexity | OBS-3: Cooldown array at file scope (informational, correct) | Informational | N/A | Documented |
| #182 | Perplexity | OBS-1: ICO table now present — enforcement worked | Positive | ✅ | Resolved |
| #182 | Perplexity | OBS-2: Playwright EADDRINUSE collision (sequential rerun fixed) | Medium | ✅ Documented | LESSON-OPS-052 |

### V3 (PRs #183, #184, #191, #192)

| PR # | Source | Comment summary | Severity | Fixed? | Current state |
|---|---|---|---|---|---|
| #183 | Copilot review | FINDING-V769-01: `update_interval: never` → blank dashboard fields | High | ✅ Changed to `60s` | Resolved |
| #183 | Copilot review | FINDING-V769-02: SRAM allocator budget vs datasheet size | Medium | ✅ Static strings | Resolved |
| #183 | Copilot review | FINDING-V769-03: Cloudflare Tunnel credential failure (known limitation) | Low | Deferred → self-resolved | Resolved via BUG-078 |
| #183 | Copilot review | FINDING-V769-04: History endpoints public (deliberate trade-off) | Informational | ✅ Accepted; SEC-ADR not updated | **Open — ADR mismatch** |
| #184 | Perplexity | F-01: Merged export role uses batch heuristic (correct for V3-C) | Informational | N/A — V3-D scope | Tracked for #191 |
| #184 | Perplexity | F-02: Physical device tests not run in agent session | Low | Operator post-merge scope | Operator checklist |
| #184 | Perplexity | F-03: `bump-version.sh` failed before assemble-first | Low | ✅ Fixed in session | Lesson added |
| #191 | Perplexity | F-01: No findings requiring disposition | — | N/A | Clean |
| #192 | Perplexity | All 15 gates PASS; zero findings | — | N/A | Clean |

### V4 (PRs #193, #194)

| PR # | Source | Comment summary | Severity | Fixed? | Current state |
|---|---|---|---|---|---|
| #193 | GitHub Copilot | BUG-082: `csv.reserve()` does not truncate — unbounded append past cap | Blocking (logical) | Deferred to Phase 7 | **Open — Phase 7 required** |
| #193 | OpenAI Codex | BUG-082: Same finding independently confirmed | Blocking (logical) | Deferred to Phase 7 | **Open — Phase 7 required** |
| #193 | Autonomous | `Promise.resolve(loadHistory()).catch()` wrapper needed | Low | ✅ Fixed in PR | Resolved |
| #194 | (docs PR) | BUG-082 documented; LESSON-OPS-127 added | — | ✅ | Documentation complete |

### V5 (PR #195)

| PR # | Source | Comment summary | Severity | Fixed? | Current state |
|---|---|---|---|---|---|
| #195 first attempt | Device gate | Incorrect C3 YAML syntax — device failed to compile | Blocking | ✅ Rework | Resolved |
| #195 rework | Device gate | All three boards: watermark ≥ 10,000 B; stress test passed | — | ✅ | PASS |

**Severity distribution table (all Phase V PRs):**

| Severity | Raised | Fixed in-phase | Deferred | Accepted as trade-off |
|---|---|---|---|---|
| Blocking | 7 | 6 | 1 (BUG-082 → Phase 7) | 0 |
| High | 2 | 2 | 0 | 0 |
| Medium | 5 | 3 | 0 | 2 (ICO table eventually enforced; Playwright sequential) |
| Low | 6 | 4 | 1 (FINDING-V769-03 self-resolved) | 1 (physical device tests = operator scope) |
| Informational / Cosmetic | 6 | 1 (batch heuristic) | 0 | 5 |

---

## Handoff to Phase 7

_One-page summary for Phase 7 plan authors._

### Top 3 Phase V outcomes Phase 7 must build on

1. **Auth coverage is complete except history GET endpoints.** All write and topology-disclosure endpoints are auth-gated per `SEC-ADR-001`. The history endpoints (`/history/` and `/api/v2/history/`) were auth-gated in v7.6.8.1 and then deliberately made public in v7.6.9.0. Phase 7 must decide: restore auth (with dashboard `authFetch()` wiring per issue #196) or formally amend `SEC-ADR-001` to document the revised posture. This is the first thing to resolve because Phase 7's per-device persistence engine will generate larger history payloads, amplifying the risk.

2. **The persistence architecture is confirmed safe to extend.** The v7.6.9.3 struct audit confirmed: (a) `free_heap_internal` at boot is 70,144–70,952 B on C3, well above the 65 KB floor; (b) NVS persistence is per-field (no `sizeof(SensorEntity)` blob serialisation), so Phase 7 struct changes are NVS-safe; (c) the 8-persistent-metric C3 ceiling is the correct constraint (capacity study §Executive Summary). Phase 7's persistence engine design can proceed from `Docs/phase-V-capacity-study.md` without re-measuring baseline.

3. **The dashboard export architecture is manifest-driven.** `getMetricColumnsForSensor()` (v7.6.9.2) means adding a new sensor type or metric no longer requires updating a static `EXPORT_SENSOR_SUFFIXES` array. Phase 7's per-device persistence layer should extend this — the `# device_id:` / `# metrics:` comment header format for per-device CSV export (issues #166/#171) plugs directly into the existing manifest-driven column builder.

### Top 3 unresolved items Phase 7 must address

1. **BUG-082 (issue #139):** WROOM history endpoint OOM crash. `reserve()` does not truncate. Phase 7 chunked streaming is the only correct fix. Make this the first deliverable of Phase 7 (before or as the first step of the persistence engine redesign). Until fixed, WROOM boards crash on any `/history/` request with large NVS.

2. **History auth gap:** `SEC-ADR-001` says `/history/` is auth-gated; the code does not enforce this. Phase 7 must resolve the inconsistency in the first PR that touches `web-handler.h`. Option A: restore auth + wire `authFetch()` in dashboard (issue #196 prerequisite). Option B: formally update `SEC-ADR-001` RV-04 to accept public read-only history.

3. **NVS partition sizing:** Phase V was OTA-safe and could not change partition tables. Phase 7 requires a re-flash. `Docs/phase-V-capacity-study.md` recommends 640 KB NVS for 4 MB boards, 1.5 MB for 8 MB boards, 3 MB for 16 MB boards.

### Top 3 process changes Phase 7 should adopt

1. **Pre-merge device testing is mandatory for all firmware-touching PRs.** Define a minimum smoke test checklist (≥ 3 endpoints × ≥ 2 boards) in the Phase 7 plan §Device Testing and make it a ⛔ PRE-PR GATE in every agent prompt.

2. **ADR amendments must co-merge with the code change they track.** When a PR reverses or amends a decision recorded in an ADR, the ADR update must be in the same PR. Add a mandatory Instruction Compliance Output row: "Does this PR amend any existing ADR? If yes, cite ADR name and amendment line."

3. **Checkpoint grep assertions must be machine-derived, not estimated.** Critical Rule 64 applies. Phase 7 prompt authors should run every ⛔ CHECKPOINT assertion against the current codebase before publishing the prompt, and record the derivation method next to the expected count.

---

_End of Phase V Comprehensive Closure Analysis._
