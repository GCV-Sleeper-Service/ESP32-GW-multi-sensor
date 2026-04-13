# Aggregator ADR-001 — Satellite History Storage: Proxy vs Local Copy

**Status:** Accepted  
**Date:** 2026-04-12  
**Context:** Issue #162 — Decision: Aggregator satellite history storage — proxy vs local copy  
**Depends on:** Issue #161 (proxy bug fix — V1-A in Phase V)  
**Author:** Phase V planning, informed by issue #162 body and architecture review  

---

## Context

The aggregator can display satellite sensor history on its dashboard via one of two architectural strategies:

1. **On-demand proxy** (current, v7.6.x): The aggregator fetches history from each satellite in real-time when the dashboard requests it, via the `/api/aggregator/proxy/{gw_id}/history/{device}/{metric}` endpoint.

2. **Pull and store locally** (Phase 7 option): The aggregator periodically fetches and stores satellite history in its own NVS partition, serving it directly without querying the satellite.

Issue #162 opened this as a design question. Issue #161 revealed a critical bug in the existing proxy path (silent 502 with no diagnostic when the satellite is unreachable). Before this decision can be made formally, #161 must be fixed (V1-A in Phase V).

---

## Options Considered

### Option 1 — On-Demand Proxy (Current, keep for v7.6.x)

**Description:**  
`handle_aggregator_proxy_()` in `firmware/core/web-handler.h` fetches from the satellite's `/api/v2/history/` URL on demand, using `fetch_to_buffer()` into the 32 KB `s_proxy_tmp` buffer, and returns the result to the dashboard.

**Current implementation issues (fixed in V1-A):**
- Returns bare 502 with no body when satellite is unreachable — dashboard shows empty chart
- No timeout parameter — uses `fetch_to_buffer()` default (5 s), which is too short for history fetches
- Returns 502 when satellite has no history — should return 200 with empty body

**Pros:**
- No storage change required — no NVS partition resize, no schema change
- Satellite is the single source of truth — no sync protocol, no divergence
- Works with current `SegmentSnapshot`-based persistence on the satellite
- Zero SRAM overhead on aggregator (beyond the existing 32 KB `s_proxy_tmp` buffer)
- Simple: one fetch per dashboard history request

**Cons:**
- Satellite offline = no history available to the dashboard (hard failure, not degraded)
- Timing-sensitive: a 15-second timeout means the dashboard waits up to 15 s for history to load
- History not available for bundle export (Phase 7 multi-satellite export cannot include satellite history)
- 32 KB buffer cap: satellite history responses > 32 KB are truncated with a 502 error

**Verdict for v7.6.x:** ✅ Keep — after V1-A fix, this is a viable short-term path.

---

### Option 2 — Pull and Store Locally (Target for Phase 7)

**Description:**  
The aggregator periodically pulls satellite history (all metrics, all segments) and stores it in its own NVS partition (dedicated `agg_hist` namespace or a separate partition). The dashboard reads history from the aggregator's local store, not from the satellite.

**Pros:**
- History survives satellite offline — dashboard can show historical data even if the satellite is unreachable
- Enables bundle export in Phase 7 (single ZIP with all satellites' full history)
- Removes the 15-second dashboard wait — history is pre-fetched in the polling cycle
- S3 aggregator has 16 MB flash and 8 MB PSRAM — ample resources for multi-satellite history storage
- Decouples dashboard load time from satellite reachability

**Cons:**
- Requires a partition table change on the aggregator (adding or resizing the history partition) — not OTA-safe, requires re-flash
- Requires a sync protocol: what triggers a pull? (discovery-based vs scheduled)
- Schema mismatch: if satellite firmware and aggregator firmware are at different versions with different `SegmentSnapshot` layouts, data corruption is possible
- Aggregator NVS format must be decided: binary NVS blobs (current) vs CSV files vs a new binary format
- Re-flash logistics: changing the partition table requires a physical re-flash of the aggregator board
- Aggregator stores N × satellite history: at ~244 KB per device per year (current monolithic model), 4 satellites × 244 KB = ~1 MB NVS flash just for history

**Verdict for v7.6.x:** ❌ Deferred — partition table change is OTA-unsafe; complexity is too high for Phase V.

---

## Decision

**Option 1 — On-demand proxy — is confirmed as the v7.6.x short-term path.**

After the V1-A fix (proxy 502 diagnostic and timeout), the proxy path is viable for all current deployment scenarios where satellites are reliably on the LAN.

**Option 2 — Pull and store locally — is designated Phase 7 pre-work, targeted for v7.7.1.x.**

The Phase 7 per-device persistence engine (`Docs/v7.7-implementation-plan.md`) already plans the NVS partition rework needed for satellite history storage. Option 2 implementation must be deferred until after the partition table change is executed as part of Phase 7.

---

## Consequences

### Immediate (Phase V)

- V1-A in Phase V fixes the proxy to:
  - Return 200 + empty body when satellite has no history (not 502)
  - Return 502 + JSON body `{"error":"upstream_fetch_failed","url":"..."}` when satellite is unreachable
  - Use a 15-second timeout (configurable via new `timeout_s` parameter on `fetch_to_buffer()`)
  - Log `ESP_LOGW` when a fetch fails so the issue is visible in the serial log

- Issue #162 is closed when `Docs/decisions/AGG-ADR-001-satellite-history-storage.md` is committed (V3-E in Phase V).

### Phase 7

- The aggregator history storage design (Option 2) must be fully specified as part of Phase 7 planning.
- The implementation must answer the open questions below before beginning.

### Dashboard behaviour after V1-A

| Satellite state | Pre-V1-A proxy behaviour | Post-V1-A proxy behaviour |
|---|---|---|
| Online, has history | ✅ 200 + CSV | ✅ 200 + CSV |
| Online, no history | ❌ 502 (empty body) | ✅ 200 + empty body |
| Offline | ❌ 502 (empty body) | ✅ 502 + JSON error |
| History > 32 KB | ❌ 502 (truncation) | ❌ 502 + JSON error (unchanged — Phase 7 fix) |

---

## Open Questions for Phase 7

These questions must be answered before beginning Option 2 implementation:

### Q1 — NVS Partition Budget for Multi-Satellite History on S3

At the current `SegmentSnapshot` cost (~244 KB per device per year at 1080 segments), how large does the aggregator NVS history partition need to be to store N satellites × M months of history?

- 2 satellites × 6 months: ~244 KB × 2 = ~488 KB
- 4 satellites × 12 months: ~244 KB × 4 = ~976 KB
- 8 satellites × 12 months: ~244 KB × 8 = ~1.95 MB

The S3 has 16 MB flash. A 4 MB dedicated aggregator history partition is feasible. This must be verified against the Phase 7 capacity study (see `Docs/phase-V-capacity-study.md` §Aggregator Capacity section).

### Q2 — Sync Trigger: Discovery-Based vs Scheduled

How does the aggregator know when to pull satellite history?

- **Discovery-based:** Pull when a new satellite is added (initial sync), then incremental pull every N hours
- **Scheduled:** Pull from all satellites on a fixed schedule (e.g., every 6 hours)
- **Hybrid:** Discovery triggers initial full pull; scheduled poll does incremental

The sync trigger must not block the polling task (`agg_poll` at 10,240 B stack), which runs on a 30-second cycle. A separate `agg_hist_sync` task is likely required.

### Q3 — Schema Mismatch Handling

If the satellite firmware and aggregator firmware are at different versions with different `SegmentSnapshot` layouts (e.g., satellite is on v7.6.x monolithic schema, aggregator is on v7.7.x per-device schema), how is the mismatch detected and handled?

Options:
- Store the satellite firmware version alongside the pulled history blobs
- Add a schema version field to `SegmentSnapshot` (already planned in Phase 7)
- Reject pulls from mismatched satellite versions until satellite is upgraded

### Q4 — Storage Format: Binary NVS Blobs vs CSV

The current NVS persistence uses binary `SegmentSnapshot` blobs. For multi-satellite aggregator storage:

- **Binary blobs:** Compact, fast, but opaque — difficult to inspect or migrate
- **CSV:** Human-readable, easy to export, but ~3× larger than binary
- **Hybrid:** Binary for hot storage (recent 30 days), CSV for cold archive

Phase 7 must choose one format. The Phase 7 capacity study sections in `Docs/phase-V-capacity-study.md` provide the size analysis needed to make this choice.

### Q5 — Re-Flash Logistics for Partition Table Change

Changing the partition table requires erasing the flash, flashing the new partition table, and reflashing the firmware. This cannot be done via OTA. The operator workflow must be:

1. Download new firmware binary + partition table
2. Connect USB to aggregator board
3. Run `esptool.py` flash command
4. Verify boot and satellite list recovery from NVS backup

This is a one-time maintenance event per aggregator board. The Phase 7 implementation plan must include operator documentation for this re-flash procedure.

---

## Related Documents

- `Docs/v7.7-implementation-plan.md` — Phase 7 per-device persistence engine (includes aggregator history storage as a v7.7.1.x deliverable)
- `Docs/v7.7-v7.8-persistence-architecture.md` — §5, §12, §14–16 — aggregator storage design
- `Docs/phase-V-capacity-study.md` — §5 Aggregator Capacity — NVS budget analysis
- Issue #161 — Proxy bug fix (V1-A prerequisite)
- Issue #162 — This decision (closed by this ADR)

---

_End of AGG-ADR-001._
