# Phase V — Memory and Flash Capacity Study

**Date:** 2026-05-05 (expanded from 2026-04-12 original)  
**Scope:** All 6 ESP32 board variants — current and future sensor/device type combinations  
**Purpose:** Inform Phase 7 (v7.7.x) per-device persistence engine design, partition sizing, and sensor expansion planning  
**Measurement source:** `Docs/board-measurement-log-v7.6.10.md` — all values are measured at ESPHome 2026.4.1 / ESP-IDF 5.5.4  
**No code changes — research and planning document only**

---

## Executive Summary

| Board | Measured free_heap | Max persistent metrics (safe heap) | Max live-only metrics | BUG-084 max concurrent | Notes |
|---|---|---|---|---|---|
| ESP32-C3 SuperMini (400 KB SRAM) | 58,456 B | ~7–8 | ~400+ | 4 | Heap floor: 58 KB. Each persistent metric costs ~804 B static. |
| ESP32-WROOM-32D (520 KB SRAM) | 38,760 B | ~9–10 | ~500+ | 4 | More SRAM than C3 but tighter measured heap (long uptime). |
| ESP32-S3 DevKitC N16R8 (512 KB + 8 MB PSRAM) | 53,432 B (int) | 50+ (PSRAM-backed) | 1000+ | 8 | Heap floor: 100 KB internal. PSRAM absorbs dynamic allocations. |
| ESP32-S3 SuperMini (512 KB + 2 MB PSRAM) | 123,156 B (int) | 30+ (PSRAM-backed) | 1000+ | 8 | Best satellite free_heap. 2 MB PSRAM. |
| ESP32-C6 SuperMini (512 KB SRAM) | 150,332 B | ~15–18 | ~600+ | 4 | Highest non-PSRAM free_heap. ⚠️ 91.6% flash on 4 MB. |
| ESP32-C5 WROOM-1U (384 KB + 8 MB PSRAM) | 32,908 B (int) | ~8 (low internal heap) | 1000+ (PSRAM) | 8 | Lowest internal heap. ⚠️ BLE antenna issue. |

**Current production firmware** (v7.6.6.8) uses:
- ESP32-C3: 11 persistent metrics across 5 sensors (3 env × 2 + 1 ping × 2 + 1 system × 3) = 868 B × 11 = ~9,548 B static history buffers
- After V1-B (OPT-02): 8 persistent metrics (delete NAS history) = ~6,432 B

**Key recommendations:**
1. ESP32-C3 should be limited to **8 persistent metrics maximum** in production deployments
2. Binary sensors should use `EventLog` (Phase 7), not `HistoryBuffer` — saves 748 B per binary metric
3. Phase 7 NVS partition should be 640 KB for 4 MB boards, 1.5 MB for 8 MB boards, 3 MB for 16 MB boards
4. Aggregator (S3) can store up to 8 satellites' full 45-day history in a 4 MB NVS partition

---

## §1 — Per-Metric Cost Model

### Static SRAM per persistent metric

```
sizeof(HistoryBuffer):
  buf_[96]  = 96 × sizeof(HistEntry) = 96 × 8 B = 768 B
  head_     = 4 B (int)
  count_    = 4 B (int)
  Total     = 776 B

sizeof(MetricState):
  current_value      = 4 B (float)
  accumulator        = 4 B (float)
  sample_count       = 4 B (int)
  valid              = 1 B (bool)
  last_update_epoch  = 4 B (uint32_t)
  history pointer    = 4 B (pointer)
  padding            = ~7–11 B (compiler alignment)
  Total              ≈ 28 B

Total per persistent metric:
  776 B (HistoryBuffer, static global) + 28 B (MetricState, embedded in SensorEntity)
  = ~804 B
```

**Note:** `HistoryBuffer` instances are static globals (allocated in BSS at compile time, not on the heap). They are guaranteed to be present from boot. The 804 B figure is therefore **static SRAM cost** that reduces available heap from the moment the firmware starts.

### Live-only metric cost

A live-only metric (no `HistoryBuffer`, `history = nullptr`) costs only:
```
sizeof(MetricState) ≈ 28 B (embedded in SensorEntity, also static)
```

### SensorEntity overhead (one-time per device)

```
struct SensorEntity:
  id[32]           = 32 B
  name[64]         = 64 B
  category         = 4 B (enum)
  metric_count     = 4 B (int)
  metric_defs ptr  = 4 B (const pointer)
  metric_states[MAX_METRICS_PER_DEVICE]  = 4 × 28 B = 112 B
  Total            ≈ 220 B per device (for MAX_METRICS_PER_DEVICE=4)
```

`SensorEntity` instances are also static (the `devices[]` array).

### Task stack costs (one-time, not per metric)

| Task | Stack size | Measured peak (v7.6.10.0) | Notes |
|---|---|---|---|
| httpd task | 16,384 B | ~3,460 B (C3), ~3,200 B (WROOM), ~6,350 B (S3) | 16 KB override via local component. S3 regression: ESPHome 2026.4.1 SSE. |
| ping_adapter task | 4,096 B | TBD | |
| agg_poll task | 10,240 B | 10,240 B (unchanged) | AGGREGATOR_ENABLED only; Phase 7 history sync must remain a separate task. |
| hist_delete task | 8,192 B | 8,192 B | On-demand, transient maintenance task. |
| import deferred task | 8,192 B | 8,192 B | V1-D import task; created only during import. |

**v7.6.10.0 findings:** The httpd stack watermark varies significantly by board:

| Board | httpd_stack_wm | Used | Headroom | Headroom % |
|---|---|---|---|---|
| C3 SuperMini | 12,924 B | ~3,460 B | 12,924 B | 79% |
| WROOM-32D | 13,188 B | ~3,196 B | 13,188 B | 80% |
| S3 DevKitC N16R8 | 10,036 B | ~6,348 B | 10,036 B | 61% |
| S3 SuperMini | 12,512 B | ~3,872 B | 12,512 B | 76% |
| C6 SuperMini | 12,820 B | ~3,564 B | 12,820 B | 78% |
| C5 WROOM-1U | 12,728 B | ~3,656 B | 12,728 B | 78% |

**S3 DevKitC watermark regression:** Dropped from 12,528 B (v7.6.9.5) to 10,036 B
(v7.6.10.0) — a 2,492 B increase in stack usage. Caused by ESPHome 2026.4.1's new
SSE internals. The S3 SuperMini does NOT show this regression (12,512 B), suggesting
the SSE code path is aggregator-specific. Still above the 10,000 B threshold but
should be monitored on future ESPHome upgrades.

### NVS flash per metric per segment

```
Current monolithic model (SegmentSnapshot):
  sizeof(HistEntry) = 8 B (uint32_t epoch + float value)
  Per segment, per metric series: 96 entries × 8 B = 768 B
  Plus SegmentSnapshot header/metadata overhead: ~100–150 B shared across all metrics
  For 11 current metrics: (11 × 768) + 150 = ~8,598 B per segment
  Per metric per segment: ~8,598 / 11 ≈ ~782 B (amortised)

  At 1080 segments (45 days × 24 segments/day):
  Total NVS for 11 metrics: 1080 × 8,598 B ≈ ~9.3 MB

  ⚠️ This exceeds the current 256 KB NVS partition — segments are evicted using a
  ring-buffer scheme. Only the most recent ~32 segments are retained in practice
  at the current 256 KB NVS size.

Phase 7 DeviceSegment model (planned):
  Per device, per segment: sizeof(DeviceSegment) ≈ 226 B per device
  (restructured: one segment entry per device-metric pair, not a monolithic snapshot)
  At 1080 segments × 1 device: 1080 × 226 B ≈ ~244 KB per device per year

  With 640 KB NVS partition (Phase 7 target for 4 MB boards):
  Usable NVS after system overhead (~100 KB): ~540 KB
  Devices at full retention: 540 KB / 244 KB ≈ 2.2 devices at full year retention
  Or: 5 devices × ~108 KB each ≈ 3.5 months retention per device
```

---

## §2 — Board-by-Board Analysis

### §2.1 — ESP32-C3 SuperMini

**Specifications:**
- SRAM: 400 KB (363 KB usable after ROM/stack/WiFi/BT reserved)
- PSRAM: None
- Flash: 4 MB
- Typical free heap at boot (current firmware v7.6.6.8): ~55–65 KB
- After Phase V V1-B (NAS history removed): ~57–67 KB

**Static SRAM allocation breakdown (current v7.6.6.8):**

| Component | Size |
|---|---|
| ESPHome runtime + WiFi stack | ~220 KB |
| ESPHome IDF static data | ~40 KB |
| Firmware static globals (devices[], MetricDefs) | ~8 KB |
| HistoryBuffer × 11 (current) | ~8,536 B (~8.3 KB) |
| httpd task stack | 16,384 B |
| ping_adapter task stack | 4,096 B |
| ESPHome component stacks | ~10 KB |
| Available heap at boot | ~55–65 KB |

**After V1-B (remove 3 NAS HistoryBuffers, ~2,328 B gain):**
- HistoryBuffer × 8 = ~6,208 B
- Available heap at boot: ~57–67 KB

**Maximum persistent metrics on C3 (safe heap ≥ 65 KB):**

At 804 B per persistent metric, and targeting 65 KB minimum free heap:
- Current firmware uses ~55–65 KB free heap
- Each additional persistent metric costs 804 B static (reduces heap by 804 B)
- Starting from ~65 KB (post-V1-B + optimisations target): 0 B headroom for additional persistent metrics without compromising the 65 KB floor

**Conservative safe limit: 8 persistent metrics on C3.** The current 8 (post-V1-B) are at the practical ceiling. Any new persistent sensor added to a C3 must remove an existing one.

**Maximum live-only metrics on C3:**

At 28 B per MetricState (static, not heap): live-only metrics are essentially free from a heap perspective. The constraint is the fixed-size `devices[]` array and `MAX_METRICS_PER_DEVICE` compile-time constant.

Practical limit: ~20–30 live-only metrics across all sensors (limited by `devices[]` array size and code complexity, not SRAM).

**NVS flash capacity on C3 (current 256 KB partition):**

At ~782 B per metric per segment (amortised):
- With 8 metrics: 8 × 768 B = 6,144 B per segment (excluding header)
- 256 KB / 6,144 B ≈ 41 segments maximum
- At 15-minute intervals: 41 segments × 15 min = ~10 hours of full history

**With Phase 7 640 KB partition:**
- 640 KB / 6,144 B ≈ 104 segments
- 104 × 15 min = ~26 hours of full history on C3

**Note:** The current 96-point in-memory ring buffer (24 hours at 15-min intervals) cannot be fully persisted in 256 KB. Phase 7's 640 KB target allows approximately 26 hours — more than the in-memory window, which is the correct design target.

---

### §2.2 — ESP32-S3 DevKitC1-N16R8

**Specifications:**
- Internal SRAM: ~512 KB
- PSRAM: 8 MB (external, via SPIRAM)
- Flash: 16 MB
- Typical free heap at boot (aggregator firmware): ~100–150 KB internal + 7+ MB PSRAM

**Key difference from C3:** Dynamic heap allocations (std::string, vectors, JSON parsing) can overflow to PSRAM automatically. This means the S3 can hold far more persistent metrics without heap pressure.

**Maximum persistent metrics on S3:**

Static `HistoryBuffer` globals are in BSS (internal SRAM), not PSRAM. However, with 512 KB internal SRAM and generous overhead budgets:
- Available for HistoryBuffers: ~200 KB after WiFi/BT/stack reserves
- At 776 B per HistoryBuffer: 200 KB / 776 B ≈ ~257 HistoryBuffers

**Safe practical limit: 50 persistent metrics on S3** (with comfortable headroom and room for the aggregator's `SatelliteCache[]` array).

**NVS flash capacity on S3 (current partition):**

The aggregator has a 16 MB flash. A 4 MB NVS partition is feasible for Phase 7:
- 4 MB / ~8 KB per segment (8 metrics) ≈ 512 segments per satellite
- At 15-minute intervals: 512 × 15 min ≈ 5.3 days per satellite
- For 4 satellites: 4 × 4 MB = 16 MB — this would require the entire flash for NVS, which is impractical

**Realistic aggregator history budget:**
- Dedicated 4 MB NVS partition on S3
- Per satellite history at Phase 7 DeviceSegment model (~226 B per device per segment):
  - 2 devices per satellite × 1080 segments/year = 2 × 244 KB = 488 KB per satellite
  - 4 MB / 488 KB ≈ 8 satellites at full 45-day retention
- **Conclusion: S3 aggregator can store 4–8 satellites' full 45-day history in a 4 MB partition**

---

### §2.3 — ESP32 WROOM-32D (4 MB flash)

**Specifications:**
- SRAM: 520 KB (vs 400 KB on C3 — 120 KB advantage)
- PSRAM: None
- Flash: 4 MB
- Estimated free heap at boot (current firmware): ~80–95 KB

**Maximum persistent metrics on WROOM-32D:**

The WROOM-32D has 120 KB more SRAM than the C3. This translates to approximately:
- 120 KB / 776 B ≈ ~154 additional HistoryBuffers theoretically available
- Practical safe limit (targeting ≥ 80 KB free heap): ~12–15 persistent metrics

**Summary:** The WROOM-32D is substantially more capable than the C3 for history persistence. A WROOM-32D satellite can support a weather station (7 persistent metrics) plus environmental sensors without heap pressure.

---

### §2.4 — ESP32 with 8 MB Flash

**Specifications:** Same SRAM as WROOM-32D (520 KB), 8 MB flash.

**NVS flash capacity increase:**

With Phase 7, an 8 MB board could have a 1.5 MB NVS partition:
- 1.5 MB / ~8 KB per segment (8 metrics) ≈ 192 segments
- At 15-minute intervals: 192 × 15 min ≈ 48 hours of full history per metric
- This comfortably covers the 24-hour in-memory window with a full day of NVS backup

**Maximum persistent metrics:** Same as WROOM-32D (~12–15).

---

### §2.5 — ESP32 with 16 MB Flash

**Specifications:** Same SRAM as WROOM-32D (520 KB), 16 MB flash.

**NVS flash capacity increase:**

With Phase 7, a 16 MB board could have a 3 MB NVS partition:
- 3 MB / ~8 KB per segment ≈ 384 segments
- At 15-minute intervals: 384 × 15 min ≈ 96 hours (4 days) of full history per metric

**Use case:** Best fit for a satellite running a weather station (7 persistent metrics) with long-term history requirements. The 3 MB partition gives 4 days of full 7-metric history in NVS.

---

## §3 — Sensor Type Analysis

### §3.1 — Environmental Sensor (2 persistent metrics)

- Metrics: `temp` (°C), `hum` (%)
- History enabled: Both
- SRAM cost: 2 × 804 B = 1,608 B static
- NVS cost per segment: 2 × 768 B = 1,536 B
- **Current production type.** Well within C3 limits. Multiple env sensors are supported.

### §3.2 — Network Ping Sensor (2 persistent metrics)

- Metrics: `ping_ms` (ms), `success_pct` (%)
- History enabled: Both
- SRAM cost: 2 × 804 B = 1,608 B static
- **Current production type.** Same cost as environmental. One ping sensor per C3 is safe.

### §3.3 — System Health Sensor / NAS (4 metrics, 3 persistent)

- Metrics: `cpu_pct` (persistent), `ram_pct` (persistent), `disk_pct` (persistent), `uptime_hrs` (live-only)
- SRAM cost: 3 × 804 B + 28 B = 2,440 B static
- **Current production type.** After V1-B, the 3 NAS history buffers are removed from the C3 firmware, saving 2,328 B. The NAS system sensor is live-only on C3 after V1-B.

### §3.4 — Binary Sensor (1 metric, history optional)

- Metrics: `state` (0 or 1)
- History enabled: Depends on use case (see §6 for EventLog recommendation)
- SRAM cost (with HistoryBuffer): 804 B static
- SRAM cost (with EventLog, Phase 7): ~100–150 B (see §6)
- **Future type.** Not implemented in v7.6.x. Phase 7 design decision required.

### §3.5 — Weather Station (7 persistent metrics)

- Metrics: `temp`, `hum`, `pressure`, `wind_speed`, `wind_gust`, `illumination`, `rain_period`
- History enabled: All 7
- SRAM cost: 7 × 804 B = 5,628 B static
- NVS cost per segment: 7 × 768 B = 5,376 B
- **Future type.** Only feasible on WROOM-32D or S3 (C3 would exceed safe heap floor if combined with other sensors).

**C3 viability:** Adding a weather station (7 new persistent metrics) to a C3 with the current firmware (8 existing metrics post-V1-B) would add 5,628 B static, pushing total HistoryBuffer usage to ~11.8 KB and reducing available heap below the 65 KB floor. **Not recommended on C3.**

**WROOM-32D viability:** A weather station alone (7 metrics) uses 5,628 B static on a WROOM-32D, leaving ~80+ KB heap free. ✅ Safe.

### §3.6 — Power Measurement Sensor (7 metrics, 4 persistent)

- Metrics: `amps` (persistent), `volts` (persistent), `watts` (persistent), `energy_kwh` (persistent), `energy_24h` (live-only), `energy_session` (live-only), `energy_tariff` (live-only)
- SRAM cost: 4 × 804 B + 3 × 28 B = 3,300 B static
- NVS cost per segment: 4 × 768 B = 3,072 B
- **Future type.** C3: viable if existing metrics allow headroom (e.g., 4 env metrics + 4 power metrics = 8 total persistent → within C3 limit).

---

## §4 — Maximum Sensors by Mix (Table)

The following table shows how many sensors of each type a satellite can safely support, for three board categories.

**Assumptions:**
- "Safe" = free heap at boot ≥ 65 KB (C3) or ≥ 80 KB (WROOM) or ≥ 100 KB internal (S3)
- HistoryBuffer cost: 776 B static each
- C3 headroom for new HistoryBuffers post-V1-B: ~2 KB (≈ 2–3 additional persistent metrics)
- WROOM-32D headroom: ~18 KB (≈ 22 additional persistent metrics)
- S3 headroom: ~200 KB internal SRAM (≈ 257 HistoryBuffers, effectively unlimited for sensors)

| Sensor combination | Persistent metrics | SRAM cost (B) | C3 ✅/❌ | WROOM-32D ✅/❌ | S3 ✅/❌ |
|---|---|---|---|---|---|
| 3 env sensors (current C3 baseline) | 6 | 4,656 | ✅ | ✅ | ✅ |
| 3 env + 1 ping (current C3 full) | 8 | 6,208 | ✅ (at limit) | ✅ | ✅ |
| 3 env + 1 ping + 1 binary (EventLog) | 8 + event | ~6,300 | ✅ | ✅ | ✅ |
| 4 env + 1 ping | 10 | 7,760 | ❌ (>65 KB floor) | ✅ | ✅ |
| 1 weather station | 7 | 5,432 | ⚠️ (marginal) | ✅ | ✅ |
| 1 weather + 1 env | 9 | 6,984 | ❌ | ✅ | ✅ |
| 1 weather + 1 ping | 9 | 6,984 | ❌ | ✅ | ✅ |
| 1 power + 2 env | 8 | 6,208 | ✅ (at limit) | ✅ | ✅ |
| 2 power + 1 env | 10 | 7,760 | ❌ | ✅ | ✅ |
| 5 env sensors | 10 | 7,760 | ❌ | ✅ | ✅ |
| Aggregator: 4 satellites each 8 metrics | 32 (proxied) | N/A | ❌ (satellite role) | N/A | ✅ |

**❌ entries on C3:** Any combination exceeding 8 persistent metrics is prohibited on ESP32-C3. The plan step V1-B (removing NAS history) is specifically designed to make room within this ceiling.

---

## §5 — Aggregator Capacity for Satellite History Storage

This section answers Phase 7 planning question: how many satellites' full history can the S3 aggregator store locally after Option 2 (pull-and-store, from ADR AGG-ADR-001) is implemented?

**S3 aggregator flash budget:**

| Partition | Current size | Phase 7 target |
|---|---|---|
| NVS (system config, satellite list) | ~20 KB | ~20 KB |
| NVS history (satellite history storage) | N/A (current) | 4 MB (new dedicated partition) |
| Firmware OTA slot 0 | ~1.5 MB | ~1.5 MB |
| Firmware OTA slot 1 | ~1.5 MB | ~1.5 MB |
| SPIFFS/LittleFS | ~512 KB | ~512 KB |
| Total flash used | ~3.5 MB | ~7.5 MB |
| Available on 16 MB S3 | ~12.5 MB | ~8.5 MB remaining |

**Satellite history storage at Phase 7 DeviceSegment model:**

Assumption: 2 sensor devices per satellite (1 env + 1 ping), each with 2 persistent metrics.

```
Per satellite per year:
  Devices: 2
  Metrics per device: 2
  Segments per year: 1080 (24 × 45 days)
  Bytes per device per segment: ~226 B (Phase 7 DeviceSegment)
  Per satellite per year: 2 devices × 1080 segments × 226 B = ~488 KB

4 MB NVS history partition:
  Available (after NVS overhead ~100 KB): ~3.9 MB
  Satellites at full year retention: 3.9 MB / 488 KB ≈ 8 satellites
  Satellites at 45-day retention: same 8 satellites (45-day = 1080 segments is the design target)
```

**Aggregator with 8 satellites × 8 metrics per satellite:**

```
8 metrics per satellite × 226 B × 1080 segments = ~1.95 MB per satellite per year
4 MB / 1.95 MB ≈ 2 satellites at full retention

For 4 satellites at 8 metrics: 4 × 1.95 MB = ~7.8 MB — requires 8 MB NVS partition
```

**Recommendation:** For S3 aggregators tracking ≤ 4 satellites with ≤ 8 metrics each at 45-day retention, a 4 MB NVS history partition is sufficient. For higher loads, scale to 8 MB. Given 16 MB total flash on the S3 N16R8, this is achievable within the available flash budget.

---

## §6 — Binary Sensor: HistoryBuffer vs EventLog

### Current HistoryBuffer model applied to binary sensors

A binary sensor (leak detector, motion sensor, light switch) has one metric with two possible values: 0 (off/no event) or 1 (on/event).

If a `HistoryBuffer` with 96 points at 15-minute intervals is used:
- Cost: 776 B static SRAM (same as any other persistent metric)
- Efficiency: extremely low — 96 × 8 B = 768 B stores 96 float readings, most of which are 0.0 or 1.0
- Temporal resolution: 15-minute granularity — a 2-second leak event is invisible between samples
- False negatives: a leak that starts and stops within one 15-minute interval may produce 0.0 at the sample time

**Verdict: `HistoryBuffer` is a poor fit for binary sensors.**

### Proposed EventLog model (Phase 7)

An event log stores only state-change transitions, not periodic samples:

```cpp
struct EventEntry {
  uint32_t epoch;   // 4 B — when the state changed
  uint8_t  state;   // 1 B — new state (0 or 1)
  uint8_t  _pad[3]; // 3 B — padding for alignment
};                  // = 8 B per event (same size as HistEntry, convenient)

struct EventLog {
  static constexpr int CAP = 20; // 20 events is typically sufficient
  EventEntry events_[CAP];       // 20 × 8 B = 160 B
  int head_;                     // 4 B
  int count_;                    // 4 B
  // Total: 168 B
};
```

**EventLog cost: ~168 B** vs **HistoryBuffer cost: 776 B** — a saving of **608 B per binary sensor**.

**Additional advantages of EventLog:**
- Captures exact transition times (second precision, not 15-minute granularity)
- A 2-second leak event is captured — no false negatives
- 20 transitions cover 10 on/off cycles — sufficient for most binary sensor patterns
- NVS persistence: 20 × 8 B = 160 B per log vs 768 B per series — **79% smaller**

**Recommendation for Phase 7:** Binary sensors (leak, motion, door, light switch, relay) should use `EventLog`, not `HistoryBuffer`. The `MetricState.history` pointer should be typed as a union or the metric definition should carry a `metric_type` field distinguishing `HISTORY_RING` from `HISTORY_EVENT`.

**Migration from HistoryBuffer:** No migration needed since binary sensors are a new Phase 7 sensor type. No existing NVS data to migrate.

---

## §7 — Residual Risks

### Risk R-01: C3 Heap Floor

**Risk:** Any firmware change that adds persistent metrics to a C3 satellite without removing existing ones will push the heap below 65 KB, potentially causing allocation failures during WiFi reconnection or history fetch.

**Rule for implementers:** On ESP32-C3, the maximum persistent metric count is 8. This is a **hard ceiling**, not a soft guideline. New sensor types on C3 must be configured as live-only unless an existing persistent metric is removed.

### Risk R-02: Phase 7 Partition Table Change Required

**Risk:** Increasing the NVS partition size (from 256 KB to 640 KB for C3, or adding a 4 MB history partition on S3) requires a full re-flash (not OTA). If Phase 7 ships the new firmware via OTA without the new partition table, the firmware will boot correctly but NVS reads/writes will fail or corrupt data.

**Mitigation:** Phase 7 must ship a re-flash utility and clear documentation. OTA must be disabled for the Phase 7 partition-table change PR.

### Risk R-03: SegmentSnapshot Size Increase

**Risk:** Phase 7 introduces new sensor types (weather station, power meter, binary sensor with EventLog) that expand the `SegmentSnapshot` or replace it with `DeviceSegment`. Any schema change that increases the per-segment size reduces the number of segments that fit in the NVS partition.

**Rule for implementers:** Phase 7 must specify the exact `DeviceSegment` size and validate that the target NVS partition accommodates the required retention period before finalising the schema.

### Risk R-04: S3 PSRAM May Obscure C3 Bugs

**Risk:** Development and testing on the S3 aggregator can produce code that works correctly on S3 but fails on C3 due to heap exhaustion. PSRAM overflow of dynamic allocations masks allocation failures that would occur on C3.

**Mitigation:** All satellite firmware changes must be tested on C3 hardware before merging. Phase V acceptance criteria for each step explicitly require free heap verification on C3.

### Risk R-05: Aggregator Option 2 History Pull May Block Polling Task

**Risk:** If Phase 7 aggregator history pull runs on the `agg_poll` task (10,240 B stack, 30-second cycle), a slow satellite history fetch (up to 15 s for large history) would block the polling cycle and delay live sensor updates for all satellites.

**Mitigation (Phase 7):** Implement history sync as a separate `agg_hist_sync` task with its own stack and trigger mechanism, independent of the `agg_poll` task.

---

## §8 — Partition Size Recommendations for Phase 7

| Board flash | Current NVS size | Phase 7 NVS system partition | Phase 7 NVS history partition | Rationale |
|---|---|---|---|---|
| 4 MB (C3, WROOM-32D) | 256 KB | 256 KB | 640 KB (new) | 640 KB ≈ 104 segments × 8 metrics = 26 hours full history |
| 8 MB (WROOM-32D variant) | 256 KB | 256 KB | 1.5 MB (new) | 1.5 MB ≈ 192 segments × 8 metrics = 48 hours full history |
| 16 MB (S3, ESP32-16) | 256 KB | 512 KB | 4 MB (new) | 4 MB supports 8 satellites × 45-day history (aggregator role) |

**Phase 7 partition table template (4 MB board):**

```
nvs,      data, nvs,     0x9000,  0x6000  (24 KB — system NVS, satellites, config)
otadata,  data, ota,     0xF000,  0x2000
ota_0,    app,  ota_0,   0x11000, 0x180000
ota_1,    app,  ota_1,   0x191000,0x180000
nvs_hist, data, nvs,     0x311000,0xA0000  (640 KB — history partition)
```

**Phase 7 partition table template (16 MB S3 aggregator):**

```
nvs,      data, nvs,     0x9000,  0x10000  (64 KB — system NVS)
otadata,  data, ota,     0x19000, 0x2000
ota_0,    app,  ota_0,   0x20000, 0x200000
ota_1,    app,  ota_1,   0x220000,0x200000
nvs_hist, data, nvs,     0x420000,0x400000  (4 MB — aggregator satellite history)
spiffs,   data, spiffs,  0x820000,0x80000   (512 KB)
```

---

## §9 — Phase 7 Implementation Constraints

The following constraints are derived from this capacity study and must be honoured by the Phase 7 per-device persistence engine:

1. **C3 maximum persistent metrics: 8.** Phase 7 code must enforce or document this limit.
2. **Phase 7 `DeviceSegment` size must be verified against the target NVS partitions** before the schema is finalised.
3. **Binary sensors must use `EventLog`, not `HistoryBuffer`.** The `MetricDef` struct should carry a `history_type` enum (`HISTORY_RING` / `HISTORY_EVENT`).
4. **Aggregator history partition must be separate from the system NVS partition.** Mixing history data with config data in the same 256 KB partition (as in v7.6.x) is not viable at Phase 7 scale.
5. **History pull for Phase 7 Option 2 must run in a task separate from `agg_poll`** to avoid blocking live sensor updates.
6. **OTA must be disabled for the Phase 7 partition-table change.** A re-flash utility must be provided with clear operator documentation.

---

## §10 — Six-Board Measured Capacity Table (v7.6.10.0)

All values measured at ESPHome 2026.4.1 / ESP-IDF 5.5.4 on actual hardware. Source: `Docs/board-measurement-log-v7.6.10.md`.

### Build Outputs

| Board | Chip | Arch | Flash | Binary | RAM % | Flash % | OTA Headroom |
|---|---|---|---|---|---|---|---|
| C3 SuperMini | ESP32-C3 | RISC-V | 4 MB | 1,428,928 B | 18.5% | 80.7% | 340 KB |
| WROOM-32D | ESP32 | Xtensa LX6 | 4 MB | 1,279,395 B | 22.0% | 72.3% | 490 KB |
| S3 DevKitC N16R8 | ESP32-S3 | Xtensa LX7 | 16 MB | 934,715 B | 37.7% | 29.7% | 2.1 MB |
| S3 SuperMini | ESP32-S3 | Xtensa LX7 | 4 MB | 1,305,072 B | 20.4% | 73.7% | 464 KB |
| C6 SuperMini | ESP32-C6 | RISC-V | 4 MB | 1,620,928 B | 20.5% | 91.6% | ⚠️ 145 KB |
| C5 WROOM-1U | ESP32-C5 | RISC-V | 8 MB | 1,662,064 B | 22.0% | 52.8% | 1.5 MB |

**Key observation:** WiFi 6 + 802.15.4 boards (C6, C5) have ~192–233 KB larger binaries than WiFi 4 boards (C3, WROOM, S3). This is the radio driver stack code, not application firmware.

### Runtime Heap

| Board | SRAM | PSRAM | free_heap | min_free_heap | httpd_wm | Safe Concurrent |
|---|---|---|---|---|---|---|
| C3 SuperMini | 400 KB | None | 58,456 | 47,616 | 12,924 | 4 |
| WROOM-32D | 520 KB | None | 38,760 | 15,936 | 13,188 | 4 |
| S3 DevKitC N16R8 | 512 KB | 8 MB OPI | 53,432 | 8,398,704 | 10,036 | 8 |
| S3 SuperMini | 512 KB | 2 MB quad | 123,156 | 2,209,636 | 12,512 | 8 |
| C6 SuperMini | 512 KB | None | 150,332 | 152,820 | 12,820 | 4 |
| C5 WROOM-1U | 384 KB | 8 MB quad | 32,908 | 8,420,784 | 12,728 | 8 |

---

## §11 — Cross-Architecture Comparison: RISC-V vs Xtensa

### RISC-V boards: C3 (single-core 160 MHz), C6 (single-core 160 MHz), C5 (single-core 240 MHz)

RISC-V boards use unified memory — there is no separate IRAM/DRAM split. All code that fits runs from SRAM, the rest executes from flash. This simplifies memory management but means there's no IRAM optimization lever (LESSON-OPS-131 is N/A for RISC-V).

httpd stack watermarks are consistent: 12,728–12,924 B across all three RISC-V boards, suggesting ~3,400–3,650 B peak stack usage. The 16 KB stack override provides 78–79% headroom.

### Xtensa boards: WROOM (dual-core LX6 240 MHz), S3 (dual-core LX7 240 MHz)

Xtensa boards have separate IRAM and DRAM. The S3 shows `IRAM: 100.0%` — all 16,384 B of IRAM is consumed. Overflow code executes from flash (slightly slower, acceptable for this workload). The WROOM could theoretically use `sram1_as_iram: true` to gain 40 KB IRAM, but this subtracts from DRAM and is counterproductive (LESSON-OPS-131).

**S3 DevKitC stack anomaly:** The S3 DevKitC N16R8 shows a significantly lower httpd watermark (10,036 B) than all other boards (12,512–13,188 B). This is a 2,492 B regression from v7.6.9.5 and is unique to the aggregator role — the S3 SuperMini (satellite) shows 12,512 B. The cause is ESPHome 2026.4.1's new SSE internals, which only affect the aggregator's SSE event stream generation.

### Heap behavior difference

| Architecture | Heap trend | Notes |
|---|---|---|
| RISC-V (C3/C6) | Stable after boot | free_heap settles within 30–60s |
| RISC-V (C5) | Declining for 2.5+ min | 50 KB → 33 KB over 165s. Needs longer observation. |
| Xtensa (WROOM) | Stable but tight | min_free_heap of 15,936 B after extended uptime |
| Xtensa (S3) | Stable with PSRAM overflow | Internal heap stays ~53 KB; dynamic allocs go to PSRAM |

---

## §12 — PSRAM Impact: Measured Comparison

| Board | PSRAM | Internal free_heap | Total free_heap | Crash under 8 concurrent | Effect |
|---|---|---|---|---|---|
| C3 SuperMini | None | 58,456 | 58,456 | ❌ CRASH | Baseline non-PSRAM behavior |
| WROOM-32D | None | 38,760 | 38,760 | ❌ CRASH | Tightest non-PSRAM board |
| C6 SuperMini | None | 150,332 | 164,936 | (untested at 8) | Most capable non-PSRAM |
| S3 SuperMini | **2 MB quad** | 123,156 | 2,225,904 | ✅ PASS | Even 2 MB PSRAM eliminates crash |
| S3 DevKitC | **8 MB OPI** | 53,432 | 8,452,136 | ✅ PASS | Standard aggregator configuration |
| C5 WROOM-1U | **8 MB quad** | 32,908 | 8,434,968 | ✅ PASS | PSRAM saves C5 despite low internal heap |

**Key finding:** PSRAM of any size (2 MB, 8 MB) completely eliminates BUG-084 crash susceptibility. The crash occurs when heap drops below the ~15–20 KB WiFi/LWIP minimum. With PSRAM, dynamic allocations overflow to PSRAM before internal heap reaches critical levels.

**Trade-off:** PSRAM is ~6× slower than internal SRAM (~40 MHz SPI bus vs ~240 MHz internal bus). For a 15-second sensor poll cycle and 30-second dashboard refresh, this latency is irrelevant.

---

## §13 — BUG-084: Concurrency as a Capacity Constraint

BUG-084 establishes that non-PSRAM boards have a hard limit of 4 concurrent HTTP connections. This has planning implications:

### Scenario analysis for non-PSRAM satellites

| Scenario | Connections | C3/WROOM/C6 | S3/C5 (PSRAM) |
|---|---|---|---|
| Dashboard open (SSE + status poll) | 2 | ✅ | ✅ |
| Dashboard + aggregator polling | 3–4 | ✅ (at limit) | ✅ |
| Dashboard + aggregator + Prometheus scrape | 5–6 | ⚠️ Risk zone | ✅ |
| Two dashboard tabs | 4 | ✅ (at limit) | ✅ |
| Two dashboards + aggregator | 5–6 | ❌ Likely crash | ✅ |

**Phase 7 implication:** The per-device persistence engine must not add long-running HTTP connections to the satellite. The deferred task pattern (httpd handler → xTaskCreate → NVS operation) is mandatory precisely because it keeps the httpd connection short-lived.

**Aggregator socket scaling:** For S3 aggregators with PSRAM, the current `CONFIG_LWIP_MAX_SOCKETS: 15` supports up to 8 satellites + 2 dashboard sessions. For larger deployments, this value should be increased in the board profile's `sdkconfig_options`.

---

## §14 — Satellite Role Variants: BLE-Disabled Configurations

Two upcoming use cases don't need the BLE radio stack:

### §14.1 — Zigbee-only satellite (C5/C6)

When C5/C6 boards receive data from Zigbee sensors via 802.15.4, BLE passive scanning is unnecessary overhead. The ESP-IDF BLE stack (NimBLE on RISC-V) consumes ~40–60 KB of heap.

| Board | Current free_heap (BLE enabled) | Estimated free_heap (BLE disabled) | Persistent metric headroom |
|---|---|---|---|
| C6 (512 KB, no PSRAM) | 150,332 B | ~190–210 KB | ~25–30 metrics |
| C5 (384 KB, 8M PSRAM) | 32,908 B (internal) | ~80–90 KB (internal) | ~15 metrics (internal only) |

Disabling BLE on the C5 would transform it from "danger zone" (32 KB internal) to "comfortable" (80+ KB internal). For Zigbee-only C5 satellites, this is the recommended configuration.

### §14.2 — WiFi-only satellite (any board)

Weather stations and power meters that expose REST APIs over WiFi don't need BLE at all. The satellite queries these devices via HTTP client (`fetch_to_buffer()`). Disabling BLE frees the same ~40–60 KB.

| Board | Current free_heap | Estimated with BLE disabled | Persistent metrics gained |
|---|---|---|---|
| C3 (400 KB) | 58,456 B | ~100–120 KB | +5–7 additional |
| WROOM (520 KB) | 38,760 B | ~80–100 KB | +5–7 additional |
| C6 (512 KB) | 150,332 B | ~190–210 KB | +5–7 additional |

**Implementation:** Remove `esp32_ble_tracker` component from the board profile's sensor config. The `render_sensor_config.py` pipeline already uses substitution-driven generation — a `capabilities.ble: false` flag could drive this. This is a Phase 7 or Phase E task.

### §14.3 — Binary sensor satellite (C6 with 4 MB flash)

Binary sensors (door/window contacts, motion sensors, leak detectors) have a distinct capacity profile. They use `EventLog` (§6) at ~168 B per sensor instead of `HistoryBuffer` at 776 B. Firmware code additions for binary sensor support are minimal compared to environmental sensors.

The C6 with 4 MB flash (91.6% OTA utilization) is a suitable candidate for binary-sensor-only firmware:

| Metric | Environmental firmware | Binary sensor firmware (estimated) |
|---|---|---|
| HistoryBuffer per metric | 776 B | N/A |
| EventLog per sensor | N/A | ~168 B |
| Code size delta | Baseline | ~+5–10 KB (event log code) |
| Flash % impact on C6 4MB | 91.6% | ~92–93% (still within limit) |
| Sensors supported (C6 heap) | ~15–18 env metrics | ~50+ binary sensors |

The C6 with 8 MB flash is the primary C6 satellite for environmental sensor workloads. The 4 MB variant is retained for lightweight binary sensor deployments.

---

_End of Phase V Capacity Study._
