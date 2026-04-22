# Phase V — Results and Handoff to Phase 7

_Last updated: 2026-04-22_

---

## Phase V Delivery Record

### Sub-phase V1 — Critical Fixes (v7.6.7.x)

| Version | Step | PR | Status | Fix Cycles | Agent | Key Outcome |
|---|---|---|---|---|---|---|
| v7.6.7.0 | V1-A/B/C | #176 | Complete | 2 | Codex/GPT/Perplexity | Proxy 502 fix; `fetch_to_buffer()` timeout + HTTP status; NAS history disabled; logger level WARN |
| v7.6.7.1 | V1-D | #177 | Complete | 0 | Codex/Perplexity | Import POST crash fixed — `xTaskCreate` deferred task (Rule 40); `/api/import/status`; 409 gate on data endpoints |
| v7.6.7.2 | V1-E/F/G | #178 | Complete | 0 | Codex/Perplexity | Dashboard footer version badge; dead code removal (`stream_snapshot_series_()`, `HistoryBuffer::stream_to()`); import lifetime comment |
| v7.6.7.3 | Operational telemetry | #179 | Complete | 0 | Codex | Operational telemetry fields (`free_heap`, `uptime_seconds`) added to `/api/status` |

**V1 heap baseline (post-v7.6.7.2, physical C3 SuperMini @ 192.168.120.189):**
- free_heap_total at boot: ~69 KB (70,568 B measured at v7.6.7.1; floor 65 KB carried forward to V2)
- free_heap_internal at boot: ~69 KB (C3 has no PSRAM; free_heap_total = free_heap_internal)

### Sub-phase V2 — Security Hardening (v7.6.8.x)

| Version | Step | PR | Status | Fix Cycles | Agent | Key Outcome |
|---|---|---|---|---|---|---|
| v7.6.8.0 | V2-A/B/C/D | #180 | Complete | 1 | Codex | Auth guards on all write/topology endpoints; `/api/status/full` split; SEC-ADR-001; dashboard auth header wiring to aggregator endpoints |
| v7.6.8.1 | V2-E/F/G | #181 | Complete | 0 | Codex/Perplexity | Auth on history endpoints; 60 KB `csv.reserve()` cap (V2-E); per-URL add-satellite DoS cooldown (V2-F); `Docs/decisions/SEC-ADR-001-residual-vulnerabilities.md` (V2-G) |
| v7.6.8.2 | V2-H/I/J | #182 | Complete | 0 | Codex/Perplexity | `CONFIG_LWIP_MAX_SOCKETS` 18→15 on C3 (V2-H ✅); V2-I/J blocked — insufficient headroom for stack reduction |

**Operator measurement results (between V1 and V2, physical C3 @ 192.168.120.189):**

| Measurement | Value | Gate Result |
|---|---|---|
| httpd stack peak usage | 16,124 B (of 16,384 B stack) | V2-J blocked — headroom 260 B < 2,048 B minimum |
| httpd stack headroom | 260 B unused | → no reduction applied (would leave negative margin) |
| ping_adapter watermark | 2,160 B unused (1,936 B peak of 4,096 B) | → no reduction (112 B margin < 2,048 B minimum); V2-I blocked |
| LWIP sockets validation | Pass (5-min two-tab stress test, zero ENFILE) | → set 15 |

### Sub-phase V3 — Dashboard Enhancements (v7.6.9.x)

| Version | Step | PR | Status | Fix Cycles | Agent | Key Outcome |
|---|---|---|---|---|---|---|
| v7.6.9.0 | V3-A | #183 | Complete | 1 | Codex | Device Name + Firmware rows; PSRAM conditional (None / NNNN KB); Flash/SRAM static text sensors; MAC row removed; hotfix: polling telemetry regression |
| v7.6.9.1 | V3-B/C | #184 | Complete | 1 | Codex | Satellite `hostname`/`ip` in `/api/aggregator/gateways`; CSV `role` column at position 3; satellite-prefixed merged export columns; `getExportRole()` |
| v7.6.9.2 | V3-D/E | #191 | Complete | 0 | Codex | Manifest-driven `getMetricColumnsForSensor()`; `EXPORT_SENSOR_SUFFIXES` removed; ping + system metrics in export; `AGG-ADR-001` decision doc |
| v7.6.9.3 | V3-F | #192 | Complete | 0 | Codex/Perplexity | Struct audit — heap above floor (70,952 B / 69.3 KiB); no code changes; Phase V preliminary closure |
| v7.6.9.4 | V4 | #193 | Complete | 1 | Codex | Heap-adaptive cap `clamp(free_heap/3, 12000, 60000)` at both history handlers; status-gated initial `loadHistory()` with 15 s fallback |
| v7.6.9.5 | V5 | #195 | Complete | 1 (rework) | Codex | C3 `external_components` block fix (BUG-083) — C3 now gets 16 KB httpd stack override; PR #195 first attempt failed device gate |

---

v7.6.9.6 was originally planned (Cloudflare polling fix + SEC-ADR amendment) but dropped after the issue self-resolved.

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

| Issue | Title | Status | Closed/Touched by PR | Classification | Notes |
|---|---|---|---|---|---|
| #136 | Tech-debt: Hardcoded C3 values in dashboard | Closed | #183 | FIXED_FULLY | Device card cleanup (v7.6.9.0); DEVICE_INFO_MAP moved to `status-snapshot.js` |
| #138 | Enhancement: Gateway card PSRAM/flash info | Closed | #183 | FIXED_FULLY | PSRAM conditional (None/NNNN KB); Flash/SRAM static text sensors added (v7.6.9.0) |
| #139 | Bug: History loading serialization for C3 boards | Open (partial) | #181, #193 | FIXED_PARTIALLY | Heap-adaptive `clamp()` cap shipped; chunked streaming + per-device NVS deferred to Phase 7 |
| #143 | Enhancement: No visible version badge | Closed | #178 | FIXED_FULLY | Dashboard footer `<span id="versionBadge">` populated from `App.version` before SSE init (v7.6.7.2) |
| #144 | Enhancement: Update gateway card | Closed | #183 | FIXED_FULLY | Device Name + Firmware rows; MAC row removed; hotfix for polling telemetry regression (v7.6.9.0) |
| #161 | Bug: Proxy 502 — no diagnostic | Closed | #176 | FIXED_FULLY | `fetch_to_buffer()` timeout + HTTP status; proxy returns 502 JSON or 200 empty body (v7.6.7.0) |
| #162 | Decision: Aggregator history storage strategy | Closed | #191 | FIXED_FULLY | `AGG-ADR-001-satellite-history-storage.md` decision doc committed (v7.6.9.2) |
| #163 | Feature: Security hardening | Closed | #180 | FIXED_FULLY | Auth guards on all write/topology endpoints; `/api/status/full` split from public `/api/status` (v7.6.8.0) |
| #164 | Bug: C3 heap regression / memory footprint | Closed | #182, #192 | FIXED_FULLY | V2 stack/socket measurements documented; LWIP sockets 18→15; heap above floor at Phase V close (v7.6.8.2, v7.6.9.3) |
| #165 | Tech-debt: SRAM optimisations | Closed | #176, #182, #192 | FIXED_FULLY | NAS history disabled (~2.3 KB saved, v7.6.7.0); LWIP sockets 18→15 (v7.6.8.2); struct audit passed — no padding changes needed (v7.6.9.3) |
| #166 | Enhancement: CSV export format | Open (partial) | #184, #191 | FIXED_PARTIALLY | `role` column + satellite prefix + manifest-driven `getMetricColumnsForSensor()` shipped; per-device `# headers` format deferred to Phase 7 (v7.7.2.x) |
| #170 | Enhancement: Satellite gateway card display | Closed | #184 | FIXED_FULLY | Satellite `hostname`/`ip` in `/api/aggregator/gateways`; gateway selector + summary + settings cards updated (v7.6.9.1) |
| #171 | Bug: Data export logic / import POST crash | Open (partial) | #177, #191 | FIXED_PARTIALLY | Import crash fixed (xTaskCreate, Rule 40, v7.6.7.1); manifest-driven export (v7.6.9.2); per-device import/export protocol deferred to Phase 7 (v7.7.2.x) |

### Deferred

| Issue | Classification | Target | Rationale |
|---|---|---|---|
| #137 | DEFERRED_INTENTIONAL | Phase 7+ | SVG board diagrams for WROOM-32D and S3-DevKitC1-N16R8 — design task with no firmware/JS dependency; deferred per plan line 42 |
| #139 | FIXED_PARTIALLY | Phase 7 | Full chunked streaming fix (BUG-082) — `reserve()` hint does not prevent unbounded append past cap; per-device NVS storage required |
| #166 | FIXED_PARTIALLY | Phase 7 (v7.7.2.x) | Per-device CSV export with `# device_id:` / `# metrics:` comment headers (v7.7.2.0); multi-device bundle export (v7.7.2.2) |
| #171 | FIXED_PARTIALLY | Phase 7 (v7.7.2.x) | Per-device CSV export (v7.7.2.0); per-device CSV import v2 (v7.7.2.1); multi-device bundle export (v7.7.2.2) |
| #190 | OUT_OF_SCOPE | Phase VX (v7.6.10.x) | Post-plan UX enhancement (opened 2026-04-17); Framework/ESPHome/MAC-to-Eventlog relocation; dashboard-only, no firmware dependency |
| #196 | OUT_OF_SCOPE | Phase VX (v7.6.10.x) | Unified dashboard auth / `authFetch()` pattern; opened day of sweep and milestoned Phase VX at creation |

---

## Context for Phase 7

### What Changed in Phase V

1. **Auth coverage:** All write endpoints and topology-disclosure endpoints are now auth-gated. See SEC-ADR-001 for the complete post-V2 auth table.

2. **`fetch_to_buffer()` signature:** Now has `timeout_s`, `out_http_status`, and `basic_auth` optional parameters. All call sites use defaults except the proxy (15s timeout) and aggregator polling (basic_auth for `/api/status/full`).

3. **Dashboard export:** Now manifest-driven via `getMetricColumnsForSensor()`. Ping and system metrics appear in exports. CSV format includes `role` column at position 3 (breaking change from pre-V3).

4. **NAS history disabled:** `metrics_system[]` entries for cpu/ram/disk have `history_enabled = false`. Three `HistoryBuffer` statics deleted. ~2.3 KB SRAM saved.

5. **Import deferred task:** `handle_import_begin_()` uses `xTaskCreate` for `build_import_epoch_map_()`. New `/api/import/status` endpoint for readiness polling.

6. **Capacity study:** `Docs/phase-V-capacity-study.md` — C3 max 8 persistent metrics, partition recommendations for Phase 7.

7. **Include BUG-083** finding and dashboard auth refactor deferral

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
