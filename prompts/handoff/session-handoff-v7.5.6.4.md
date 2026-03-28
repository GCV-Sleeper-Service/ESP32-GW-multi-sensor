# Session Handoff — v7.5.6.4: Test Fixtures + Playwright + Phase 6 Closure

_Date: 2026-03-26_
_Repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor_

---

## Project State Summary

**v7.5.6.3** is the current version on `main`. Phase 6 Steps 0–3 are complete and merged.

Key changes in v7.5.6.3 (PR #84):
- Created `scripts/exporters/system-metrics-exporter.sh` — bash exporter for Linux (cron-friendly, `LC_ALL=C`, `sed` value sanitization, `|| echo "0"` fallbacks, "Attempted push" log wording)
- Created `scripts/exporters/system-metrics-exporter.py` — Python stdlib-only exporter (Linux/macOS/Windows, one-shot and continuous mode via `--interval`, `with urllib.request.urlopen()` context manager, PEP 8 compliant imports at module top level, macOS RAM returns `0.0`)
- Created `Docs/data-ingest-setup.md` — comprehensive 9-section guide covering: Overview, Prerequisites, Adding a system device, Bash exporter, Python exporter, Custom exporters, Monitoring, Troubleshooting, Security
- Version bumped to 7.5.6.3 across all locations
- Full regeneration pipeline (Critical Rule 28) executed
- Scripts are executable (`chmod +x`)
- No firmware or dashboard logic changes

Cumulative Phase 6 state:
- v7.5.6.0: `POST /api/ingest/{device_id}/{metric_key}?val={float}` endpoint ✅
- v7.5.6.1: `nas01` system device in manifest, `external_push` adapter ✅
- v7.5.6.2: System card renderer with usage bars, satellite + aggregator support ✅
- v7.5.6.3: Example exporter scripts + comprehensive documentation ✅

---

## Pre-merge Checklist

Before starting v7.5.6.4:

- [ ] PR #84 merged to main ✅ (merged 2026-03-26)
- [ ] Tag created: `git tag -a v7.5.6.3 -m "Phase 6 Step 3: Example exporter scripts and ingest documentation"`
- [ ] Tag pushed: `git push origin v7.5.6.3`
- [ ] Local Playwright validation passed (3sensor, mixed, aggregator):
  ```bash
  FIXTURE_SET=3sensor npx playwright test --project=chromium
  FIXTURE_SET=mixed npx playwright test --grep "Mixed" --project=chromium
  FIXTURE_SET=aggregator npx playwright test --grep "Aggregator" --project=chromium
  ```
- [ ] Device test completed:
  ```bash
  # On a Linux host (NAS, Pi, etc.):
  bash scripts/exporters/system-metrics-exporter.sh http://192.168.120.189 nas01
  python3 scripts/exporters/system-metrics-exporter.py --gateway http://192.168.120.189 --device nas01
  # Verify dashboard shows real values on system card
  ```

---

## What to Read Before v7.5.6.4

| Priority | Document | Why |
|----------|----------|-----|
| 1 | `prompts/phase6/v7.5.6.4-implementation-instructions-for-coding-agent.md` | Step 4 prompt |
| 2 | `Docs/phase6-implementation-plan.md` — v7.5.6.4 section | Phase 6 design and acceptance criteria |
| 3 | `prompts/phase6/v7.5.6.3-prompt-and-pr-audit.md` | Lessons from v7.5.6.3 |
| 4 | `Docs/bugs-and-lessons-learned.md` — LESSON-OPS-079, BUG-050/051 | Critical test fixture lessons |
| 5 | `Docs/writing-prompts-for-coding-agents-guide.md` — §3.11 | Test Group Implementation Guardrails |
| 6 | `tests/browser/dashboard.spec.js` | Current test groups and last group number |
| 7 | `tests/mock-server/server.js` | Mock server patterns |
| 8 | `prompts/prompt-index-and-workflow.md` — Critical Rules 1–28 | All project guardrails |

---

## Phase 6 Progress

| Step | Version | Scope | Status |
|------|---------|-------|--------|
| 0 | v7.5.6.0 | POST /api/ingest endpoint | ✅ Complete (merged) |
| 1 | v7.5.6.1 | System device category + manifest | ✅ Complete (merged) |
| 2 | v7.5.6.2 | System card renderer | ✅ Complete (merged) |
| 3 | v7.5.6.3 | Example exporter scripts + documentation | ✅ Complete (PR #84, merged) |
| **4** | **v7.5.6.4** | **Test fixtures + Playwright + Phase 6 closure** | **⬅️ Next** |

---

## Key Codebase Facts for v7.5.6.4

### Scope: Test fixtures, Playwright tests, Phase 6 closure

This is the final Phase 6 step. v7.5.6.4 creates no new firmware or dashboard application logic. It produces:
1. A new `system` fixture variant (`tests/fixtures/variants/system/`) with 2 ThermoPro + 1 network + 1 system device = 4 total sensors
2. Playwright Group N tests for system card rendering, colour coding, live update
3. Mock server extension: `/api/ingest/:deviceId/:metricKey` POST route
4. `/api/v2/live` returning non-null system device values for the `system` fixture
5. CI matrix update to include the `system` fixture set
6. Phase 6 Closure Gate (all acceptance criteria from `Docs/phase6-implementation-plan.md`)
7. Architecture plan updated with "Phase 6 COMPLETE"
8. Carry-forward audits: `buildNetworkCard()` for BUG-073 XSS pattern, `updateNetworkCards()` for BUG-072 truthy check pattern

### System fixture specification

- **Fixture set name:** `system`
- **Devices:** 2 ThermoPro environmental sensors + 1 network device (`wan_ping`) + 1 system device (`nas01`) = **4 total sensors**
- **LESSON-OPS-079 compliance:** The `mixed` fixture variant MUST also be updated to include `nas01` — the system device was added to `config/sensors.json` in v7.5.6.1, so all fixture variants derived from the live manifest must include it
- **Expected sensor count:** `expectedSensorCount: 4` (hardcoded integer, NOT computed)

### Mock server requirements for v7.5.6.4

- Add `/api/ingest/:deviceId/:metricKey` POST route responding `{"ok":true}` (mirrors firmware behaviour)
- `/api/v2/live` for the `system` fixture MUST return non-null values for `nas01` metrics (`cpu_pct`, `ram_pct`, `disk_pct`, `uptime_hrs`) so the system card renders with actual bar fills
- All existing routes must remain unchanged

### Test group guardrails (LESSON-OPS-079, BUG-050/051)

- New test group must use `expectedSensorCount: 4`, NOT `timeout: 30000`
- Sensor counts are hardcoded integers — never computed from fixture data
- Each test in the system group must include a `beforeEach` skip guard:
  ```js
  test.beforeEach(async ({ page }) => {
    if (process.env.FIXTURE_SET !== 'system') test.skip();
  });
  ```
- §5f MANDATORY existing-test audit: before adding the new group, verify all existing test groups still pass with the `system` fixture. This prevents BUG-051 (existing tests broken by new fixture).

### Phase 6 Closure Gate

All of the following must be true before v7.5.6.4 is merged:
- [ ] `system` fixture variant present and valid
- [ ] `mixed` fixture variant updated to include `nas01`
- [ ] Playwright `system` group tests pass: `FIXTURE_SET=system npx playwright test --grep "System" --project=chromium`
- [ ] Full `system` fixture run passes (not just the new group): `FIXTURE_SET=system npx playwright test --project=chromium`
- [ ] All existing fixture sets still pass: `3sensor`, `mixed`, `aggregator`
- [ ] Mock server `/api/ingest` route present and tested
- [ ] CI matrix updated to include `system` fixture set
- [ ] Architecture plan has "Phase 6 COMPLETE" marker
- [ ] `Docs/phase6-implementation-plan.md` updated with completion status
- [ ] `buildNetworkCard()` audited for BUG-073 XSS pattern — fix applied if found
- [ ] `updateNetworkCards()` audited for BUG-072 truthy check pattern — fix applied if found

### Generator pipeline (Critical Rule 28)

```bash
bash scripts/bump-version.sh 7.5.6.4
python3 scripts/render_sensor_config.py --write
node tests/fixtures/generate-fixtures.js
bash scripts/generate-header.sh
python3 scripts/render_sensor_config.py --check
grep -q "free_heap" tests/fixtures/api-status.json
bash scripts/preflight.sh
```

### Test infrastructure — expected counts for all fixture sets after v7.5.6.4

| Fixture Set | Command | Expected |
|-------------|---------|----------|
| 3sensor (baseline) | `FIXTURE_SET=3sensor npx playwright test --project=chromium` | ~97 pass, 18 skip |
| mixed | `FIXTURE_SET=mixed npx playwright test --grep "Mixed" --project=chromium` | 7 pass (or more if updated) |
| system | `FIXTURE_SET=system npx playwright test --grep "System" --project=chromium` | New group count TBD |
| system (full) | `FIXTURE_SET=system npx playwright test --project=chromium` | All applicable pass |
| aggregator | `FIXTURE_SET=aggregator npx playwright test --grep "Aggregator" --project=chromium` | 11 pass, 1 skip |

---

## Known Issues and Technical Debt

| Issue | Severity | Blocking v7.5.6.4? |
|-------|----------|---------------------|
| Fixture variants lack system device (LESSON-OPS-079) | Medium | **Yes — this is what v7.5.6.4 fixes** |
| `config/*.json` CI workaround | Medium | No |
| Console error tests fail in proxy environments | Low | No |
| Dashboard JS/HTML mirroring is manual | Medium | No — no dashboard changes in Step 4 |
| Section comment stale in `pollV2Live()` | Low | No — cosmetic |
| `buildNetworkCard()` latent `description` XSS (BUG-073) | Low | **Audit required in v7.5.6.4** |
| `updateNetworkCards()` latent `last_seen` truthy (BUG-072) | Low | **Audit required in v7.5.6.4** |
| Aggregator manifest truncation (Issue #85, BUG-071) | High | No — targeted for v7.5.7.0 |

---

## Lessons Learned from v7.5.6.3 (Apply to v7.5.6.4)

1. **Prompt-provided code is the #1 defect source.** 8 of 9 PR defects in v7.5.6.3 were prompt code bugs copied verbatim by the agent. For v7.5.6.4, the prompt provides test code — review all test assertions, selectors, and fixture expectations before running the agent.

2. **Always lint embedded code blocks.** PEP 8 import violations, missing context managers, and locale issues all came from un-linted prompt code. The v7.5.6.4 prompt's JavaScript test code should be verified against actual DOM structure before the agent runs.

3. **Sanitize early, not late.** The bash exporter needed value sanitization added post-review. For v7.5.6.4, the mock server's `/api/ingest` route should validate that `val` is numeric to match firmware behaviour.

4. **Three review rounds are expensive.** PR #84 needed 3 commits (initial + 2 fix rounds). Catching prompt code bugs before agent execution saves entire review cycles. Apply `shellcheck` and `pylint` to prompt code blocks.

5. **Resource cleanup patterns must be explicit in prompts.** `with` context managers, `LC_ALL=C`, and value sanitization are easy to forget. For v7.5.6.4, test setup/teardown patterns in the prompt must be explicit — do not assume the agent will infer the right pattern from existing tests.

---

## Workflow for v7.5.6.4

> **⚠️ IMPORTANT: Do NOT use this chat session to invoke the coding agent directly.**

1. Merge PR #84 to main ✅ (already done)
2. Tag v7.5.6.3
3. Device test v7.5.6.3 (see Pre-merge Checklist above)
4. **Open a NEW coding agent session** and paste the prompt from `prompts/phase6/v7.5.6.4-implementation-instructions-for-coding-agent.md`
5. Wait for the agent to create the PR
6. Copilot PR reviewer reviews automatically
7. Human reviews PR against the Review Checklist in the prompt (§9 equivalent)
8. Fix any issues
9. **Produce PR and prompt audit documents** (see Post-PR Closure section below)
10. Merge to main
11. Run full CI-exact Playwright validation across ALL fixture sets:
    ```bash
    FIXTURE_SET=3sensor npx playwright test --project=chromium
    FIXTURE_SET=mixed npx playwright test --grep "Mixed" --project=chromium
    FIXTURE_SET=system npx playwright test --grep "System" --project=chromium
    FIXTURE_SET=system npx playwright test --project=chromium  # FULL, no grep
    FIXTURE_SET=aggregator npx playwright test --grep "Aggregator" --project=chromium
    ```
12. Tag: `git tag -a v7.5.6.4 -m "Phase 6 Complete: Data ingest and system metrics"`
13. Push tag: `git push origin v7.5.6.4`

**CRITICAL — Additional workflow step for v7.5.7.0 preparation:**

14. Once the v7.5.6.4 PR is merged, the handoff document for v7.5.7.0 (`prompts/session-handoff-v7.5.7.0.md`) must be produced. It should include:
    - The **complete agent prompt** for v7.5.7.0 (`prompts/phase6/v7.5.7.0-implementation-instructions-for-coding-agent.md` or equivalent path)
    - **Documentation updates** to address the v7.5.7.0 issue: [GCV-Sleeper-Service/ESP32-GW-multi-sensor#85](https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor/issues/85) — "[BUG-071][ARCH] Aggregator manifest truncation, satellite scaling, and PSRAM-aware support for v7.5.7.0"
    - The v7.5.7.0 prompt must cover: buffer increase (4096→8192), truncation detection guard, PSRAM-aware `MAX_SATELLITES` scaling in `render_sensor_config.py`, and documentation updates for aggregator setup and architecture plans
    - The v7.5.7.0 handoff must reference Issue #85 as the canonical source

---

## Post-PR Closure Deliverables (for v7.5.6.4)

After the v7.5.6.4 PR is merged, produce these documents:

### 1. Session Handoff Document
**File:** `prompts/session-handoff-v7.5.7.0.md`
**Format:** Same as this document. Must include:
- Project state summary with v7.5.6.4 changes and Phase 6 Complete status
- v7.5.7.0 scope: BUG-071 fix (aggregator manifest truncation), PSRAM-aware satellite scaling
- Reference to [Issue #85](https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor/issues/85) as the canonical implementation source
- Pre-merge checklist for v7.5.7.0
- **Complete agent prompt** for v7.5.7.0 implementation (or instructions to produce it)
- Lessons learned from Phase 6 overall

### 2. PR and Prompt Audit Document
**File:** `prompts/phase6/v7.5.6.4-prompt-and-pr-audit.md`
**Format:** Same as `prompts/phase6/v7.5.6.3-prompt-and-pr-audit.md`

### 3. Updated Prompt Corrections (if needed)
If the v7.5.6.4 audit reveals defects in the v7.5.7.0 prompt, produce correction text.

---

## v7.5.7.0 Preview — What Comes After v7.5.6.4

v7.5.7.0 is the **aggregator hardening step** (not Phase 6). Its scope from [Issue #85](https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor/issues/85):

- **Buffer fix:** Increase `manifest_json` and `s_fetch_tmp` from 4096 → 8192 bytes in `SatelliteCache` struct
- **Truncation guard:** Detect `manifest_len == AGG_MANIFEST_BUF_SIZE - 1`, log warning, omit broken manifest from `/api/aggregator/gateways` response
- **PSRAM-aware scaling:** `MAX_SATELLITES` set by board profile (`capabilities.psram` field):
  - No PSRAM → 2 satellites (ESP32-C3 SuperMini, ESP32-WROOM-32D)
  - PSRAM ≥ 4MB → up to 8 satellites (ESP32-S3 N16R8)
- **Update `render_sensor_config.py`:** Board profile generation emits `MAX_SATELLITES` and `AGG_MANIFEST_BUF_SIZE` based on `capabilities.psram` and `capabilities.ram_kb`
- **Documentation updates:** `Docs/aggregator-setup.md`, `Docs/v7.5-v7.6-architecture-plan.md`, `Docs/bugs-and-lessons-learned.md`

---

_End of session handoff document._
