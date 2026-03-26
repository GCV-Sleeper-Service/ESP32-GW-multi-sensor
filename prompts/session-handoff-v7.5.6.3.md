# Session Handoff — v7.5.6.3: Example Exporter Scripts + Documentation

_Date: 2026-03-26_
_Repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor_

---

## Project State Summary

**v7.5.6.2** is the current version on `main`. Phase 6 Steps 0–2 are complete and merged.

Key changes in v7.5.6.2 (PR #83):
- `CARD_RENDERERS.system` registered in `dashboard.js` — dispatches `buildSystemCard()`
- `buildSystemCard()` renders horizontal usage bars (CPU, RAM, Disk) + uptime value + last-seen timestamp
- `buildUsageBarRow()` helper generates the bar HTML structure
- `METRIC_FORMATTERS` added: `cpu_usage`, `ram_usage`, `disk_usage`, `uptime_hours` (note: these keys intentionally do NOT match the manifest metric keys `cpu_pct`, `ram_pct`, `disk_pct`, `uptime_hrs`)
- `updateSystemCards()` processes `/api/v2/live` data for system devices in satellite mode
- `_updateSystemCardDOM()` DRY helper extracted (shared by satellite and aggregator paths)
- `updateUsageBar()` helper with color coding: `bar-ok` (<60%), `bar-warning` (60–80%), `bar-danger` (>80%)
- `pollV2Live()` response handler now calls both `updateNetworkCards()` and `updateSystemCards()`
- System card CSS added: `.system-card`, `.system-usage-row`, `.system-bar-bg`, `.system-bar-fill`, `.bar-ok/warning/danger`
- Aggregator mode: system branch added to `_populateGatewayDeviceLive()` using shared `_updateSystemCardDOM()`
- ALL changes mirrored to `dashboard.html` (LESSON-OPS-043)
- `dashboard.h` regenerated (gzip-compressed)
- `description` field escaped with `escHtml()` (BUG-073 fix)
- `last_seen` guard changed from truthy to explicit null/undefined check (BUG-072 fix)
- `updateUsageBar()` includes `isFinite()` guard for NaN protection (BUG-074 fix)

Cumulative Phase 6 state:
- v7.5.6.0: `POST /api/ingest/{device_id}/{metric_key}?val={float}` endpoint ✅
- v7.5.6.1: `nas01` system device in manifest, `external_push` adapter, `_SYSTEM_METRICS` constant ✅
- v7.5.6.2: System card renderer with usage bars, satellite + aggregator support ✅

---

## Pre-merge Checklist

Before starting v7.5.6.3:

- [ ] PR #83 merged to main
- [ ] Tag created: `git tag -a v7.5.6.2 -m "Phase 6 Step 2: System card renderer with usage bars"`
- [ ] Tag pushed: `git push origin v7.5.6.2`
- [ ] Local Playwright validation passed:
  ```bash
  FIXTURE_SET=3sensor npx playwright test --project=chromium
  FIXTURE_SET=mixed npx playwright test --grep "Mixed-Category" --project=chromium
  FIXTURE_SET=aggregator npx playwright test --grep "Aggregator" --project=chromium
  ```
- [ ] Device test completed (§10 of v7.5.6.2 prompt):
  ```bash
  cd /config/ESP32-GW-multi-sensor && git pull origin main
  esphome compile firmware/esp32-c3-multi-sensor.yaml
  esphome run firmware/esp32-c3-multi-sensor.yaml

  # Push test data:
  curl -X POST "http://192.168.120.189/api/ingest/nas01/cpu_pct?val=45.2"
  curl -X POST "http://192.168.120.189/api/ingest/nas01/ram_pct?val=72.8"
  curl -X POST "http://192.168.120.189/api/ingest/nas01/disk_pct?val=55.0"
  curl -X POST "http://192.168.120.189/api/ingest/nas01/uptime_hrs?val=168.5"

  # Open dashboard — verify:
  # - 3 environmental cards (unchanged)
  # - 1 network card (unchanged)
  # - 1 NEW system card with CPU/RAM/disk bars filled + uptime showing "7.0 days"
  # - Toggle dark/light mode — bars visible in both
  # - CPU bar green (45.2%), RAM bar yellow (72.8%), Disk bar green (55.0%)
  ```

---

## What to Read Before v7.5.6.3

| Priority | Document | Why |
|----------|----------|-----|
| 1 | `prompts/phase6/v7.5.6.3-implementation-instructions-for-coding-agent.md` | Step 3 prompt |
| 2 | `Docs/phase6-implementation-plan.md` — v7.5.6.3 section | Phase 6 design and acceptance criteria |
| 3 | `Docs/bugs-and-lessons-learned.md` — LESSON-OPS-074, LESSON-OPS-077, BUG-062 | Critical lessons |
| 4 | `Docs/v7.5-v7.6-architecture-plan.md` — Section 9.2 | Ingest endpoint design |
| 5 | `Docs/aggregator-setup.md` — §15 CI workaround | Deployment config handling |
| 6 | `prompts/prompt-index-and-workflow.md` — Critical Rules 1–28 | All project guardrails |
| 7 | `Docs/writing-prompts-for-coding-agents-guide.md` | Prompt authoring methodology |

---

## Phase 6 Progress

| Step | Version | Scope | Status |
|------|---------|-------|--------|
| 0 | v7.5.6.0 | POST /api/ingest endpoint | ✅ Complete (merged) |
| 1 | v7.5.6.1 | System device category + manifest | ✅ Complete (merged) |
| 2 | v7.5.6.2 | System card renderer (CARD_RENDERERS.system) | ✅ Complete (PR #83, merged) |
| **3** | **v7.5.6.3** | **Example exporter scripts + documentation** | **⬅️ Next** |
| 4 | v7.5.6.4 | Test fixtures + Playwright + Phase 6 closure | Pending |

---

## Key Codebase Facts for v7.5.6.3

### Scope: Scripts + Docs only

v7.5.6.3 creates **NO firmware or dashboard changes**. It produces:
1. A bash exporter script for Linux hosts (`scripts/exporters/system-metrics-exporter.sh`)
2. A Python exporter script — cross-platform, stdlib-only (`scripts/exporters/system-metrics-exporter.py`)
3. A comprehensive data ingest setup guide (`Docs/data-ingest-setup.md`)

This is the lowest-risk step in Phase 6. No compiled artifacts change beyond version bump regeneration.

### Ingest API contract

The exporter scripts must target this exact API:
```
POST /api/ingest/{device_id}/{metric_key}?val={float}
```

Response codes:
- `200` with `{"ok":true}` — success
- `404` — unknown device ID or metric key
- `400` — missing or invalid `val` parameter

Metric keys for the `nas01` system device: `cpu_pct`, `ram_pct`, `disk_pct`, `uptime_hrs`

### Python exporter — stdlib-only constraint ⚠️

The Python exporter MUST use only stdlib modules. **Do NOT** add `psutil`, `requests`, or any pip dependency. The CPU metric uses `os.getloadavg()` / `os.cpu_count()` — this is an intentional load-average approximation, not actual CPU utilization. The prompt explicitly warns against "improving" this.

### Bash exporter — error handling

The bash script uses `|| echo "0"` fallbacks for each metric collection command and `|| true` on curl calls. This makes it safe for cron usage where failures should not break the crontab.

### Documentation coverage

`Docs/data-ingest-setup.md` must cover 9 sections:
1. Overview
2. Prerequisites
3. Adding a system device
4. Using the bash exporter
5. Using the Python exporter
6. Custom exporters (API contract)
7. Monitoring
8. Troubleshooting
9. Security (no auth in v7.5.6.x, network isolation recommended)

### Generator pipeline

No firmware changes, but the generator still needs to run for version bump:
```bash
bash scripts/bump-version.sh 7.5.6.3
python3 scripts/render_sensor_config.py --write
node tests/fixtures/generate-fixtures.js
bash scripts/generate-header.sh
python3 scripts/render_sensor_config.py --check
grep -q "free_heap" tests/fixtures/api-status.json
bash scripts/preflight.sh
```

### Deferred item from v7.5.6.2

The "Network card live data polling" section comment in `dashboard.js` is stale — `pollV2Live()` now drives both network and system updates. This is low-priority cosmetic debt. If the agent touches `dashboard.js` for version bump, it could fix this, but it's not required.

### What v7.5.6.3 needs to do

1. Create `scripts/exporters/system-metrics-exporter.sh` (executable)
2. Create `scripts/exporters/system-metrics-exporter.py` (executable)
3. Create `Docs/data-ingest-setup.md` (comprehensive 9-section guide)
4. Version bump to 7.5.6.3
5. Run full regeneration pipeline (Critical Rule 28)
6. Pass all Playwright tests (3sensor, mixed, aggregator)
7. Pass preflight
8. Create session log and changelog entry

### Test infrastructure

| Fixture Set | Command | Expected |
|-------------|---------|----------|
| 3sensor (baseline) | `FIXTURE_SET=3sensor npx playwright test --project=chromium` | ~97 pass, 18 skip |
| mixed | `FIXTURE_SET=mixed npx playwright test --grep "Mixed" --project=chromium` | 7 pass |
| aggregator | `FIXTURE_SET=aggregator npx playwright test --grep "Aggregator" --project=chromium` | 11 pass, 1 skip |

No new fixture variants needed for v7.5.6.3. System device test fixtures are deferred to v7.5.6.4 (LESSON-OPS-079).

---

## Known Issues and Technical Debt

| Issue | Severity | Blocking v7.5.6.3? |
|-------|----------|---------------------|
| Fixture variants lack system device (LESSON-OPS-079) | Medium | No — deferred to v7.5.6.4 |
| `config/*.json` CI workaround (no per-target builds) | Medium | No — documented workaround |
| Console error tests fail in proxy environments | Low | No — environment issue |
| `beginResponseStream` used in some older endpoints | Low | No — no firmware changes |
| Dashboard JS/HTML mirroring is manual | Medium | No — no dashboard changes in Step 3 |
| Section comment stale in `pollV2Live()` | Low | No — cosmetic, carry forward |
| `buildNetworkCard()` latent `description` XSS (same as BUG-073) | Low | No — audit in v7.5.6.4 |
| `updateNetworkCards()` latent `last_seen` truthy check (same as BUG-072) | Low | No — audit in v7.5.6.4 |

---

## Lessons Learned from v7.5.6.2 (Apply to v7.5.6.3)

1. **Prompt-provided code blocks can contain bugs.** 3 of 4 merge-blocking defects in PR #83 were in code the prompt provided verbatim. For v7.5.6.3, the prompt provides full script code — review the bash and Python scripts for edge cases before the agent reproduces them.

2. **Guard style consistency.** LESSON-OPS-080: if one guard in a code block uses explicit null/undefined checks, all guards must use the same pattern. For v7.5.6.3, this applies to the Python exporter's error handling — verify consistency between `try/except` blocks.

3. **`escHtml()` on all config-derived strings.** BUG-073 taught us that any string from config inserted into HTML must be escaped. Not directly relevant to v7.5.6.3 (no dashboard changes), but the data-ingest-setup.md should reference this when describing the system card.

4. **DRY extraction when code appears in two paths.** PR #83 had duplicated system update logic in satellite + aggregator paths until review caught it. For v7.5.6.3, the two exporter scripts share the same API contract — documentation should make this clear.

5. **Aggregator live-update path must be explicitly named in prompts.** The v7.5.6.2 prompt didn't name `_populateGatewayDeviceLive()`, which caused the agent to find it independently and duplicate code. Not relevant to v7.5.6.3 (no dashboard changes), but carry forward to v7.5.6.4 if it adds system-related tests.

---

## Workflow for v7.5.6.3

> **⚠️ IMPORTANT: Do NOT use this chat session to invoke the coding agent directly.**
> Large PRs created from chat-based agent invocations cause "merge too big" errors.
> Instead, run the coding agent's prompt script independently and wait for the PR to appear.

1. Merge PR #83 to main (if not already done)
2. Tag v7.5.6.2
3. Device test v7.5.6.2 (see Pre-merge Checklist above)
4. **Open a NEW coding agent session** (separate from this chat) and paste the prompt from `prompts/phase6/v7.5.6.3-implementation-instructions-for-coding-agent.md`
5. **Wait for the agent to create the PR** — do not proceed until the PR is open and visible on GitHub
6. **Copilot PR reviewer** reviews automatically
7. Human reviews PR against the Review Checklist in the prompt (§9)
8. Fix any issues (send failures back to the agent in the same session it used to create the PR)
9. **Produce PR and prompt audit documents** (see Post-PR Closure section below)
10. Merge to main
11. Device test using §10 of v7.5.6.3 prompt:
    ```bash
    # On a Linux host (NAS, Pi, etc.):
    bash scripts/exporters/system-metrics-exporter.sh http://192.168.120.189 nas01
    # Expected: output line showing pushed metrics

    # Or with Python:
    python3 scripts/exporters/system-metrics-exporter.py --gateway http://192.168.120.189 --device nas01
    # Expected: output line showing pushed metrics

    # Verify on dashboard: system card should update with real values
    ```
12. Tag: `git tag -a v7.5.6.3 -m "Phase 6 Step 3: Example exporter scripts and ingest documentation"`
13. Push tag: `git push origin v7.5.6.3`

---

## Post-PR Closure Deliverables

After the v7.5.6.3 PR is merged (or during review), produce these documents:

### 1. Session Handoff Document
**File:** `session-handoff-v7.5.6.4.md`
**Format:** Same as this document. Must include:
- Project state summary with v7.5.6.3 changes
- Pre-merge checklist for v7.5.6.4
- Key codebase facts for v7.5.6.4 scope (test fixtures, Playwright tests, Phase 6 closure)
- Lessons learned from v7.5.6.3
- Post-PR closure deliverables section (recursive)
- **Note:** v7.5.6.4 is the Phase 6 closure step — the handoff should include the full list of Phase 6 acceptance criteria from `Docs/phase6-implementation-plan.md`

### 2. PR and Prompt Audit Document
**File:** `v7.5.6.3-prompt-and-pr-audit.md`
**Format:** Same as `v7.5.6.2-prompt-and-pr-audit.md`. Must include:

#### Part I — Prompt Audit
- What the prompt does well
- Critical prompt defects (A1–AN format)
- Prompt-vs-guide compliance summary
- Specific checks for v7.5.6.3:
  - Does the prompt provide complete, copy-ready script code?
  - Does the prompt warn about the stdlib-only constraint explicitly?
  - Does the prompt specify the `data-ingest-setup.md` section list?
  - Does the prompt address script executability (`chmod +x`)?
  - Does the prompt specify error handling patterns for both scripts?
  - Does the prompt address the CPU metric approximation intentionally?

#### Part II — PR Audit
- What the PR did correctly
- Key PR defects found (with severity and merge-blocker status)
- Review comment resolution table
- Agent responsibility vs prompt responsibility attribution

#### Part III — Lessons
- New lessons for `bugs-and-lessons-learned.md`
- Updates needed for `writing-prompts-for-coding-agents-guide.md`
- Fixes needed for v7.5.6.4 prompt (if any)

### 3. Updated Prompt Corrections (if needed)
If the v7.5.6.3 audit reveals defects in the v7.5.6.4 prompt, produce correction text.

---

## v7.5.6.4 Preview — What Comes After v7.5.6.3

v7.5.6.4 is the **Phase 6 closure step**. Its scope includes:
- New fixture variant with system device (satisfies LESSON-OPS-079)
- Playwright Group 18+ tests for system card rendering
- System card color coding tests
- Ingest endpoint mock in test server
- Architecture plan updated with "Phase 6 COMPLETE"
- Phase 6 Complete callout in changelog
- **Carry-forward items from v7.5.6.2 audit:**
  - Audit `buildNetworkCard()` for latent `description` XSS (BUG-073 pattern)
  - Audit `updateNetworkCards()` for latent `last_seen` truthy check (BUG-072 pattern)

---

_End of session handoff document._
