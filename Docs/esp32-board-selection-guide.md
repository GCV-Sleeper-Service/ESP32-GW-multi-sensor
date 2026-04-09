**The C3's 400 KB SRAM with no PSRAM is the root of every heap crash you've hit.** WiFi + BLE + ESPHome eat ~160 KB before your code even starts. 
History buffers for 4 sensors take another ~48 KB. That leaves ~80 KB free, which is enough for normal operation but razor-thin during concurrent dashboard loads or large CSV exports. 
A 5th sensor or heavier aggregator caching would push it over.

**The S3 N16R8 solves this permanently** for ~$12. 
The 8 MB PSRAM acts as overflow — ESP-IDF automatically allocates from it when internal SRAM runs low. 
Your existing aggregator on the S3 stays above 200 KB free heap even with 2 satellites polling, precisely because the satellite caches live in PSRAM.

For the **Zigbee future**, the C6 is the board to watch. It's the only mature chip that does WiFi 6 + BLE + 802.15.4 (Zigbee/Thread) in one package, with 512 KB SRAM — 25% more than the C3. 
The C5 adds 5 GHz WiFi on top of that, which matters in congested environments, but its software ecosystem is still catching up. 
ESPHome added C6 support in 2025.6 and it's described as "still being refined."

**The C61 is not worth buying** — 256 KB SRAM is too small for a gateway role, it has no Thread certification, and no ESPHome support.

**The P4 is interesting but premature** — 768 KB SRAM + 32 MB PSRAM is massive, but it has no WiFi/BT (needs a C6 companion chip), and ESPHome support just landed. Good for experimentation, not production yet.

The practical recommendation: stock up on **S3 N16R8** boards for aggregators and **C6 Mini** boards for future Zigbee-capable satellites. 
Keep using C3 SuperMini for cost-sensitive satellite deployments where 3 sensors or fewer is the target.

# ESP32 Board Selection Guide for Multi-Sensor Gateway

_Date: 2026-03-25_
_Context: ESP32-GW multi-sensor gateway project — satellite and aggregator roles_
_Based on: Espressif datasheets, project field experience (v7.5.5.5), ESPHome compatibility_

---

## 1. Chip Family Specifications

| Chip | CPU | Cores | MHz | SRAM | PSRAM Support | Flash (typical) | WiFi | BLE | 802.15.4 (Zigbee/Thread) | LP Core | ESPHome Support |
|------|-----|-------|-----|------|---------------|-----------------|------|-----|--------------------------|---------|-----------------|
| **ESP32-C3** | RISC-V | 1 | 160 | 400 KB | No | 4 MB | 802.11n (WiFi 4) | 5.0 | No | No | ✅ Mature |
| **ESP32-S3** | Xtensa LX7 | 2 | 240 | 512 KB | Yes (up to 16 MB OPI) | 4–32 MB | 802.11n (WiFi 4) | 5.0 | No | No | ✅ Mature |
| **ESP32-C5** | RISC-V | 1 | 240 | 384 KB | Yes (up to 8 MB) | 4 MB | 802.11ax (WiFi 6, dual-band 2.4+5 GHz) | 5.0 | **Yes** | Yes (48 MHz) | ⚠️ Early (ESP-IDF 5.4+) |
| **ESP32-C6** | RISC-V | 1 | 160 | 512 KB | Optional | 4–16 MB | 802.11ax (WiFi 6, 2.4 GHz) | 5.3 | **Yes** | Yes (20 MHz) | ⚠️ Since ESPHome 2025.6 |
| **ESP32-C61** | RISC-V | 1 | 160 | 256 KB | 2 MB pseudo-RAM | 2–4 MB | 802.11ax (WiFi 6, 2.4 GHz) | 5.0 | Partial (no Thread cert) | Yes | ❌ Not yet |
| **ESP32-P4** | RISC-V | 2 | 400 | 768 KB | Yes (up to 32 MB) | 16–32 MB | **None** | **None** | No | Yes (40 MHz) | ⚠️ Since ESPHome 2025.6 |

---

## 2. Recommended Boards by Role

### Satellite Gateway — Small, low-cost, single-purpose

A satellite's job is straightforward: receive BLE sensor data, serve a dashboard, and expose an API. Memory pressure comes from the dashboard serving (~45KB gzipped), history buffers (24h RAM + 45 days NVS), and WiFi stack overhead.

| Board | Chip | SRAM | PSRAM | Flash | Price (approx) | Recommended For | Notes |
|-------|------|------|-------|-------|----------------|-----------------|-------|
| **ESP32-C3 SuperMini** | C3 | 400 KB | None | 4 MB | $2–4 | ✅ Default satellite (1–3 BLE sensors) | Current project baseline. Free heap drops to ~80KB under load. Works but tight — no room for large history buffers or many concurrent HTTP clients. |
| **ESP32-C3 SuperMini Plus** | C3 | 400 KB | None | 4 MB | $3–5 | ✅ Satellite with better antenna | External antenna option for placement inside enclosures or at distance. Same chip, better RF. |
| **ESP32-S3 SuperMini** | S3 | 512 KB | None | 4 MB | $4–6 | ⚠️ Satellite only if PSRAM variant | Without PSRAM, marginal improvement over C3. Get the N8R8 or N16R8 variant instead. |
| **ESP32-C6 Mini** | C6 | 512 KB | None | 4 MB | $3–5 | ✅ Future satellite with Zigbee sensors | WiFi 6 + 802.15.4 in one chip. When ESPHome C6 matures, this becomes the satellite for Zigbee TP357 replacements. 512 KB SRAM gives 25% more headroom than C3. |
| **ESP32-C5 DevKitC-1** | C5 | 384 KB | Up to 8 MB | 4 MB | $6–10 | ✅ Future satellite: Zigbee + 5 GHz WiFi | Only option for 5 GHz WiFi + Zigbee. Useful in congested 2.4 GHz environments. PSRAM support offloads heap pressure. Software maturity is the main risk. |
| **ESP32-WROOM-32D** | ESP32 | 520 KB | None (module) | 4 MB | $3–6 | ⚠️ Legacy satellite | Classic dual-core, more SRAM than C3, BT Classic. No PSRAM on the base module. Good if you have them already; don't buy new for this project. |

### Aggregator Gateway — More memory, multi-satellite polling

An aggregator runs the full satellite pipeline plus satellite polling (HTTP fetches), response caching (`SatelliteCache` = ~6.5KB per satellite), and a richer dashboard with per-gateway tabs. This is where C3's 400KB SRAM becomes a real constraint.

| Board | Chip | SRAM | PSRAM | Flash | Price (approx) | Recommended For | Notes |
|-------|------|------|-------|-------|----------------|-----------------|-------|
| **ESP32-S3-DevKitC-1 N16R8** | S3 | 512 KB | **8 MB OPI** | 16 MB | $10–15 | ✅ **Primary aggregator recommendation** | Current project aggregator. PSRAM lets you move history buffers and satellite cache off the main heap. 16 MB flash gives room for larger dashboards and OTA. Dual-core handles polling + HTTP serving concurrently. |
| **ESP32-S3-DevKitC-1 N32R8** | S3 | 512 KB | **8 MB OPI** | 32 MB | $12–18 | ✅ Aggregator with future growth | Same as N16R8 but 32 MB flash. Useful if dashboard grows or you want to store more fixture data. |
| **ESP32-S3 WROOM-2 (N32R16)** | S3 | 512 KB | **16 MB OPI** | 32 MB | $15–20 | ✅ Heavy aggregator (8+ satellites) | Maximum PSRAM for the S3. If you plan to aggregate 8 satellites with full caching, this gives the most headroom. |
| **ESP32-C6-DevKitC-1 N16** | C6 | 512 KB | None | 16 MB | $8–12 | ⚠️ Light aggregator (2–3 satellites) | Single-core limits concurrent HTTP handling. No PSRAM means satellite cache competes with heap. Viable for 2–3 satellites if Zigbee sensor support is needed on the aggregator itself. |
| **ESP32-P4 + C6 combo** | P4+C6 | 768 KB + 32 MB PSRAM | **32 MB** | 16–32 MB | $25–40 | 🔮 Future premium aggregator | P4 has no WiFi — needs a C6 co-processor. Massive processing power and memory. Overkill for current scope but interesting for Phase E (captive portal with rich UI). ESPHome P4 support is very early. |

### Zigbee Sensor Bridge — Future role for C5/C6

When the project adds direct Zigbee sensor support (bypassing BLE entirely), the satellite needs an 802.15.4 radio. This rules out C3 and S3.

| Board | Chip | Zigbee | Thread | WiFi | Notes |
|-------|------|--------|--------|------|-------|
| **ESP32-C6 Mini** | C6 | ✅ | ✅ | WiFi 6 (2.4 GHz) | Best near-term option. Single chip handles WiFi + Zigbee + BLE. 512 KB SRAM. |
| **ESP32-C5 DevKitC-1** | C5 | ✅ | ✅ | WiFi 6 (2.4+5 GHz) | Adds 5 GHz band. Software less mature than C6. |
| **ESP32-C61** | C61 | Partial | ❌ No cert | WiFi 6 (2.4 GHz) | **Not recommended.** 256 KB SRAM is too tight. No Thread. No ESPHome support yet. Budget chip for simple endpoints, not gateways. |

---

## 3. Memory Pressure Analysis

This is the core concern you raised. Here's what actually happens with the gateway firmware at v7.5.5.5:

### ESP32-C3 (400 KB SRAM, no PSRAM)

| Memory consumer | Approximate size | Notes |
|----------------|-----------------|-------|
| WiFi + BLE stack (ESP-IDF) | ~120 KB | Fixed overhead, non-negotiable |
| ESPHome framework | ~40 KB | Event loop, components, logging |
| Dashboard gzip payload | ~45 KB | Served from flash, but decompression needs temp buffers |
| SensorEntity array (4 devices) | ~8 KB | Scales with device count |
| HistoryBuffer (24h × 4 sensors × 2 metrics) | ~48 KB | 96 points × 4 bytes × 8 buffers |
| NVS read/write buffers | ~8 KB | Segment snapshot during persist/restore |
| HTTP response buffers | ~4–16 KB | Depends on concurrent requests |
| **Free heap at runtime** | **~80–100 KB** | Measured on real device |

**Where it gets dangerous:**
- Large CSV export (all sensors, 45 days) can spike to 30KB+ response buffer
- Concurrent dashboard load (manifest + live + history × 4) can briefly consume 20KB+ in flight
- Adding a 5th sensor pushes HistoryBuffer to 60KB, leaving ~70KB free
- Aggregator mode adds ~6.5KB per satellite cache plus polling HTTP buffers

**Mitigation on C3:** Keep sensor count to 3 or fewer. Use `beginResponse()` not `beginResponseStream()` (pre-reserves a known buffer). The project already uses pre-reserved string patterns for CSV responses (LESSON-OPS-056).

### ESP32-S3 N16R8 (512 KB SRAM + 8 MB PSRAM)

The S3 with PSRAM changes the calculus entirely:

- PSRAM is slower than internal SRAM (~40 MHz SPI vs ~240 MHz bus) but 8 MB is enormous
- ESP-IDF can allocate from PSRAM automatically for `malloc()` calls when internal SRAM is exhausted
- History buffers, satellite caches, and large response strings can live in PSRAM
- Internal SRAM stays free for stack, ISR handlers, DMA buffers, and WiFi

**Practical impact:** Free internal heap stays above 200 KB even with aggregator mode + 8 satellites. PSRAM handles the bulk storage. The main concern shifts from "will it crash?" to "will it be slow?" — and for a 15-second poll cycle, PSRAM latency is irrelevant.

**PSRAM gotcha for S3 N8R8:** OPI PSRAM uses GPIO35–37. Those pins are not available for general I/O. The board profile must exclude them. Already handled in the project's S3 board profile.

### ESP32-C6 (512 KB SRAM, no PSRAM)

25% more SRAM than C3, plus WiFi 6 is more efficient. Good enough for a 4-sensor satellite. No PSRAM means satellite role only — same as C3 and WROOM-32D. Aggregator role requires PSRAM (see `Docs/architecture-overview.md`).

### ESP32-P4 (768 KB SRAM + up to 32 MB PSRAM)

Massive headroom. Could aggregate dozens of satellites. The missing WiFi means it needs a C6 companion chip. The development boards (like Waveshare ESP32-P4 Nano) pair a P4 with a C6-MINI for connectivity. ESPHome P4 support is very early — expect rough edges in 2026.

---

## 4. Forward-Looking Considerations

### Zigbee transition path

The ThermoPro TP357 uses BLE advertising — no pairing, just passive receive. If you transition to Zigbee sensors in the future:

1. **C3 satellites cannot receive Zigbee** — no 802.15.4 radio. They'd need replacement.
2. **C6 satellites can receive both BLE and Zigbee** — the 802.15.4 radio handles Zigbee while BLE continues for legacy sensors. This is the smoothest migration path.
3. **C5 adds 5 GHz WiFi** on top of C6's capabilities. Worth it if your environment has 2.4 GHz congestion.
4. **ESPHome Zigbee support** is still maturing (2025.6+). Production Zigbee sensor integration likely needs ESP-IDF level work or waiting for ESPHome improvements through 2026.

### PSRAM as a safety net

Every heap crash you've seen on the C3 (dashboard serving under load, large CSV exports, concurrent history fetches) would be eliminated by PSRAM. The S3 N16R8 at ~$12 is the cheapest way to get 8 MB PSRAM. For any new satellite deployment where budget allows, the S3 SuperMini N8R8 variant (if available) or the DevKitC-1 N16R8 is a safer choice than the C3.

### Board availability and supply chain

| Chip | Board Availability (2026) | Supply Stability |
|------|---------------------------|------------------|
| ESP32-C3 | Abundant — dozens of boards | Stable, mature chip |
| ESP32-S3 | Abundant — DevKitC, SuperMini, Feather variants | Stable |
| ESP32-C6 | Growing — DevKitC, Mini, Seeed XIAO | Good, production chip |
| ESP32-C5 | Limited — DevKitC-1, DFRobot FireBeetle 2 | Early availability, expect stock gaps |
| ESP32-C61 | Very limited | Too new, avoid for production |
| ESP32-P4 | Limited — Function-EV-Board, Waveshare, Olimex | Available but expensive, early ecosystem |

---

## 5. Recommended Deployment Configurations

### Configuration A: Budget deployment (current)

| Role | Board | Cost |
|------|-------|------|
| Satellite × 3 | ESP32-C3 SuperMini (4 MB) | $3 each |
| Aggregator × 1 | ESP32-S3-DevKitC-1 N16R8 | $12 |
| **Total** | | **~$21** |

Proven, stable, running in production now. C3 satellites work well with 3 sensors each. Aggregator has PSRAM for comfortable multi-satellite polling.

### Configuration B: Comfortable deployment (recommended for new builds)

| Role | Board | Cost |
|------|-------|------|
| Satellite × 3 | ESP32-S3 SuperMini N4R2 or N8R8 | $5–8 each |
| Aggregator × 1 | ESP32-S3-DevKitC-1 N16R8 | $12 |
| **Total** | | **~$27–36** |

PSRAM on satellites eliminates heap pressure entirely. Dual-core helps with concurrent HTTP + BLE. Slightly larger form factor than C3 SuperMini but still compact.

### Configuration C: Zigbee-ready deployment (future)

| Role | Board | Cost |
|------|-------|------|
| Satellite × 3 | ESP32-C6 Mini or DevKitC (4–16 MB) | $5–10 each |
| Aggregator × 1 | ESP32-S3-DevKitC-1 N16R8 | $12 |
| **Total** | | **~$27–42** |

C6 satellites handle BLE + Zigbee + WiFi 6. Aggregator stays on S3 for PSRAM and dual-core. Requires ESPHome C6 support to fully mature.

### Configuration D: Premium/future deployment

| Role | Board | Cost |
|------|-------|------|
| Satellite × 3 | ESP32-C5 DevKitC-1 (4 MB + PSRAM) | $8–10 each |
| Aggregator × 1 | ESP32-P4 + C6 combo board | $30 |
| **Total** | | **~$54–60** |

Maximum capability. 5 GHz WiFi + Zigbee on satellites. P4 aggregator with 768 KB SRAM + 32 MB PSRAM can handle a large sensor fleet. Requires significant ESPHome maturation.

---

## 6. Summary Decision Matrix

| Question | Answer |
|----------|--------|
| Need cheapest satellite that works today? | **ESP32-C3 SuperMini** |
| Want a satellite that won't crash under load? | **ESP32-S3 SuperMini/DevKitC with PSRAM** |
| Need Zigbee sensor support on satellites? | **ESP32-C6 Mini** (or C5 for 5 GHz) |
| Best aggregator for 2–4 satellites? | **ESP32-S3-DevKitC-1 N16R8** |
| Best aggregator for 5+ satellites? | **ESP32-S3 WROOM-2 N32R16** or **ESP32-P4 combo** |
| Should I buy ESP32-C61? | **No** — too constrained (256 KB SRAM), no Thread cert, no ESPHome |
| Should I buy ESP32-P4 now? | **Not for production** — ESPHome support too early. Good for experimentation. |
| What to stock up on for future-proofing? | **ESP32-S3-DevKitC-1 N16R8** (aggregator) + **ESP32-C6 Mini** (satellites) |

---

_End of board selection guide._
