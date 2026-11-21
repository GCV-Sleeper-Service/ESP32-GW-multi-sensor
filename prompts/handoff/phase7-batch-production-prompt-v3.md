# Phase 7 — Batch Prompt Production Session Template

_Reusable prompt for producing the agent prompt bundles of one batch of Phase 7 steps._
_Version 3.0 — 2026-11-21 (R5a, PLAN-038). It replaces version 2.0, `prompts/handoff/phase7-batch-production-prompt-update.md`, which is now history. The binding rules of a bundle moved to `prompts/producer-contract.md`; this file keeps what is particular to a Phase 7 batch._
_Operator: start a planning session with the start prompt of `Docs/planner-start-here.md`, and give it this file with the section "Batch-specific context" filled in._
_Precedence: `AGENTS.md`, `Docs/development-process-guide.md` and `prompts/producer-contract.md` govern this file._

---

## Trigger table

| Batch | Step of the plan of record | Trigger | Steps to produce (tier, PLAN-017) | Key theme |
|-------|------|---------|-----------------|-----------|
| Batch 2 | R5b | R5a.1 merged | v7.7.1.2 (LOW), v7.7.1.3 (MEDIUM), v7.7.1.4 (HIGH) | Per-device structs, persist write path, restore engine and retention budget |
| Batch 3 | R9 | R18a merged | v7.7.2.1 (MEDIUM), v7.7.2.2 (HIGH), v7.7.2.3 (MEDIUM) | Engine switchover, migration, per-device delete and socket cap |
| Batch 4 | R13 | R12 merged | v7.7.3.1 (MEDIUM), v7.7.3.2 (MEDIUM), v7.7.3.3 (HIGH) | Export and import, bundle export and import, Phase 7 closure |

v7.7.3.3 is the Phase 7 closure and v1.0 (PLAN-015). The former v7.7.5.x optimisation sprint belongs to v1.1, so Phase 7 has no Batch 5. A step's prompt closes its issue: #214 v7.7.1.2, #215 v7.7.1.3, #216 v7.7.1.4, #217 v7.7.2.1, #218 v7.7.2.2, #219 and #224 v7.7.2.3, #220 v7.7.3.1, #221 v7.7.3.2, #222 v7.7.3.3 (plan of record, section 6).

---

## Lessons of Phase 7 (kept from version 2.0)

Batch 1 had five structural defects, and the May Batch 2 audits found more (issue #228, PR #233). Each now has a rule of the producer contract:

| # | Defect | Rule now |
|---|--------|----------|
| E-1 | Consolidated audit, session log and `CURRENT-STATE.md` listed as work after the merge | Contract 7.8; lint L1 and L7 |
| E-2 | Device testing handed to the operator | Contract 7.7 |
| E-3 | Stale board address and YAML file name | Contract 2.1 and 2.3; lint L4 and L5 |
| E-4 | Scope list without the files that `bump-version.sh` changes | Contract 7.4 |
| E-5 | Assembly `--check` before `--write` | Contract 3.5; lint L6 |
| #228 A1, A2 | A runtime step without device tests on every board it touches | Contract 2.3 |
| #228 A3 | Version bump after the compile | Contract 7.7 |
| #228 A4, PR #233 H-1 | Embedded code with a wrong signature or declaration order | Contract 3.4 |
| #228 A5, PR #233 M-1 | Pre-filled struct sizes | Contract 3.2 |
| #228 A6 | A scope section that pointed to another prompt | Contract 4.1; lint L3 |
| PR #233 M-2 | Line numbers as anchors | Contract 3.1 |

---

## Instructions for the prompt producer

You are the prompt producer for the ESP32-GW Multi-Sensor Gateway project. Read the codebase, then produce the bundles of one batch of Phase 7 steps under `prompts/producer-contract.md`. The May 2026 prompts are source material, not text to copy (PLAN-017).

### Setup

Run the restart check of `Docs/planner-start-here.md` first, with its clones and its table.

### Mandatory reading (in order)

1. `CURRENT-STATE.md` — the ground truth. If it contradicts a plan, `CURRENT-STATE.md` wins.
2. `Docs/plan-of-record.md` — section 2, the ladder, the block of this batch (R5b, R9 or R13) and the blocks of its code steps.
3. `prompts/producer-contract.md` — the whole file.
4. `Docs/development-process-guide.md` — §2.1 to §2.5, §3, §4.1 and §4.3.
5. `Docs/decisions/decision-log.md` — PLAN-001 to PLAN-011 for Phase 7, and every row from PLAN-012 on.
6. `Docs/phase-7-review-and-rewrite.md` — the details of the batch's steps. Its partition section is stale (`CURRENT-STATE.md`, Stale Documents).
7. `Docs/v7.7-v7.8-persistence-architecture.md` — per-device key scheme, FNV-1a hash, retention budget. Its memory budget needs measured values.
8. `Docs/phase-V-capacity-study.md` §6 — the EventLog design for binary sensors.
9. `prompts/prompt-index-and-workflow.md` — the Critical Rules table.
10. `AGENTS.md` — what the agent and the reviewers read.
11. The record and the consolidated audit of the last merged step, and the session handoffs of the batch's steps.
12. Every `firmware/core/*.h` file that the batch's steps change: the code as it is, not as the plan says.
13. The May 2026 prompts of the batch and the audits of issue #228 and PR #233, as evidence.

### Verify before producing

Run these in your own clone, and write each output into the live-extract table. The first two lines put the clone on `origin/main`, so that every command reads the same tree. If the plan and the code disagree, STOP and ask the operator before you produce.

```bash
git fetch origin
git switch --detach origin/main
git rev-parse --short origin/main
git show origin/main:VERSION
git show origin/main:CURRENT-STATE.md | sed -n '3,4p'
ls firmware/core/*.h | wc -l
grep -c '^| [0-9]' prompts/prompt-index-and-workflow.md
find tests -name '*.spec.js' | sort
grep -n 'handle_history_\|handle_api_v2_history_\|SegmentSnapshot' firmware/core/web-handler.h
grep -n 'struct.*Segment\|struct.*Device\|struct.*Event' firmware/core/data-model.h  # no match: no output and exit 1; record "none"
grep -n 'struct.*Segment\|struct.*Device\|struct.*Meta' firmware/core/nvs-persistence.h
grep -A6 '^static void maybe_yield_nvs_scan_(' firmware/core/nvs-persistence.h | grep -o 'pdMS_TO_TICKS([0-9]*)'
```

### The live-extract table (contract 2.2)

It replaces the Board Info Extraction Gate and the Spec File Path Gate of version 2.0. It holds at least:

- `VERSION`, the commit of `origin/main` and the date.
- For every board that a step tests: device name, address, role, board profile and YAML file, from the fleet table of `CURRENT-STATE.md`, `scripts/provision.sh` and the operator's latest `fleet` output.
- Every function signature, struct, constant and key name that a prompt names, each with its `grep -n` source.
- The Rule 61 delay in `maybe_yield_nvs_scan_()`.
- The Playwright spec paths.
- The paths that `bash scripts/bump-version.sh <version>` and the pipeline change, from a rehearsal run on a scratch worktree.
- From v7.7.1.3 on, the OTA slot of each board profile that a step builds; the `.bin` size is a `<MEASURED>` value of the step.

### Deliverables

- For each step: the bundle of contract section 6, with the names of contract 6.2.
- For the batch: the assumption audit `prompts/handoff/phase7/phase7-batch<N>-assumption-audit.md` with the live-extract table and the six answers of process guide §4.1; the audit files that the tiers need (contract 5.3); the batch process metrics. All of it goes into one documentation PR (plan of record, R5b, R9 and R13).

### Phase 7 facts that every bundle uses

- The production boards and the test board are the ones in the fleet table of `CURRENT-STATE.md`. A step tests the boards that its block in the plan of record names, in its order.
- The version on a board is read from `/api/status/full` with `-u "$ESP_USER:$ESP_PASS"`, because the public `/api/status` holds no version.
- `dashboard/dashboard.h` is in the regenerated outputs of every code prompt that bumps the version, because the version is in the dashboard; R5 made the header reproducible, so a build without a change of the dashboard leaves it as it is.
- Every board YAML keeps its `external_components` block (`AGENTS.md`).
- `bash scripts/provision.sh satellite` runs before every commit (`AGENTS.md`, CI Safety).

### Batch 4: the Phase 7 closure

v7.7.3.3 holds the whole closure set of the plan of record block R17, which follows process guide §4.3, and the answers to the questions of issue #228 §D (`CURRENT-STATE.md`, Unimplemented Recommendations). Its §2 first checks, as closure §1 of version 2.0 did: every Phase 7 step issue except #222 is closed; the session log and the record (consolidated audit) of every step are on `main`; `CURRENT-STATE.md` is current; and `prompts/prompt-index-and-workflow.md` holds every Critical Rule that Phase 7 added. The issue sweep classifies every open `phase/7` issue as resolved, deferred to a named milestone, or new. There is no separate closure prompt: the plan of record puts the closure set into the v7.7.3.3 pull request.

---

## Batch-specific context

_Fill in this section before you give the file to the planning session._

### Batch number: [2 / 3 / 4]

### Last merged step: [step of the plan of record and version]

### Steps to produce

| Step | Version | Issue | Tier | Key files changed |
|------|---------|-------|------|-------------------|
| [R4, R6, ...] | v7.7.[A.B] | #[n] | [LOW / MEDIUM / HIGH] | [files] |

### Leftovers that the assumption audit settles

[For Batch 2: every item of the plan of record block R5b. Otherwise: the routed items of the last records.]

### Operator's notes

[Changes on the build host or the boards, and decisions since the last batch, or "none".]

---

## Reuse for later phases

Copy this file for the new phase, then replace the trigger table, the reading list and the phase facts. `prompts/producer-contract.md` does not change with the phase. A phase-agnostic name for this file (issue #228 E14) waits until after v1.0 (PLAN-012).

---

_End of batch production prompt template._
