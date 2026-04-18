# Bugs and Lessons Learned — Redirect

_This file has been split into domain-scoped files at v7.6.4.0._
_See `Docs/lessons/index.md` for the complete cross-reference._

| Domain | File |
|--------|------|
| Dashboard | `Docs/lessons/dashboard.md` |
| Firmware | `Docs/lessons/firmware.md` |
| Build Pipeline | `Docs/lessons/build-pipeline.md` |
| Testing | `Docs/lessons/testing.md` |
| Operations | `Docs/lessons/operations.md` |

## Latest Operational Addendum

- `LESSON-OPS-126` moved into `Docs/lessons/operations.md`: checkpoint grep assertions must be validated against the actual replacement block in the same prompt.
- Critical Rule: checkpoint grep counts must be mechanically derived from the replacement block in the same prompt, not estimated from memory.

### BUG-082: `csv.reserve(cap)` does not truncate - string grows unbounded past reserved capacity (v7.6.9.4)

**Symptom:** WROOM board (192.168.120.190) crashes with heap exhaustion when serving `/history/{id}/temp` or when dashboard loads history at boot, despite v7.6.9.4 adaptive cap computing a safe reserve value of ~12 KB.

**Root cause:** `std::string::reserve(N)` pre-allocates capacity N but does NOT prevent the string from growing beyond N through `.append()` calls. The NVS scan loop in `handle_history_()` (`firmware/core/web-handler.h`) appended ~40 KB of CSV data (556 segments x 4 points x ~18 bytes/line) into a string reserved at 12 KB, triggering repeated reallocations. During reallocation from ~24 KB -> ~48 KB, `std::string` temporarily holds both old and new buffers (72 KB total), exceeding the WROOM's ~34 KB free heap.

**Resolution:** Deferred to Phase 7. The proper fix is chunked HTTP streaming - serving NVS segments in paged responses (~3.6 KB each) instead of building the full CSV in RAM. A simple truncation guard (`break` when `csv.size() >= adaptive_cap`) was considered but rejected because it would truncate history display on ALL boards (including C3) as their NVS fills up, not just WROOM.

**Data safety:** NVS data is intact on flash. Raw partition backup extracted via `esptool read_flash 0x370000 0x80000`. Offline parser script (`scripts/parse_nvs_history.py`) available for extraction.

**Lesson:** `reserve()` is an allocation optimization, not a size constraint. Any time a `reserve()` cap is introduced as a safety net for heap-constrained boards, verify whether the subsequent append loops actually enforce the cap as a truncation limit. See LESSON-OPS-127.

