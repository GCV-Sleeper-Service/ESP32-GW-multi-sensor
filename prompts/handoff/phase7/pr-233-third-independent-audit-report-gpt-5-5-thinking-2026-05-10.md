# PR #233 third-party audit — GPT-5.5 Thinking — 2026-05-10

_Auditor: GPT-5.5 Thinking_  
_Repository: `GCV-Sleeper-Service/ESP32-GW-multi-sensor`_  
_Target: current `main` with PR #233 merged; PR #233 final head `2692e742ca96f2772da8892ddd6a4225d97cb99f`; merge commit `a2c83442f3d6d19d65ab0651c4ea596673e9080a`_
_Report path: `prompts/handoff/phase7/pr-233-third-independent-audit-report-gpt-5-5-thinking-2026-05-10.md`_

---

## Verdict

**FAIL — one HIGH-severity defect remains.**

PR #233 fixes the requested A1-A11 and B9.1-B9.4 mechanical/doctrinal items in the merged files: WROOM coverage is present, v7.7.1.3 and v7.7.1.4 move the version bump ahead of compile/device evidence, `find_partition_size_bytes_()` uses the live 3-arg signature, v7.7.1.2 uses a two-phase commented-out `static_assert` measurement pattern, v7.7.1.4 is self-contained, Rule 61 now points at the 5 ms helper behavior, and the active B9 wording is reframed as in-PR.

The blocker is independent of those known review items: v7.7.1.4 tells the implementation agent to place `RetentionBudget` and `calculate_retention_budgets_()` after the per-device persist functions, then tells it to inject `RetentionBudget budgets[NUM_DEVICES]` and a `calculate_retention_budgets_()` call into the earlier `persist_device_segment_()` function. Literal execution creates a C++ declaration-order compile error.

**Dispatch recommendation:** do not dispatch v7.7.1.4, and do not treat the corrected-batch gate as passed, until H1 is fixed. If v7.7.1.2/v7.7.1.3 are dispatched independently, fix M1 first to avoid committing stale measured-size claims.

---

## Audit Method

I audited the merged state on current `main`, not a speculative branch. I inspected the nine PR #233 modified files, the audit prompt, issue #228 acceptance scope, PR #233 metadata and review comments, live `firmware/core/nvs-persistence.h`, doctrinal docs, and the canonical bump-version whitelist source.

Commands run included targeted `rg`/`nl` checks, a bullet-for-bullet whitelist comparison, and:

```bash
bash scripts/lint-prompts.sh --baseline main
```

Result: exit 0, with 14 warning(s). All listed lint items were `EXISTING` or `WARN`; no new blocking lint error was reported.

The audit prompt does not fully match current `main`: its C1 wording asks for zero `pdMS_TO_TICKS(1)` hits under `prompts/**`, but current `main` now contains that literal in historical prompt files and in already-committed audit/prompt artifacts. I therefore report C1 two ways: the PR #233 modified files pass, while the strict repo-wide command is not satisfiable on current `main`.

Per the operator instruction, I inspected the other same-topic audit reports only after completing the independent pass. Reconciliation is in the Cross-Audit Reconciliation section.

---

## Summary Table — §2.A

| Check | Result | Note |
|---|---|---|
| A1 | PASS | v7.7.1.3 §6 Task Group 3 has C3 `.189` and WROOM-32D `.170` blocks. |
| A2 | PASS | v7.7.1.4 §6 Task Group 5 has both production satellites plus explicit RISC-V vs Xtensa-LX6 language. |
| A3 | PASS | v7.7.1.3 bump at line 146 and first compile at line 372; v7.7.1.4 bump at line 161 and first compile at line 499. |
| A4 | PASS | v7.7.1.4 includes a live-header grep and calls `find_partition_size_bytes_(HISTORY_PARTITION_LABEL, ESP_PARTITION_TYPE_DATA, ESP_PARTITION_SUBTYPE_DATA_NVS)`. |
| A5 | PASS with MEDIUM note | v7.7.1.2 has the required commented-out two-phase `static_assert` form and six-step measurement procedure; M1 covers stale byte claims in the changelog template. |
| A6 | PASS | v7.7.1.4 §3 inlines the canonical 6 source bullets and 6 regenerated-artifact bullets. |
| A7 | PASS | `session-handoff-v7.7.1.3.md` has 9 top-level `## ` sections and a Risk Profile with 3 mitigated risks. |
| A8 | PASS | v7.7.1.2 Checkpoint A uses `^static constexpr` to count definitions only. |
| A9 | PASS | v7.7.1.4 `PERFORMANCE-ACK` names `restore_device_history_v2_()` and `persist_device_segment_()`, says the helper must stay off HTTP path, and avoids guessed timing claims. |
| A10 | PASS | v7.7.1.3 Claude prompt cites `pdMS_TO_TICKS(5)`, BUG-043 rev2, and the live helper line. |
| A11 | PASS | Reviewer checklist includes `bash scripts/provision.sh status` before upload. |
| B9.1 | PASS | `CURRENT-STATE.md` footer now says mandatory in-PR deliverable. |
| B9.2 | PASS | `prompt-index-and-workflow.md` line 71 is reframed to §6 in-PR device testing; remaining `post-merge` mentions are Rule 63 wording and a revision-log entry. |
| B9.3 | PASS | `consolidated-audit-template-phase7.md` device results are in-PR and WROOM uses `.170`. |
| B9.4 | PASS | `phase7-review-prompts-perplexity.md` has a HISTORICAL banner. |

---

## Summary Table — §2.B

| Check | Result | Note |
|---|---|---|
| C1 | PASS for PR #233 files; FAIL for strict current-main wording | The nine PR #233 files have zero `pdMS_TO_TICKS(1)` hits. A repo-wide `prompts/**` search does not have zero hits on current `main` because historical/audit artifacts contain the literal. See L2. |
| C2 | PASS | No stale WROOM `.190` full-IP reference in the nine PR #233 files. |
| C3 | PASS | No stale WROOM YAML filename in the nine PR #233 files; WROOM device blocks use `esp32-wroom-32d-gw.yaml`. |
| C4 | PASS | Modified prompt checkpoints order `assemble-sensor-history.sh --write` before `--check`. |
| C5 | PASS | No `esphome run` in the nine PR #233 files; device uploads use `timeout 300 esphome upload ... --device=...`. |
| C6 | PASS | All §6 device-test `curl -s` lines targeting board IPs include `--connect-timeout 5 --max-time 10`. |
| C7 | PASS | No `see v7.7.1.2 §3` / `see other prompt` scope reference remains in modified §3 content. |
| C8 | PASS with MEDIUM note | v7.7.1.2 struct block no longer uses narrative `// sizeof(X) = N bytes`; M1 covers hard-coded measured-size claims elsewhere in the prompt. |
| C9 | PASS | `bash scripts/lint-prompts.sh --baseline main` exits 0 with 14 warning(s), all `EXISTING` or `WARN`. |

---

## Summary Table — §2.C

| Check | Result | Note |
|---|---|---|
| Coherence | FAIL | H1: v7.7.1.4 produces a declaration-order compile blocker. |
| Unverified factual claims | FAIL | M1: v7.7.1.2 changelog template hard-codes byte counts despite requiring empirical measurement. |
| Cross-prompt consistency | FAIL | H1 arises from interaction between v7.7.1.3 persist placement and v7.7.1.4 budget placement. |
| Non-idempotent procedures | PASS | The SIZING log is explicitly removed before commit and regenerated via assembly. |
| Doctrinal drift not caught by lint | PASS with LOW note | L1: v7.7.1.4 PR body template understates WROOM evidence. |
| Rule 61 lint gap | NOTE | Add the planned L8/C13 follow-up; not itself a PR #233 blocker. |
| N3 whitelist verification | PASS | The 12 canonical bullet items match exactly; quoted below. |

---

## N3 Whitelist Verification

Canonical source bullet list from `prompts/handoff/phase7-batch-production-prompt-update.md`:

```markdown
- `VERSION`
- `scripts/render_sensor_config.py` (VERSION constant)
- `tests/fixtures/generate-fixtures.js` (VERSION constant)
- `dashboard/core/app-shell.js` (App.version)
- `firmware/core/config.h` (version comment)
- `firmware/core/data-model.h` (version comment)
- `dashboard/dashboard.js`, `dashboard/dashboard.html` (bundle)
- `dashboard/dashboard.h` (gzip header)
- `dashboard/sensor_history_multi.h` (assembly)
- `src/gateway_manifest.h` (manifest)
- `tests/fixtures/manifest.json`, `tests/fixtures/api-status.json` (fixtures)
- `tests/fixtures/variants/*/` (variant fixtures)
```

v7.7.1.4 §3 inlined bullet list:

```markdown
- `VERSION`
- `scripts/render_sensor_config.py` (VERSION constant)
- `tests/fixtures/generate-fixtures.js` (VERSION constant)
- `dashboard/core/app-shell.js` (App.version)
- `firmware/core/config.h` (version comment)
- `firmware/core/data-model.h` (version comment)
- `dashboard/dashboard.js`, `dashboard/dashboard.html` (bundle)
- `dashboard/dashboard.h` (gzip header)
- `dashboard/sensor_history_multi.h` (assembly)
- `src/gateway_manifest.h` (manifest)
- `tests/fixtures/manifest.json`, `tests/fixtures/api-status.json` (fixtures)
- `tests/fixtures/variants/*/` (variant fixtures)
```

Result: PASS. The bullet content is identical. The surrounding heading text differs slightly (`directly modified` in v7.7.1.4), but the audit prompt specifically scoped the byte-for-byte comparison to the 6 source bullets and 6 regenerated-artifact bullets.

---

## HIGH Findings

### H1 — v7.7.1.4 will emit C++ that uses `RetentionBudget` before it is declared

**Severity:** HIGH  
**File:** `prompts/phase7/v7.7.1.4-agent-prompt-gpt-codex.md`  
**Locations:** line 168, lines 186-191, lines 426-449

Task Group 1 says:

```markdown
Add after the per-device persist functions (from v7.7.1.3):
```

It then defines:

```cpp
struct RetentionBudget {
  int max_slots;           // calculated slot count for this device
  const char *device_id;   // which device this budget is for
};

static int calculate_retention_budgets_(RetentionBudget *budgets, int max_budgets) {
```

Task Group 3 later says:

```markdown
In `persist_device_segment_()`, replace the line that uses `DEV_PERSIST_PROVISIONAL_SLOTS` during meta initialization:
```

and injects:

```cpp
    // Use calculated budget if available, fallback to provisional
    RetentionBudget budgets[NUM_DEVICES] = {};
    calculate_retention_budgets_(budgets, NUM_DEVICES);
```

**Why this is HIGH:** v7.7.1.3 defines `persist_device_segment_()` before `persist_all_devices_v2()`. v7.7.1.4 says to add the budget calculator after the per-device persist functions, which places the complete `RetentionBudget` type and the helper function below `persist_device_segment_()`. C++ requires the complete type before `RetentionBudget budgets[NUM_DEVICES]` and at least a prior declaration before calling `calculate_retention_budgets_()`. Literal prompt execution therefore fails at compile time.

This is a dispatch blocker because v7.7.1.4 is boot-path/persistence code and the audit gate requires zero HIGH defects before dispatch.

**Concrete fix:** change v7.7.1.4 Task Group 1 to place `struct RetentionBudget` and `calculate_retention_budgets_()` before `persist_device_segment_()`, for example after `save_device_meta_()` and before any function that uses those names.

**Better design fix:** compute budgets once in `persist_all_devices_v2()` or at boot and pass `budget_slots` into `persist_device_segment_()`; this also removes the O(N squared) per-cycle recomputation that the prompt already flags.

---

## MEDIUM Findings

### M1 — v7.7.1.2 changelog template hard-codes byte-size claims that the same prompt requires measuring

**Severity:** MEDIUM  
**File:** `prompts/phase7/v7.7.1.2-agent-prompt-gpt-codex.md`  
**Location:** lines 487-502

Offending content:

```markdown
- `DeviceHistoryMeta` struct: per-device ring buffer state (36 bytes)
- `DeviceSegmentHeader` + `DeviceSegment` structs: per-device hourly segments (226 bytes)
- `EventLog` class: binary sensor state-change-only history (168 bytes, Rule 67)
- `EventEntry` struct: timestamped state transition record (8 bytes)
...
- EventLog saves 608 B per binary sensor vs HistoryBuffer (776 B → 168 B)
```

**Why this matters:** §2 of the same prompt requires empirical `sizeof(...)` measurement before enabling `static_assert`s and explicitly warns not to copy audit-estimated values. The changelog template reintroduces fixed byte counts that can drift from the actual measured values.

**Concrete fix:** replace fixed byte values with measurement-tied placeholders, or instruct the agent to fill them only after the §2 sizing procedure and to cite the measured values in the session log.

---

## LOW Findings

### L1 — v7.7.1.4 PR-body template understates the required device evidence

**Severity:** LOW  
**File:** `prompts/phase7/v7.7.1.4-agent-prompt-gpt-codex.md`  
**Location:** line 680

Offending content:

```markdown
Boot-tested on C3: board boots and responds to all endpoints.
```

**Why this matters:** Task Group 5 requires both C3 `.189` and WROOM-32D `.170` boot-path testing. The PR-body template should not mention only C3.

**Concrete fix:** change the template to:

```markdown
Boot-tested on C3 (.189) and WROOM-32D (.170): both boards boot and respond to status/full-status/history endpoints.
```

### L2 — Audit prompt C1 is not directly satisfiable on current `main`

**Severity:** LOW / audit-scope mismatch
**File:** `prompts/handoff/phase7/pr-233-third-independent-audit-prompt.md`

The audit prompt asks for zero repo-wide `pdMS_TO_TICKS(1)` hits under `prompts/**`. Current `main` has historical and audit-artifact hits, including same-topic audit files. The PR #233 modified files are clean, so this is not a PR #233 defect, but future audit prompts should scope this check to active prompt files or to PR-modified files unless historical/audit artifacts are excluded.

---

## Cross-Audit Reconciliation

I inspected the other same-topic audit reports after completing the independent audit:

| Report | Verdict | Reconciliation |
|---|---|---|
| `pr-233-third-independent-audit-perplexity-2026-05-10.md` | CONDITIONAL PASS | Disagree. It did not catch H1 and states the prompts may be dispatched. H1 is mechanically demonstrable from the placement directive and inserted C++ block, so I treat the Perplexity verdict as a miss. |
| `pr-233-third-independent-audit-report-claude-opus-4.7-2026-05-10.md` | FAIL | Agree. It independently confirms the same H1 declaration-order compile blocker, M1 stale byte-count issue, and L1 PR-body C3-only issue. It also adds line-number fragility as a medium/low follow-up; I consider that valid but not dispatch-blocking. |

The original producer-driving audit reports (`new-prompts-audit-report-Copilot.md`, `new-prompts-audit-report-Opus4.7.md`, `phase7-batch2-prompt-audit-report-GPT.md`) identified the A-series defects that PR #233 was meant to fix. My audit agrees those known A/B9 items are materially fixed; the FAIL verdict is due to the newly discovered H1 prompt-code coherence defect.

---

## Disposition Recommendation

| Finding | Disposition |
|---|---|
| H1 — v7.7.1.4 declaration-order compile blocker | Fix in a follow-up PR before dispatching v7.7.1.4. If the batch gate is all-or-nothing, do not dispatch v7.7.1.2/v7.7.1.3 either until this is corrected. |
| M1 — v7.7.1.2 hard-coded byte counts | Fix before dispatching v7.7.1.2, or require measured values to replace the placeholders before any changelog commit. |
| L1 — v7.7.1.4 PR body mentions only C3 | Merge/fix with H1; not a standalone blocker. |
| L2 — audit prompt C1 current-main mismatch | Track in the next audit-prompt/template cleanup; not a PR #233 implementation blocker. |

---

## Confidence Statement

Confidence that H1 is real: **0.95**. The prompt text unambiguously places the type/function below the function body that later uses them.

Confidence there are zero additional HIGH defects: **0.80**. I ran the mechanical checks, lint, and a targeted prompt-code coherence pass; two independent FAIL reports now converge on the same blocker. Residual risk remains because these are implementation prompts containing substantial embedded C++ that has not yet been compiled.

_End of report._
