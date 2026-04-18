# Phase V — Results and Handoff to Phase 7

_Fill in during Phase V execution. Each row completed when the step merges._
_Last updated: 2026-04-17_

---

## Phase V Delivery Record

### Sub-phase V1 — Critical Fixes (v7.6.7.x)

| Version | Step | PR | Status | Fix Cycles | Agent | Key Outcome |
|---|---|---|---|---|---|---|
| v7.6.7.0 | V1-A/B/C | #___ | | | | |
| v7.6.7.1 | V1-D | #___ | | | | |
| v7.6.7.2 | V1-E/F/G | #___ | | | | |

**V1 heap baseline (post-v7.6.7.2):**
- free_heap_total at boot: ___ KB
- free_heap_internal at boot: ___ KB

### Sub-phase V2 — Security Hardening (v7.6.8.x)

| Version | Step | PR | Status | Fix Cycles | Agent | Key Outcome |
|---|---|---|---|---|---|---|
| v7.6.8.0 | V2-A/B/C/D | #___ | | | | |
| v7.6.8.1 | V2-E/F/G | #___ | | | | |
| v7.6.8.2 | V2-H/I/J | #___ | | | | |

**Operator measurement results (between V1 and V2):**

| Measurement | Value | Gate Result |
|---|---|---|
| httpd stack peak usage | ___ B | |
| httpd stack headroom | ___ B | → set ___ B |
| ping_adapter watermark | ___ B | → set ___ B |
| LWIP sockets validation | Pass/Fail | → set ___ |

### Sub-phase V3 — Dashboard Enhancements (v7.6.9.x)

| Version | Step | PR | Status | Fix Cycles | Agent | Key Outcome |
|---|---|---|---|---|---|---|
| v7.6.9.0 | V3-A | #___ | | | | |
| v7.6.9.1 | V3-B/C | #___ | | | | |
| v7.6.9.2 | V3-D/E | #___ | | | | |
| v7.6.9.3 | V3-F | #___ | | | | |
| v7.6.9.4 | V4 | #193 | In progress | 0 | Codex | Heap-adaptive history reserve cap at both handlers and status-gated initial history boot with 15 s fallback |

---

## Test Results (Final State)

| Fixture Set | Tests | Pass | Fail | Skip |
|---|---|---|---|---|
| 3sensor (chromium) | 149 | 102 | 0 | 47 |
| 3sensor (firefox) | 149 | 102 | 0 | 47 |
| mixed | 8 | 8 | 0 | 0 |
| system | 9 | 9 | 0 | 0 |
| aggregator | 12 | 11 | 0 | 1 |
| **Total** | 327 | 232 | 0 | 95 |

---

## Device Test Results

### C3 Satellite (192.168.120.189)

| Test | Result | Heap Before | Heap After |
|---|---|---|---|
| Boot and stabilise | Skipped by operator request | | |
| Dashboard open (SSE) | Skipped by operator request | | |
| Import begin (no crash) | Not run | | |
| History fetch | Not run | | |
| Auth on ingest (401) | Not run | | |
| Status field strip | Not run | | |

### S3 Aggregator (192.168.120.191)

| Test | Result | Notes |
|---|---|---|
| Proxy history (satellite online) | Skipped by operator request | Device flashing/test gate not run |
| Proxy history (satellite offline) | Skipped by operator request | Device flashing/test gate not run |
| Gateways auth (401/200) | Not run | Device flashing/test gate not run |
| Satellite hostname/IP display | Not run | Device flashing/test gate not run |

---

## Issues Resolved

| Issue | Title | Closed by PR | Notes |
|---|---|---|---|
| #136 | Tech-debt: Hardcoded C3 values | #___ | |
| #138 | Enhancement: Gateway card PSRAM/flash | #___ | |
| #139 | Bug: History heap exhaustion | #___ (partial) | Full fix Phase 7 |
| #143 | Enhancement: Version badge | #___ | |
| #144 | Enhancement: Gateway card cleanup | #___ | |
| #161 | Bug: Proxy 502 | #___ | |
| #162 | Decision: Aggregator history | #___ (ADR) | |
| #163 | Feature: Security hardening | #___ | |
| #164 | Bug: C3 heap regression | #___ | Measurements taken |
| #165 | Tech-debt: SRAM optimisations | #___ | Multiple steps |
| #166 | Enhancement: CSV export | #___ | |
| #170 | Enhancement: Satellite gateway card | #___ | |
| #171 | Bug: Import crash | #___ | |

### Deferred

| Issue | Reason | Target |
|---|---|---|
| #137 | SVG generation — scope too large for Phase V | Phase 7+ |
| #139 | Full chunked streaming fix | Phase 7 |

---

## Context for Phase 7

### What Changed in Phase V

1. **Auth coverage:** All write endpoints and topology-disclosure endpoints are now auth-gated. See SEC-ADR-001 for the complete post-V2 auth table.

2. **`fetch_to_buffer()` signature:** Now has `timeout_s`, `out_http_status`, and `basic_auth` optional parameters. All call sites use defaults except the proxy (15s timeout) and aggregator polling (basic_auth for `/api/status/full`).

3. **Dashboard export:** Now manifest-driven via `getMetricColumnsForSensor()`. Ping and system metrics appear in exports. CSV format includes `role` column at position 3 (breaking change from pre-V3).

4. **NAS history disabled:** `metrics_system[]` entries for cpu/ram/disk have `history_enabled = false`. Three `HistoryBuffer` statics deleted. ~2.3 KB SRAM saved.

5. **Import deferred task:** `handle_import_begin_()` uses `xTaskCreate` for `build_import_epoch_map_()`. New `/api/import/status` endpoint for readiness polling.

6. **Capacity study:** `Docs/phase-V-capacity-study.md` — C3 max 8 persistent metrics, partition recommendations for Phase 7.

### What Phase 7 Must Do

1. Increase NVS partition to 640 KB (4 MB boards) or 4 MB (S3 aggregator) — requires re-flash
2. Implement per-device persistence engine (v7.7.0.x)
3. Implement aggregator history pull (Option 2 from AGG-ADR-001) — v7.7.1.x
4. Implement binary sensor EventLog type (from capacity study §6)
5. Honour C3 8-metric ceiling in persistence config

### New Critical Rules from Phase V

| # | Rule | Source |
|---|---|---|
| Rule | Checkpoint grep counts must be mechanically derived from the replacement block in the same prompt, not estimated from memory. | v7.6.9.4 |

### New Lessons from Phase V

| # | Lesson | Source |
|---|---|---|
| LESSON-SEC-001 | All write endpoints require auth | v7.6.8.0 |
| LESSON-OPS-126 | Checkpoint grep assertions must be validated against the actual replacement block in the same prompt | v7.6.9.4 |

---

_End of Phase V results._
