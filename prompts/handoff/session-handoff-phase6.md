# Session Handoff — Phase 6 Implementation Start

_Date: 2026-03-25_
_Repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor_
_Current HEAD: `db7003d` + docs/phase6-prompt-audit (pending merge) + P3 docs overhaul (pending merge)_

---

## Project State Summary

**v7.5.5.5** is the current version on main. Phase 5 (Aggregator MVP) is complete. A fixture fragility hotfix (`db7003d`) was merged adding LESSON-OPS-077, Critical Rule 28, and preflight `free_heap` guards.

Two PRs are pending merge at time of writing:
1. `docs/phase6-prompt-audit` — rewrites all 5 Phase 6 prompts with post-Phase-5 lessons
2. P3 documentation overhaul — README update, Phase D plan, file cleanup, session log consolidation

**Both must be merged before starting Phase 6.**

---

## What to Read Before Phase 6

These are the essential documents for any coding agent or human working on Phase 6:

| Priority | Document | Why |
|----------|----------|-----|
| 1 | `prompts/phase6/v7.5.6.0-implementation-instructions-for-coding-agent.md` | Step 0 prompt (audited) |
| 2 | `Docs/phase6-implementation-plan.md` | Phase 6 design and acceptance criteria |
| 3 | `Docs/v7.5-v7.6-architecture-plan.md` — §9.2 | Ingest endpoint architecture |
| 4 | `Docs/bugs-and-lessons-learned.md` — BUG-062, BUG-070/071, LESSON-OPS-074, LESSON-OPS-077 | Critical lessons from Phase 5 |
| 5 | `Docs/aggregator-setup.md` — §15 | CI workaround for deployment configs |
| 6 | `prompts/prompt-index-and-workflow.md` — Critical Rules 1–28 | All project guardrails |
| 7 | `Docs/writing-prompts-for-coding-agents-guide.md` | Prompt authoring methodology |

---

## Phase 6 Steps (v7.5.6.0–v7.5.6.4)

| Step | Version | Scope | Prompt |
|------|---------|-------|--------|
| 0 | v7.5.6.0 | POST /api/ingest endpoint | `prompts/phase6/v7.5.6.0-...md` |
| 1 | v7.5.6.1 | System device category + manifest | `prompts/phase6/v7.5.6.1-...md` |
| 2 | v7.5.6.2 | System card renderer (CARD_RENDERERS.system) | `prompts/phase6/v7.5.6.2-...md` |
| 3 | v7.5.6.3 | Example exporter scripts + documentation | `prompts/phase6/v7.5.6.3-...md` |
| 4 | v7.5.6.4 | Test fixtures + Playwright + Phase 6 closure | `prompts/phase6/v7.5.6.4-...md` |

---

## Key Codebase Facts for Phase 6

### Firmware architecture

- `dashboard/sensor_history_multi.h` is the main firmware file (~3200 lines). All API endpoints, `SensorEntity` model, history persistence, and aggregator logic live here.
- `send_json_error_()` already exists (line ~1927) — uses `beginResponse()` + `add_common_headers_()`. Reuse it.
- `add_common_headers_()` already exists (line ~1921) — adds `Cache-Control: no-store` + CORS.
- Use `beginResponse()` not `beginResponseStream()` for small JSON responses (codebase convention).
- Use `::time(nullptr)` not `time(nullptr)` (ESPHome namespace convention).

### Dashboard architecture

- `CARD_RENDERERS` registry dispatches card rendering by device category.
- `METRIC_FORMATTERS` registry formats metric values for display.
- `pollV2Live()` polls `/api/v2/live` every 15 seconds — used for network and system cards.
- Environmental data comes through SSE state events; non-environmental through REST polling.
- Aggregator dashboard: GATEWAYS section (`#gwGrid`) is separate from SENSORS section (`#sensorGrid`).

### Generator pipeline

- `config/sensors.json` is the source of truth.
- `render_sensor_config.py --write` produces: `sensor_history_multi.h` entities, `gateway_manifest.h`, `dashboard.js` defaults, test fixtures, YAML blocks.
- `generate-fixtures.js` produces variant test fixtures.
- Version bumps require BOTH generators (Critical Rule 28):
  ```bash
  bash scripts/bump-version.sh <version>
  python3 scripts/render_sensor_config.py --write
  node tests/fixtures/generate-fixtures.js
  bash scripts/generate-header.sh
  python3 scripts/render_sensor_config.py --check
  grep -q "free_heap" tests/fixtures/api-status.json
  bash scripts/preflight.sh
  ```

### CI workaround

`config/gateway.json` and `config/aggregator.json` are gitignored deployment configs. They change generator output. CI runs without them. Before running `--write`/`--check`/preflight/tests locally, move them out:
```bash
mv config/gateway.json config/gateway.json.bak 2>/dev/null
mv config/aggregator.json config/aggregator.json.bak 2>/dev/null
# ... run checks ...
mv config/gateway.json.bak config/gateway.json 2>/dev/null
mv config/aggregator.json.bak config/aggregator.json 2>/dev/null
```

### Test infrastructure

| Fixture Set | Command | Expected |
|-------------|---------|----------|
| 3sensor (baseline) | `FIXTURE_SET=3sensor npx playwright test --project=chromium` | ~97 pass, 18 skip |
| mixed | `FIXTURE_SET=mixed npx playwright test --grep "Mixed" --project=chromium` | 7 pass |
| aggregator | `FIXTURE_SET=aggregator npx playwright test --grep "Aggregator" --project=chromium` | 11 pass, 1 skip |

The 2 console-error-guard failures in 3sensor are CDN proxy issues (Chart.js adapter blocked), not code bugs. They pass in environments with full internet.

---

## Known Issues and Technical Debt

| Issue | Severity | Blocking Phase 6? |
|-------|----------|-------------------|
| `config/*.json` CI workaround (no per-target builds) | Medium | No — documented workaround |
| Console error tests fail in proxy environments | Low | No — environment issue |
| `beginResponseStream` used in some older endpoints | Low | No — new code uses `beginResponse` |
| Dashboard JS/HTML mirroring is manual | Medium | No — but always a risk |

---

## What Comes After Phase 6

| Phase | Version | Description | Plan Document |
|-------|---------|-------------|---------------|
| Phase D | v7.6.0.x | Runtime satellite management (NVS persistence, dashboard add/remove/test UI) | `Docs/phase-d-implementation-plan.md` |
| Phase 7 | v7.7.x | Per-device persistence engine | `Docs/v7.7-v7.8-persistence-architecture.md` |
| Phase E | v8.x | Captive portal + WiFi config | Not yet planned |

---

## Workflow for Each Phase 6 Step

1. Create branch: `git checkout -b copilot/v7-5-6-N-description`
2. Paste the prompt file to the coding agent
3. Agent implements, creates PR
4. Human reviews PR against the Review Checklist in the prompt
5. Fix any issues (agent or human)
6. Merge to main
7. Device test (human) using the Device Testing section in the prompt
8. Tag: `git tag -a v7.5.6.N -m "Phase 6 Step N: description"`

---

_End of handoff document._
