# Prompt Update Notes — Post v7.5.5.3-Hotfix

_Date: 2026-03-25_
_Context: BUG-064 through BUG-067 fixed, LESSON-OPS-074 added, unified boot path_

This document specifies targeted updates needed for each remaining prompt after the
v7.5.5.3-hotfix. Not a full rewrite — just the sections that are stale.

---

## v7.5.5.4 — Aggregator Playwright Tests

**Status:** Addendum created (`v7.5.5.4-hotfix-addendum.md`). Read addendum first, then
the main `-updated` prompt. The addendum overrides §2, §3, adds tests, and documents
new DOM structure.

**Workflow for the human operator:** When pasting the prompt to a coding agent, prepend:
```
Read prompts/phase5/v7.5.5.4-hotfix-addendum.md FIRST. Then read
prompts/phase5/v7.5.5.4-implementation-instructions-for-coding-agent-updated.md.
The addendum overrides specific sections of the main prompt.
```

---

## v7.5.5.5 — Phase 5 Closure

### §2 Required Reading — ADD:
```
7. `Docs/session-log-2026-03-25-v7553-hotfix.md` — hotfix session log
8. `Docs/architecture-revision-and-action-plan.md` — design principles and action plan
9. `Docs/aggregator-satellite-gateway-principles.txt` — user design principles
```

### §3 Current Status — REPLACE with:
```
- v7.5.5.4 complete and merged (aggregator Playwright tests pass)
- v7.5.5.3-hotfix merged: BUG-064–067 fixed, LESSON-OPS-074 added
- Unified boot path established (aggregator = satellite + overlay)
- New DOM structure: Gateways section (#hdr-gateways/#body-gateways/#gwGrid)
  separate from SENSORS section (#sensorGrid)
- All root baseline, mixed-category, and aggregator test suites pass
- Aggregator device-tested with real satellite
```

### §4 Pre-condition Checks — ADD `FIXTURE_SET=` prefix to first two commands:
```bash
FIXTURE_SET=3sensor npx playwright test --project=chromium
FIXTURE_SET=3sensor npx playwright test --project=firefox
```
(The prompt currently has bare `npx playwright test` which is RULE 5 violation.)

### §5a aggregator-setup.md — ADD these sections:
```
- Naming convention: sat-{chip}-{flash}m-{location} / agg-{chip}-{flash}m-{location}
- Config separation: gateway.json → sensors_file for per-device sensor config
- Board content: dashboard shows board-specific info only (no C3 content on S3)
- Gateway names should be plain text (no HTML special characters)
- The aggregator dashboard has two sections:
  - GATEWAYS: satellite tabs, summary cards, per-gateway device views, settings
  - SENSORS: local sensors configured on this aggregator device
```

### §5b Architecture plan updates — ADD:
```
Update Docs/v7.5-v7.6-architecture-plan.md Section 11 Phase 5 status:
- Mark all v7.5.5.x steps complete
- Add BUG-064 entry: "Aggregator boot path was redesigned as unified pipeline
  (BUG-064/LESSON-OPS-074). The forked if/else boot path from v7.5.5.3 was
  replaced with a single pipeline + overlay model."
- Note that Phase D (runtime satellite management) is the next milestone (v7.6.0.x)
```

### §5c Closure gate — ADD to the checklist:
```
- [ ] All fixture JSON files validated with `python3 -m json.tool` (no errors)
- [ ] `python3 scripts/render_sensor_config.py --check` passes
- [ ] BUG-064 through BUG-067 documented in bugs-and-lessons-learned.md
- [ ] LESSON-OPS-074 documented
- [ ] v7.5.5.3-hotfix session log exists
```

### §5d bugs-and-lessons — ADD note:
```
Verify that these entries exist (added by hotfix, should already be present):
- BUG-064: Aggregator boot path skips satellite pipeline
- BUG-065: Gateway cards in SENSORS section
- BUG-066: Remote satellite "calculating..." history
- BUG-067: C3 content on non-C3 boards
- LESSON-OPS-074: Aggregator boot = satellite + overlay
```

---

## Phase 6 Prompts — Common Updates

All five Phase 6 prompts (v7.5.6.0–v7.5.6.4) need these common changes:

### §2 Required Reading — ADD to all prompts:
```
- `dashboard/sensor_history_multi.h` — current file including aggregator endpoints,
  `#if AGGREGATOR_ENABLED` guards, `fetch_to_buffer()`, `s_proxy_tmp`, mutex pattern
- `src/aggregator_config.h` — generated aggregator constants
- `Docs/bugs-and-lessons-learned.md` — especially BUG-057 through BUG-067
  and LESSON-OPS-068 through LESSON-OPS-074
```

### §3 Current Status — UPDATE test baseline:
```
Replace "88 tests" or "80 tests" with "98+ tests + 7 skipped" (post-Phase-5)
Add: "Aggregator fixture set exists (FIXTURE_SET=aggregator)"
```

### §4 Pre-condition Checks — UPDATE all to CI-exact:
```bash
FIXTURE_SET=3sensor npx playwright test --project=chromium
FIXTURE_SET=3sensor npx playwright test --project=firefox
FIXTURE_SET=mixed npx playwright test --grep "Mixed-Category" --project=chromium
FIXTURE_SET=aggregator npx playwright test --grep "Aggregator" --project=chromium
bash scripts/preflight.sh
python3 scripts/render_sensor_config.py --check
```

### Critical Rules — ADD to all prompts:
```
- Use `beginResponse()` not `beginResponseStream()` for responses (LESSON-OPS-056)
- Use `add_common_headers_()` for CORS headers on all new endpoints
- Use `lwip_*()` prefixed socket functions (LESSON-OPS-068)
- Run `python3 scripts/render_sensor_config.py --write` after version bumps
  (LESSON-OPS-066 — build pipeline intermediates must be re-derived)
- Mirror all dashboard.js changes to dashboard.html (LESSON-OPS-043)
- Aggregator boot path is unified — any new feature must work in both
  satellite and aggregator modes (LESSON-OPS-074)
```

---

## v7.5.6.0 — POST /api/ingest Endpoint

### Specific additions beyond common updates:

§5 Scope — ADD clarification:
```
In aggregator mode, `/api/ingest` operates on LOCAL devices only — it does NOT
proxy ingest requests to satellites. The ingest endpoint processes data for
devices listed in this gateway's own manifest. Satellite devices are managed
by the satellites themselves.
```

§6 Do NOT — ADD:
```
- Do NOT use `beginResponseStream` for ingest responses (LESSON-OPS-056)
- Do NOT use bare `socket()` / `connect()` etc. — use `lwip_*()` (LESSON-OPS-068)
```

### Header repair check:
The v7.5.6.0 prompt file had corrupted headers (missing first 21 lines).
Verify the header was restored by the earlier repair. If the file starts with
a LESSON-OPS bullet point instead of a title/date block, the repair is missing.

---

## v7.5.6.1 — System Device Category

No specific changes beyond the common updates.

---

## v7.5.6.2 — System Card Renderer

### Header repair check:
Same as v7.5.6.0 — verify header was restored (was corrupted in the same batch).

### Specific addition:
```
The system card renderer must work in BOTH satellite and aggregator modes.
In aggregator mode, system cards for local devices appear in the SENSORS section
(#sensorGrid). System cards for remote satellite system devices appear in the
GATEWAYS section (#gwGrid) when viewing a per-gateway tab.
```

---

## v7.5.6.3 — Exporter Scripts + Docs

No specific changes beyond the common updates.

---

## v7.5.6.4 — Tests + Phase 6 Closure

### Specific additions:
```
§5 — Test execution must include all fixture sets:
  FIXTURE_SET=3sensor
  FIXTURE_SET=mixed
  FIXTURE_SET=aggregator
  FIXTURE_SET=system (new in Phase 6, if applicable)

§5 — Closure gate must include:
  - [ ] `python3 scripts/render_sensor_config.py --check` passes
  - [ ] All fixture JSON files validated with `python3 -m json.tool`
  - [ ] Aggregator mode with system devices tested (if applicable)
```

---

## Phase 7 Prompts

Phase 7 (per-device persistence) is far enough out that a comprehensive prompt rewrite
now would be wasted effort — the codebase will have changed significantly by then.

**Recommendation:** When Phase 7 implementation begins, audit the three existing prompts
(v7.7.0.0, v7.7.0.1, v7.7.1.0) against the current codebase using the same methodology
described in `Docs/writing-prompts-for-coding-agents-guide.md` Section 11. Key things to
verify at that time:

1. Pre-condition test counts (will be higher after Phase 6)
2. Required Reading includes Phase 5 and Phase 6 additions
3. `sensor_history_multi.h` function signatures match (the file grows with each phase)
4. Persistence struct sizes account for any new device categories added in Phase 6
5. CI-exact pre-condition commands include all fixture sets that exist by then

---

_End of update notes._
