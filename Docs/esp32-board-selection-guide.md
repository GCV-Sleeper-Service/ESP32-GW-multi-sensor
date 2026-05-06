**The C3's 400 KB SRAM with no PSRAM is the root of every heap crash you've hit.** WiFi + BLE + ESPHome eat ~160 KB before your code even starts. 
History buffers for 4 sensors take another ~48 KB. That leaves ~58 KB free (measured at v7.6.10.0), which is enough for normal operation but razor-thin during concurrent dashboard loads or large CSV exports. 
A 5th sensor or heavier aggregator caching would push it over.

**The S3 N16R8 solves this permanently** for ~$12. 
The 8 MB PSRAM acts as overflow — ESP-IDF automatically allocates from it when internal SRAM runs low. 
Your existing aggregator on the S3 stays above 200 KB free heap even with 2 satellites polling, precisely because the satellite caches live in PSRAM.

**BUG-084 changes the operational picture for non-PSRAM boards.** Eight concurrent HTTP connections crash C3 and WROOM via heap exhaustion — not stack overflow, but the heap dropping below WiFi/LWIP's ~15–20 KB operating minimum. The safe limit is 4 concurrent connections. This means a dashboard open in one tab while the aggregator polls the same satellite is fine (3–4 connections), but automated monitoring tools hammering the API alongside a dashboard could crash the board. PSRAM-equipped boards handle 8 concurrent connections without issue.

**The C6 is the best non-PSRAM satellite**, with 150 KB free heap (2.5× the C3) and 512 KB SRAM. But its WiFi 6 + 802.15.4 radio stacks consume 91.6% of its 4 MB OTA partition — dangerously close to the limit for future firmware growth.

**The C5 has a BLE reception problem.** It compiled, booted, and served the dashboard, but did not receive any BLE sensor data during testing. Until the root cause is resolved (likely early ESP-IDF C5 BLE support or missing IPEX antenna), it cannot replace a C3/C6 for BLE sensor workloads.

For the **Zigbee future**, the C6 remains the board to watch. It's the only mature chip that does WiFi 6 + BLE + 802.15.4 (Zigbee/Thread) in one package, with 512 KB SRAM. 
The C5 adds 5 GHz WiFi on top of that, which matters in congested environments, but its BLE stack needs more maturity before it's production-ready for this project.

**The C61 is not worth buying** — 256 KB SRAM is too small for a gateway role, it has no Thread certification, and no ESPHome support.

**The P4 is interesting but premature** — 768 KB SRAM + 32 MB PSRAM is massive, but it has no WiFi/BT (needs a C6 companion chip), and ESPHome support just landed. Good for experimentation, not production yet.

The practical recommendation: stock up on **S3 N16R8** boards for aggregators and **C6 Mini** boards for future Zigbee-capable satellites. 
Keep using C3 SuperMini for cost-sensitive satellite deployments where 3 sensors or fewer is the target.
The S3 SuperMini (with 2 MB PSRAM) is the new sweet spot for a satellite that won't crash under load — 123 KB free heap and PSRAM overflow protection.

# ESP32 Board Selection Guide for Multi-Sensor Gateway

_Date: 2026-05-05 (updated from 2026-03-25 original)_
_Context: ESP32-GW multi-sensor gateway project — satellite and aggregator roles_
_Based on: Espressif datasheets, project field experience (v7.6.10.0+), ESPHome 2026.4.1 compatibility_
_Measurement data: `Docs/board-measurement-log-v7.6.10.md` — all values are measured, not estimated_

---

## 1. Chip Family Specifications

| Chip | CPU | Cores | MHz | SRAM | PSRAM Support | Flash (typical) | WiFi | BLE | 802.15.4 (Zigbee/Thread) | LP Core | ESPHome Support |
|------|-----|-------|-----|------|---------------|-----------------|------|-----|--------------------------|---------|-----------------| 
| **ESP32** | Xtensa LX6 | 2 | 240 | 520 KB | Module-dependent | 4 MB | 802.11n (WiFi 4) | 4.2 + Classic | No | No | ✅ Mature |
| **ESP32-C3** | RISC-V | 1 | 160 | 400 KB | No | 4 MB | 802.11n (WiFi 4) | 5.0 | No | No | ✅ Mature |
| **ESP32-S3** | Xtensa LX7 | 2 | 240 | 512 KB | Yes (up to 16 MB OPI) | 4–32 MB | 802.11n (WiFi 4) | 5.0 | No | No | ✅ Mature |
| **ESP32-C5** | RISC-V | 1 | 240 | 384 KB | Yes (up to 8 MB) | 4–8 MB | 802.11ax (WiFi 6, dual-band 2.4+5 GHz) | 5.0 | **Yes** | Yes (48 MHz) | ⚠️ Early (ESP-IDF 5.4+) |
| **ESP32-C6** | RISC-V | 1 | 160 | 512 KB | Optional | 4–16 MB | 802.11ax (WiFi 6, 2.4 GHz) | 5.3 | **Yes** | Yes (20 MHz) | ⚠️ Since ESPHome 2025.6 |
| **ESP32-C61** | RISC-V | 1 | 160 | 256 KB | 2 MB pseudo-RAM | 2–4 MB | 802.11ax (WiFi 6, 2.4 GHz) | 5.0 | Partial (no Thread cert) | Yes | ❌ Not yet |
| **ESP32-P4** | RISC-V | 2 | 400 | 768 KB | Yes (up to 32 MB) | 16–32 MB | **None** | **None** | No | Yes (40 MHz) | ⚠️ Since ESPHome 2025.6 |

---

## 2. Measured Fleet Data (v7.6.10.0 / ESPHome 2026.4.1)

This table contains **measured values** from production firmware running on actual hardware, not estimates.

### Build Outputs

| Board | Chip | Flash | Binary | RAM % | Flash % | OTA Headroom |
|---|---|---|---|---|---|---|
| ESP32-C3 SuperMini | ESP32-C3 | 4 MB | 1,428,928 B | 18.5% | 80.7% | 340 KB |
| ESP32-WROOM-32D | ESP32 | 4 MB | 1,279,395 B | 22.0% | 72.3% | 490 KB |
| ESP32-S3 DevKitC N16R8 | ESP32-S3 | 16 MB | 934,715 B | 37.7% | 29.7% | 2.1 MB |
| ESP32-S3 SuperMini | ESP32-S3 | 4 MB | 1,305,072 B | 20.4% | 73.7% | 464 KB |
| ESP32-C6 SuperMini | ESP32-C6 | 4 MB | 1,620,928 B | 20.5% | **91.6%** | ⚠️ 145 KB |
| ESP32-C5 WROOM-1U | ESP32-C5 | 8 MB | 1,662,064 B | 22.0% | 52.8% | 1.5 MB |

### Runtime Telemetry

| Board | free_heap | min_free_heap | httpd_stack_wm | Stress (4 conn) | Stress (8 conn) | BLE Reception |
|---|---|---|---|---|---|---|
| C3 SuperMini | 58,456 | 47,616 | 12,924 | ✅ PASS | ❌ CRASH (BUG-084) | ✅ Working |
| WROOM-32D | 38,760 | 15,936 | 13,188 | ✅ PASS | ❌ CRASH (BUG-084) | ✅ Working |
| S3 DevKitC N16R8 | 53,432 | 8,398,704 | 10,036 | ✅ PASS | ✅ PASS | ✅ Working |
| S3 SuperMini | 123,156 | 2,209,636 | 12,512 | ✅ PASS | ✅ PASS | ✅ Working |
| C6 SuperMini | 150,332 | 152,820 | 12,820 | ✅ PASS | (not tested) | ✅ Working |
| C5 WROOM-1U | 32,908 | 8,420,784 | 12,728 | (not tested) | ✅ PASS | ⚠️ **NOT WORKING** |

_Note: S3 and C5 min_free_heap includes PSRAM. Internal-only free_heap is the operative constraint._

---

## 3. Recommended Boards by Role

### Satellite Gateway — Small, low-cost, single-purpose

A satellite's job is straightforward: receive BLE sensor data, serve a dashboard, and expose an API. Memory pressure comes from the dashboard serving (~45KB gzipped), history buffers (24h RAM + 45 days NVS), and WiFi stack overhead.

**BUG-084 operational limit:** Non-PSRAM satellites crash under 8 concurrent HTTP connections. Keep to 4 concurrent connections maximum (dashboard + aggregator polling is fine; automated monitoring tools must throttle).

| Board | Chip | SRAM | PSRAM | Flash | Price | Recommended For | Measured free_heap | Notes |
|-------|------|------|-------|-------|-------|-----------------|-------------------|-------|
| **ESP32-C3 SuperMini** | C3 | 400 KB | None | 4 MB | $2–4 | ✅ Default satellite (1–3 BLE sensors) | 58,456 B | Current project baseline. Proven. BUG-084: max 4 concurrent HTTP connections. 80.7% flash. |
| **ESP32-S3 SuperMini (N4R2)** | S3 | 512 KB | **2 MB** | 4 MB | $4–6 | ✅ **Best value satellite** | 123,156 B | 2× the C3's free heap plus PSRAM overflow. Handles 8 concurrent connections. 73.7% flash. |
| **ESP32-C6 Mini** | C6 | 512 KB | None | 4 MB | $3–5 | ✅ Future satellite with Zigbee sensors | 150,332 B | Highest non-PSRAM free heap. WiFi 6 + 802.15.4. ⚠️ 91.6% flash — limited growth room. BUG-084: max 4 concurrent. |
| **ESP32-C5 WROOM-1U** | C5 | 384 KB | 8 MB | 8 MB | $6–10 | ⚠️ Re-test pending (antenna was not attached) | 32,908 B (internal) | BLE failure likely due to missing IPEX antenna. Re-test with antenna + C5 SuperMini planned. WiFi/Zigbee work. Low internal heap — BLE disable may be needed for Zigbee-only config. |
| **ESP32-WROOM-32D** | ESP32 | 520 KB | None | 4 MB | $3–6 | ⚠️ Legacy satellite | 38,760 B | Tightest non-PSRAM heap. BUG-084: max 4 concurrent. Good if you have them; don't buy new. |
| **ESP32-C3 SuperMini Plus** | C3 | 400 KB | None | 4 MB | $3–5 | ✅ Satellite with better antenna | (same as C3) | External antenna option for placement inside enclosures. Same chip as C3 SuperMini. |

### Aggregator Gateway — More memory, multi-satellite polling

An aggregator runs the full satellite pipeline plus satellite polling (HTTP fetches), response caching (`SatelliteCache` = ~6.5KB per satellite), and a richer dashboard with per-gateway tabs. Aggregator role requires PSRAM (enforced in firmware).

| Board | Chip | SRAM | PSRAM | Flash | Price | Recommended For | Notes |
|-------|------|------|-------|-------|-------|-----------------|-------|
| **ESP32-S3-DevKitC-1 N16R8** | S3 | 512 KB | **8 MB OPI** | 16 MB | $10–15 | ✅ **Primary aggregator** | Current production aggregator. httpd_stack_wm dropped to 10,036 B after ESPHome 2026.4.1 (still above 10,000 threshold). 29.7% flash — maximum growth room. |
| **ESP32-S3-DevKitC-1 N32R8** | S3 | 512 KB | **8 MB OPI** | 32 MB | $12–18 | ✅ Aggregator with future growth | Same as N16R8 but 32 MB flash. Useful if dashboard grows or Phase 7 needs larger NVS partitions. |
| **ESP32-S3 SuperMini (N4R2)** | S3 | 512 KB | **2 MB** | 4 MB | $4–6 | ⚠️ Light aggregator (≤4 satellites) | 123,156 B free_heap, 2 MB PSRAM. Enough for a small aggregator but the 4 MB flash and 73.7% utilization leave little room. Cap at 4 satellites. |
| **ESP32-S3 WROOM-2 (N32R16)** | S3 | 512 KB | **16 MB OPI** | 32 MB | $15–20 | ✅ Heavy aggregator (8+ satellites) | Maximum PSRAM for the S3. If you plan to aggregate 8 satellites with full caching, this gives the most headroom. |
| **ESP32-C6-DevKitC-1 N16** | C6 | 512 KB | None | 16 MB | $8–12 | ⚠️ Light aggregator (2–3 satellites) | Single-core limits concurrent HTTP handling. No PSRAM means satellite cache competes with heap. |
| **ESP32-P4 + C6 combo** | P4+C6 | 768 KB + 32 MB PSRAM | **32 MB** | 16–32 MB | $25–40 | 🔮 Future premium aggregator | P4 has no WiFi — needs a C6 co-processor. ESPHome P4 support is very early. |

### Zigbee Sensor Bridge — Future role for C5/C6

When the project adds direct Zigbee sensor support (bypassing BLE entirely), the satellite needs an 802.15.4 radio. This rules out C3 and S3.

| Board | Chip | Zigbee | Thread | WiFi | Notes |
|-------|------|--------|--------|------|-------|
| **ESP32-C6 Mini** | C6 | ✅ | ✅ | WiFi 6 (2.4 GHz) | Best near-term option. 150 KB free heap. ⚠️ 91.6% flash on 4MB boards. |
| **ESP32-C5 DevKitC-1** | C5 | ✅ | ✅ | WiFi 6 (2.4+5 GHz) | Adds 5 GHz band. ⚠️ BLE not working — Zigbee may have similar maturity issues. |
| **ESP32-C61** | C61 | Partial | ❌ No cert | WiFi 6 (2.4 GHz) | **Not recommended.** 256 KB SRAM is too tight. No Thread. No ESPHome support. |

---

## 4. Memory Pressure Analysis

This section uses **measured values** from v7.6.10.0 firmware running ESPHome 2026.4.1 / ESP-IDF 5.5.4 on actual hardware.

### ESP32-C3 (400 KB SRAM, no PSRAM) — Measured

| Memory consumer | Approximate size | Notes |
|----------------|-----------------|-------|
| WiFi + BLE stack (ESP-IDF) | ~120 KB | Fixed overhead, non-negotiable |
| ESPHome framework | ~40 KB | Event loop, components, logging |
| Dashboard gzip payload | ~45 KB | Served from flash, but decompression needs temp buffers |
| SensorEntity array (4 devices) | ~8 KB | Scales with device count |
| HistoryBuffer (24h × 4 sensors × 2 metrics) | ~48 KB | 96 points × 4 bytes × 8 buffers |
| NVS read/write buffers | ~8 KB | Segment snapshot during persist/restore |
| HTTP response buffers | ~4–16 KB | Depends on concurrent requests |
| **Measured free heap at runtime** | **58,456 B** | v7.6.10.0, 218s uptime |

**BUG-084 concurrency constraint:** At 4 concurrent HTTP connections, the C3 operates safely (stress test PASS, watermark 12,920 B). At 8 concurrent connections, free heap drops below the WiFi/LWIP minimum (~15–20 KB) and the board crashes. **Max safe concurrent connections: 4.**

**Maximum persistent metrics on C3:** 8 (at the practical ceiling). Each additional persistent metric costs 804 B static. Current 8 metrics post-V1-B leaves no headroom above the 58 KB measured floor.

**httpd stack sizing (v7.6.10.0 measured):** Peak httpd stack usage is ~3,400 B across all tested architectures. The 16 KB httpd stack override provides 12,924 B headroom (79%) on C3. No architecture-dependent sizing is needed.

### ESP32-S3 SuperMini (512 KB SRAM + 2 MB PSRAM) — NEW, Measured

| Metric | Value |
|---|---|
| Internal free_heap | 123,156 B |
| min_free_heap (total, includes PSRAM) | 2,209,636 B |
| httpd_stack_wm | 12,512 B |
| Stress test (4 concurrent) | PASS |
| Stress test (8 concurrent) | PASS |

**Key finding:** The S3 SuperMini with just 2 MB PSRAM provides over 2× the C3's free heap (123 KB vs 58 KB) and handles 8 concurrent connections without issues. The 2 MB PSRAM acts as overflow for dynamic allocations that would crash a C3. This makes it the **best-value satellite board** — $4–6 gets you heap crash protection that the $2–4 C3 lacks.

**Aggregator viability:** Marginal. With 2 MB PSRAM and 4 MB flash, it could aggregate ≤4 satellites. The primary constraint is flash (73.7% used) and the smaller PSRAM pool compared to the DevKitC N16R8's 8 MB OPI.

### ESP32-C6 SuperMini (512 KB SRAM, no PSRAM) — NEW, Measured

| Metric | Value |
|---|---|
| free_heap | 150,332 B |
| min_free_heap | 152,820 B (⚠️ see note) |
| httpd_stack_wm | 12,820 B |
| Stress test (4 concurrent) | PASS |

**Key finding:** The C6 has the highest free_heap of any non-PSRAM board — 150 KB, or 2.5× the C3. The extra 112 KB of SRAM (512 vs 400 KB) translates directly to more free heap. This makes the C6 the most capable non-PSRAM satellite for memory-intensive workloads.

**⚠️ Flash constraint (4 MB variant only):** At 91.6% OTA partition utilization, the C6 with 4 MB flash has only 145 KB of headroom. WiFi 6 + 802.15.4 radio stacks are the cause — they add ~192 KB to the binary compared to WiFi 4 boards. Phase 7 firmware growth or new sensor types could exceed this limit.

**C6 fleet plan:** A C6 board with **8 MB flash** is available and will become the primary C6 satellite. This resolves the flash constraint (estimated ~50% utilization with 8 MB, matching C5). The current 4 MB C6 remains viable for lightweight use cases such as **binary sensors** (door/window contacts, motion sensors, leak detectors) where firmware size is static and Phase 7 per-device persistence adds minimal code. Binary sensors use the EventLog model (§6 in the capacity study) at ~168 B per sensor — well within the 4 MB board's remaining flash.

**BUG-084:** No PSRAM means the C6 is subject to the same 4-concurrent-connection limit as C3 and WROOM. However, with 150 KB free heap, the C6 has substantially more crash margin than the C3's 58 KB.

### ESP32-C5 WROOM-1U (384 KB SRAM + 8 MB PSRAM) — NEW, Measured

| Metric | Value |
|---|---|
| Internal free_heap | 32,908 B |
| min_free_heap (total, includes PSRAM) | 8,420,784 B |
| httpd_stack_wm | 12,728 B |
| Stress test (8 concurrent) | PASS |

**⚠️ BLE sensor reception non-functional — likely antenna issue.** The C5 compiled and booted the full project firmware successfully. WiFi, dashboard serving, system metrics, and the stress test all passed. However, no BLE sensor data was received during the 2.5-minute observation window. The dashboard shows "No data" for all sensors.

**Root cause: external antenna was not attached.** The WROOM-1U module uses an IPEX connector for an external antenna — no antenna was connected during v7.6.10.2 testing. This almost certainly explains the BLE failure. Re-test planned with antenna attached. A C5 SuperMini board with integrated antenna is also being procured for independent verification.

**Internal heap is very low (32,908 B)** — lower than any other board in the fleet. The 384 KB SRAM is the smallest, and HP SRAM utilization at 54.45% (highest of any board) leaves limited free memory. The 8 MB PSRAM prevents crash, but internal heap below 33 KB is in the danger zone for WiFi/BLE stack stability. A declining heap trend was observed: 50 KB → 33 KB over 2.5 minutes. Needs extended uptime measurement to confirm stabilization.

**If BLE is not needed (Zigbee-only or WiFi-only satellite), disabling BLE could free significant internal heap.** See §4a below.

**Not recommended for production BLE deployment until antenna re-test confirms reception. Viable for WiFi-only or Zigbee-only workloads.**

### ESP32-S3 DevKitC N16R8 (512 KB SRAM + 8 MB PSRAM) — Updated

The S3 DevKitC remains the primary aggregator. Updated observations at v7.6.10.0:

- httpd_stack_wm dropped from 12,528 B (v7.6.9.5) to **10,036 B** (v7.6.10.0) — a 2,492 B regression caused by ESPHome 2026.4.1's new SSE code paths. Still above the 10,000 B threshold, but monitor on future upgrades.
- free_heap stable at 53,432 B (internal). PSRAM handles all dynamic overflow.
- Stress test (8 concurrent) passes.

**Concurrent connection scaling for aggregators:** An S3 aggregator managing N satellites with D concurrent dashboard sessions needs to handle at least N + (2 × D) concurrent HTTP connections (N outbound poll connections + 2 inbound per dashboard for SSE + status). For a 6–8 satellite deployment with 2 dashboard sessions, this is 10–12 concurrent connections. The current `CONFIG_LWIP_MAX_SOCKETS: 15` handles this. For larger deployments:

| Satellites | Dashboard Sessions | Min Connections | CONFIG_LWIP_MAX_SOCKETS |
|---|---|---|---|
| 4 | 1 | 6 | 15 (current default) |
| 6 | 2 | 10 | 15 (current default) |
| 8 | 2 | 12 | 15 (adequate) |
| 8 | 4 | 16 | 20 (needs board profile update) |

For ≤8 satellites + 2 dashboards, the current `CONFIG_LWIP_MAX_SOCKETS: 15` is sufficient. For larger deployments, update the S3 aggregator board profile's `sdkconfig_options` to increase this value. Each additional socket costs ~1–2 KB heap — negligible with 8 MB PSRAM.

### ESP32-WROOM-32D (520 KB SRAM, no PSRAM) — Updated

| Metric | Value |
|---|---|
| free_heap | 38,760 B |
| min_free_heap | 15,936 B |
| httpd_stack_wm | 13,188 B |

The WROOM has the tightest non-PSRAM heap after the C5. `min_free_heap` of 15,936 B (after extended uptime) shows it approaches the WiFi/LWIP minimum under real workload. BUG-084: crashes under 8 concurrent connections, passes at 4.

**IRAM note (LESSON-OPS-131):** ESPHome 2026.4.1 suggests `sram1_as_iram: true` for WROOM. **Do NOT enable.** This would reduce DRAM by ~40 KB, worsening heap pressure and BUG-084 crash susceptibility.

### §4a — BLE Disable Analysis: Zigbee-Only and WiFi-Only Satellite Configurations

Two upcoming use cases do not need the BLE radio stack at all:

1. **Zigbee-only satellites (C5/C6):** When C5/C6 boards receive data from Zigbee sensors via 802.15.4, BLE passive scanning is unnecessary overhead. The primary sensor attachment for C5/C6 boards is envisioned as Zigbee, not BLE.

2. **WiFi-only satellites (any board):** Weather stations, power meters, and other devices that expose a REST API over WiFi. The satellite queries these devices via HTTP — no radio scanning needed. This is already partially implemented in the data ingest pipeline.

**Estimated BLE stack cost:** The ESP-IDF BLE stack (NimBLE on RISC-V, Bluedroid on Xtensa) consumes approximately 40–60 KB of heap on ESP32 variants. Disabling it would free this memory for other uses:

| Board | Current free_heap | Estimated with BLE disabled | Impact |
|---|---|---|---|
| C5 (384 KB, 8M PSRAM) | 32,908 B | ~80–90 KB | Transforms C5 from "danger zone" to comfortable |
| C6 (512 KB, no PSRAM) | 150,332 B | ~190–210 KB | Already comfortable; becomes very generous |
| C3 (400 KB, no PSRAM) | 58,456 B | ~100–120 KB | Significant improvement for WiFi-only sensors |
| WROOM (520 KB, no PSRAM) | 38,760 B | ~80–100 KB | Relieves BUG-084 pressure substantially |

**Implementation:** In ESPHome, BLE is controlled by the `esp32_ble_tracker` component. Removing it from the board profile's sensor config (via `render_sensor_config.py`) would exclude BLE from the build. The firmware already uses a substitution-driven pipeline — a board profile flag like `capabilities.ble: false` could drive this.

**Recommendation:** Create "no-BLE" firmware variants for WiFi-only and Zigbee-only satellite roles. This is a Phase 7 or Phase E task — it requires changes to `render_sensor_config.py` and new board profiles, but no firmware core changes. The heap savings are substantial, especially on C5 (where it may be the difference between viable and non-viable).

---

## 5. BUG-084: Concurrency Limits by Board

This table summarizes the measured maximum safe concurrent HTTP connections per board.

| Board | PSRAM | Max Concurrent | Evidence |
|---|---|---|---|
| ESP32-C3 SuperMini | None | **4** | Crashes at 8 (heap exhaustion) |
| ESP32-WROOM-32D | None | **4** | Crashes at 8 (heap exhaustion) |
| ESP32-C6 SuperMini | None | **4** | Passes at 4. Not tested at 8 but no PSRAM → same limit applies. |
| ESP32-S3 SuperMini | 2 MB quad | **8** | Passes at both 4 and 8 |
| ESP32-S3 DevKitC N16R8 | 8 MB OPI | **8** | Passes at 8 |
| ESP32-C5 WROOM-1U | 8 MB quad | **8** | Passes at 8 (though BLE doesn't work) |

**Operational guidance:** When a dashboard browser tab is open AND an aggregator is polling the same satellite, the satellite sees 3–4 concurrent connections. This is within limits for all boards. The risk scenario is automated monitoring tools (Prometheus, Grafana) adding additional connections on top of normal dashboard + aggregator traffic.

---

## 6. Forward-Looking Considerations

### Zigbee transition path

The ThermoPro TP357 uses BLE advertising — no pairing, just passive receive. If you transition to Zigbee sensors in the future:

1. **C3 satellites cannot receive Zigbee** — no 802.15.4 radio. They'd need replacement.
2. **C6 satellites can receive both BLE and Zigbee** — the 802.15.4 radio handles Zigbee while BLE continues for legacy sensors. 512 KB SRAM and 150 KB free heap make this the smoothest migration path.
3. **C5 adds 5 GHz WiFi** on top of C6's capabilities. Useful in congested 2.4 GHz environments. However, BLE reception doesn't work yet (A-004). Zigbee may or may not have the same issue — untested.
4. **ESPHome Zigbee support** is still maturing (2025.6+). Production Zigbee sensor integration likely needs ESP-IDF level work or waiting for ESPHome improvements through 2026.

### PSRAM as a safety net

Every heap crash you've seen on the C3 (dashboard serving under load, large CSV exports, concurrent history fetches, BUG-084) would be eliminated by PSRAM. The S3 SuperMini at ~$5 is now confirmed as the cheapest way to get PSRAM protection. For any new satellite deployment where budget allows, the S3 SuperMini is a safer choice than the C3.

### C6 flash constraint

The C6 with 4 MB flash uses 91.6% of its OTA partition. The fleet now has two C6 paths:

1. **C6 with 8 MB flash** (primary satellite) — resolves the constraint entirely. New board profile needed (`esp32-c6-supermini-8m` or equivalent) with the 8 MB partition table giving 3 MB OTA slots.
2. **C6 with 4 MB flash** (binary sensor satellite) — retained for lightweight use cases. Binary sensors (door contacts, motion, leak detectors) use EventLog at ~168 B per sensor and add minimal firmware code. Phase 7 per-device persistence for binary sensors is feasible within the remaining 145 KB headroom.

The 4 MB C6 should not receive environmental sensor (HistoryBuffer) or weather station firmware variants — those add too much code.

### Board availability and supply chain

| Chip | Board Availability (2026) | Supply Stability |
|------|---------------------------|------------------|
| ESP32-C3 | Abundant — dozens of boards | Stable, mature chip |
| ESP32 (WROOM) | Abundant | Stable, but legacy |
| ESP32-S3 | Abundant — DevKitC, SuperMini, Feather variants | Stable |
| ESP32-C6 | Growing — DevKitC, Mini, Seeed XIAO | Good, production chip |
| ESP32-C5 | Limited — DevKitC-1, WROOM-1U, DFRobot FireBeetle 2 | Early availability, expect stock gaps |
| ESP32-C61 | Very limited | Too new, avoid for production |
| ESP32-P4 | Limited — Function-EV-Board, Waveshare, Olimex | Available but expensive, early ecosystem |

---

## 7. Recommended Deployment Configurations

### Configuration A: Budget deployment (current production)

| Role | Board | Cost | Measured free_heap |
|------|-------|------|--------------------|
| Satellite × 3 | ESP32-C3 SuperMini (4 MB) | $3 each | 58,456 B |
| Aggregator × 1 | ESP32-S3-DevKitC-1 N16R8 | $12 | 53,432 B (+8M PSRAM) |
| **Total** | | **~$21** | |

Proven, stable, running in production now. C3 satellites work well with 3 sensors each. BUG-084 limit: 4 concurrent connections per satellite. Aggregator has PSRAM for comfortable multi-satellite polling.

### Configuration B: Comfortable deployment (recommended for new builds)

| Role | Board | Cost | Measured free_heap |
|------|-------|------|--------------------|
| Satellite × 3 | ESP32-S3 SuperMini N4R2 | $5 each | 123,156 B (+2M PSRAM) |
| Aggregator × 1 | ESP32-S3-DevKitC-1 N16R8 | $12 | 53,432 B (+8M PSRAM) |
| **Total** | | **~$27** | |

PSRAM on satellites eliminates heap pressure and BUG-084 crash risk. Dual-core helps with concurrent HTTP + BLE. Handles 8 concurrent connections. Slightly larger form factor than C3 SuperMini but still compact.

### Configuration C: Zigbee-ready deployment (future)

| Role | Board | Cost | Measured free_heap |
|------|-------|------|--------------------|
| Satellite × 3 | ESP32-C6 Mini (4–16 MB) | $5–10 each | 150,332 B |
| Aggregator × 1 | ESP32-S3-DevKitC-1 N16R8 | $12 | 53,432 B (+8M PSRAM) |
| **Total** | | **~$27–42** | |

C6 satellites handle BLE + Zigbee + WiFi 6. ⚠️ Flash constraint on 4 MB boards (91.6%) — prefer 16 MB C6 variants. BUG-084: max 4 concurrent connections. Aggregator stays on S3 for PSRAM and dual-core.

### Configuration D: Premium/future deployment

| Role | Board | Cost | Measured free_heap |
|------|-------|------|--------------------|
| Satellite × 3 | ESP32-C5 WROOM-1U (8 MB + PSRAM) | $8–10 each | 32,908 B (+8M PSRAM) |
| Aggregator × 1 | ESP32-P4 + C6 combo board | $30 | TBD |
| **Total** | | **~$54–60** | |

⚠️ **Not recommended yet.** C5 BLE re-test needed (antenna was missing). C5 SuperMini with integrated antenna being procured. P4 ESPHome support is too early. Reassess when C5 antenna test completes and P4 ecosystem stabilizes. For Zigbee-only C5 satellites, consider BLE-disabled firmware variant (§4a) to recover ~50 KB internal heap.

### Configuration E: WiFi-only satellite (weather station / power meter)

| Role | Board | Cost | Est. free_heap (BLE disabled) |
|------|-------|------|-------------------------------|
| Satellite × N | ESP32-C3 SuperMini or C6 Mini | $3–5 each | ~100–120 KB (C3) / ~190–210 KB (C6) |
| Aggregator × 1 | ESP32-S3-DevKitC-1 N16R8 | $12 | 53,432 B (+8M PSRAM) |

For sensors attached via WiFi (REST API weather stations, power meters queried over HTTP), the satellite doesn't need BLE at all. Disabling BLE frees ~40–60 KB of heap, transforming even the C3 from "tight" to "comfortable." The firmware variant would remove `esp32_ble_tracker` and use HTTP polling instead. This is a future firmware variant — requires `render_sensor_config.py` changes.

---

## 8. Summary Decision Matrix

| Question | Answer |
|----------|--------|
| Need cheapest satellite that works today? | **ESP32-C3 SuperMini** (58 KB free heap, 4 max concurrent) |
| Want a satellite that won't crash under load? | **ESP32-S3 SuperMini N4R2** (123 KB free heap, 2 MB PSRAM, 8 max concurrent) |
| Need Zigbee sensor support on satellites? | **ESP32-C6 Mini** (150 KB free heap, ⚠️ 91.6% flash on 4 MB — use 8 MB variant) |
| Need 5 GHz WiFi + Zigbee? | **ESP32-C5** (re-test with antenna pending; consider BLE-disabled variant for Zigbee-only) |
| WiFi-only satellite (weather/power meter)? | **Any board with BLE disabled** — C3 becomes ~100 KB free, C6 becomes ~200 KB free |
| Best aggregator for 2–4 satellites? | **ESP32-S3-DevKitC-1 N16R8** |
| Best aggregator for 5+ satellites? | **ESP32-S3 WROOM-2 N32R16** or **ESP32-P4 combo** |
| Best aggregator for 6–8 satellites + 2 dashboards? | **ESP32-S3-DevKitC-1 N16R8** (CONFIG_LWIP_MAX_SOCKETS: 15 is sufficient) |
| Can the S3 SuperMini be an aggregator? | Marginal — 2 MB PSRAM, cap at ≤4 satellites, 73.7% flash |
| C6 with 4 MB flash — what's it good for? | **Binary sensors** (door/window/motion/leak). Too tight for env sensor firmware growth. |
| C6 with 8 MB flash — what's it good for? | **Primary C6 satellite** — resolves flash constraint, good for env + Zigbee workloads |
| Should I buy ESP32-C61? | **No** — too constrained (256 KB SRAM), no Thread cert, no ESPHome |
| Should I buy ESP32-P4 now? | **Not for production** — ESPHome support too early |
| What to stock up on for future-proofing? | **ESP32-S3-DevKitC-1 N16R8** (aggregator) + **ESP32-C6 Mini 8MB** (satellites) |
| Is the WROOM-32D worth keeping? | Yes for existing deployments. Don't buy new — 38 KB free heap is tight. |

---

## 9. Cross-Reference

| Document | What it contains |
|---|---|
| `Docs/board-measurement-log-v7.6.10.md` | Raw measurement data, anomalies (A-001 through A-004) |
| `Docs/phase-V-capacity-study.md` | Per-metric cost model, max sensors by board, NVS flash analysis |
| `Docs/lessons/firmware.md` | BUG-084, LESSON-OPS-129/130/131 |
| `firmware/boards/*.yaml` | Board profiles for code generation |
| `partitions/*.csv` | Partition tables per board |

---

_End of board selection guide._
