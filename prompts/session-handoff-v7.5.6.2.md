# Session Handoff — v7.5.6.2: System Card Renderer

_Date: 2026-03-26_
_Repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor_
_Current HEAD: PR #82 pending merge (`copilot/implement-phase6-step-again` → `main`)_

---

## Project State Summary

**v7.5.6.1** is the current version on the `copilot/implement-phase6-step-again` branch (PR #82). Phase 6 Step 1 (system device category + manifest) is complete and audit-verified. PR #82 must be merged and tagged before starting Step 2.

Key changes in v7.5.6.1:
- `nas01` system device added to `config/sensors.json` with `category: "system"`, `adapter: "external_push"`
- `_SYSTEM_METRICS` constant added to `sensor_manifest_lib.py` (cpu_pct, ram_pct, disk_pct, uptime_hrs)
- `render_entity_block()` extended with `external_push` branch
- `manifest_v2()` extended with `external_push` branch producing correct measurements
- `render_yaml_averaging()` and `generate_board_yaml()` extended for `external_push` — `compute_averages(epoch)` now runs for system devices
- `MAX_SENSORS` raised to 5
- `canonicalize_sensors()` hardened with adapter→category mapping and mismatch rejection
- SENSOR COUNT CONFIGURATION GUIDE updated to distinguish NUM_ENV_SENSORS vs NUM_DEVICES
- History stub CSVs generated for system metrics
- LESSON-OPS-079 documented (fixture variant gap deferred to v7.5.6.4)
- All 34 changed files include version bump artifacts, docs, and fixtures

---

## Pre-merge Checklist

Before starting v7.5.6.2:

- [ ] PR #82 merged to main
- [ ] Tag created: `git tag -a v7.5.6.1 -m "Phase 6 Step 1: System device category and manifest entries"`
- [ ] Tag pushed: `git push origin v7.5.6.1`
- [ ] Local Playwright validation passed:
  ```bash
  FIXTURE_SET=3sensor npx playwright test --project=chromium
  FIXTURE_SET=mixed npx playwright test --grep "Mixed-Category" --project=chromium
  FIXTURE_SET=aggregator npx playwright test --grep "Aggregator" --project=chromium
  ```
- [ ] Device test completed (§10 of v7.5.6.1 prompt):
  ```bash
  curl -X POST "http://192.168.120.189/api/ingest/nas01/cpu_pct?val=45.2"
  # Expected: {"ok":true}
  curl -s http://192.168.120.189/api/v2/live | jq '.devices.nas01'
  # Expected: cpu_pct: 45.2
  ```

---

## What to Read Before v7.5.6.2

| Priority | Document | Why |
|----------|----------|-----|
| 1 | `prompts/phase6/v7.5.6.2-implementation-instructions-for-coding-agent.md` | Step 2 prompt |
| 2 | `Docs/phase6-implementation-plan.md` | Phase 6 design and acceptance criteria |
| 3 | `Docs/bugs-and-lessons-learned.md` — LESSON-OPS-043, BUG-056, BUG-064, BUG-065, LESSON-OPS-079 | Critical lessons |
| 4 | `dashboard/dashboard.js` — `CARD_RENDERERS`, `buildNetworkCard()`, `pollV2Live()`, `updateNetworkCards()` | Card renderer pattern |
| 5 | `dashboard/dashboard.html` — CSS structure, JS mirror requirement | HTML mirroring |
| 6 | `prompts/prompt-index-and-workflow.md` — Critical Rules 1–28 | All project guardrails |
| 7 | `Docs/writing-prompts-for-coding-agents-guide.md` | Prompt authoring methodology |

---

## Phase 6 Progress

| Step | Version | Scope | Status |
|------|---------|-------|--------|
| 0 | v7.5.6.0 | POST /api/ingest endpoint | ✅ Complete (merged) |
| 1 | v7.5.6.1 | System device category + manifest | ✅ Complete (PR #82, pending merge) |
| **2** | **v7.5.6.2** | **System card renderer (CARD_RENDERERS.system)** | **⬅️ Next** |
| 3 | v7.5.6.3 | Example exporter scripts + documentation | Pending |
| 4 | v7.5.6.4 | Test fixtures + Playwright + Phase 6 closure | Pending |

---

## Key Codebase Facts for v7.5.6.2

### Dashboard architecture

- `CARD_RENDERERS` registry dispatches card rendering by device category. Has `environmental`, `network`, `_default`. Step 2 adds `system`.
- `buildNetworkCard()` is the reference pattern for non-environmental cards.
- `pollV2Live()` polls `/api/v2/live` every 15 seconds. `updateNetworkCards()` currently only handles `category === 'network'`.
- **System device data does NOT come through ESPHome SSE.** Same as network — comes via `/api/v2/live` REST polling.
- Aggregator: local system cards render in SENSORS section; remote satellite system cards render in GATEWAYS section. `renderGatewayDevices()` dispatches via `CARD_RENDERERS[category]`.

### Metric key naming — POTENTIAL TRAP ⚠️

The v7.5.6.2 prompt §5c defines metric formatter keys as:
- `METRIC_FORMATTERS.cpu_usage`
- `METRIC_FORMATTERS.ram_usage`
- `METRIC_FORMATTERS.disk_usage`
- `METRIC_FORMATTERS.uptime_hours`

But the manifest metric keys (from v7.5.6.1) are:
- `cpu_pct`, `ram_pct`, `disk_pct`, `uptime_hrs`

The `updateSystemCards()` code in §5d correctly uses `devData.cpu_pct` (manifest keys), but the formatter names don't match the manifest keys. This is not a bug (formatters are called explicitly, not by key lookup), but it could confuse the agent. **Verify the agent doesn't try to auto-wire formatters by manifest key name.**

### HTML mirroring (LESSON-OPS-043)

ALL JS changes to `dashboard.js` MUST be mirrored to `dashboard.html`. The prompt §5f calls this out explicitly. This is always the highest-risk item in dashboard steps.

### Generator pipeline

No firmware changes in Step 2. Only dashboard files change. But the generator still needs to run for version bump:
```bash
bash scripts/bump-version.sh 7.5.6.2
python3 scripts/render_sensor_config.py --write
node tests/fixtures/generate-fixtures.js
bash scripts/generate-header.sh
python3 scripts/render_sensor_config.py --check
grep -q "free_heap" tests/fixtures/api-status.json
bash scripts/preflight.sh
```

### What v7.5.6.2 needs to do

1. Register `CARD_RENDERERS.system` in `dashboard.js`
2. Implement `buildSystemCard()` with horizontal usage bars (CPU, RAM, Disk) and uptime value
3. Implement `buildUsageBarRow()` helper
4. Add `METRIC_FORMATTERS` for cpu/ram/disk/uptime
5. Implement `updateSystemCards()` to process `/api/v2/live` data
6. Implement `updateUsageBar()` helper with color coding (green/yellow/red)
7. Wire `updateSystemCards()` into `pollV2Live()` response handler
8. Add system card CSS (`.system-card`, `.system-bar-*`, `.bar-ok/warning/danger`)
9. Mirror ALL changes to `dashboard.html` (LESSON-OPS-043)
10. Regenerate `dashboard.h` (gzip-compressed)

### Test infrastructure

| Fixture Set | Command | Expected |
|-------------|---------|----------|
| 3sensor (baseline) | `FIXTURE_SET=3sensor npx playwright test --project=chromium` | ~97 pass, 18 skip |
| mixed | `FIXTURE_SET=mixed npx playwright test --grep "Mixed" --project=chromium` | 7 pass |
| aggregator | `FIXTURE_SET=aggregator npx playwright test --grep "Aggregator" --project=chromium` | 11 pass, 1 skip |

Note: No fixture variant includes the system device yet (LESSON-OPS-079). System card rendering is verified by device testing only until v7.5.6.4.

---

## Known Issues and Technical Debt

| Issue | Severity | Blocking v7.5.6.2? |
|-------|----------|---------------------|
| Fixture variants lack system device (LESSON-OPS-079) | Medium | No — deferred to v7.5.6.4 |
| `config/*.json` CI workaround (no per-target builds) | Medium | No — documented workaround |
| Console error tests fail in proxy environments | Low | No — environment issue |
| `beginResponseStream` used in some older endpoints | Low | No — no firmware changes in Step 2 |
| Dashboard JS/HTML mirroring is manual | Medium | **YES — highest risk item** |
| Metric formatter key names don't match manifest keys | Low | No — but verify agent doesn't auto-wire |

---

## Lessons Learned from v7.5.6.1 (Apply to v7.5.6.2)

These lessons from the v7.5.6.1 audit should be applied when reviewing v7.5.6.2:

1. **Data flow tracing:** The prompt must trace the complete data path. For v7.5.6.2: `pollV2Live() → fetch /api/v2/live → updateSystemCards() → DOM update`. Verify the prompt covers every link.
2. **"Follow X pattern" must enumerate sites:** The prompt references `buildNetworkCard()` — verify it names every function and file that needs to change.
3. **Validation gates:** No new validation gates expected in Step 2 (no firmware changes), but verify dashboard rendering doesn't break existing tests.
4. **Generated comments:** If the dashboard has any developer-facing guide comments, verify they're updated.
5. **Review-fix cycle cost:** The prompt provides full code for all functions — this should minimize ambiguity and reduce fix cycles.

---

## Workflow for v7.5.6.2

1. Merge PR #82 to main
2. Tag v7.5.6.1
3. Device test v7.5.6.1 (see Pre-merge Checklist above)
4. Paste `prompts/phase6/v7.5.6.2-implementation-instructions-for-coding-agent.md` to coding agent
5. Agent implements, creates PR
6. **Copilot PR reviewer** reviews automatically
7. Human reviews PR against the Review Checklist in the prompt
8. **Produce PR and prompt audit documents** (see Post-PR Closure section below)
9. Fix any issues (agent or human)
10. Merge to main
11. Device test using §10 of v7.5.6.2 prompt
12. Tag: `git tag -a v7.5.6.2 -m "Phase 6 Step 2: System card renderer"`

---

## Post-PR Closure Deliverables

After the v7.5.6.2 PR is merged (or during review), produce these documents:

### 1. Session Handoff Document
**File:** `session-handoff-v7.5.6.3.md`
**Format:** Same as this document. Must include:
- Project state summary with v7.5.6.2 changes
- Pre-merge checklist for v7.5.6.3
- Key codebase facts for v7.5.6.3 scope (exporter scripts)
- Lessons learned from v7.5.6.2
- Post-PR closure deliverables section (recursive)

### 2. PR and Prompt Audit Document
**File:** `v7.5.6.2-prompt-and-pr-audit.md`
**Format:** Same as `v7.5.6.1-prompt-and-pr-audit.md`. Must include:

#### Part I — Prompt Audit
- What the prompt does well
- Critical prompt defects (using the 10-point defect registry format: A1–AN)
- Prompt-vs-guide compliance summary (check all items from §9 pre-flight checklist in `writing-prompts-for-coding-agents-guide.md`)
- Specific checks for v7.5.6.2:
  - Does the prompt trace the full data path (pollV2Live → updateSystemCards → DOM)?
  - Does the prompt identify the HTML mirroring requirement explicitly?
  - Does the prompt warn about the metric key naming mismatch?
  - Does the prompt identify all functions in `dashboard.js` that need modification?
  - Does the prompt address aggregator mode rendering?

#### Part II — PR Audit
- What the PR did correctly
- Key PR defects found (with severity and merge-blocker status)
- Review comment resolution table (# | File | Issue | Sev | Fixed? | Commit)
- Agent responsibility vs prompt responsibility attribution

#### Part III — Lessons
- New lessons for `bugs-and-lessons-learned.md`
- Updates needed for `writing-prompts-for-coding-agents-guide.md`
- Fixes needed for remaining Phase 6 prompts (v7.5.6.3, v7.5.6.4)

### 3. Updated Prompt Corrections (if needed)
If the v7.5.6.2 audit reveals defects in the v7.5.6.3 or v7.5.6.4 prompts, produce
correction text in the same format as Task 4 in the v7.5.6.1 session.

---

## What Comes After Phase 6

| Phase | Version | Description | Plan Document |
|-------|---------|-------------|---------------|
| Phase D | v7.6.0.x | Runtime satellite management (NVS persistence, dashboard add/remove/test UI) | `Docs/phase-d-implementation-plan.md` |
| Phase 7 | v7.7.x | Per-device persistence engine | `Docs/v7.7-v7.8-persistence-architecture.md` |
| Phase E | v8.x | Captive portal + WiFi config | Not yet planned |

---

_End of handoff document._