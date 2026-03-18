# Phase 3–5 — Assistant Prompt Templates (Revised 2026-03-18)

_Revised: 2026-03-18 (post-Phase-3 completion, BUG-044 fix, expanded Phase 4/5 prompts)_
_Usage: Copy the prompt for the current step into a new conversation with the assistant._
_Each prompt is self-contained — the assistant should be able to implement the step from scratch._

---

## How to Use These Prompts

### Starting a new step

1. Confirm the previous step is merged and device-tested (if applicable)
2. Open a new conversation with the assistant
3. Use the master prompt template below, filling in the step-specific details
4. The assistant will clone the repo, read the required docs, and implement the step

### Master prompt template

```
Clone https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Before making ANY changes, read these files completely:
1. Docs/phase<N>-implementation-plan.md (where N = 3, 4, or 5)
2. Docs/bugs-and-lessons-learned.md
3. Docs/changelog.md
4. The step-specific instructions: prompts/phase<N>/v<VERSION>-implementation-instructions.md

Then implement v<VERSION> exactly as specified in the instructions file.

Current status:
- Previous step v<PREV_VERSION> is complete and merged
- Device testing results from previous step: <PASTE RESULTS OR "confirmed passing">
- main is green
- Current date: <TODAY>

Follow all rules listed under "Critical rules" in the instructions file.
After implementation, run validation (preflight + Playwright tests), create a PR,
and provide the exact device testing checklist for me to execute post-merge.
Do NOT proceed to any later step.
```

### After the assistant completes work

1. Review the PR diff
2. Approve pending workflows if needed
3. Wait for all CI checks to pass
4. Merge only if all checks are green
5. If any workflow fails: copy the exact failure output, send it back, and wait
6. After merge, execute the device testing checklist the assistant provided
7. After device testing passes, apply the git tag:
   ```bash
   git pull origin main
   git tag -a v<VERSION> -m "<description from instructions file>"
   git push origin v<VERSION>
   ```
8. Record test results for the next step's status section

---

## Step Index

### Phase 3 — C++ SensorEntity Model ✅ COMPLETE

| Version | Scope | Status |
|---|---|---|
| v7.5.3.0 | Pre-Phase 3 cleanup | ✅ Complete |
| v7.5.3.1 | Define SensorEntity structs | ✅ Complete |
| v7.5.3.2 | Generator dual output | ✅ Complete |
| v7.5.3.3 | Wire YAML lambdas (dual-write) | ✅ Complete |
| v7.5.3.4 | BUG-043 hotfix + LWIP sockets | ✅ Complete |
| v7.5.3.5 | BUG-043 continued fix (sequential history) | ✅ Complete |
| (no bump) | BUG-043 gzip + pre-reserved history response | ✅ Complete |
| v7.5.3.6 | `/api/v2/live` endpoint | ✅ Complete |
| v7.5.3.7 | `/api/v2/history` endpoint (RAM-only) | ✅ Complete |
| v7.5.3.8 | Remove SensorSlot (BIG SWITCHOVER) | ✅ Complete |
| v7.5.3.9 | Phase 3 closure | ✅ Complete |

### BUG-043 Supplementary (BUG-044)

| Item | Scope | Status |
|---|---|---|
| Preflight enhancements | 5 new checks per BUG-043-preflight-enhancement-instructions.md | ✅ Complete (2026-03-18) |
| Browser regression tests | Group 16: 8 tests per BUG-043-browser-test-implementation-instructions.md | ✅ Complete (2026-03-18) |

### Phase 4 — First Non-Climate Sensor (Ping Probe)

| Version | Scope | Status |
|---|---|---|
| **v7.5.4.0** | **Add ping device to manifest** | **Next** |
| v7.5.4.1 | Implement ICMP ping adapter | Pending |
| v7.5.4.2 | Add network card renderer | Pending |
| v7.5.4.3 | Mixed-category test fixtures | Pending |
| v7.5.4.4 | Phase 4 closure | Pending |

### Phase 5 — Aggregator MVP

| Version | Scope | Status |
|---|---|---|
| v7.5.5.0 | Aggregator config schema | Pending |
| v7.5.5.1 | Aggregator polling task | Pending |
| v7.5.5.2 | Aggregator API endpoints | Pending |
| v7.5.5.3 | Aggregator dashboard UI | Pending |
| v7.5.5.4 | Aggregator Playwright tests | Pending |
| v7.5.5.5 | Phase 5 closure | Pending |

---

## BUG-043 Lessons Applied Across All Prompts (CRITICAL)

These rules were established during BUG-043 resolution and apply to every future step:

| Lesson | Rule |
|---|---|
| LESSON-OPS-050 | In-flight guards mandatory on interval-driven fetch functions |
| LESSON-OPS-051 | Dashboard network changes require real-device validation |
| LESSON-OPS-052 | History fetches must be sequential, never concurrent |
| LESSON-OPS-053 | NVS scan loops must yield (vTaskDelay every N blobs) |
| LESSON-OPS-054 | Startup polling must be batch=1; ESPHome handler ordering matters |
| LESSON-OPS-055 | Gzip-compress large embedded responses; preflight must guard format |
| LESSON-OPS-056 | Never use beginResponseStream for responses >10KB — use pre-reserved string |
| **LESSON-OPS-057** | **Specified tests/checks must be tracked to implementation completion** |
| **LESSON-OPS-058** | **Device testing sections must include full local workflow (pull, compile, flash, verify)** |

### Code rules (apply to every step)
1. Operate autonomously, ask if anything is unclear
2. Update documentation alongside code — no drift allowed
3. Use `bash scripts/bump-version.sh <version>` for every version bump
4. Regenerate all artifacts after source changes (`generate-header.sh`, `render_sensor_config.py --write`)
5. Run `bash scripts/preflight.sh` — must pass
6. Run full Playwright test suite — all tests must pass
7. Mirror all `dashboard.js` changes to `dashboard.html` (LESSON-OPS-043)
8. Use `::time(nullptr)` not `time(nullptr)` in ESPHome C++ (project convention)
9. Never fire concurrent history requests from dashboard JS (LESSON-OPS-052)
10. **Never use `beginResponseStream` for responses >10KB** — use pre-reserved `std::string` + zero-copy `beginResponse` (LESSON-OPS-056)
11. **Dashboard.h must be gzip-compressed** — `generate-header.sh` handles this (LESSON-OPS-055)
12. **Device testing sections must include full pull/compile/flash/verify workflow** (LESSON-OPS-058)
