# Current Project State

_Last verified: 2026-11-14 — restart re-verification by the operator: on 2026-11-11 the production boards .189, .170 and .191 reported v7.7.1.1, ESPHome was 2026.4.1, the httpd stack override check passed and a compile without upload succeeded; on 2026-11-14 the same three boards reported v7.7.1.1 again. No firmware change since v7.7.1.1._
_Next action: R5b, the Batch 2 prompts re-produced under the producer contract `prompts/producer-contract.md` with batch prompt v3.0 (PLAN-017, PLAN-038). The review runner passed its dry run (2026-11-20) and its posting run (2026-11-21) on PR #239; the next code step, R4, uses it for review B. The order and the scope of every step are in `Docs/plan-of-record.md` (PLAN-024). Phase 7 Step v7.7.1.2 is dispatched after R5b._

---

## Version and Phase

- **Current version:** 7.7.1.1
- **Active phase:** Phase 7 implementation underway
- **Last completed phase:** Phase VX (board onboarding + auth refactor, 4 steps, 3 PRs)
- **Next implementation phase:** Phase 7 (per-device persistence engine)
- **ESPHome version:** 2026.4.1 (ESP-IDF 5.5.4, upgraded in Phase VX v7.6.10.0)
- **Method of record:** HowTo-LLM-Assisted-Workflow-v2 v2.3.1 (450c446), bound in PR #234 (PLAN-017).
- **Development paused:** 2026-05-10 to 2026-11-14, for reasons outside the project. The May 2026 Batch 2 prompts (v7.7.1.2 to v7.7.1.4) are not dispatched: they are re-produced under the method of record and audited at their tier first (PLAN-017).

## What Just Shipped (last 3 steps)

| Step | PR | Summary |
|---|---|---|
| v7.7.1.1 | #226 | History endpoints now stream CSV with `httpd_resp_send_chunk()`, fixing BUG-082 heap exhaustion on larger retained history sets; follow-up preserved aggregator proxy compatibility, restored NI-002 `HEALTH:` evidence on WROOM/C3, and live-verified `.191` proxy history against the chunked C3 upstream |
| v7.7.1.0 | #225 | Health-check telemetry task added as a ninth firmware fragment; boot startup, assembly, and preflight updated for periodic heap/NVS/stack telemetry |
| v7.6.10.4 | #202 | Dashboard auth refactor: `authFetch()` wrapper, auth modal, eliminated browser native auth dialogs |

## What's Next

The order, the scope and the status of every step are in `Docs/plan-of-record.md` (PLAN-024). In short:

1. **R5b** — the Batch 2 prompts re-produced under the producer contract and batch prompt v3.0 (PLAN-017, PLAN-038). No firmware change. Review B runs on the review runner (PLAN-022, PLAN-023).
2. **Phase 7 Steps v7.7.1.2 to v7.7.1.4** — per-device structs and key scheme; persist engine (write path); restore engine (boot path) and retention budget.
3. **v7.7.1.5** — new board secrets (SEC-003).
4. **Phase 7 Steps v7.7.2.1 to v7.7.3.3** — engine switchover, migration, export and import, and closure. v7.7.3.3 is v1.0 (PLAN-015).
5. **After v1.0** — the ESPHome upgrade spike; v1.1 with the partition layouts and the former optimisation sprint; then Phases 8 and 9.

## Open Issues (by severity)

| Issue | Severity | Description | Target |
|---|---|---|---|
| BUG-084 | High | Non-PSRAM boards crash under 8 concurrent HTTP connections. Safe limit: 4 concurrent. | Phase 7 (socket limit config) |
| #137 | Low | Board-type SVG diagrams for documentation. Cosmetic. | Phase 7+ or standalone |
| A-004 | Medium | C5 WROOM-1U BLE not verified. The external antenna is fitted (operator, 2026-11-05). The re-test needs a BLE-capable build on .180. | Test-board check |
| WROOM heap | Medium | `.170` reported `min_free_heap` 3,988 B at 7.5 days uptime on v7.7.1.1 (operator reading, 2026-11-14; 5,156 B on 2026-11-11 in the same boot). It is the lowest value since boot: a deep dip, not a proven leak. | Heap sampling, decided before v7.7.1.2 |
| C6 flash | Medium | C6 SuperMini uses 91.6% of OTA partition on 4MB flash. Phase 7 firmware growth may exceed. | Phase 7 planning |

## Recently Resolved

| Issue | Version | Resolution |
|---|---|---|
| #139 / BUG-082 | v7.7.1.1 | Replaced full-CSV-in-RAM history responses with chunked HTTP streaming in `handle_history_()` and `handle_api_v2_history_()`, kept aggregator proxy compatibility by dechunking upstream `/api/v2/history`, hardened the parser for case-insensitive `Transfer-Encoding` handling and truncation drain, and restored NI-002 `HEALTH:` validation coverage on WROOM/C3. |

## Phase 7 Device Validation Snapshot

_Observed on 2026-05-08 after flashing v7.7.1.1 production builds._

| Metric | v7.7.1.0 baseline (C3) | v7.7.1.1 (C3 observed) | Delta |
|---|---|---|---|
| `heap_free` | 39,704 B | 52,080 B | +12,376 B |
| `min_free` | 29,776 B | 48,096 B | +18,320 B |
| `httpd_stack_wm` | 12,932 B | 11,976 B | -956 B |
| `hc_stack_wm` | 2,176 B | 2,308 B | +132 B |

## Board Fleet and Measurements

_Fleet: nine boards (BOARD-002). Identity comes from the operator's board file and esptool output of 2026-11-04. `firmware_now` comes from the operator's `fleet` output of 2026-11-11 and readings of 2026-11-14; the date is in each cell._

| device_id | Board | Chip (esptool) | Module | Flash MB | PSRAM MB | USB | IP | Role | board_profile | firmware_now | Antenna | Notes |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| sat-esp32-4m-170 | ESP32 dev board | ESP32-D0WD-V3, rev v3.1 | WROOM-32D (module marking not checked) | 4 | 0 | USB-UART bridge | 192.168.120.170 | production satellite | `esp32-wroom-32d` | v7.7.1.1 (2026-11-14) | fitted | formerly at .190 |
| sat-s3-4m-173 | ESP32-S3 SuperMini | ESP32-S3 (QFN56), rev v0.2 | none (flash and PSRAM in the chip package) | 4 | 2 | native USB-Serial/JTAG | 192.168.120.173 | test | `esp32-s3-supermini-4m` | v7.6.10.1 (2026-11-11) | fitted | marginal as an aggregator |
| sat-c5-8m-180 | ESP32-C5 dev board | ESP32-C5, rev v1.0 | WROOM-1U | 8 | 8 | USB-UART bridge | 192.168.120.180 | test | `esp32-c5-wroom1u-8m` | v7.6.10.1 (2026-11-11) | external, fitted | BLE not verified (A-004) |
| sat-c5-8m-181 | Seeed XIAO ESP32C5 | ESP32-C5, rev v1.0 | ESP32-C5-WROOM-1 | 8 | 8 | native USB-Serial/JTAG | 192.168.120.181 | not yet on project firmware | none yet | minimum firmware (2026-11-14) | external, fitted | needs a board profile |
| sat-c6-4m-184 | ESP32-C6 SuperMini | ESP32-C6FH4 (QFN32), rev v0.2 | none | 4 | 0 | native USB-Serial/JTAG | 192.168.120.184 | test | `esp32-c6-supermini-4m` | v7.6.10.1 (2026-11-11) | fitted | OTA slot 91.6 % full in May 2026 |
| esp32-c3-multi | ESP32-C3 SuperMini | ESP32-C3 (QFN32), rev v0.4 | none | 4 | 0 | native USB-Serial/JTAG | 192.168.120.189 | production satellite | `esp32-c3-supermini` | v7.7.1.1 (2026-11-14) | fitted | renamed sat-c3-4m-176 at .176 after v1.0 |
| agg-s3-16m-1 | ESP32-S3-DevKitC-1 N16R8 | ESP32-S3 (QFN56), rev v0.2 | N16R8 | 16 | 8 | USB-UART bridge | 192.168.120.191 | production aggregator | `esp32-s3-devkitc1-n16r8` | v7.7.1.1 (2026-11-14) | fitted | renamed agg-s3-16m-191 after v1.0 |
| agg-s3-16m-192 | ESP32-S3-DevKitC-1 N16R8 | ESP32-S3 (QFN56), rev v0.2 | N16R8 | 16 | 8 | USB-UART bridge | 192.168.120.192 | test aggregator | `esp32-s3-devkitc1-n16r8` | minimum firmware (2026-11-14) | fitted | its web page has an OTA upload form and no login |
| agg-c5-8m-194 | Seeed XIAO ESP32C5 | ESP32-C5, rev v1.0 | ESP32-C5-WROOM-1 | 8 | 8 | native USB-Serial/JTAG | 192.168.120.194 | not yet on project firmware | none yet | minimum firmware (2026-11-14) | external, fitted | needs a board profile |

_Minimum firmware is a plain ESPHome build without the project firmware. Such a board does not answer `/api/status`. The private columns (MAC, hub port, tty) are in the git-ignored `config/fleet.local.csv` on the build host._

### Measurements (2026-05-05)

_Source: `Docs/board-measurement-log-v7.6.10.md` (2026-05-05)_

| Board | IP | Chip | PSRAM | free_heap (boot) | min_free_heap | httpd_wm | Role |
|---|---|---|---|---|---|---|---|
| C3 SuperMini | .189 | ESP32-C3 | None | 58,456 | 47,616 | 12,924 | Satellite (production) |
| WROOM-32D | .170 | ESP32 | None | 38,760 | 15,936 | 13,188 | Satellite (production) |
| S3 DevKitC N16R8 | .191 | ESP32-S3 | 8 MB | 53,432 | 8,398,704 | 10,036 | Aggregator (production) |
| S3 SuperMini | .173 | ESP32-S3 | 2 MB | 123,156 | 2,209,636 | 12,512 | Test (marginal aggregator) |
| C6 SuperMini | .184 | ESP32-C6 | None | 150,332 | 152,820 | 12,820 | Test (flash-constrained) |
| C5 WROOM-1U | .180 | ESP32-C5 | 8 MB | 32,908 | 8,420,784 | 12,728 | Test (BLE pending A-004) |

Credentials: `$ESP_USER` / `$ESP_PASS` in the operator's shell; the firmware reads `gateway_mgmt_username` / `gateway_mgmt_password` from the git-ignored `firmware/secrets.yaml`

## Unimplemented Recommendations

_Items from postmortems or phase closures that have NOT been acted on._

| Source | Recommendation | Status |
|---|---|---|
| BUG-075-076 postmortem | Add periodic health-check task logging stack HWM, heap stats, socket usage, NVS stats | **Partially implemented in v7.7.1.0** — heap, stack HWM, NVS stats, and uptime now logged; socket counters remain deferred |
| BUG-075-076 postmortem | Monitor `nvs_get_stats()` for partition pressure | **Implemented in v7.7.1.0** |
| BUG-075-076 postmortem | Monitor socket exhaustion under load via lwIP counters | **Not implemented** |
| BUG-075-076 postmortem | Audit ESPHome component defaults for hardcoded-too-small values | **Not implemented** — proposed as Phase 7 Step -1 |
| Phase V closure | Show `min_free_heap` instead of `free_heap` on dashboard | **Not implemented** — deferred post-v7.6.9.0 |
| v7.6.10.4 session log | 10 prompt recommendations for writing guide | **Not implemented** — pending Phase VY |
| Restart check 2026-11 | Full-length WROOM history export at 60 % NVS fill or more, with peak heap recorded (BUG-082 acceptance evidence) | **Partly done** — a full-length export completed on 2026-11-11 without a reboot; peak heap and NVS fill were not recorded. Routed to the Phase 7 closure step (v7.7.3.3) |
| Restart check 2026-11 | Firmware `.bin` size checkpoint against the OTA slot in every Phase 7 prompt from v7.7.1.3 on (C6 4 MB at 91.6 %) | **Not implemented** — routed to the Batch 2 re-production |
| Restart check 2026-11 | Test counts disagree across README (402 and 117), `AGENTS.md` (~370) and this file (~370+); reconcile all three with `npx playwright test --list` | **Not implemented** — routed to the v7.7.3.3 documentation rewrite |
| Restart check 2026-11 | Make `dashboard/dashboard.h` reproducible: `scripts/generate-header.sh` compresses with `gzip -9 -c`, which stores a file name and a time, so every build changes the file (for example use `gzip -n`) | **Implemented in R5** — `scripts/generate-header.sh` compresses with `gzip -n`; the pipeline wrote the header once (PLAN-031) |
| PR #234 | `scripts/preflight.sh` sends the browser test's report to `/dev/null`, so a failure leaves no evidence | **Implemented in R5** — preflight prints the report when the browser test fails (PLAN-020) |
| Issue #228 §D | Phase-closure prompt refinements | **Deferred** — folded into the v7.7.3.3 closure prompt |
| PR #235 review (Muse) | Literal management login remains in live test scripts and historical records; the housekeeping scrub covers only seven named files | **Partly implemented in R5** — `scripts/stress-test-httpd-stack.sh` holds no default login now; `scripts/exporters/system-metrics-exporter.sh` still sets default values for `METRICS_USER` and `METRICS_PASS`; live-script cleanup and secret rotation routed to v7.7.1.5 (SEC-003); historical records and git history retain old values |
| PR #235 review (Gemini) | Retire the superseded RV-04 narrative and resolution target in SEC-ADR-001; the restart amendment now states that v7.7.1.1 resolved it | **Deferred** — documentation cleanup routed to v7.7.1.5; preserve this PR's prescribed history coverage rows and original prompt |
| PR #237 inline review (Gemini) | Add temporary-resource cleanup to the scope-gate test fixture and the workflow/body helpers of prompt check files; give malformed run blocks a bounded extraction diagnostic | **Deferred** — next prompt check-file and fixture production (PLAN-031); the supplied R5 files remain byte-identical to their dispatched hashes |
| PR #237 CI | Browser Tests cannot install browsers: Playwright 1.56.0 does not support the runner's `ubuntu26.04-x64` platform | **Implemented in R5c** — the four workflows run on `ubuntu-24.04` (PLAN-034); `browser-tests.yml` also starts when its own file changes |
| PR #237 external review A | Add quoted Basic-auth token pass/fail regression cases, including variable and placeholder exceptions, in normal and baseline lint modes | **Deferred** — next fixture production under PLAN-031, alongside the Gemini fixture follow-ups; the supplied R5 fixtures and check file remain byte-identical |
| PR #237 external review A | Exercise the documentation CI fast path on a clean GitHub runner after the PyYAML fix | **Done after the R5 merge** — in the operator's PR #238 (closed, never merged) `preflight-and-compile` took the fast path and passed in 26 seconds |
| R5 after-merge check | Lint baseline mode sorted the violation keys with `LC_ALL=C` but ran `comm` in the shell's locale; in `en_US.UTF-8` `comm` stopped with "not in sorted order", and one fixture case failed on the build host (12 passed, 1 failed). CI runs in `C.UTF-8` and did not show it. R5c reviews A/B also found a cosmetic check-file diagnostic: CHECKPOINT C correctly expects 16 added lines in the plan of record, but its failure message says 17; correcting that message is deferred to the next check-file production (PLAN-031), preserving the dispatched check file | **Implemented in R5c** — `LC_ALL=C comm -23` (PLAN-034); a fixture run in a non-C locale joins the next fixture production (PLAN-031) |
| R5c planning (CI logs) | The actions `checkout@v4`, `setup-node@v4`, `setup-python@v5`, `cache@v4` and `upload-artifact@v4` target Node.js 20; the runner forces them to Node.js 24 and warns that Node.js 20 is deprecated. `setup-node` also installs Node.js 20 for the jobs. `.github/workflows/external-review.yml` pins `actions/checkout` at v4.4.0, which gives the same warning (run 44861784463) | **Not implemented** — no job fails yet; the operator decides when a CI maintenance step updates them |
| PR #239 review A | Four helper scripts print `esphome run` advice: `scripts/provision.sh`, `scripts/render_sensor_config.py`, `scripts/change_sensor_number.py`, `scripts/patch-esphome-httpd-stack.sh`; `AGENTS.md` allows only `esphome upload` and `esphome compile` | **Not implemented** — the advice is printed, not run; routed to a later script-cleanup step that the operator schedules |
| R5r audit (GPT, finding 9) | The tests of the review runner run in no CI job: `.github/workflows/ci.yml` calls `scripts/preflight.sh`, which does not run `tests/external-review/test_external_review.py` | **Not implemented** — it needs a change of `ci.yml` outside R5r; routed to a later tooling step that the operator schedules |
| R5r planning (lint L11) | Rule L11 of `scripts/lint-prompts.sh` reports a false login literal on a quoted diff line that begins with `-u` and has a colon later in the same word, as a removed YAML key `update_interval` with its colon has; the login check of `scripts/external-review.py` (item 2.1) uses the same rule, so it refuses such a line too | **Not implemented** — a false finding, not a leak; routed to a later tooling step that the operator schedules |
| R5r | Prove the review runner on GitHub: a dry run on PR #239 that posts nothing and writes three turns to the run summary, then one posting run that posts one comment | **Done 2026-11-21** — dry run 44828100924 (`gemini-4-argon`, 2026-11-20) wrote three turns to its summary; posting run 44861784463 (`gemini-4-hydrogen`, 2026-11-21) posted one comment on PR #239; the sign-in used direct federation, with no service account. The last condition of R5r in plan of record section 5, that the next code step uses the runner for review B, is checked at R4 |
| PR #240 inline review and review A M1 | The three inline fixes of the runner (thought parts screened before reuse, the raw PR title screened, every Link header read) and the fix of review A finding M1 (encoded at signs and slashes) have no permanent test: their regression tests ran from a temporary file, because the supplied test file was fixed | **Not implemented** — routed to a later runner-hardening tooling step that the operator schedules |
| PR #240 review A L1, Q1 and Q2 | L1 (LOW): the runner reads the diff and the file list of the PR without pinning them to the two commits that its header prints; reading them through the compare endpoint, pinned to both commits, closes it. Q1: hidden HTML (comments, `<details>`) in the model's answer. Q2: Unicode spaces before a slash. Q1 and Q2 are not verified | **Not implemented** — routed to the runner-hardening step |
| R5r runs (2026-11-21) | The runner sends no check-run data, so review B marks the CI gates UNCLEAR and advises FIX FIRST on every step whose review file has CI gates; a data block with the check runs of the PR head (name, status, conclusion, head commit) fixes it | **Not implemented** — routed to the runner-hardening step; until then the operator's merge checklist covers the CI gates |
| R5r runs (2026-11-21) | A second profile (step 4 of "Add a profile" in `Docs/operator/R5r-review-runner.md`); a comparison of the runner's models on a PR with seeded defects; and, for the operator page, deleting an earlier runner comment before a new run, so that the model does not review its own earlier output | **Not implemented** — routed to the runner-hardening step |
| R5a internal audit (2026-11-21) | `AGENTS.md`, "PR Title and Body — Preservation Rules" item 2, names an "Audit Gate Notice" among the sections of a PR body. No document under `Docs/` defines it. The May 2026 prompt `prompts/handoff/phase7/issue-228-CDE-producer-session-prompt.md` gave a text for the PR of issue #228 §C to §E, which no longer holds, because the Batch 2 prompts are re-produced first (PLAN-017); §8 of the prompts of the restart steps does not ask for it, and R5a does not use it. Rule 7.10 of `prompts/producer-contract.md` asks for it only when a prompt gives its text | **Not implemented** — routed to the next pull request that changes `AGENTS.md` |

## Stale Documents Requiring Update Before Use

| Document | Written | Issue |
|---|---|---|
| `Docs/v7.7-v7.8-persistence-architecture.md` | 2026-03-19 | Architecture decisions still valid. Memory budget (§15) needs measured values from board-measurement-log. Update during Phase 7 prompt production. |
| `Docs/phase-7-review-and-rewrite.md` | 2026-05-07 | Its section "Partition Table Changes" plans the USB reflash for v7.7.1.4. The partition change moves to v1.1 as its own step (PLAN-015). |
| `Docs/phase-E-captive-portal-plan.md` | 2026-05-07 | Phase E is deferred until after Phase 9, and step E-b waits for the Zigbee spike (PLAN-014). Re-check the plan against the current ESPHome release before use. |
| `Docs/phase-9-cloud-upload-plan.md` | 2026-05-07 | The primary upload target is now the Azure tier-2 ingest endpoint, not InfluxDB Cloud (PLAN-013). Rewrite at Phase 9 start. |
| The nine Batch 2 prompt files of May 2026: the agent prompt and the two-step file of v7.7.1.2, v7.7.1.3 and v7.7.1.4 in `prompts/phase7/`, and `session-handoff-v7.7.1.2.md`, `-v7.7.1.3.md` and `-v7.7.1.4.md` in `prompts/handoff/phase7/` | 2026-05 | **Superseded, not to be dispatched** (PLAN-017). They are re-produced under the method of record; until then they are source material only. |
| `prompts/handoff/phase7-batch-production-prompt.md` (version 1), `prompts/handoff/phase7-batch-production-prompt-update.md` (version 2.0), and the banner of `prompts/handoff/phase7-prompt-production-instructions.md`, which names version 2.0 as current | 2026-05 | **Superseded** by `prompts/producer-contract.md` and `prompts/handoff/phase7-batch-production-prompt-v3.md` (PLAN-038). History only. |


_Documents that are history only are in `Docs/archive/`. `Docs/archive/README.md` lists what moved there on 2026-11-16 and on 2026-11-21 (PLAN-025, PLAN-038)._

## Architecture Quick Reference

- **Firmware:** 9 C++ fragments in `firmware/core/`, assembled by `scripts/assemble-sensor-history.sh` → `dashboard/sensor_history_multi.h` (generated, never edit directly)
- **Dashboard:** 12 core modules in `dashboard/core/`, 9 component directories in `dashboard/components/`, built by `scripts/bundle-dashboard.sh` → `dashboard/dashboard.js` and `dashboard/dashboard.html` (generated, never edit directly)
- **Pipeline:** `provision.sh <role>` → `assemble-sensor-history.sh` → `render_sensor_config.py` → `bundle-dashboard.sh` → `build-dashboard.sh` → `minify-dashboard.sh` → `generate-header.sh` → `esphome compile` → `esphome upload`
- **Auth:** Application-level via `dashboard/core/auth.js` with `authFetch()` wrapper. Management endpoints require Basic Auth. `/api/status` is public.
- **Tests:** ~370+ Playwright tests across 12 spec files, 4 fixture sets (3sensor, mixed, system, aggregator)
- **Httpd stack:** Uniform 16 KB via local component override in `firmware/local_components/web_server_idf/`. Must re-apply after ESPHome upgrades via `scripts/patch-esphome-httpd-stack.sh`.


## Planning Documents

| Document | Purpose |
|---|---|
| `Docs/plan-of-record.md` | Plan of record: the ladder of steps to v1.0, the scope and done-when of each step, open findings and risks (PLAN-024) |
| `Docs/planner-start-here.md` | Entry page for planning and prompt-producing sessions (PLAN-030) |
| `prompts/producer-contract.md` | Producer contract: the binding rules of a prompt bundle (PLAN-038) |
| `Docs/phase-7-review-and-rewrite.md` | Rewritten Phase 7 plan (supersedes `Docs/archive/planning-2026-05/v7.7-implementation-plan.md`) |
| `Docs/phase-E-captive-portal-plan.md` | Phase E scoping — WiFi provisioning, sensor discovery |
| `Docs/phase-8-notifications-plan.md` | Phase 8 scoping — Telegram, ntfy.sh, threshold alerts |
| `Docs/phase-9-cloud-upload-plan.md` | Phase 9 scoping — InfluxDB, MQTT, store-and-forward |
| `Docs/phase-10-dashboard-ui-plan.md` | Phase 10 scoping — responsive UI, i18n |
| `Docs/board-selection-guide-expansion.md` | Board capability matrix with Phase 7 retention numbers |


## KPI Baselines (for tracking)

| Metric | Phase Y | Phase V | Phase VX |
|---|---|---|---|
| Steps in phase | 9 | 10 (5 planned + 5 mitigation) | 4 |
| Fix cycles per step (avg) | 0.3 | 0.5 | 1.0 |
| Wall-clock per step (est.) | ~2h | ~2.5h | ~3h |
| New bugs discovered | 3 | 5 | 2 |
| New critical rules added | 12 | 8 | 4 |
| Verification : production sessions | not recorded | not recorded | not recorded |

---

_This file is updated as a mandatory in-PR deliverable for every step that changes shipped state (per Docs/development-process-guide.md §2.5)._
_If the "Last verified" date is more than 1 step old, run verification checks before trusting values._
