# Phase V — Conclusion Assessment

_Fill in after Phase V completes (all V1/V2/V3 steps merged or explicitly deferred)._

---

## Summary

| Sub-phase | Steps planned | Steps delivered | Steps deferred | Fix cycles total |
|---|---|---|---|---|
| V1 (v7.6.7.x) | 7 (V1-A through V1-G planned; V1-H unplanned) | 8 (incl. V1-H) | 0 | 2 |
| V2 (v7.6.8.x) | 10 (V2-A through V2-J) | 8 (V2-I/J blocked by gate) | 0 | 1 |
| V3 (v7.6.9.x) | 6 (V3-A through V3-F) | 6 | 0 | 2 |
| V4 (v7.6.9.4) | 1 | 1 | 0 | 1 |
| V5 (v7.6.9.5) | 1 | 1 | 0 | 1 |
| V6 (v7.6.9.6) | 1 | 0 | 1 (self-resolved) | 0 |
| **Total** | **26** | **24** | **1** | **7** |

---

## What Succeeded

### V1 — Critical Fixes
| Step | Outcome | Notes |
|---|---|---|
| v7.6.7.0 (V1-A/B/C) | ✅ Complete | Proxy 502 fix (`fetch_to_buffer()` timeout+HTTP status); NAS history disabled (~2.3 KB heap); logger INFO→WARN. 2 fix cycles (Round 1 commit `9d033d0`, fix `004541b`). |
| v7.6.7.1 (V1-D) | ✅ Complete | Import POST crash fixed via `xTaskCreate` deferred task (Rule 40); `/api/import/status` endpoint; 409 gate. 0 fix cycles. |
| v7.6.7.2 (V1-E/F/G) | ✅ Complete | Dashboard footer version badge; dead code removal (`stream_snapshot_series_()`, `HistoryBuffer::stream_to()`); import session lifetime comment. 0 fix cycles. |
| v7.6.7.3 (V1-H — unplanned) | ✅ Complete | `min_free_heap`, `httpd_stack_watermark_bytes`, `ping_stack_watermark_bytes` added to `/api/status`. Required for V2-H/I/J gate measurements. 0 fix cycles. ⚠️ No session log or audit — Critical Rule 20 violation. |

### V2 — Security Hardening
| Step | Outcome | Notes |
|---|---|---|
| v7.6.8.0 (V2-A/B/C/D) | ✅ Complete | Auth guards on `/api/ingest/`, `/api/aggregator/add-satellite`, aggregator topology endpoints; `/api/status/full` split. 1 CI remediation fix cycle. |
| v7.6.8.1 (V2-E/F/G) | ⚠️ Partial | Auth added to history endpoints (V2-E) — subsequently removed in v7.6.9.0 (deliberate trade-off; SEC-ADR mismatch). 60 KB `csv.reserve()` cap. Per-URL DoS cooldown (V2-F). SEC-ADR-001 committed (V2-G). 0 fix cycles. |
| v7.6.8.2 (V2-H/I/J) | ⚠️ Partial | V2-H: `CONFIG_LWIP_MAX_SOCKETS` 18→15 ✅. V2-I blocked (ping stack 112 B margin < 2,048 B gate). V2-J blocked (httpd stack 260 B unused, reduction unsafe). 0 fix cycles. |

### V3 — Dashboard Enhancements
| Step | Outcome | Notes |
|---|---|---|
| v7.6.9.0 (V3-A) | ✅ Complete | Device card: Device Name, Firmware, PSRAM conditional, Flash/SRAM; MAC removed. 2 hotfixes pre-merge (polling regression + Cloudflare credential fix). |
| v7.6.9.1 (V3-B/C) | ✅ Complete | Satellite `hostname`/`ip` in `/api/aggregator/gateways`; CSV `role` column at position 3; satellite slug prefix. 1 fix cycle (`bump-version.sh` before assemble). |
| v7.6.9.2 (V3-D/E) | ✅ Complete | `getMetricColumnsForSensor()` manifest-driven; `EXPORT_SENSOR_SUFFIXES` removed; `AGG-ADR-001` committed. 0 fix cycles. |
| v7.6.9.3 (V3-F) | ✅ Complete | Struct audit — no-code-change path: heap 70,952 B ≥ 65 KB gate. Preliminary Phase V closure. 0 fix cycles. |

### V4–V6
| Step | Outcome | Notes |
|---|---|---|
| v7.6.9.4 (V4) | ⚠️ Partial | Heap-adaptive cap `clamp(free_heap/3, 12000, 60000)` delivered. BUG-082: `csv.reserve()` does not truncate — WROOM OOM crash not fixed; deferred to Phase 7 chunked streaming. 1 fix cycle (PR #193 code + PR #194 docs). Device gate skipped by operator. |
| v7.6.9.5 (V5) | ✅ Complete | BUG-083 fixed: missing `external_components` in C3 YAML template; C3 now gets 16 KB httpd stack. First PR attempt failed device gate (YAML syntax); rework passed. All three boards uniform ~12.8 KB watermark. 1 fix cycle (rework). |
| v7.6.9.6 (V6) | ⛔ Dropped | Self-resolved: BUG-078 (v7.6.0.1) fixed 401→500 HTTP status mapping; browser auth dialog now works over Cloudflare Tunnel. SEC-ADR RV-03 amendment appended to SEC-ADR-001. Auth UX deferred to Phase VX as issue #196. |

---

## What Was Deferred

| Item | Reason | Target |
|---|---|---|
| #139 — History OOM (BUG-082) | `csv.reserve()` is hint not cap; chunked streaming requires per-device NVS engine | Phase 7 (v7.7.x) |
| #166 — Per-device CSV export | Per-device `# device_id:` / `# metrics:` headers; multi-device bundle | Phase 7 (v7.7.2.x) |
| #171 — Per-device import v2 | Per-device CSV import with header routing; depends on per-device NVS | Phase 7 (v7.7.2.x) |
| #137 — Board SVG diagrams | Design task, no firmware/JS dependency | Phase 7+ (or standalone documentation) |
| v7.6.9.6 (Cloudflare polling fix) | Self-resolved via BUG-078 fix in v7.6.0.1 (401→500 mapping). Auth UX enhancement → issue #196 | Phase VX (v7.6.10.x) |
| History auth gap (SEC-ADR mismatch) | History GET endpoints public; SEC-ADR-001 says auth required — mismatch unresolved | Phase 7 (first PR touching `web-handler.h`) |

---

## What Phase 7 Inherits

### From V1
- Post-V1 heap baseline (physical C3 SuperMini @ 192.168.120.189, post-v7.6.7.2): free_heap ~69 KB (70,568 B measured at v7.6.7.1). Floor 65 KB carried forward to V2.
- NAS history disabled — three `HistoryBuffer` statics removed; ~2.3 KB SRAM saved permanently.

### From V2
- Auth coverage table (SEC-ADR-001 final state)
- Gated optimisation results (V2-H/I/J measurement values)
- Residual vulnerabilities documented in SEC-ADR-001

### From V3
- AGG-ADR-001 decision: Option 1 (proxy) confirmed for v7.6.x
- Manifest-driven export architecture established
- Capacity study recommendations for Phase 7 partition sizing

### From V4
- Heap-adaptive history cap `clamp(free_heap/3, 12000, 60000)` in both `/history/` handlers. Status-gated `loadHistory()` boot with 15 s fallback.
- BUG-082 open: `reserve()` does not cap unbounded `.append()` growth — WROOM OOM crash on large NVS history fetch. Phase 7 must implement chunked streaming.

### From V5
- All three boards now run 16 KB httpd stack override (C3 previously on stock 4 KB since v7.6.8.0).
- Phase V final device state: C3 watermark 12,768 B, WROOM 12,964 B, S3 12,944 B (all on 16 KB stack, stress-test threshold ≥ 10,000 B).

---

## Lessons Learned

### New Critical Rules Added
| # | Rule | Source |
|---|---|---|
| 63 | Session log is a pre-merge acceptance criterion (§6), not a post-merge deliverable (§9). Required sections: ESPHome output (or documented absence), Playwright fixture table, evidence summary. | Phase Y closure analysis → Phase V Rule 63 |
| 64 | Checkpoint grep assertions in agent prompts must be mechanically derived from the replacement block in the same prompt — never estimated from memory or a prior session. | LESSON-OPS-126 / v7.6.9.4 |

### New LESSON-OPS Entries
| # | Lesson | Source |
|---|---|---|
| LESSON-SEC-001 | All write/management endpoints require `authenticate_management_()` as their absolute first executable line | v7.6.8.0 |
| LESSON-OPS-126 | Checkpoint grep assertions must be validated against the actual replacement block in the same prompt — never estimated from memory or a prior session | v7.6.9.4 |
| LESSON-OPS-127 | `std::string::reserve()` is an allocation hint, not a size constraint — does not prevent unbounded `.append()` growth | v7.6.9.4 / BUG-082 |
| LESSON-OPS-128 | Verify configuration equivalence before theorizing about measurement discrepancies | v7.6.9.5 / BUG-083 |

### Prompt Methodology Improvements
- Pre-merge device testing is now a mandatory gate for firmware PRs affecting HTTP response shape, auth policy, or boot sequence (Q6 meta-lesson from closure analysis)
- ADR amendments must co-merge with the code change they track — add mandatory ADR-amendment checkbox to Instruction Compliance Output table in Phase 7 prompts
- Checkpoint grep derivation must be machine-derived: each ⛔ CHECKPOINT must include search pattern and count derived from the same prompt's code block (Critical Rule 64)
- Unplanned steps must carry all standard deliverables: session log, consolidated audit, changelog entry — no exceptions

---

## Metrics

| Metric | Value |
|---|---|
| Total PRs | 13 (PRs #176–#195, excluding #185–#190 which are non-Phase-V) |
| Total fix cycles | 7 (V1: 2, V2: 1, V3: 2, V4: 1, V5: 1) |
| Average fix cycles per step | 0.54 (7 ÷ 13 versions) |
| Steps with 0 fix cycles | 8 (v7.6.7.1, v7.6.7.2, v7.6.7.3, v7.6.8.1, v7.6.8.2, v7.6.9.2, v7.6.9.3, v7.6.9.6 n/a) |
| Steps with >2 fix cycles | 0 |
| Playwright test count (final) | 232 pass / 95 skip / 0 fail (327 total, 6 fixture sets) |
| Critical Rule violations caught | 1 (v7.6.7.3 missing session log and audit — Critical Rule 20) |

---

_End of Phase V conclusion assessment._
