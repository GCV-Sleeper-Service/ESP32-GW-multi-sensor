# Multi-Phase Planning Session — Post-VX Supplement

_Append this supplement to `prompts/handoff/multi-phase-planning-prompt.md` AFTER Phase VX completes (board onboarding + optional auth refactor)._
_This supplements the v7.6.9.5 supplement — both should be appended._
_Prerequisite: `Docs/board-measurement-log-v7.6.10.md` exists with populated measurements._
_Updated: 2026-05-05 — ESPHome 2026.4.1, corrected board specs/IPs, 3 boards (not 4), BUG-084 findings._

---

## Context: What Phase VX Delivered

Phase VX (v7.6.10.x) was an infrastructure sprint between Phase V closure and Phase 7 start. It produced:

1. **ESPHome upgrade** (2026.2.1 → 2026.4.1, ESP-IDF 5.5.4) — new C6/C5 board support, updated local component override
2. **Board onboarding** — 3 new boards (S3 SuperMini, C6 SuperMini, C5 WROOM-1U) added to provisioning pipeline. C6-DevKitC-1 deferred (board not available).
3. **Measurement dataset** — `Docs/board-measurement-log-v7.6.10.md` with real telemetry from all boards
4. **BUG-084 finding** — heap exhaustion under concurrent HTTP connections on non-PSRAM boards. Safe concurrent limit: 4 connections on non-PSRAM boards.
5. **Dashboard auth refactor** (if completed as v7.6.10.4) — unified authentication flow eliminating browser native auth dialogs

### What the measurements revealed (fill after VX completes)

_The advisor running the multi-phase planning session should read `Docs/board-measurement-log-v7.6.10.md` and note these values:_

| Board | IP | free_heap (boot) | min_free_heap | httpd_stack_wm | Max persistent metrics | Aggregator viable? |
|---|---|---|---|---|---|---|
| C3 SuperMini | .189 | 58,456 | 47,616 | 12,924 | 8 | No (no PSRAM) |
| WROOM-32D | .170 | 38,760 | 15,936 | 13,188 | 10–12 | No (no PSRAM, tight heap) |
| S3 DevKitC (8M) | .191 | 53,432 | 8,398,704 | 10,036 | 50+ (PSRAM) | Yes (current aggregator) |
| S3 SuperMini (2M) | .173 | 123,156 | 2,209,636 | 12,512 | 30+ (PSRAM) | Marginal (2MB PSRAM, ≤4 satellites) |
| C6 SuperMini | .184 | 150,332 | 152,820 | 12,820 | 15–18 | No (no PSRAM, single core) |
| C5 WROOM-1U (8M) | .180 | 32,908 | 8,420,784 | 12,728 | 8 (low internal heap) | No (⚠️ BLE non-functional — see below) |

These measured values supersede the capacity study's estimates where they differ.

**C5 BLE failure note:** The C5 compiles and boots but did NOT receive BLE sensor data during
testing. **Root cause: external IPEX antenna was not attached.** Re-test with antenna planned,
plus C5 SuperMini (integrated antenna) being procured for independent verification.
Phase 7 planning should treat C5 BLE as "pending re-test" rather than "non-functional."
For Zigbee-only C5 workloads, BLE can be disabled to free ~50 KB internal heap.

**C6 flash constraint note:** The C6 with 4MB flash uses 91.6% of its OTA partition.
Phase 7 firmware growth may exceed the partition. C6 satellites may need to skip
Phase 7 persistence features or acquire C6 boards with larger flash.

**BUG-084 note for planning:** Non-PSRAM boards (C3, WROOM, C6) crash under 8 concurrent
HTTP connections. This limits operational scenarios — dashboard open + aggregator polling
simultaneously could crash a satellite. Phase 7 should consider reducing `CONFIG_LWIP_MAX_SOCKETS`
on non-PSRAM satellites to 8 (fail-safe refusal instead of crash).

**S3 watermark note:** S3 httpd stack watermark dropped from 12,528 B (v7.6.9.5) to 10,036 B
(v7.6.10.0). Still above 10,000 B threshold but tighter. Future ESPHome upgrades should
re-check this.

---

## Additional Phase 7 Review Questions

**10. Does the Phase 7 plan account for the dashboard auth refactor?**

If Phase VX completed v7.6.10.4 (dashboard auth refactor):
- All fetch calls now use `authFetch()` with explicit `Authorization` headers
- No browser native auth dialogs appear during operation
- Phase 7's new endpoints and dashboard components must use the same `authFetch()` pattern
- New Playwright tests may need fixture updates for the auth module

If Phase VX did NOT complete v7.6.10.4:
- The auth refactor should be folded into early Phase 7 (before any new endpoints are added that the dashboard polls)
- Doing it later means every new endpoint added in Phase 7 will trigger additional browser auth dialogs

**11. Does the Phase 7 plan reference the board measurement dataset?**

Phase 7's memory budget calculations should use measured values from `Docs/board-measurement-log-v7.6.10.md`, not the capacity study's estimates. Specifically:
- The C3's post-BUG-083-fix `free_heap` (~58 KB at boot) is ~13 KB lower than pre-fix because the 16 KB stack is now properly allocated
- The C6 and C5 measurements establish new baseline numbers that weren't available when Phase 7 was planned
- If the S3 SuperMini (2 MB PSRAM) can serve as aggregator, Phase 7's per-device persistence engine may need to accommodate a smaller PSRAM budget
- BUG-084 (heap exhaustion) constrains the maximum safe concurrent connections on non-PSRAM boards — Phase 7's SSE/polling architecture must respect this limit

**12. Does the Phase 7 plan handle the ESPHome version upgrade?**

Phase VX upgraded from ESPHome 2026.2.1 to 2026.4.1 (ESP-IDF 5.5.4). Phase 7 should:
- Reference the updated ESPHome version in all build instructions
- Use the updated local component override (re-applied by `patch-esphome-httpd-stack.sh`)
- Note the `message_generator_t` type change (ESPHome 2026.4.0+ uses `json::SerializationBuffer<>` instead of `std::string` — see version gate in `web_server_idf.h`)
- Note the `sram1_as_iram` hint — NOT recommended for WROOM (LESSON-OPS-131)

**13. Does Phase 7 account for BUG-084 heap limits?**

The per-device persistence engine in Phase 7 allocates NVS buffers on the heap. On non-PSRAM
boards (C3: ~58 KB free, WROOM: ~38 KB free), the available heap is already tight. Phase 7
must ensure that persistence operations don't run concurrently with HTTP requests (the deferred
task pattern already handles this — httpd handler spawns a task, doesn't do NVS inline).

---

## Phase 8 (Captive Portal) — Auth Integration Point

If the dashboard auth refactor completed in Phase VX, Phase 8 (captive portal provisioning) needs to account for it:

- The captive portal will need its own auth flow (WiFi provisioning credentials are distinct from management credentials)
- The `auth.js` module's `authFetch()` pattern should be extended, not duplicated
- Consider whether the captive portal uses the same credential store as management auth, or has a separate provisioning-only credential

---

## Phase 10 (Standalone Role) — Simplified Auth

If producing Phase 10 (standalone role) plans, the dashboard auth refactor changes the auth picture:

- Standalone boards may not need management auth at all (single-user, physical access only)
- The `auth.js` module should have a "no-auth" mode where `authFetch()` degrades to plain `fetch()`
- This could be driven by a firmware flag in `/api/status` (e.g., `"auth_required": false`)

---

## Updated Current State Summary Items

Add these to the Current State Summary (in addition to the v7.6.9.5 supplement's items):

- **ESPHome version:** 2026.4.1 with ESP-IDF 5.5.4 (upgraded in Phase VX)
- **Board fleet:** 3 production + N test boards (N = count of boards that compiled successfully in Phase VX)
- **New board IPs:** S3 SuperMini .173, C5 WROOM-1U .180, C6 SuperMini .184
- **Dashboard auth:** Application-level credential management via `auth.js` module (if v7.6.10.4 completed). All fetch calls use `authFetch()`. Browser native auth dialogs eliminated.
- **Local component override:** Re-applied for ESPHome 2026.4.1. `patch-esphome-httpd-stack.sh --check` passes (46-line drift warning expected — LESSON-OPS-130). Stack size uniform 16 KB.
- **BUG-084:** Non-PSRAM boards crash under 8 concurrent HTTP connections (heap exhaustion). Safe limit: 4 concurrent. Stress test updated with `--concurrent` parameter.
- **S3 watermark:** Dropped from 12,528 to 10,036 B after ESPHome 2026.4.1. Monitor.
- **IRAM:** `sram1_as_iram` not applicable (LESSON-OPS-131). No board profile changes.
- **Known board compilation failures:** None — all 6 boards compile successfully. However, ESP32-C5 BLE reception is non-functional (A-004). C5 is usable for WiFi/Zigbee testing only.
- **C6 flash constraint:** 91.6% OTA partition utilization on 4MB flash. Phase 7/8/10 firmware growth may require C6 boards with larger flash or partition redesign.

---

_End of post-VX multi-phase planning supplement._
