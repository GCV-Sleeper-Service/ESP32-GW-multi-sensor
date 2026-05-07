# Multi-Phase Planning Session — Methodology Audit Supplement

_Append this supplement to `prompts/handoff/multi-phase-planning-prompt.md` AFTER the post-VX supplement._
_Source: Phase VY methodology audit session (2026-05-07)_
_Prerequisite: `CURRENT-STATE.md` exists at repo root._

---

## Additional Mandatory Reading (appended to the 18-document list in the main prompt)

In addition to the documents listed in the main planning prompt, this session must also read:

19. `CURRENT-STATE.md` — current version, open issues, board measurements, unimplemented recommendations, stale documents
20. `Docs/feature-roadmap.md` — feature priority ordering and phase numbering
21. `AGENTS.md` — agent instructions file (to understand what inline reviewers now see)
22. `Docs/development-process-guide.md` — skim Sections 2-4 for process changes that affect prompt production

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

**Validation needed:** Confirm chunked streaming can be decoupled from per-device persistence by checking whether `/history/` handlers use `seg_NNN` keys directly or through an abstraction that Phase 7 replaces. Run: `grep -n 'seg_' firmware/core/nvs-persistence.h | head -20`

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

## Process Requirements for All Future Phase Prompts

Based on Phase VY findings, all future agent prompts must include:

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

## GitHub Project Management

### Milestones

Create a GitHub Milestone for each implementation phase. Link every PR to its phase milestone. The milestone progress bar provides a visual completion percentage without maintaining a separate tracker.

When creating the Phase 7 plan, also create the Phase 7 milestone. Each step's PR gets linked to it at PR creation time.

### Labels

Standardized label set (create once, use consistently):

**Phase labels:** `phase/7`, `phase/E`, `phase/8`, `phase/9`
**Type labels:** `type/firmware`, `type/dashboard`, `type/docs`, `type/tests`, `type/infra`
**Risk labels:** `risk/high`, `risk/medium`, `risk/low`
**Status labels:** `status/review-in-progress`, `status/device-test-needed`, `status/blocked`

Agent prompts should include: "Apply labels `phase/7`, `type/firmware`, `risk/medium` to the PR."

### Issue Management

After every phase closure, run an issue sweep. New issues discovered during execution become GitHub Issues (not just LESSON-OPS or BUG entries in markdown files). Every issue gets a phase label for when it's expected to be addressed.

---

## Health-Check and Long-Duration Monitoring

### Weekly Health-Check Script

Create a cron job or manual script on the LXC container that logs board health:

```bash
#!/bin/bash
# scripts/weekly-health-check.sh
DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)
for board in 192.168.120.189 192.168.120.190 192.168.120.191; do
  echo "$DATE $board $(curl -s -u ESPadmin:ESPpass100 http://$board/api/status/full | \
    python3 -c "import sys,json; d=json.load(sys.stdin); print(json.dumps({k:d.get(k,'N/A') for k in ['version','free_heap','min_free_heap','uptime_seconds']}))" 2>/dev/null || echo 'UNREACHABLE')"
done >> Docs/health-check-log.jsonl
```

This log is consumed when updating `CURRENT-STATE.md` — if any board shows `min_free_heap` below 15,000, flag it in the open issues section.

### Pre-Design Measurement Protocol

Before any phase that modifies firmware behavior, record baseline measurements from all production boards. The Phase 7 Step 0 (health-check telemetry task) makes this easier going forward by adding runtime logging. Until then, use `curl` + `scripts/stress-test-httpd-stack.sh` to collect baselines manually.

---

## Parallelism Model

Phase 7 (and future phases) can use two parallel tracks where dependencies allow:

```
Track A (firmware):   Step 0 → Step 1 → Step 2 → ... → Step N
Track B (tests+docs): Mock contracts → test stubs → doc updates (parallel with Track A review periods)
```

Track B PRs don't merge until the corresponding Track A PR merges (merge-order constraint), but the work happens simultaneously, reducing wall-clock time by an estimated 20-30%.

Documentation-only PRs should be merged independently and should not trigger the CI compile workflow (path filtering now active on `ci.yml`).

---

## Feature Priority Context

The planning session should read `Docs/feature-roadmap.md` for the full feature ordering. Summary of priorities:

1. Per-device persistence (Phase 7) — **highest, addresses production crash BUG-082**
2. Captive portal provisioning (Phase E) — runtime board detection, WiFi setup
3. Notifications — Telegram first, then ntfy.sh, then email (Phase 8)
4. Cloud data upload — InfluxDB Cloud first (Phase 9)
5. Dashboard UI enhancements — dynamic sizing, multi-language (Phase 10)
6. Analytics — browser-side statistics (Phase 11) — lowest priority

---

## Cost Optimization

The operator has non-profit discounts for Anthropic and OpenAI, plus $2000 Microsoft Azure credits. The planning session should consider LLM cost allocation when recommending phase scope:

- **Claude Opus** — planning and prompt production only (expensive, rate-limited)
- **Codex/GPT** — agent execution and external reviews (non-profit pricing)
- **Copilot** — inline reviews and local agent execution (evaluate plan tier after GitHub changes)
- **Perplexity Pro** — structured three-turn review (when MCP cooperates)

Phase scope should be sized so that prompt production for a full phase fits within a single Claude Opus session allocation.

---

_End of methodology audit supplement._
