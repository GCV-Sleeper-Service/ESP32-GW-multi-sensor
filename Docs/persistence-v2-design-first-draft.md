# Generalized History Persistence — Design Proposal (v8.x)

_Author: Architecture proposal for Invisible_
_Date: 2026-03-19_
_Prerequisite: Phase 4+ complete, BUG-045/046/048 lessons absorbed_
_Repo: [GCV-Sleeper-Service/ESP32-GW-multi-sensor](https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor)_

---

## Table of Contents

1. [Why This Redesign](#1-why-this-redesign)
2. [Constraints](#2-constraints)
3. [Design Principles](#3-design-principles)
4. [Storage Model: Per-Device Segments](#4-storage-model-per-device-segments)
5. [NVS Key Scheme](#5-nvs-key-scheme)
6. [Retention Budgeting](#6-retention-budgeting)
7. [Manifest-Driven Persistence Configuration](#7-manifest-driven-persistence-configuration)
8. [Boot Restore Flow](#8-boot-restore-flow)
9. [Persist Flow](#9-persist-flow)
10. [Import/Export Format](#10-importexport-format)
11. [Migration Path from v7.x](#11-migration-path-from-v7x)
12. [Partition Layout Changes](#12-partition-layout-changes)
13. [Memory Budget](#13-memory-budget)
14. [Sensor Type Catalog](#14-sensor-type-catalog)
15. [What Not to Do](#15-what-not-to-do)
16. [Implementation Phases](#16-implementation-phases)

---

## 1. Why This Redesign

The v7.x persistence engine packs all sensor data into a single `SegmentSnapshot` struct whose
array dimensions are set at compile time by `NUM_SENSORS`. This creates three problems that
compound as the sensor ecosystem grows:

**Adding or removing any device changes the struct size.** `SegmentSnapshot` contains
`temp[NUM_SENSORS][4]` and `hum[NUM_SENSORS][4]`. When `NUM_SENSORS` changes from 3 to 4, every
existing NVS blob becomes physically unreadable — `nvs_get_blob()` returns
`ESP_ERR_NVS_INVALID_LENGTH` because the stored blob is a different byte count than the new
struct. This is not a recoverable schema mismatch — the data is gone unless you build a cross-
schema deserializer. BUG-045/046/048 demonstrated this cascade in production.

**All devices must have the same metric shape.** The current struct hardcodes `temp` and `hum`
arrays. A weather station with four metrics (temp, hum, wind speed, rainfall) or a ping probe
with two (latency, success rate) cannot use this format without wasteful padding or separate
parallel systems.

**Retention is uniform.** All devices share the same segment slots and the same 45-day window.
A leak sensor that only needs 30 days of binary history consumes the same per-slot overhead as
a weather station with four float metrics. There's no way to give environmental sensors more
retention while keeping operational metrics shorter.

The goal is a persistence format where **adding a weather station doesn't destroy your
ThermoPro history**, where **each device's metric count is stored in the blob itself** (not
assumed from a compile-time constant), and where **retention is budgeted per device** based on
available flash.

---

## 2. Constraints

### Hardware

| Resource | Value | Notes |
|---|---|---|
| ESP32-C3 RAM | ~320 KB usable | Single core, no PSRAM |
| Flash total | 4 MB | ESP32-C3 SuperMini |
| History partition (current) | 512 KB | NVS type, dedicated |
| History partition (proposed) | 768 KB | See Section 12 |
| Max NVS key length | 15 chars | ESP-IDF NVS limitation |
| Max NVS blob size | ~4000 bytes | Page-limited; in practice ~1984 bytes safe |
| Firmware binary | ~1.55 MB | Current v7.5.x |
| OTA slot headroom | ~220 KB per slot | Can be reduced safely |

### Software

- No dynamic allocation for core persist/restore paths (ESP32 heap fragmentation risk)
- All struct sizes must be deterministic at compile time
- Boot restore must complete before dashboard serves history (but can yield periodically — BUG-043 pattern)
- Import must handle files up to 200 KB via chunked URL-path transport
- NVS write endurance: ~100K cycles per page; hourly writes × 45 days = ~1080 writes/cycle — acceptable

### Operational

- Users change sensor configurations occasionally (add a probe, swap a dead sensor)
- Configuration changes must not destroy existing history for unchanged devices
- CSV export/import must remain the data portability mechanism
- OTA updates that change metric definitions should preserve data where possible

---

## 3. Design Principles

**1. Per-device isolation.** Each device's history segments are stored under device-specific NVS
keys. Adding device B never touches device A's data. Removing device B frees its NVS keys without
affecting anything else.

**2. Self-describing blobs.** Every segment blob carries its own metric count and metric key list
in the header. The restore path validates the blob against the current manifest, not against a
compile-time constant. A blob written with 2 metrics can be read by firmware expecting 2 metrics
for that device, regardless of how many other devices exist.

**3. Manifest-driven retention.** The v2 manifest declares each device's persistence policy:
`flash` (with priority tier) or `ram_only`. The firmware calculates each device's maximum
retention at boot based on available partition space and priority allocation.

**4. Fixed maximum metric count per blob.** To avoid dynamic allocation in the persist/restore
path, segment blobs use a compile-time maximum: `MAX_PERSIST_METRICS_PER_DEVICE = 6`. This
covers the largest planned sensor type (weather station with 5-6 metrics). Devices with fewer
metrics use a subset of the fixed array; unused slots are zeroed. The blob size is constant per
device within a firmware build.

**5. Graceful degradation on metric mismatch.** If a device's metric count changes between
firmware versions (e.g., a firmware update adds a new metric to weather stations), the restore
path loads the metrics it can match by key and ignores extras. No data loss for the metrics that
still exist.

---

## 4. Storage Model: Per-Device Segments

### DeviceHistoryMeta (one per persistent device)

```cpp
static constexpr uint32_t DEV_HIST_MAGIC = 0x44485632UL;  // "DHV2"
static constexpr uint16_t DEV_HIST_VERSION = 1;

struct DeviceHistoryMeta {
  uint32_t magic = DEV_HIST_MAGIC;
  uint16_t version = DEV_HIST_VERSION;
  uint16_t metric_count;          // metrics persisted for this device
  uint16_t points_per_segment;    // typically 4 (hourly at 15-min intervals)
  uint16_t max_slots;             // retention capacity (calculated at boot from budget)
  uint16_t valid_segments;        // how many slots contain valid data
  uint16_t next_slot;             // ring buffer write cursor
  uint32_t last_persist_epoch;    // dedup guard
  char     device_id[16];         // e.g., "office\0", "wan_ping\0"
};
```

### DeviceSegment (one per device per hour)

```cpp
static constexpr int MAX_PERSIST_METRICS = 6;
static constexpr int PERSIST_POINTS_PER_SEGMENT = 4;  // unchanged from v7.x

struct DeviceSegmentHeader {
  uint32_t magic = DEV_HIST_MAGIC;
  uint16_t version = DEV_HIST_VERSION;
  uint16_t metric_count;          // how many metrics are populated in this blob
  uint16_t points_per_segment;
  uint32_t saved_at_epoch;
  uint32_t first_epoch;
  uint32_t last_epoch;
};

struct DeviceSegment {
  DeviceSegmentHeader header;
  uint16_t counts[MAX_PERSIST_METRICS] = {};
  HistEntry data[MAX_PERSIST_METRICS][PERSIST_POINTS_PER_SEGMENT] = {};
};
// sizeof(DeviceSegment) = 22 + 12 + 192 = 226 bytes (constant regardless of actual metric count)
```

**Why fixed `MAX_PERSIST_METRICS = 6`:** This covers the widest planned sensor (weather station:
temp, humidity, wind speed, wind direction, rainfall, light/UV). A ThermoPro device still writes
a 226-byte blob — the unused metric slots (indices 2–5) contain zeroed counts and data. The
waste is 4 × 36 = 144 bytes per segment per ThermoPro device, but this buys us zero dynamic
allocation and constant blob size.

**Why constant blob size matters:** `nvs_get_blob()` requires the caller to provide the exact
expected size. If blob sizes vary per device, the restore path needs to query blob size first
(extra NVS read) or use dynamic allocation. Constant size means a single stack-allocated
`DeviceSegment` buffer works for every device.

---

## 5. NVS Key Scheme

NVS keys are limited to 15 characters. The scheme must encode both device identity and slot
number.

### Key format

```
dm_{hash}        → DeviceHistoryMeta    (3 + 8 = 11 chars)
ds_{hash}_{slot} → DeviceSegment        (3 + 8 + 1 + 3 = 15 chars max)
```

Where `{hash}` is an 8-character truncated hash of the device ID:

```cpp
static uint32_t device_key_hash_(const char *device_id) {
  // FNV-1a 32-bit hash, truncated to 8 hex chars
  uint32_t h = 0x811c9dc5;
  for (const char *p = device_id; *p; p++) {
    h ^= (uint8_t)*p;
    h *= 0x01000193;
  }
  return h;
}

// "office"   → dm_a3f7b2c1, ds_a3f7b2c1_000 .. ds_a3f7b2c1_719
// "wan_ping"  → dm_8e12d4f0, ds_8e12d4f0_000 .. ds_8e12d4f0_335
```

**Why hashing instead of truncated device IDs:** Device IDs like `first_floor` (11 chars) would
exceed the 15-char key limit when combined with a prefix and slot number. Hashing to 8 hex chars
is collision-resistant for the scale we're dealing with (<20 devices) and leaves room for a
3-digit slot suffix.

**Slot suffix format:** `_{NNN}` — 3 digits, zero-padded. Max 999 slots per device (999 hours =
41.6 days). This is sufficient for all planned retention windows.

### Legacy compatibility key

```
v7_migrated      → uint8_t flag (0 or 1)
```

Set to 1 after one-time migration from v7.x format completes successfully.

---

## 6. Retention Budgeting

### The problem

With per-device segments, total NVS consumption = Σ (slots_per_device × sizeof(DeviceSegment) +
NVS_overhead_per_blob). The partition has a fixed size. We need to divide the budget among
devices intelligently.

### Budget calculation at boot

```
Usable partition bytes = partition_size × 0.85  (15% NVS page overhead)
Per-slot cost = sizeof(DeviceSegment) + NVS_BLOB_OVERHEAD  (≈ 226 + 48 = 274 bytes)
Meta cost per device = sizeof(DeviceHistoryMeta) + NVS_BLOB_OVERHEAD  (≈ 40 + 48 = 88 bytes)
Persistent devices = devices where manifest says history_backend == "flash"

Available for segments = Usable - (persistent_device_count × meta_cost)
```

### Priority tiers

The manifest assigns each persistent device a `persist_priority`:

| Priority | Meaning | Budget share |
|---|---|---|
| `high` | Long-term value (environmental, weather) | 70% of segment budget |
| `normal` | Moderate value (soil moisture, leak) | 20% of segment budget |
| `low` | Operational (ping, host metrics) | 10% of segment budget |

Within each tier, budget is divided equally among devices in that tier.

### Example: 768 KB partition, 5 persistent devices

```
Usable: 768K × 0.85 = 652 KB
Meta: 5 × 88 = 440 bytes ≈ 0.4 KB
Segment budget: 651.6 KB

High tier (70% = 456 KB):
  3 ThermoPro → 152 KB each → 152000/274 = 554 slots = 23.1 days each

Normal tier (20% = 130 KB):
  1 Weather station → 130 KB → 130000/274 = 474 slots = 19.8 days

Low tier (10% = 65 KB):
  1 Ping → 65 KB → 65000/274 = 237 slots = 9.9 days
```

### Reported to user

The `/api/storage-stats` endpoint reports per-device retention:

```json
{
  "partition_bytes": 786432,
  "usable_bytes": 668467,
  "devices": {
    "office":      { "max_days": 23.1, "used_days": 18.4, "slots": 554, "used": 442 },
    "first_floor": { "max_days": 23.1, "used_days": 23.1, "slots": 554, "used": 554 },
    "outside":     { "max_days": 23.1, "used_days": 22.7, "slots": 554, "used": 545 },
    "weather":     { "max_days": 19.8, "used_days": 12.3, "slots": 474, "used": 295 },
    "wan_ping":    { "max_days": 9.9,  "used_days": 5.1,  "slots": 237, "used": 122 }
  }
}
```

---

## 7. Manifest-Driven Persistence Configuration

The v2 manifest already has per-measurement `history` and `history_backend` fields. For v8.x,
we extend the device-level manifest:

```json
{
  "id": "office",
  "name": "Office",
  "category": "environmental",
  "adapter": "thermopro_ble",
  "persist": {
    "backend": "flash",
    "priority": "high"
  },
  "measurements": [
    { "key": "temp_c",       "history": true,  "persist": true },
    { "key": "humidity_pct", "history": true,  "persist": true },
    { "key": "battery_pct",  "history": false, "persist": false },
    { "key": "rssi_dbm",     "history": false, "persist": false }
  ]
}
```

```json
{
  "id": "wan_ping",
  "name": "WAN Latency",
  "category": "network",
  "adapter": "icmp_ping",
  "persist": {
    "backend": "flash",
    "priority": "low"
  },
  "measurements": [
    { "key": "ping_ms",     "history": true, "persist": true },
    { "key": "success_pct", "history": true, "persist": true }
  ]
}
```

```json
{
  "id": "nas_health",
  "name": "NAS Status",
  "category": "system",
  "adapter": "http_ingest",
  "persist": {
    "backend": "ram_only"
  },
  "measurements": [
    { "key": "cpu_pct",  "history": true, "persist": false },
    { "key": "ram_pct",  "history": true, "persist": false },
    { "key": "disk_pct", "history": true, "persist": false }
  ]
}
```

**Rules:**
- `persist.backend = "flash"` → device gets NVS segment storage, budget-allocated retention
- `persist.backend = "ram_only"` → device uses `HistoryBuffer` ring buffers only (24h, lost on reboot)
- Only measurements with `persist: true` are written to flash segments
- `persist: true` measurements must also have `history: true` (persisting without RAM history makes no sense)
- Maximum 6 measurements with `persist: true` per device (`MAX_PERSIST_METRICS` limit)

---

## 8. Boot Restore Flow

```
boot_restore():
  1. Initialize NVS history partition
  2. Check v7_migrated flag — if 0, run migration (Section 11)
  3. For each device in manifest where persist.backend == "flash":
     a. Calculate max_slots from budget (Section 6)
     b. Load DeviceHistoryMeta from dm_{hash}
     c. Validate: magic, version, device_id match
     d. If metric_count in meta != current device's persistent metric count:
        - Log migration message
        - Adjust: keep segments but only restore matching metrics
     e. Restore segments (newest `min(valid_segments, RAM_SEGMENTS)`) into
        the device's HistoryBuffer ring buffers
     f. Yield every 4 segments (BUG-043 pattern)
  4. Mark restore complete
```

### Metric mismatch handling during restore

When a firmware update adds a new metric to a device (e.g., weather station gains UV index):

- The stored segments have `metric_count = 4` (old)
- The current manifest has 5 persistent metrics
- The restore path matches metrics by **position order** in the manifest (metric 0 = temp,
  metric 1 = hum, etc.)
- Metrics 0–3 are restored normally from the stored blob
- Metric 4 (UV index) has no historical data — its HistoryBuffer starts empty
- The DeviceHistoryMeta is updated with the new `metric_count = 5` and persisted

When a metric is removed:

- The stored segments have `metric_count = 5`
- The current manifest has 4 persistent metrics
- The restore path loads metrics 0–3, ignores metric 4 in the blob
- DeviceHistoryMeta updated to `metric_count = 4`

**This handles the common cases without data loss.** Reordering metrics in the manifest is the
dangerous operation — it causes metric identity confusion. The generator should validate that
persistent metric ordering is append-only.

---

## 9. Persist Flow

```
persist_hourly_segment():
  For each device where persist.backend == "flash":
    1. Build DeviceSegment from the device's HistoryBuffer ring buffers
       (export latest PERSIST_POINTS_PER_SEGMENT entries per persistent metric)
    2. Load DeviceHistoryMeta from NVS
    3. Dedup check: skip if last_persist_epoch matches
    4. Write segment to ds_{hash}_{next_slot}
    5. Update meta (next_slot, valid_segments, last_persist_epoch)
    6. Save meta
    7. Yield between devices (BUG-043 pattern)
```

### Slot overflow behavior

When `valid_segments == max_slots`, the ring buffer wraps: `next_slot` overwrites the oldest
segment. The `valid_segments` count stays at `max_slots`.

When the budget changes (e.g., a device is added, reducing per-device allocation), `max_slots`
decreases. If `valid_segments > new_max_slots`, the oldest excess segments become unreachable
(they'll eventually be overwritten). No explicit deletion needed — the ring buffer naturally
reclaims them.

---

## 10. Import/Export Format

### Export: Per-device CSV

Each device exports a separate CSV file. The filename encodes the device ID:

```
history_office_2026-03-19.csv
history_wan_ping_2026-03-19.csv
```

CSV format — columnar, one column per persistent metric:

```csv
epoch,temp_c,humidity_pct
1710264000,23.4,45.2
1710264900,23.5,44.8
1710265800,,45.1
```

Empty cells represent gaps (the metric had no reading for that interval). This is identical
to how the current temp/hum CSVs work, just generalized to N metrics.

### Export: All-devices bundle

The "Export All" button produces a multi-section CSV:

```csv
# device: office
# category: environmental
# metrics: temp_c,humidity_pct
epoch,temp_c,humidity_pct
1710264000,23.4,45.2
...

# device: wan_ping
# category: network
# metrics: ping_ms,success_pct
epoch,ping_ms,success_pct
1710264000,12.3,100
...
```

The `# device:` comment headers allow the import parser to split the file by device.

### Import: Multi-sensor replace

Works as today — wipes the history partition, writes all devices from the CSV. The parser reads
`# device:` headers to route rows to the correct device's segment slots.

### Import: Single-device merge

The existing read-modify-write merge logic generalizes naturally:
1. Build epoch→slot index for the target device (from its segments)
2. For each imported row, find the matching epoch slot
3. Overlay the imported values into the segment
4. Write back modified segments

The merge is per-device — it only touches the target device's NVS keys. Other devices are
completely unaffected. This eliminates the BUG-048 class of failure entirely.

---

## 11. Migration Path from v7.x

### One-time automatic migration at first boot

When firmware with the v8.x persistence engine boots and finds no `v7_migrated` flag:

1. **Read old `hist_meta`** — the v7.x HistoryMeta blob (if present)
2. **For each old segment slot** (0 to `valid_segments`):
   a. Read the v7.x `SegmentSnapshot` blob (fixed size, `NUM_SENSORS` from build)
   b. For each environmental sensor `i` in `[0, NUM_SENSORS)`:
      - Extract `temp[i][*]` and `hum[i][*]` arrays
      - Build a `DeviceSegment` for device `devices[i].id` with 2 metrics
      - Write to `ds_{hash}_{slot}`
   c. Yield every 4 blobs
3. **Write new DeviceHistoryMeta** for each environmental device
4. **Set `v7_migrated = 1`**
5. **Do NOT delete old blobs** — they serve as a safety net for rollback

### Rollback safety

If the user needs to roll back to v7.x firmware:
- The old `hist_meta` and `seg_NNN` keys are still present
- The v7.x firmware ignores the new `dm_*` and `ds_*` keys (unknown keys are harmless in NVS)
- History works as before the upgrade

### Migration time estimate

Reading and rewriting 1080 segments × 3 devices = 3240 NVS operations. At ~2ms per operation
with periodic yields, this takes ~8-10 seconds. Acceptable for a one-time boot event.

---

## 12. Partition Layout Changes

### Current

```csv
history,    data, nvs,      ,         0x80000,     # 512 KB
```

### Proposed

```csv
ota_0,      app,  ota_0,    0x10000,  0x180000,    # 1.5 MB (was 1.69 MB)
ota_1,      app,  ota_1,    ,         0x180000,    # 1.5 MB (was 1.69 MB)
history,    data, nvs,      ,         0xC0000,     # 768 KB (was 512 KB)
```

**Trade-off:** Each OTA slot shrinks by 192 KB (from 1728 KB to 1536 KB). Current firmware binary
is ~1550 KB, which exceeds the proposed 1536 KB OTA slot.

**Resolution options:**
1. Optimize firmware size — the embedded gzip dashboard (~45 KB) is the largest payload.
   Dashboard minification + more aggressive gzip could save 5-10 KB. Removing unused ESPHome
   components could save more.
2. Keep OTA at 0x190000 (1.5625 MB) — gives 768 KB - 128 KB = 640 KB history partition
3. Accept 640 KB (0xA0000) history partition — the budget calculations in Section 6 work at
   640 KB with slightly reduced retention

**Practical recommendation:** Start with **0xA0000 (640 KB)** history partition. This requires
shrinking each OTA slot by only 128 KB (to 0x190000 = 1.5625 MB), which leaves ~15 KB headroom
for the current firmware binary. If firmware grows, optimize the dashboard payload.

**Partition changes require a full reflash** — OTA cannot update the partition table. This is
acceptable for a major version upgrade (v7.x → v8.x).

### Budget at 640 KB

```
Usable: 640K × 0.85 = 544 KB
3 ThermoPro (high, 70%) = 380 KB → 380K/(3×274) = 462 slots/device = 19.3 days
1 Weather (normal, 20%) = 109 KB → 109K/274 = 397 slots = 16.5 days
1 Ping (low, 10%) = 54 KB → 54K/274 = 199 slots = 8.3 days
```

Reasonable retention for all device types. Environmental sensors get ~19 days instead of 45,
but with CSV export the user can archive periodically.

---

## 13. Memory Budget

### RAM: per-device HistoryBuffer instances

Each persistent metric gets a `HistoryBuffer` (96 entries × 8 bytes = 768 bytes). RAM-only
metrics also get `HistoryBuffer` instances.

| Configuration | HistoryBuffers | RAM |
|---|---|---|
| 3 ThermoPro (2 metrics each) | 6 | 4.5 KB |
| + 1 Weather (4 metrics) | 10 | 7.5 KB |
| + 1 Ping (2 metrics) | 12 | 9.0 KB |
| + 1 Host (4 metrics, RAM-only) | 16 | 12.0 KB |
| + 2 Leak (1 metric each) | 18 | 13.5 KB |

13.5 KB for 18 history buffers. Well within the ~320 KB budget (~4.2%).

### Stack: DeviceSegment for persist/restore

`sizeof(DeviceSegment)` ≈ 226 bytes. Allocated once on the stack during persist/restore loops.
Not a concern.

### Heap: migration (one-time)

The v7.x migration needs to read old `SegmentSnapshot` (~230 bytes) and write new `DeviceSegment`
(~226 bytes). Both can be stack-allocated sequentially. No heap allocation needed.

---

## 14. Sensor Type Catalog

This table maps each planned sensor type to its persistence characteristics:

| Sensor Type | Category | Adapter | Metrics (persistent) | Metrics (RAM-only) | Persist Priority | Notes |
|---|---|---|---|---|---|---|
| ThermoPro TP357 | environmental | thermopro_ble | temp_c, humidity_pct | battery_pct, rssi_dbm | high | Core use case |
| Weather station | environmental | weatherflow / ecowitt | temp_c, humidity_pct, wind_speed_ms, rainfall_mm | wind_dir_deg, uv_index | high | 4-6 metrics |
| Leak sensor | environmental | zigbee_binary | leak_detected | battery_pct, rssi_dbm | normal | Binary metric (0/1) |
| Soil moisture | environmental | zigbee_analog | moisture_pct | battery_pct, rssi_dbm | normal | Single analog metric |
| Ultrasound distance | environmental | uart_distance | distance_cm | signal_quality | normal | Single analog metric |
| WAN ping | network | icmp_ping | ping_ms, success_pct | — | low | Operational metric |
| Host health | system | http_ingest | — | cpu_pct, ram_pct, disk_pct, swap_pct | ram_only | Pushed via /api/ingest |

**Design validation:** The widest persistent sensor is the weather station at 4-6 metrics. With
`MAX_PERSIST_METRICS = 6`, every planned type fits without waste exceeding 50% of blob capacity.

---

## 15. What Not to Do

### Do not use variable-length blobs

`nvs_get_blob()` requires the caller to know the expected size, or to call it twice (once to
query size, once to read). Variable-length blobs also require heap allocation for the read
buffer. The constant-size `DeviceSegment` eliminates both problems.

### Do not store metric keys in every segment blob

The metric identity is established in `DeviceHistoryMeta` and the manifest. Repeating key
strings in every hourly segment wastes ~50-100 bytes per blob × 1000 blobs = 50-100 KB. Use
positional indexing (metric 0, 1, 2...) within segments and resolve keys from the meta/manifest.

### Do not attempt cross-schema blob deserialization

If a device's metric count changes between firmware versions, don't try to parse old blobs with
the new layout. The positional restore approach (Section 8) handles this cleanly: restore what
matches, ignore the rest. Old blobs will naturally cycle out as new segments overwrite them.

### Do not make partition size a runtime variable

The partition table is burned at flash time. Don't build features that assume the partition might
be different sizes at runtime. Calculate budgets from the actual partition size at boot, but
document the expected layout.

### Do not persist non-environmental history to flash by default

RAM-only is the right default for operational metrics (ping, host health). Let the user opt in to
flash persistence via manifest configuration. This keeps the default flash footprint manageable
and avoids unnecessary write wear.

---

## 16. Implementation Phases

### Phase A — Foundation (v8.0.x)

1. Define `DeviceHistoryMeta` and `DeviceSegment` structs
2. Implement per-device NVS key scheme with hash-based keys
3. Implement retention budget calculator (reads manifest, computes per-device max_slots)
4. Implement per-device persist and restore loops
5. Update `/api/storage-stats` to report per-device retention
6. Keep v7.x `SegmentSnapshot` code alive in parallel (for migration)

**Deliverable:** New persistence engine works for environmental devices. Old data preserved via
parallel codepath until migration is validated.

### Phase B — Migration (v8.1.x)

1. Implement one-time v7→v8 migration in boot path
2. Add `v7_migrated` flag
3. Test migration with real device data (export before, migrate, verify after)
4. Test rollback (flash v7.x firmware, verify old data still accessible)
5. Remove v7.x `SegmentSnapshot` codepath after migration is proven

**Deliverable:** Seamless upgrade from v7.x. No manual data export/import required.

### Phase C — Multi-type persistence (v8.2.x)

1. Enable flash persistence for non-environmental devices (weather, leak, soil)
2. Implement per-device CSV export/import
3. Implement multi-device bundle export/import with `# device:` headers
4. Dashboard: per-device storage stats and retention display
5. Update partition table (optional — only if 512 KB is insufficient)

**Deliverable:** Any sensor type can persist to flash with manifest-controlled retention.

### Phase D — Optimization (v8.3.x)

1. Retention auto-tuning: monitor actual write rates and adjust budgets
2. Defragmentation: NVS partition health monitoring and preemptive erase
3. Compression: optional zlib compression of segment blobs for space savings
4. Smart export scheduling: automatic CSV export to SD card or HTTP push before
   retention window expires

**Deliverable:** Production-hardened persistence for long-term deployments.

---

_End of design proposal._
