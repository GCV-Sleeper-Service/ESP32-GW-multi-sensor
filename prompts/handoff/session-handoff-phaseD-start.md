# Session Handoff — Phase D Start: Runtime Satellite Management (v7.6.0.x)

_Date: 2026-03-28_
_Repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor_
_Assumption: v7.5.7.0 has been implemented, tested, and merged to `main`_

---

## Project State Summary

**v7.5.7.0** is the current version on `main`. **Phase 6 is COMPLETE. v7.5.7.0 (bridge step) is COMPLETE.**

### What v7.5.7.0 delivered

- `AGG_MANIFEST_BUF_SIZE = 8192` — manifest buffer doubled, named constant replaces magic number
- `s_fetch_tmp` increased to 8192 to match manifest buffer
- Truncation detection guard in `handle_aggregator_gateways_()` — truncated manifests emit `"manifest":null` with warning log
- PSRAM-aware aggregator gating in `render_sensor_config.py`: no PSRAM → `AGGREGATOR_ENABLED 0` (satellite only), PSRAM → up to 8 satellites
- `#define AGG_MANIFEST_BUF_SIZE 8192` emitted in generated `aggregator_config.h`
- BUG-074 and LESSON-OPS-085 documented
- `Docs/aggregator-setup.md` updated with buffer sizes and PSRAM scaling rules
- **Fixup commit (`4336f33`) — PR #93 audit corrections:**
  - Heading hierarchy fixed in `Docs/aggregator-setup.md` (`## 2.1)` → `### 2.1)`)
  - Magic numbers extracted to `SATELLITE_CAP_PSRAM = 8` and `AGG_MANIFEST_BUF_SIZE_BYTES = 8192` module-level constants in `render_sensor_config.py`
  - Instruction Compliance Output table (16 rows) added to session log

**PR #93 merged 2026-03-28. 5 commits, 28 files changed.**

### Cumulative state entering Phase D

| Phase | Version Range | Status |
|-------|--------------|--------|
| Phase 1–3 | v7.5.0.x–v7.5.3.x | ✅ Complete |
| Phase 4 | v7.5.4.x | ✅ Complete |
| Phase 5 | v7.5.5.x | ✅ Complete |
| Phase 6 | v7.5.6.x | ✅ Complete |
| v7.5.7.0 | Bridge step | ✅ Complete |
| **Phase D** | **v7.6.0.x** | **⬅️ Starting** |

### Key infrastructure that Phase D builds on

- **`SatelliteCache` struct** — static array of `MAX_SATELLITES` entries with manifest/live/status JSON buffers, health tracking, and mutex protection
- **`init_aggregator_satellites()`** — currently copies compile-time arrays into `satellite_caches[]`. Phase D v7.6.0.0 modifies this to try NVS first.
- **Stub endpoints** — `POST /api/aggregator/add-satellite`, `DELETE /api/aggregator/satellite/{id}`, `POST /api/aggregator/test-satellite` all return 501 today. Phase D v7.6.0.1–v7.6.0.3 replace these with working implementations.
- **Dashboard Settings panel** — read-only display of satellite list. Phase D v7.6.0.4 adds add/remove/test controls.
- **`MAX_SATELLITES`** — compile-time constant. After v7.5.7.0, boards without PSRAM get `AGGREGATOR_ENABLED 0` (satellite only). PSRAM boards get up to 8 satellites. Phase D introduces `runtime_satellite_count` to track actual count at runtime while `MAX_SATELLITES` remains the array sizing upper bound.
- **Aggregator mutex** — `s_cache_mutex` protects all `satellite_caches[]` reads/writes. Phase D NVS operations and API handlers must acquire this mutex.

---

## Pre-Phase-D Checklist

Before starting v7.6.0.0:

- [x] v7.5.7.0 merged to main and tagged — merged 2026-03-28T21:19:35Z
- [ ] Device testing completed:
  - [ ] S3 aggregator compiles and boots with `MAX_SATELLITES` ≤ 8
  - [ ] `/api/aggregator/gateways` returns valid JSON
  - [ ] Heap values recorded (internal + total)
- [ ] All Playwright fixture sets passing:
  ```bash
  FIXTURE_SET=3sensor npx playwright test --project=chromium
  FIXTURE_SET=mixed npx playwright test --grep "Mixed-Category" --project=chromium
  FIXTURE_SET=system npx playwright test --grep "System Devices" --project=chromium
  FIXTURE_SET=aggregator npx playwright test --grep "Aggregator" --project=chromium
  bash scripts/preflight.sh
  python3 scripts/render_sensor_config.py --check
  ```

---

## Phase D Step Index

| Version | Scope | Prompt File | Status |
|---------|-------|-------------|--------|
| v7.6.0.0 | NVS satellite persistence layer + runtime loop migration | `prompts/phaseD/v7.6.0.0-implementation-instructions-for-coding-agent-updated.md` | Pending |
| v7.6.0.1 | POST /api/aggregator/add-satellite | `prompts/phaseD/v7.6.0.1-implementation-instructions-for-coding-agent-updated.md` | Pending |
| v7.6.0.2 | DELETE /api/aggregator/satellite/{id} | `prompts/phaseD/v7.6.0.2-implementation-instructions-for-coding-agent-updated.md` | Pending |
| v7.6.0.3 | POST /api/aggregator/test-satellite | `prompts/phaseD/v7.6.0.3-implementation-instructions-for-coding-agent-updated.md` | Pending |
| v7.6.0.4 | Dashboard add/remove/test UI | `prompts/phaseD/v7.6.0.4-implementation-instructions-for-coding-agent-updated.md` | Pending |
| v7.6.0.5 | Playwright tests + Phase D closure | `prompts/phaseD/v7.6.0.5-implementation-instructions-for-coding-agent-updated.md` | Pending |

### Prompt variant note

Three prompt variants exist for each step:
- **Base** (`v7.6.0.x-...for-coding-agent.md`) — original drafts
- **Updated** (`v7.6.0.x-...-updated.md`) — base prompts with ambiguity fixes and hybrid improvements from the CL variants
- **CL** (`v7.6.0.x-...-CL.md`) — alternate prompt set with stronger low-level specificity

The comparison report (`prompts/phaseD/phaseD-prompt-comparison-report.md`) recommends the **`-updated`** variants for execution. Use those unless you have a specific reason to switch.

---

## What to Read Before v7.6.0.0

1. `Docs/phase-d-implementation-plan.md` — the Phase D plan. Covers NVS storage design, key scheme (`agg_sats` namespace, `s0_id`/`s0_name`/`s0_url`/`s0_poll` pattern), boot sequence, API contracts for all three endpoints.
2. `Docs/architecture-forward-looking-notes.md` — Section 1 (PSRAM aggregator restriction), Section 2 (manifest serving separation), Section 4 (NVS compaction risk).
3. `Docs/aggregator-setup.md` — updated in v7.5.7.0 with buffer sizes and PSRAM scaling rules.
4. `prompts/phaseD/phaseD-prompt-comparison-report.md` — comparison analysis. Read §1 (executive verdict) and §3 (per-step deltas) before starting.
5. `prompts/prompt-index-and-workflow.md` — all 35 critical rules. Phase D prompts should reference them.
6. `Docs/writing-prompts-for-coding-agents-guide.md` — especially §3.12 (mock contract fidelity) for the new API endpoints, and §3.13 (code quality gates).
7. `Docs/bugs-and-lessons-learned.md` — ALL entries. For Phase D:
   - BUG-043 (NVS scan yielding) — NVS loops must yield
   - BUG-048 (blob size mismatch) — NVS read failures must be handled gracefully
   - BUG-074 (manifest truncation) — the bug v7.5.7.0 fixed; informs buffer sizing decisions
   - LESSON-OPS-053 (NVS handles must close on every path)
   - LESSON-OPS-074 (aggregator boot = satellite + overlay)
8. `dashboard/sensor_history_multi.h` — the main file. Key locations:
   - `SatelliteCache` struct (~line 1371)
   - `init_aggregator_satellites()` — the function v7.6.0.0 modifies
   - `aggregator_poll_task_()` — the polling loop that uses `MAX_SATELLITES` (will change to `runtime_satellite_count`)
   - Stub endpoints (~line 3270+): `handle_add_satellite_()`, `handle_remove_satellite_()`, `handle_test_satellite_()`
   - All `for (int i = 0; i < MAX_SATELLITES; i++)` loops — v7.6.0.0 changes these to `runtime_satellite_count`

---

## Key Design Decisions for Phase D

These are settled — do not revisit during implementation:

1. **`runtime_satellite_count` replaces `MAX_SATELLITES` in loop bounds.** `MAX_SATELLITES` remains the compile-time array size. `runtime_satellite_count` tracks the actual active count. Set at boot from NVS (or compile-time fallback), incremented/decremented by add/remove APIs.

2. **NVS namespace `"agg_sats"`.** Separate from the history namespace. Keys: `count` (u8), `s{i}_id` (str), `s{i}_name` (str), `s{i}_url` (str), `s{i}_poll` (u16).

3. **Compile-time fallback on first boot.** If `count` key is absent from NVS, populate from `SATELLITE_IDS[]` / `SATELLITE_NAMES[]` / `SATELLITE_URLS[]` / `SATELLITE_POLL_INTERVALS[]` and write to NVS. This makes the first boot seamless.

4. **Add-satellite uses query parameters** (not JSON body). Contract: `POST /api/aggregator/add-satellite?url=...&name=...&poll=30`. This is consistent with `/api/ingest` and avoids the `handleBody()` limitation on ESPHome's AsyncWebServer.

5. **Test-satellite probes `/api/manifest`** at the candidate URL and returns the parsed manifest to the caller. No side effects — does not add the satellite.

6. **Remove-satellite by ID** (not by index). `DELETE /api/aggregator/satellite/{id}`. Compacts the array to avoid gaps.

7. **`POST /api/aggregator/reset-satellites`** — resets NVS satellite list to compile-time defaults. This is the escape hatch if NVS becomes corrupted.

---

## Phase 6 Lessons Relevant to Phase D

These lessons from Phase 6 apply directly to Phase D prompt execution:

| Lesson | Relevance to Phase D |
|--------|---------------------|
| LESSON-OPS-081 (mock contract fidelity) | Phase D adds 3 new API endpoints (add, remove, test). Each needs a full contract-lock in the prompt and contract-faithful mocks. |
| LESSON-OPS-082 (fixture composition ripple) | Phase D changes the aggregator fixture when `runtime_satellite_count` is introduced. Downstream text (test descriptions, skip reasons) must be audited. |
| Rule 29 (prompt code = production code) | Phase D prompts contain C++ code blocks. The `-updated` variants have been reviewed, but verify during execution. |
| Rule 30 (no stub-level mocking) | Mock endpoints for add/remove/test must mirror all firmware validation branches. |
| LESSON-OPS-074 (aggregator boot = satellite + overlay) | The NVS satellite loading in v7.6.0.0 is an extension of the boot overlay pattern. It must not break the satellite boot path. |

---

## v7.5.7.0 Lessons

| Lesson | Description |
|--------|-------------|
| LESSON-OPS-086 | Prompt Do-NOT lists must exclude expected regeneration side-effects. "Do NOT change dashboard JS" conflicts with `bump-version.sh` which changes `App.version`. |
| LESSON-OPS-087 | Prompt-provided code blocks must apply the same constant policy as the target codebase. Python literal `8192` was inconsistent with C++ named `AGG_MANIFEST_BUF_SIZE`. |
| LESSON-OPS-088 | Mandatory deliverable tables should be templated with placeholder rows in the session log section to prevent omission. |

---

## Device Testing Resources

Phase D requires two devices throughout:

- **S3 aggregator** (PSRAM, runs aggregator firmware with `config/aggregator.json`)
- **C3 satellite** (at least one, reachable from aggregator over network)

Device testing highlights per step:
- **v7.6.0.0:** Boot with NVS satellites, reboot and verify persistence, clear NVS and verify compile-time fallback
- **v7.6.0.1:** Add satellite via API, verify polling starts, verify NVS persistence across reboot
- **v7.6.0.2:** Remove satellite via API, verify polling stops, verify NVS updated
- **v7.6.0.3:** Test-satellite probe, verify no side effects (satellite not added)
- **v7.6.0.4:** Full browser test of dashboard add/remove/test workflow
- **v7.6.0.5:** Playwright regression + Phase D closure verification

---

## Prompt Index Update Needed

The `prompts/prompt-index-and-workflow.md` Phase D section currently says `_Prompt not yet created_` for all steps. After v7.6.0.0 begins, update the index to reference the `-updated` prompt files in `prompts/phaseD/`. Example:

```
| v7.6.0.0 | NVS satellite persistence layer | `prompts/phaseD/v7.6.0.0-implementation-instructions-for-coding-agent-updated.md` | Pending |
```

---

## Post-Phase-D Roadmap

After Phase D completes (v7.6.0.5 merged):
1. **Phase 7** (v7.7.0.x–v7.7.2.x) — Per-device persistence engine. Prompts exist for v7.7.0.0, v7.7.0.1, v7.7.1.0.
2. **Phase E** (v8.0.x) — Captive portal + WiFi config. Not yet planned.

---

_End of session handoff document._
