# Lessons to append to Docs/lessons/firmware.md

_Append these entries after LESSON-OPS-131._

---

### LESSON-OPS-132: WiFi 6 + 802.15.4 radio stacks add ~192 KB to firmware binary (2026-05-05)

Context: v7.6.10.2 measurements showed the C6 (WiFi 6 + 802.15.4) binary at 1,620,928 B
vs C3 (WiFi 4, no 802.15.4) at 1,428,928 B — a 192 KB difference. The C5 binary is even
larger at 1,662,064 B (dual-band WiFi 6).

On 4 MB flash with the standard partition table (1,769,472 B OTA slots), the C6 uses
91.6% of its partition — only 145 KB headroom. Any significant firmware growth risks
exceeding the OTA partition.

**Recommendation:** For C6/C5 boards intended for production with firmware growth
(Phase 7 per-device persistence, new sensor types), use boards with ≥8 MB flash.
Retain 4 MB C6 boards for lightweight use cases (binary sensors, simple monitoring).

### LESSON-OPS-133: ESP32-C6 min_free_heap reporting inverts with free_heap when non-internal memory exists (2026-05-05)

Context: v7.6.10.2 measurements showed C6 `min_free_heap: 152,820` > `free_heap: 150,332`.
This is because `free_heap` reports `free_heap_internal` only, while `min_free_heap` tracks
total heap (including ~14.6 KB of non-internal allocatable memory such as RTC SRAM).

The `free_heap_total` (164,936) − `free_heap_internal` (150,332) = 14,604 B of non-internal
allocatable memory exists on the C6. This is not PSRAM — it's likely RTC fast memory or
another memory region that ESP-IDF can allocate from but is not classified as "internal."

**Impact:** Dashboard and monitoring tools that compare `min_free_heap < free_heap` as a
health check will show a false anomaly on C6 boards. Consider using
`esp_get_minimum_free_heap_size()` with `MALLOC_CAP_INTERNAL` flag for consistent reporting
across all boards, or document the C6 exception.

### LESSON-OPS-134: ESP32-C5 WROOM-1U requires external IPEX antenna for BLE reception (2026-05-05)

Context: v7.6.10.2 testing showed C5 BLE sensor reception failure. The external IPEX antenna
was not attached to the WROOM-1U module during testing. Without antenna, BLE reception range
is effectively zero — WiFi works because it uses higher power and can reach the router, but
BLE passive scanning for nearby ThermoPro sensors fails.

**Lesson:** Always verify antenna connection before diagnosing BLE reception failures on
modules with IPEX connectors (U.FL). The WROOM-1U specifically uses an external antenna
by design — unlike SuperMini or DevKitC boards which have integrated PCB antennas.

**Follow-up:** Re-test with antenna attached. Procure C5 SuperMini (integrated antenna) for
independent verification.

---

_End of new lessons._
