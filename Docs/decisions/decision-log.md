# Decision Log

_One-line index of architectural decisions. Full rationale in linked documents._
_Updated: 2026-11-14_

---

## How to Use This Log

Every architectural decision gets a one-line entry here with date, decision, and a link to the source document. This log is searchable and serves as the discovery index — you read the full ADR/document only when investigating a specific decision.

When making a new architectural decision during any session, add a line here as part of the deliverables.

---

## Decisions

| Date | ID | Decision | Rationale Link |
|---|---|---|---|
| 2026-03-05 | SEC-001 | Basic Auth for management endpoints, public `/api/status` | `Docs/decisions/SEC-ADR-001-residual-vulnerabilities.md` |
| 2026-03-05 | SEC-RV | Accept 5 residual vulnerabilities (no TLS, Basic Auth over HTTP, etc.) | `Docs/decisions/SEC-ADR-001-residual-vulnerabilities.md` |
| 2026-03-19 | ARCH-001 | Per-device persistence engine to replace monolithic SegmentSnapshot | `Docs/v7.7-v7.8-persistence-architecture.md` §1-4 |
| 2026-03-19 | ARCH-002 | FNV-1a hash for NVS key scheme, 15-char limit | `Docs/v7.7-v7.8-persistence-architecture.md` §6 |
| 2026-03-19 | ARCH-003 | Priority-tiered retention budgeting per device | `Docs/v7.7-v7.8-persistence-architecture.md` §7 |
| 2026-03-22 | AGG-001 | Aggregator stores satellite history locally (not proxy-only) | `Docs/decisions/AGG-ADR-001-satellite-history-storage.md` |
| 2026-03-31 | BUILD-001 | `external_components` block mandatory in all board YAMLs for httpd stack override | `Docs/lessons/firmware.md` (LESSON-OPS-097–102) |
| 2026-03-31 | BUILD-002 | Local components go in `firmware/local_components/`, never `custom_components` | `prompts/prompt-index-and-workflow.md` Critical Rule 41 |
| 2026-04-09 | PROMPT-001 | Never use LLM-optimized agent prompt variants for execution | `Docs/writing-guide/multi-llm-prompt-optimization-analysis-2026-04-09.md` |
| 2026-04-10 | ARCH-004 | Deferred task pattern mandatory for HTTP handlers doing NVS operations | `prompts/prompt-index-and-workflow.md` Critical Rule 40 |
| 2026-04-10 | ARCH-005 | All dashboard POST calls must use `application/x-www-form-urlencoded`, never JSON | `Docs/lessons/firmware.md` (LESSON-OPS-103) |
| 2026-04-12 | ARCH-006 | Firmware fragments in `firmware/core/`, assembled by script, never edit generated `sensor_history_multi.h` | Phase Y architecture plan |
| 2026-04-12 | ARCH-007 | Dashboard modular components in `dashboard/core/` + `dashboard/components/`, never edit generated files | Phase X architecture plan |
| 2026-04-14 | HEAP-001 | Heap-adaptive history cap: `clamp(free_heap/3, 12000, 60000)` — safety net until chunked streaming | `Docs/phase-V-implementation-plan-addendum-v7.6.9.4.md` |
| 2026-04-16 | HEAP-002 | `csv.reserve()` does NOT truncate — known BUG-082, full fix deferred to Phase 7 | `Docs/lessons/firmware.md` (BUG-082) |
| 2026-04-20 | SEC-RV03 | v7.6.9.6 (Cloudflare polling fix) dropped as self-resolved; SEC-ADR amendment appended directly | `Docs/decisions/SEC-ADR-001-RV-03-amendment.md` |
| 2026-04-26 | STACK-001 | Uniform 16 KB httpd stack for all boards via local component override | `Docs/lessons/firmware.md` (BUG-083, LESSON-OPS-128) |
| 2026-05-05 | BOARD-001 | 6-board fleet: C3, WROOM, S3-16M, S3-4M, C6, C5. All compile. C5 BLE pending antenna retest. | `Docs/board-measurement-log-v7.6.10.md` |
| 2026-05-06 | AUTH-001 | Application-level auth via `dashboard/core/auth.js` with `authFetch()` wrapper. Browser native dialogs eliminated. | `Docs/session-log-2026-05-06-v7.6.10.4.md` |
| 2026-05-07 | PLAN-001 | Phase 7 reordering: chunked streaming (BUG-082) before persistence engine | `Docs/phase-7-review-and-rewrite.md` |
| 2026-05-07 | PLAN-002 | Binary sensors use state-change-only deduplication (EventLog, not HistoryBuffer) | `Docs/phase-7-review-and-rewrite.md` §binary-sensors |
| 2026-05-07 | PLAN-003 | TLS/notifications enabled only on PSRAM + C6 boards | `Docs/phase-8-notifications-plan.md` |
| 2026-05-07 | PLAN-004 | Four partition table layouts: 4MB-std (640KB), 4MB-C6 (480KB), 8MB (1MB), 16MB (4MB) | `Docs/phase-7-review-and-rewrite.md` §partitions |
| 2026-05-07 | PLAN-005 | Phase ordering: 7 → E → 8 → 9 → 10 | `Docs/phase-7-review-and-rewrite.md` §ordering |
| 2026-05-07 | PLAN-006 | Version numbering: .0 = research (no bump), .1+ = implementation | `Docs/phase-7-review-and-rewrite.md` §versioning |
| 2026-05-07 | PLAN-007 | MQTT bridge included in Phase 9 (not deferred) | `Docs/phase-9-cloud-upload-plan.md` |
| 2026-05-07 | PLAN-008 | Aggregator-first notification/cloud architecture (satellites don't need TLS) | `Docs/phase-8-notifications-plan.md` |
| 2026-05-07 | PLAN-009 | C6 8MB is the intended standard satellite; C6 4MB is binary-sensor-only satellite | `Docs/board-selection-guide-expansion.md` |
| 2026-05-07 | PLAN-010 | NVS deduplication study (value-dictionary for environmental sensors) deferred to v7.7.5.0 | `Docs/phase-7-review-and-rewrite.md` §optimization |
| 2026-05-07 | PLAN-011 | RAM window reduction (24h→2h on non-PSRAM) deferred to v7.7.5.1, after chunked streaming | `Docs/phase-7-review-and-rewrite.md` §optimization |
| 2026-11-14 | PLAN-012 | Meta-work freeze until v1.0 is tagged: no new methodology documents, audits of audits or producer-prompt rewrites, except the HowTo v2 adoption items listed in PLAN-017; batch-production prompt v3.0 must be shorter than v2.0 | `prompts/handoff/phase7/method-adoption-2026-11-14.md` |
| 2026-11-14 | PLAN-017 | HowTo-LLM-Assisted-Workflow-v2 at `v2.3.1` (`450c446`) is the method of record; `Docs/development-process-guide.md` holds the project bindings. Pre-dispatch gate (operator decision 2026-11-05): no prompt is dispatched until its §2 checks and lint have been run against `main` on the day of dispatch and recorded in the PR (process guide §2.1 item 6). Transition (operator decision 2026-11-05): the Batch 2 prompts of May 2026 (v7.7.1.2-v7.7.1.4) are not dispatched; they are re-produced under this method and audited at their tier before dispatch, to validate the method, and code embedded in a prompt is compiled on a scratch branch before dispatch (first: v7.7.1.4). Before v1.0 the only HowTo v2 adoption items (PLAN-012) are this PR, the R5 tooling PR (`scripts/scope-gate.py`, lint L8, rules for the two recurred classes and a credential-literal rule, CI stub, PR-body check), `prompts/producer-contract.md` with batch-production prompt v3.0, the Batch 2 re-production with its audits, and Critical Rule retirements. Tiers: v7.7.1.2 LOW; v7.7.1.3, 2.1, 2.3, 3.1, 3.2 MEDIUM; v7.7.1.4, 2.2, 3.3 HIGH. Five reviewers on every code step; three inline reviewers on documentation-only PRs | `prompts/handoff/phase7/method-adoption-2026-11-14.md` |
| 2026-11-14 | HEAP-002a | BUG-082 is resolved in v7.7.1.1 by chunked history streaming (supersedes HEAP-002, "full fix deferred to Phase 7"); the HEAP-001 adaptive cap stays as a second guard | `Docs/session-log-2026-05-08-v7.7.1.1.md` |
| 2026-11-14 | PLAN-013 | The primary Phase 9 upload target is the Azure tier-2 ingest endpoint (supersedes decision C-2, InfluxDB Cloud as primary target, in `Docs/phase-9-cloud-upload-plan.md`); InfluxDB stays documented as an alternative only (operator decision 2026-11-05) | `prompts/handoff/phase7/housekeeping-2026-11-14-restart.md` §6 |
| 2026-11-14 | PLAN-014 | Phase E is deferred until after Phase 9 (supersedes the position of Phase E in PLAN-005); step 8.1 owns the settings and credential NVS namespace; step E-b waits for the Zigbee spike (operator decision 2026-11-05) | `prompts/handoff/phase7/housekeeping-2026-11-14-restart.md` §6 |
| 2026-11-14 | PLAN-015 | v1.0 is v7.7.3.3, the Phase 7 closure; `v1.0-rc1` is tagged at v7.7.2.3; the v7.7.5.x optimisation sprint becomes v1.1; the PLAN-004 partition layouts (USB reflash) move to v1.1 as their own HIGH step (operator decision 2026-11-05) | `prompts/handoff/phase7/housekeeping-2026-11-14-restart.md` §6 |
| 2026-11-14 | PLAN-016 | ESPHome stays pinned at 2026.4.1 through v1.0; an upgrade is assessed after v1.0 in a spike on test boards only (operator decision 2026-11-05) | `prompts/handoff/phase7/housekeeping-2026-11-14-restart.md` §6 |
| 2026-11-14 | PLAN-018 | Quality, functionality and security come before speed; every planned date is indicative, and no estimate justifies skipping a check, shortening a review or merging early (operator decision 2026-11-05) | `prompts/handoff/phase7/housekeeping-2026-11-14-restart.md` §6 |
| 2026-11-14 | PLAN-019 | Review pipeline (operator decisions 2026-11-14): Codex is the coding agent; external review A is Claude in its own session; external review B is a Meta Muse model (Spark or Wonder), with Gemini on the web as the fallback. This supersedes reviewer rows 4 and 5 and the Perplexity paragraph of `Docs/development-process-guide.md` §2.4, because both former external reviewers came from the coding agent's vendor | `prompts/handoff/phase7/housekeeping-2026-11-14-restart.md` §6 |
| 2026-11-14 | PLAN-020 | CI (PR #234, `d4fe89a`): the required `preflight-and-compile` job runs on every pull request to `main`, documentation-only ones too, because a required check that a path filter skips blocks the merge. The tooling PR of PLAN-017 also makes `scripts/preflight.sh` show the browser test's report when that test fails (operator decision 2026-11-14) | `prompts/handoff/phase7/housekeeping-2026-11-14-restart.md` §6 |
| 2026-11-14 | PLAN-021 | Two additions to the PLAN-017 list, as exceptions to PLAN-012 (operator decisions 2026-11-14): an operator guide in `Docs/operator/`, one page per step, in simple English with one diagram; and one documentation PR that brings the restart plan of record into `Docs/` and moves superseded planning documents to `Docs/archive/` after an inventory | `prompts/handoff/phase7/housekeeping-2026-11-14-restart.md` §6 |
| 2026-11-14 | BOARD-002 | Nine-board fleet (supersedes BOARD-001): production C3 .189, WROOM .170 and S3 16 MB .191; test S3 4 MB .173, C5 .180, C6 .184 and S3 16 MB .192; two XIAO ESP32C5 (.181, .194) not yet on project firmware. Boards are renamed to the role-chip-flash-octet convention after v1.0 (.189 becomes sat-c3-4m-176 at .176; agg-s3-16m-1 becomes agg-s3-16m-191) | `CURRENT-STATE.md` (Board Fleet and Measurements) |
| 2026-11-14 | SEC-002 | `/history/` and `/api/v2/history/` are public since v7.6.9.0 (`0a4b0d1`); accepted for the LAN-only deployment; replaces the V2-E history login recorded in SEC-ADR-001; re-decided before any Internet route (SEC-003) | `Docs/decisions/SEC-ADR-001-residual-vulnerabilities.md` (Amendment 2026-11) |
| 2026-11-14 | SEC-003 | Secret-handling policy: agents and scripts must take the management login from `$ESP_USER`/`$ESP_PASS`, firmware from the git-ignored `firmware/secrets.yaml`. This housekeeping removes the login from the seven files listed in the housekeeping record §3; live test scripts and historical records still contain literals. Live-script cleanup and changing the management password, native API key and OTA password together remain work for v7.7.1.5 (LOW), the step after v7.7.1.4; git history retains old values. No Internet route until that is done, an Access application with an Allow policy fronts the hostname, only the aggregator is published, and SEC-002 is re-decided | `Docs/decisions/SEC-ADR-001-residual-vulnerabilities.md` (Amendment 2026-11) |

---

_Add new entries at the bottom. Format: date, short ID, one-line decision, link to source._
