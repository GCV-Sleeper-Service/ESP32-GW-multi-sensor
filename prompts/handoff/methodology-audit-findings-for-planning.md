# Multi-Phase Planning Session — Methodology Audit Supplement

_Append this supplement to `prompts/handoff/multi-phase-planning-prompt.md` AFTER the post-VX supplement._
_Source: Phase VY methodology audit session (2026-05-06)_
_Prerequisite: `CURRENT-STATE.md` exists at repo root._

---

## Mandatory Pre-Planning Gate: Assumption Audit

Before producing ANY planning output, run this gate:

```
⛔ ASSUMPTION AUDIT — MANDATORY BEFORE PLANNING

1. Read `CURRENT-STATE.md` — confirm version, open issues, and stale document list.
2. Run: cat VERSION — does it match CURRENT-STATE.md?
3. For every file path referenced in the Phase 7 plan, verify it exists:
   - grep -l 'function_name' firmware/core/*.h  (not sensor_history_multi.h)
   - ls dashboard/core/ dashboard/components/   (not dashboard/dashboard.js)
4. Check "Unimplemented Recommendations" section of CURRENT-STATE.md:
   - Any items from previous postmortems that haven't been addressed?
   - These become Step 0 or Step -1 of the next phase.
5. State assumptions explicitly:
   - "I assume X because Y" — then verify X with a grep/curl/ls command.
   - If verification is impossible, flag as UNVERIFIED ASSUMPTION.
6. Simplest explanation first (Occam's Razor):
   - Before hypothesizing WHY something behaves unexpectedly, confirm WHAT is happening.
   - One diagnostic command eliminates hours of investigation.
```

This gate catches the class of error documented in BUG-083 (plausible but wrong explanation accepted without a single `grep` check) and the BUG-075-076 postmortem gap (recommendations written, archived, forgotten).

---

## Phase 7 Reordering Recommendation

The Phase 7 plan (2026-03-19) orders steps architecturally: structs → persist → restore → wire → export. This is clean but operationally wrong.

**Issue #139 / BUG-082 is crashing production boards NOW.** Both C3 and WROOM dashboards become unusable after ~3 weeks of accumulated history data. The chunked streaming fix should run before the multi-week persistence engine work begins.

Recommended Phase 7 step order:

| Step | Content | Rationale |
|---|---|---|
| Step -1 | ESPHome component defaults audit | Proactive measurement — prevents another httpd-stack-class surprise |
| Step 0 | Health-check telemetry task (BUG-075-076 recommendation) | Finally implements the 6-week-old postmortem recommendation |
| Step 1 | Chunked HTTP streaming for `/history/` endpoints | Fixes BUG-082 / #139 against EXISTING NVS key scheme |
| Step 2+ | Per-device persistence engine (structs, persist, restore, wire) | Original Phase 7 scope, rewritten against current codebase |
| Step N | Export/import v2, regression, phase closure | Original Phase 7 tail |

**Validation needed:** Confirm chunked streaming can be decoupled from per-device persistence by checking whether `/history/` handlers use `seg_NNN` keys directly or through an abstraction that Phase 7 replaces.

---

## Stale Documents — What Must Be Rewritten

The Phase 7 review (Deliverable 1 of the planning prompt) should flag these specific staleness issues:

1. `Docs/v7.7-implementation-plan.md` references `dashboard/sensor_history_multi.h` 9 times — now a generated artifact from `firmware/core/`. Every file path referencing this must be updated to target the correct fragment.

2. Same plan references `dashboard/dashboard.js` 5+ times — now a generated artifact from `dashboard/core/` + `dashboard/components/`. Must reference the correct source modules.

3. All Phase 7 steps that add HTTP endpoints must include the `authFetch()` pattern for dashboard integration and the `authenticate_management_()` call for firmware-side auth.

4. All steps modifying board behavior must include the `external_components` block check.

5. The Phase 7 architecture doc's memory budget (Section 15) uses pre-Phase-V estimates. Current measured values are in `Docs/board-measurement-log-v7.6.10.md` and supersede all earlier calculations.

6. Phase 7 steps that add new FreeRTOS tasks must document expected task queue depth. Current deferred tasks: `schedule_reboot_()`, `schedule_reset_satellites_()`, `schedule_delete_data_()`. Phase 7 adds at least 2 more.

---

## Process Requirements for Phase 7 Prompts

Based on Phase VY findings, all Phase 7 agent prompts must include:

1. **`CURRENT-STATE.md` as first mandatory read** — replaces the ad-hoc "read these 10 files" pattern.

2. **Checkpoint queries, not assertions** — Use `grep -c 'authFetch' dashboard/core/history.js` instead of "line 47 should contain authFetch." Function/identifier anchors are stable across commits; line numbers decay with every merge.

3. **Flash/test automation** — Steps touching firmware include:
   ```
   esphome clean → esphome compile → esphome upload --device=IP → sleep 30 → curl smoke tests
   ```
   Never use `esphome run` (hangs on log output).

4. **Checkpoint failure = stop, not fix** — "If this check fails, STOP and post actual vs expected as a PR comment. Do NOT modify code to pass the checkpoint."

5. **Post-merge deliverables include `CURRENT-STATE.md` update** — The "What Just Shipped" and "Open Issues" sections are updated after every merge.

6. **Recommendation tracking** — Any postmortem or phase closure recommendation becomes either a GitHub Issue or an entry in `CURRENT-STATE.md` "Unimplemented Recommendations." No third option. No archiving without tracking.

---

## Parallelism Model

Phase 7 can use two parallel tracks where dependencies allow:

```
Track A (firmware):   Step 0 → Step 1 → Step 2 → ... → Step N
Track B (tests+docs): Mock contracts → test stubs → doc updates (parallel with Track A review periods)
```

Track B PRs don't merge until the corresponding Track A PR merges (merge-order constraint), but the work happens simultaneously, reducing wall-clock time by an estimated 20-30%.

Documentation-only PRs should be merged independently and should not trigger the CI compile workflow (path filtering now active on `ci.yml`).

---

## Feature Priority Context

The planning session should also read `Docs/feature-roadmap.md` (if present) or the operator's feature priority notes. The original feature plan (v7.4-era) ordered priorities as:

1. Per-device persistence (Phase 7) — **highest, addresses production crash**
2. Notifications — Telegram first, then ntfy.sh, then email (Phase 8.x)
3. Cloud data upload — InfluxDB Cloud first (Phase 8.5+)
4. Captive portal provisioning (Phase E / 8.0)
5. Dynamic dashboard sizing (Phase 9.0)
6. Multi-language, AI analytics (Phase 9.1, 10.x) — lowest priority

The operator's guiding principle: "Don't complicate things beyond necessity. Only things that incrementally improve should be adopted."

---

## Cost Optimization Note

The operator has non-profit discounts for Anthropic and OpenAI, plus $2000 Microsoft Azure credits. The planning session should consider LLM cost allocation when recommending phase scope:

- **Claude Opus** — planning and prompt production only (expensive, rate-limited)
- **Codex/GPT** — agent execution and external reviews (non-profit pricing)
- **Copilot** — inline reviews and local agent execution (evaluate plan tier after GitHub changes)
- **Perplexity Pro** — structured three-turn review (when MCP cooperates)

Phase scope should be sized so that prompt production for a full phase fits within a single Claude Opus session allocation.

---

_End of methodology audit supplement._
