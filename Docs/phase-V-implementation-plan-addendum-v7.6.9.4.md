# Phase V Plan Addendum — v7.6.9.4: Issue #139 Partial Fix (Heap-Adaptive History)

_Date: 2026-04-16_
_Addendum to: `Docs/phase-V-implementation-plan.md`_
_Target file for this addendum: append as a new section at the end of the plan, before the "Risk Summary" section, and add a row to the version table at line ~1235_

---

## Why this addendum exists

The Phase V plan, as written (line 44 of the issue table; line 805 of the V2-E section), deliberately defers the full fix for issue #139 ("History loading serialization for C3 boards") to Phase 7 on the rationale that true fix requires chunked streaming + per-device storage. v7.6.8.1 shipped a safety-net mitigation (heap cap at 60 KB on `csv.reserve()`) labelled by the plan as "a safety net — the full fix (chunked streaming) is tracked in #139 for Phase 7".

Two events after the plan was finalised have changed the risk profile:

1. **Issue #139 comment (2026-04-12, owner):** "the same problem is with ESP32 board as well that has 512KB RAM and it should not be affected by this problem but it is. Fix is getting urgent." This extends the blast radius from the C3-only (400 KB SRAM) case to the WROOM (520 KB SRAM) case.

2. **v7.6.9.0 device testing (2026-04-16):** the WROOM satellite (192.168.120.190) crashes when `/history/office/temp` is fetched. This is the urgency in #139 comment materialising on-device during Phase V closure testing. The 60 KB cap from v7.6.8.1 was sized against the C3's 68 KB free-heap margin; on the WROOM with `free_heap: 39316` and `min_free_heap: 22016` (current post-boot telemetry), a 60 KB reserve is **larger than the running free heap** — it either triggers `std::bad_alloc` or forces a fragmentation spiral that crashes the board.

The 60 KB constant was chosen in V2-E specifically for the C3's heap budget. It did not anticipate the WROOM case because the working assumption was that WROOM had enough headroom; that assumption has been empirically disproven.

## Scope of this deviation

The Phase V plan's controlling invariant is "no Phase 7 work in Phase V" (plan line 1223). This addendum **does not** schedule Phase 7 work in Phase V. It schedules **two small, local, OTA-safe mitigations** that strictly extend the v7.6.8.1 safety-net approach:

1. **Server-side: replace the fixed 60 KB cap with a heap-adaptive cap.** The math becomes `std::min(est_bytes, clamp(free_heap/3, 12000, 60000))`. On a board with 68 KB free, this yields roughly 22 KB — enough to return ~20 hours of hourly data safely. On a board with 30 KB free, it yields 10 KB (the floor). This preserves the safety-net character of the V2-E fix (still a cap, still reserves upfront to prevent reallocation storms) while making the cap responsive to actual conditions. No architectural change. No change to response semantics — clients receiving a truncated CSV see fewer rows, not an error.

2. **Client-side: defer initial history load until after the first status snapshot returns.** Currently `loadHistory()` fires on a fixed timer at boot. Deferring it by ~2 seconds (or gating on `applyStatusSnapshot()` success) lets the BLE scan settle, `handle_status_full_` report stable heap, and the browser's Basic Auth credential cache warm up. This is a ~15-line change in `boot.js` and does not alter the history path's behavior after the defer.

Both changes live in files already in Phase V's V2 and V3 scope. Neither touches `SegmentSnapshot`, `HistoryMeta`, `PERSIST_SLOTS`, `HISTORY_HOURS`, or `HISTORY_INTERVAL_MINUTES`. Neither changes partition tables. Neither reorganises fragment boundaries (Rule 62). The changes are fully reversible by diff revert.

## What this deviation does NOT deliver

This addendum explicitly does NOT deliver the full #139 fix. In particular:

- **No server-side time-windowed chunked responses** (still Phase 7 — requires response framing changes).
- **No per-device NVS storage** (still Phase 7 — the architectural rewrite is v7.7.0.x).
- **No dashboard paged history loader** (client stays with full-CSV fetch; server just returns less of it under pressure).
- **No change to the `/history` or `/api/v2/history` URL schemas or auth posture.**

These remain tracked in #139 for Phase 7. This addendum sizes itself to be "the 20% of the fix that buys 80% of the stability on currently-shipped boards". The remaining 20% of stability — cases with very large long-term history on 4 MB boards — is left for Phase 7.

## Why this is the minimum viable deviation

Three alternatives were considered and rejected:

- **"Do nothing until Phase 7"** — leaves WROOM in a crash state on every `/history` load. Urgency signal from #139 comment is unambiguous. Not acceptable.

- **"Do the full #139 fix now"** — violates the "no Phase 7 work in Phase V" invariant materially. The chunked-streaming protocol change touches the history response framing, which affects dashboard parsers, Playwright fixtures, and (per V2-E) auth posture. This is 3–5 sessions of work per the issue body and blocks Phase V closure.

- **"Lower the fixed cap to 20 KB"** — the simplest possible change, but penalises healthy boards (S3 with 8 MB PSRAM sees no benefit, and its history truncates at 20 KB unnecessarily). The adaptive formula is barely more complex and scales correctly across all three SoC classes.

The adaptive formula + client-side defer is the smallest change that closes the urgent WROOM crash while leaving Phase 7's scope intact.

## Version slot and sequencing

**Version:** v7.6.9.4
**Sequence:** After v7.6.9.3 (V3-F — struct audit / Phase V preliminary closure) merges. v7.6.9.4 is the first of three additional mitigation steps before Phase V actually closes.

Three v7.6.9.x mitigations were identified during v7.6.9.0 device testing and deferred from v7.6.9.0's main PR to keep the hotfix scope tight:
- v7.6.9.4 — this step: heap-adaptive history cap + boot sequencing (#139 partial)
- v7.6.9.5 — C3 `httpd_stack_watermark_bytes` investigation (measured at 644 bytes on current builds — near-overflow)
- v7.6.9.6 — polling-mode `/api/status/full` 500 over Cloudflare Tunnel: narrow SEC-ADR RV-03 amendment to re-expose `free_heap` + `uptime_seconds` on public `/api/status`

All three must complete before Phase 7 planning begins. **v7.6.9.6 is the actual Phase V closure step**, not v7.6.9.4.

**Updated version table** (to be inserted at line ~1241 of `Docs/phase-V-implementation-plan.md`):

| Phase V — V1 | v7.6.7.0–v7.6.7.3 | Critical fixes + telemetry |
| Phase V — V2 | v7.6.8.0–v7.6.8.2 | Security hardening |
| Phase V — V3 | v7.6.9.0–v7.6.9.3 | Dashboard enhancements + export/import |
| **Phase V — V4** | **v7.6.9.4** | **Heap-adaptive history cap (#139 partial — OTA-safe mitigation)** |
| **Phase V — V5** | **v7.6.9.5** | **C3 httpd stack watermark investigation** |
| **Phase V — V6** | **v7.6.9.6** | **Polling telemetry: narrow /api/status un-strip + SEC-ADR amendment (Phase V actual closure)** |

v7.6.9.4 is sub-phase "V4" — a one-step mitigation phase. Calling it a distinct sub-phase rather than a V3 addendum makes the plan deviation explicit in git history and in version tagging.

**Decision gate between v7.6.9.3 and v7.6.9.4:** if v7.6.9.3 struct audit found no changes needed (heap ≥ 65 KB gate) AND the WROOM history crash has been reproduced on the current main, v7.6.9.4 proceeds. If WROOM no longer crashes (unlikely but possible if intervening Phase V work freed heap), reassess — the adaptive cap is still a net improvement but urgency decreases.

## Files modified by v7.6.9.4

- `firmware/core/web-handler.h` — adaptive cap in `handle_history_()` and `handle_api_v2_history_()` (two sites, same two-line edit each)
- `dashboard/core/boot.js` — defer initial `loadHistory()` call until after first `loadStatusSnapshot()` resolves
- `Docs/changelog.md` — v7.6.9.4 entry
- `Docs/lessons/bugs-and-lessons-learned.md` — new LESSON-OPS entry on heap-adaptive allocation caps
- Generated artifacts (regenerated, not hand-edited): `dashboard/dashboard.js`, `dashboard/dashboard.html`, `dashboard/dashboard.h`, `dashboard/sensor_history_multi.h` (the fragment edit propagates here via assembly), per-board YAMLs

**Not touched:** `dashboard/sensor_history_multi.h` (never edit directly — Rule 58), `firmware/core/data-model.h`, any NVS-related file, any partition file, any board profile.

## Implementation details — server side

### Current state (`firmware/core/web-handler.h` line 1520 and line 568)

```cpp
size_t est_points = (size_t)nvs_segments * PERSIST_POINTS_PER_SEGMENT
                  + (size_t)buf->count();
size_t est_bytes  = est_points * 20 + 128;

std::string csv;
csv.reserve(std::min(est_bytes, (size_t)60000));
```

### Target state

```cpp
size_t est_points = (size_t)nvs_segments * PERSIST_POINTS_PER_SEGMENT
                  + (size_t)buf->count();
size_t est_bytes  = est_points * 20 + 128;

// v7.6.9.4 (#139 partial): heap-adaptive cap.
// Previous fixed 60 KB cap (v7.6.8.1 V2-E) was sized for C3's ~68 KB free heap
// budget. On WROOM with ~30–40 KB free, a 60 KB reserve exceeds available heap
// and crashes the board. Clamp to free_heap/3 with a 12 KB floor and the
// original 60 KB ceiling preserved for healthy boards.
size_t free_now = esp_get_free_heap_size();
size_t adaptive_cap = free_now / 3;
if (adaptive_cap < 12000) adaptive_cap = 12000;
if (adaptive_cap > 60000) adaptive_cap = 60000;

std::string csv;
csv.reserve(std::min(est_bytes, adaptive_cap));
```

Applied identically at both call sites. The dashboard tolerates truncated CSV gracefully — `parseCompactHistory()` in `live-view/index.js` processes line-by-line with bounds checks.

### Why `free_heap / 3` as the divisor

- One third accounts for (a) the CSV buffer itself, (b) the eventual response buffer the HTTP stack allocates for the final `beginResponse` raw bytes send, and (c) headroom for SSE event buffers and WiFi/BLE RX queues that run concurrently on the same heap.
- Empirically: with C3 at 68 KB free, `/3 = 22 KB`. 22 KB CSV + ~2 KB response framing + ~20 KB peak TCP/SSE overhead = ~44 KB. Leaves ~24 KB margin. Safe.
- With WROOM at 30 KB free, `/3 = 10 KB → floor bumps to 12 KB`. 12 KB + ~6 KB TCP overhead = ~18 KB. Leaves ~12 KB margin. Tight but survivable.
- With S3 at 8 MB PSRAM, divisor math is irrelevant — `est_bytes` is almost always below the 60 KB ceiling, and when it is above, the S3 has plenty of room.

### Why not a hard-coded threshold table per chip

Considered. Rejected because: (1) future board variants (WROVER-32, different flash configs) would need new entries; (2) the divisor approach is self-calibrating across SoC + current-workload combinations; (3) the 12 KB floor and 60 KB ceiling already bake in per-SoC safety by setting the envelope.

## Implementation details — client side

### Current state (`dashboard/core/boot.js` lines ~111–118)

```javascript
// BUG-043-cont (PR2) Fix E: History deferred from 8s to 10s — the sequential initial
// poll (batch=1, 200ms gap, ~30 paths) takes roughly 7-8s on a loaded device.
historyBootstrapTimerId = setTimeout(function() {
  if (!isImportActive()) loadHistory().catch(function(){});
}, 10000);
```

### Target state

```javascript
// v7.6.9.4 (#139 partial): gate initial history load on first status snapshot.
// Fixed 10 s timer was a worst-case estimate. Gating on the status snapshot
// gives us a live signal that the board is (a) responsive, (b) at its steady
// post-boot heap, (c) past the BLE/WiFi settle window. Adds a safety fallback
// timer of 15 s in case /api/status/full stays offline (e.g. auth mismatch).
var historyKicked = false;
function kickHistoryOnce() {
  if (historyKicked || isImportActive()) return;
  historyKicked = true;
  loadHistory().catch(function(){});
}

// Primary trigger: fire after the first loadStatusSnapshot() resolves successfully
// in the boot sequence (already present ~2 s after connectSSE / startPolling).
var firstStatusPromise = loadStatusSnapshot();
if (firstStatusPromise && typeof firstStatusPromise.then === 'function') {
  firstStatusPromise.then(function() { setTimeout(kickHistoryOnce, 1000); });
}

// Safety fallback: if /api/status/full never returns (e.g. 401, timeout),
// still kick history after 15 s so the user sees charts eventually.
historyBootstrapTimerId = setTimeout(kickHistoryOnce, 15000);
```

The existing `setTimeout(function() { loadStatusSnapshot().catch(function(){}); }, 2000);` and similar calls in `boot.js` remain untouched — this change **adds** a trigger, it doesn't replace existing status snapshot calls.

The 1 s delay after status snapshot resolves lets the status-snapshot UI update settle before kicking the history load (they compete for the same render thread briefly).

## Acceptance criteria

- WROOM `/history/office/temp` curl returns 200 with a truncated CSV body (≤ 12 KB) instead of crashing the board.
- C3 `/history/office/temp` curl returns 200 with a CSV body sized to ~22 KB when heap is ~68 KB, and smaller if heap is lower.
- S3 `/history/office/temp` curl returns 200 with a CSV body capped at 60 KB (unchanged ceiling).
- `httpd_stack_watermark_bytes` on C3 after `/history` calls does not regress below its v7.6.9.0 baseline.
- `min_free_heap` on WROOM after 10 minutes of dashboard traffic stays above 15 KB (was approaching 0 / reboot before this fix).
- Dashboard initial load shows history within 15 seconds of page load in both SSE and polling modes (primary trigger path OR fallback).
- All existing Playwright fixtures pass.
- No new Playwright regressions on aggregator fixtures (aggregator proxies call the same adaptive-cap code path).

## Risk assessment

**Risk: LOW-MEDIUM**

- **LOW:** server-side change is 6 lines × 2 sites. Math is simple and conservative. Worst case: cap is smaller than strictly necessary on a healthy board → response truncates a few rows. Dashboard tolerates truncation.
- **MEDIUM:** client-side change alters boot sequencing. Existing timing has been stable since v7.6.4.x. Mitigation: 15 s fallback timer preserves the old behavior if the status snapshot path fails.
- **Regression risk:** Playwright fixtures use a mock server that doesn't exercise `esp_get_free_heap_size()`. Test coverage for the adaptive cap itself is device-only. Agent prompt §8 includes explicit device smoke tests across all three boards to validate.

## Dependencies

- v7.6.9.0 PR #183 must be merged (including hotfix 2 for SRAM/Flash + polling telemetry regressions)
- v7.6.9.1, v7.6.9.2, v7.6.9.3 must be merged or explicitly skipped per their conditional gates

## Closure definition

Phase V is closed when:
- [ ] v7.6.9.3 merged (struct audit / conditional preliminary closure)
- [ ] v7.6.9.4 merged (this addendum's step — #139 partial)
- [ ] v7.6.9.5 merged (C3 stack watermark investigation)
- [ ] v7.6.9.6 merged (polling telemetry + SEC-ADR amendment — **actual closure**)
- [ ] `phaseV-results.md` updated with v7.6.9.4 / v7.6.9.5 / v7.6.9.6 outcomes
- [ ] `phaseV-conclusion-assessment.md` updated to reference all three deviations and their rationales
- [ ] Issue #139 labelled/milestoned per plan Part 0 table — with a comment linking v7.6.9.4 PR and noting partial fix, full fix deferred to Phase 7
- [ ] Issue #139 stays OPEN (partial fix, not closure) with a tick-list of remaining deliverables for Phase 7

## Changelog impact (for the plan document itself)

When this addendum merges:
- Row in the version table at line ~1241 updated
- Line 44 issue-table entry for #139 updated from `Partial v7.6.8.x (auth cap), full fix Phase 7` to `Partial v7.6.8.x (auth cap), partial v7.6.9.4 (adaptive cap + boot sequencing), full fix Phase 7`
- Line 805 V2-E note amended to reference v7.6.9.4 as an additional partial mitigation layer
- Line 1223 decision checklist clarified: "no Phase 7 work is scheduled in Phase V" is restated with the explicit carve-out that v7.6.9.4 delivers OTA-safe mitigations that preserve Phase 7 scope (adaptive cap is not the chunked-streaming fix)

---

_End of Phase V plan addendum for v7.6.9.4._
