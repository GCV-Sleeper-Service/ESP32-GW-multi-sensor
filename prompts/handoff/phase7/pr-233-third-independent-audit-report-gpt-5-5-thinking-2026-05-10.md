# PR #233 third-party audit — GPT-5.5 Thinking — 2026-05-10

_Auditor: GPT-5.5 Thinking_  
_Repository: `GCV-Sleeper-Service/ESP32-GW-multi-sensor`_  
_PR audited: #233 — `prompts: issue #228 §A + §B9 — produced-doc fixes for v7.7.1.2/1.3/1.4 and active-file post-merge cleanup`_  
_PR final head: `2692e742ca96f2772da8892ddd6a4225d97cb99f`; merge commit: `a2c83442f3d6d19d65ab0651c4ea596673e9080a`_  
_Report path: `prompts/handoff/phase7/pr-233-third-independent-audit-report-gpt-5-5-thinking-2026-05-10.md`_

---

## 1. Executive verdict

**Verdict: FAIL — one remaining HIGH-severity defect found.**

PR #233 correctly fixes the previously known A1–A11 and B9.1–B9.4 classes in the visible prompt text: WROOM coverage is present, version bumps were moved before compile/device evidence, the `find_partition_size_bytes_()` call signature was corrected, v7.7.1.4 is now self-contained, Rule 61 uses the 5 ms helper wording, and the B9 post-merge wording cleanup is materially complete.

However, the final v7.7.1.4 prompt still contains an independent C++ declaration-order compile blocker: it instructs the agent to add `RetentionBudget` and `calculate_retention_budgets_()` **after** the v7.7.1.3 persist functions, then later injects code into the already-earlier `persist_device_segment_()` body that uses `RetentionBudget` and `calculate_retention_budgets_()`. Literal execution will put the type/function definition below the function body that uses it. In C++, that is not valid for a stack array of `RetentionBudget` and a function call with no earlier declaration.

**Dispatch recommendation:** do **not** dispatch v7.7.1.4 until this is corrected. Because this audit gate was requested against the corrected batch before dispatching v7.7.1.2 / v7.7.1.3 / v7.7.1.4, the batch gate remains closed.

**Confidence:** 0.90 that the HIGH finding is real. Confidence that there are no additional HIGH findings is lower, about 0.75, because I used GitHub connector inspection and PR evidence rather than a local checkout with full script execution.

---

## 2. Audit method and source set

I inspected:

- The audit prompt: `prompts/handoff/phase7/pr-233-third-independent-audit-prompt.md`
- Issue #228 acceptance scope: §A, §B9, and the “third independent audit” acceptance item
- PR #233 final metadata, changed-file list, PR body, review comments, review threads, and final merged state
- Current `main` versions of all 9 PR #233 changed files
- Live source context: `firmware/core/nvs-persistence.h`
- Prior audit reports: GPT, Copilot consolidated, and Opus 4.7 reports
- Targeted searches for stale WROOM IP/YAML, `esphome run`, and Rule 61 delay drift

I did **not** run `bash scripts/lint-prompts.sh --baseline main` locally. For C9 I used PR-body evidence plus manual inspection of the modified files. That is sufficient for this verdict because the HIGH finding is independent of lint output.

---

## 3. Summary table — §2.A requested checks

| ID | Result | Finding |
|---|---:|---|
| A1 | PASS | v7.7.1.3 includes both C3 `.189` and WROOM-32D `.170` compile/upload/curl device-test blocks. |
| A2 | PASS | v7.7.1.4 includes both C3 `.189` and WROOM-32D `.170`, with cross-SoC boot-path validation language. |
| A3 | PASS | v7.7.1.3 and v7.7.1.4 both now use `Step 0: Version bump (FIRST — before any code changes or compile)`. |
| A4 | PASS | v7.7.1.4 now uses the live 3-arg `find_partition_size_bytes_(label, type, subtype)` form and has a pre-gate signature grep. |
| A5 | PASS with MEDIUM note | The two-phase commented-out `static_assert` measurement pattern is present. Medium finding M1 remains in the changelog template, where old hard-coded byte counts are still asserted. |
| A6 | PASS | v7.7.1.4 §3 inlines the full bump-version source-file and regenerated-artifact whitelist. |
| A7 | PASS | `session-handoff-v7.7.1.3.md` now has workflow, architecture references, Critical Rules, risk profile, checklist, and carries-forward sections; top-level section count is ≥ 8. |
| A8 | PASS | Checkpoint A now counts constant definitions only with `grep -cE '^static constexpr.*(...)'`. |
| A9 | PASS | `PERFORMANCE-ACK` no longer relies on guessed timing numbers and explicitly says the budget helper must remain off the HTTP request path. |
| A10 | PASS | Rule 61 explanation now cites 5 ms yield behavior and BUG-043 rev2; no Rule 61 `pdMS_TO_TICKS(1)` drift found in modified Phase 7 files. |
| A11 | PASS | v7.7.1.3 reviewer checklist includes `bash scripts/provision.sh status` role verification. |
| B9.1 | PASS | `CURRENT-STATE.md` footer now frames updates as mandatory in-PR deliverables. |
| B9.2 | PASS | `prompts/prompt-index-and-workflow.md` now says device testing is a §6 in-PR acceptance criterion before ready-for-review. Remaining “post-merge” mentions are treated as intentional or historical by the PR body. |
| B9.3 | PASS | `consolidated-audit-template-phase7.md` now frames device results as in-PR evidence and uses current board IP placeholders. |
| B9.4 | PASS | `phase7-review-prompts-perplexity.md` now has a clear HISTORICAL banner and says not to reuse without doctrinal review. |

---

## 4. Summary table — §2.B cross-cutting integrity checks

| ID | Result | Finding |
|---|---:|---|
| C1 | PASS for PR #233 scope; not repo-wide clean | Modified Phase 7 Rule 61 material uses `pdMS_TO_TICKS(5)`. A repository-wide search still finds old `pdMS_TO_TICKS(1)` references outside the PR #233 modified files; those appear historical/non-Rule-61 and are not a PR #233 blocker. This still supports the lint-follow-up recommendation. |
| C2 | PASS | No stale WROOM `.190` or stale WROOM YAML found in the PR #233 modified active prompt files. Repository-wide stale hits are confined to historical/operator/audit contexts or lint logic. |
| C3 | PASS | Device-test blocks use `esphome compile` and `esphome upload`; targeted search did not find `esphome run` in Phase 7 prompt material. |
| C4 | PASS | Fragment-edit checkpoints use `assemble-sensor-history.sh --write` before `--check`. |
| C5 | PASS | Device-test blocks use `timeout 300 esphome upload ...`. |
| C6 | PASS | Modified device-test curl commands include `--connect-timeout 5 --max-time 10`. |
| C7 | PASS | v7.7.1.4 §3 no longer cross-references v7.7.1.2 for scope; it is self-contained. |
| C8 | PASS with MEDIUM note | The struct-definition block no longer uses narrative `sizeof(X) = N` comments; M1 covers remaining hard-coded byte claims in the changelog template. |
| C9 | PASS by PR evidence, not re-run | PR #233 body reports `bash scripts/lint-prompts.sh --baseline main` exit 0, 14 existing warnings, 0 new errors. I did not re-run it locally. |

---

## 5. Summary table — §2.C independent inspection hot-takes

| Check | Result | Finding |
|---|---:|---|
| 1. Prompt-code coherence | FAIL | HIGH H1: v7.7.1.4 can emit C++ that uses `RetentionBudget` before it is declared/defined. |
| 2. Unverified factual claims | FAIL | MEDIUM M1: v7.7.1.2 changelog template still hard-codes byte-size claims despite requiring empirical struct-size measurement. |
| 3. Cross-prompt consistency | PASS with H1 caveat | v7.7.1.2 → v7.7.1.3 → v7.7.1.4 terminology and prerequisites are coherent; H1 is an implementation-order defect inside v7.7.1.4, not a prerequisite-chain mismatch. |
| 4. Non-idempotent procedure review | PASS | The temporary SIZING log is explicitly removed before commit; version bump is first in v7.7.1.3/v7.7.1.4. |
| 5. Doctrinal drift review | PASS with LOW note | §9 is now tag/close only. LOW L1 notes the v7.7.1.4 PR-body template still says only “Boot-tested on C3” despite the prompt requiring both C3 and WROOM testing. |
| 6. Rule 61 lint gap | PASS / follow-up | No immediate PR #233 blocker. Add a future lint to prevent `pdMS_TO_TICKS(1)` from reappearing in active Rule 61 prompt contexts. |
| 7. N3 whitelist byte-for-byte check | PASS | v7.7.1.4 §3 uses the canonical 6 source-file bullets and 6 regenerated-artifact bullets from the batch-production prompt. |

---

## 6. HIGH findings

### H1 — v7.7.1.4 prompt can generate a C++ compile blocker because `RetentionBudget` is introduced after the function that later uses it

**Severity:** HIGH  
**File:** `prompts/phase7/v7.7.1.4-agent-prompt-gpt-codex.md`  
**Location:** §6 Task Group 1 and §6 Task Group 3

**Offending content, quoted:**

Task Group 1 says:

```markdown
Add after the per-device persist functions (from v7.7.1.3):
```

and then defines:

```cpp
struct RetentionBudget {
  int max_slots;
  const char *device_id;
};

static int calculate_retention_budgets_(RetentionBudget *budgets, int max_budgets) {
  ...
}
```

Task Group 3 later says:

```markdown
In `persist_device_segment_()`, replace the line that uses `DEV_PERSIST_PROVISIONAL_SLOTS` during meta initialization:
```

and injects:

```cpp
    RetentionBudget budgets[NUM_DEVICES] = {};
    calculate_retention_budgets_(budgets, NUM_DEVICES);
```

**Why this is HIGH:**

The v7.7.1.3 prompt adds `persist_device_segment_()` before `persist_all_devices_v2()` and v7.7.1.4 instructs the new budget calculator to be added **after the per-device persist functions**. If followed literally, `persist_device_segment_()` is defined before `RetentionBudget` and before `calculate_retention_budgets_()`.

A C++ function body cannot instantiate a stack array of an undeclared/incomplete type:

```cpp
RetentionBudget budgets[NUM_DEVICES] = {};
```

Nor can it call a function with no prior declaration in C++. This is likely an ESPHome compile failure in the first v7.7.1.4 implementation attempt. Since v7.7.1.4 is boot-path code and this audit gates dispatch, this is a blocker.

**Recommended fix:**

Use one of these approaches before dispatch:

1. **Preferred minimal fix:** in v7.7.1.4, instruct the agent to place `struct RetentionBudget` and `calculate_retention_budgets_()` **before** `persist_device_segment_()`, not after the persist functions.
2. **Better design fix:** compute retention budgets once in `persist_all_devices_v2()` or at boot, then pass the selected `budget_slots` into `persist_device_segment_()` as a parameter. This also avoids the O(N²) per-cycle recomputation documented in the prompt’s own `PERFORMANCE-ACK`.
3. If keeping current structure, add a valid forward declaration and move the complete `RetentionBudget` type definition before `persist_device_segment_()`; a function prototype alone is insufficient because the array requires the complete type.

**Chance this is wrong:** low, about 10%. The only realistic escape is if the implementation agent notices and silently reorders the code despite the prompt’s “execute literally” preamble. That would be an agent correction, not a correct prompt.

---

## 7. MEDIUM findings

### M1 — v7.7.1.2 changelog template still hard-codes unverified byte-size claims

**Severity:** MEDIUM  
**File:** `prompts/phase7/v7.7.1.2-agent-prompt-gpt-codex.md`  
**Location:** §6 Step 4.4 — Changelog

**Offending content, quoted:**

```markdown
- `DeviceHistoryMeta` struct: per-device ring buffer state (36 bytes)
- `DeviceSegmentHeader` + `DeviceSegment` structs: per-device hourly segments (226 bytes)
- `EventLog` class: binary sensor state-change-only history (168 bytes, Rule 67)
...
- EventLog saves 608 B per binary sensor vs HistoryBuffer (776 B → 168 B)
```

**Why this matters:**

The same prompt correctly requires empirical `sizeof(...)` measurement before enabling `static_assert`s and warns not to copy audit-estimated values. The changelog template then reintroduces hard-coded byte-size claims. This is not as immediately blocking as H1 because it affects documentation/audit output rather than the compile path, but it undermines the storage-budget discipline that A5 was meant to enforce.

**Recommended fix:**

Replace these changelog bullets with measured placeholders tied to the measurement procedure:

```markdown
- `DeviceHistoryMeta` struct: per-device ring buffer state (measured in session log; static_assert locked)
- `DeviceSegmentHeader` + `DeviceSegment` structs: per-device hourly segments (measured in session log; static_assert locked)
- `EventLog` class: binary sensor state-change-only history (measured in session log)
```

or require the agent to fill the exact measured values after the §2 measurement checkpoint and before committing the changelog.

---

## 8. LOW findings

### L1 — v7.7.1.4 PR-body template says only C3 was boot-tested

**Severity:** LOW  
**File:** `prompts/phase7/v7.7.1.4-agent-prompt-gpt-codex.md`  
**Location:** §8 — PR body template

**Offending content, quoted:**

```markdown
Boot-tested on C3: board boots and responds to all endpoints.
```

**Why this matters:**

Task Group 5 correctly requires both C3 `.189` and WROOM-32D `.170` boot-path testing. The PR-body template should not summarize only the C3 test, because that can lead reviewers to miss whether the WROOM evidence was posted.

**Recommended fix:**

Change the template line to:

```markdown
Boot-tested on C3 (.189) and WROOM-32D (.170): both boards boot and respond to status/full-status/history endpoints.
```

### L2 — Rule 61 delay drift is not mechanically guarded yet

**Severity:** LOW / process follow-up  
**Scope:** lint/guardrail; not a PR #233 dispatch blocker by itself

PR #233 fixes the active modified Rule 61 wording to `pdMS_TO_TICKS(5)`. However, this drift was caught by review rather than by a deterministic prompt lint. A future prompt could reintroduce the 1 ms value unless lint explicitly checks active Rule 61 contexts.

**Recommended fix:**

Add a follow-up prompt-lint rule that flags active prompt files where Rule 61 / BUG-043 / `maybe_yield_nvs_scan_()` context contains `pdMS_TO_TICKS(1)`.

---

## 9. Cross-audit reconciliation

### What PR #233 appears to have fixed from prior audits

- **Opus 4.7 missing-WROOM finding:** fixed. Both v7.7.1.3 and v7.7.1.4 now include WROOM-32D `.170` blocks with the correct generated YAML name.
- **GPT/Copilot version-bump ordering finding:** fixed. Step 0 now precedes compile/upload/curl in v7.7.1.3 and v7.7.1.4.
- **GPT/Copilot `find_partition_size_bytes_()` signature drift:** fixed. The prompt now uses the 3-arg return-value form matching the live header.
- **Copilot static_assert compile-blocker:** fixed. The prompt uses a two-phase pattern with commented-out asserts until measurement is complete.
- **Copilot v7.7.1.4 self-containedness finding:** fixed. The scope whitelist is now inlined.
- **Gemini curl timeout finding:** fixed. Device curl commands include timeouts.
- **Rule 11 vs Rule 61 confusion:** fixed well enough. The handoff distinguishes the general yield principle from the concrete helper/delay rule.

### What this audit adds

H1 is independent of the prior reports and review comments. It is a prompt-code ordering defect introduced by the interaction between v7.7.1.3’s persist-function placement and v7.7.1.4’s budget-calculator placement. It was not one of the original A1–A11 items, but it is in the requested §2.C prompt-code coherence scope.

### Disagreement with PR #233 body

The PR body’s statement that all A-series and B9 items are complete is mostly supported. The reason for the **FAIL** verdict is not that A1–A11 remain unfixed; it is that the corrected prompt now contains a new HIGH compile-order defect discovered by independent inspection.

---

## 10. Disposition

| Item | Disposition |
|---|---|
| A1–A11 | Mechanically satisfied, except M1 documentation hard-code note under A5/C8. |
| B9.1–B9.4 | Satisfied. |
| Dispatch v7.7.1.2 | Can be considered after H1 is fixed if dispatch is step-isolated; M1 should still be corrected first. |
| Dispatch v7.7.1.3 | Can be considered after H1 is fixed if dispatch is step-isolated. |
| Dispatch v7.7.1.4 | **Blocked** until H1 is fixed. |
| Overall corrected-batch gate | **FAIL** until H1 is fixed and this audit or a follow-up verifies the correction. |

---

## 11. Minimal corrective patch recommendation

A minimal follow-up PR should change only the v7.7.1.4 prompt and, optionally, the v7.7.1.2 changelog template:

1. In `prompts/phase7/v7.7.1.4-agent-prompt-gpt-codex.md`, replace:
   ```markdown
   Add after the per-device persist functions (from v7.7.1.3):
   ```
   with explicit placement before `persist_device_segment_()`.
2. Add a checkpoint verifying order, for example:
   ```bash
   python3 - <<'PY'
   from pathlib import Path
   p = Path('firmware/core/nvs-persistence.h').read_text()
   assert p.index('struct RetentionBudget') < p.index('static bool persist_device_segment_')
   assert p.index('static int calculate_retention_budgets_') < p.index('static bool persist_device_segment_')
   PY
   ```
3. Update `prompts/phase7/v7.7.1.2-agent-prompt-gpt-codex.md` changelog template to avoid unmeasured byte claims or require measured values from the sizing step.
4. Update the v7.7.1.4 PR-body template to mention both C3 and WROOM boot tests.

---

_End of report._
