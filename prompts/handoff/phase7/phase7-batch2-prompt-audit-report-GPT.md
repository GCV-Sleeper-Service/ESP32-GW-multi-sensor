# Phase 7 Batch 2 Prompt Audit — Findings Report

_Date prepared: 2026-05-09_  
_Project: `GCV-Sleeper-Service/ESP32-GW-multi-sensor`_

## Executive Verdict

The new Batch 2 prompt bundle is **substantially improved**, but **not yet safe enough to use unchanged**.

It addresses the main failure categories raised in the operator notes: in-PR deliverables, device testing, stale board information, `bump-version.sh` artifact scope, `assemble --write` before `--check`, and stale Playwright paths.

However, three material problems remain:

| Severity | Finding | Why it matters |
|---|---|---|
| **High** | Device testing occurs before `bump-version.sh` in v7.7.1.3 and v7.7.1.4 prompts. | The board may be flashed/tested with the previous version while the prompt expects `/api/status` to report the new version. This can create false evidence. |
| **High** | v7.7.1.4 contains prompt-provided code that does not match the current function signature of `find_partition_size_bytes_()`. | This is likely a compile failure and directly violates the writing guide’s rule that prompt-provided code must be treated as upstream code and validated. |
| **Medium** | v7.7.1.2 struct-size comments appear wrong because of C/C++ padding/alignment. | Retention budgeting and documentation may be based on incorrect byte counts. This is especially important because Phase 7 is storage-budget sensitive. |

**Recommendation:** do **not** use the Batch 2 prompts as-is. They are close, but need a focused correction pass before giving them to an implementation agent.

---

## 1. Did the New Prompts Address All Operator Concerns?

**Mostly, but not completely.**

| Operator concern | Addressed? | Assessment |
|---|---:|---|
| PR deliverables wrongly treated as post-merge | **Yes** | The new batch-production prompt correctly moves `CURRENT-STATE.md`, changelog, session log, consolidated audit, and handoff updates into §6 / in-PR work. |
| §9 should be bookkeeping only | **Yes** | New prompts use “Post-Merge Bookkeeping (tag and close only).” This is the correct correction. |
| Device testing punted to operator | **Partly** | v7.7.1.3 and v7.7.1.4 place device testing in §6, which is good. But v7.7.1.3 still says the operator may verify the key “V2 persist complete” log post-merge. That leaves one important runtime proof outside the PR. |
| Stale WROOM IP / YAML | **Yes** | The new prompts use WROOM `.170` and include a Board Info Extraction Gate. This fixes the `.190` / stale YAML class of error. |
| `bump-version.sh` caused scope gate failures | **Yes, structurally** | The new prompts whitelist direct version-bump files and regenerated artifacts. This is the right fix. |
| `assemble --check` before `--write` | **Yes** | The new prompts consistently say `--write` before `--check`. |
| CI triggered unexpectedly | **Yes, explanation is correct** | PR #226 changed many code/build paths, including firmware, dashboard, scripts, fixtures, and generated artifacts, so CI should have run. It was not triggered merely because a prompt/audit document was added. |
| ZIP with relative paths | **Yes** | The uploaded bundle has correct relative paths. |

**Gap:** The prompts fixed the known process defects, but did not fully add a guard against **new prompt-authored code defects**. That is the most important remaining weakness.

---

## 2. Is `phase7-batch-production-prompt.md` Updated Sufficiently for Future Batches?

It is much better, but **not sufficient yet**.

### Strong improvements

The updated batch-production prompt correctly adds:

- Full `Docs/development-process-guide.md` reading, not just §2–3.
- Explicit emphasis on §2.3 device testing, §2.5 in-PR deliverables, §3.2 checkpoint rules, §3.3 scope guards, §4.1 assumption audit, and §4.3 closure.
- Board Info Extraction Gate.
- Playwright spec-path gate.
- `bump-version.sh` artifact whitelist.
- HARD vs SOFT scope boundary distinction.
- `assemble-sensor-history.sh --write` before `--check`.
- Device testing delegation: agent does compile/upload/curl; operator only does browser visual checks, serial if unavailable, and final merge.

These changes directly map to the operator’s concerns and to the development guide’s workflow.

### Missing controls

| Missing control | Required change |
|---|---|
| **Prompt-provided code verification** | Add a mandatory “Prompt Code Quality Gate” requiring signature checks, compile feasibility review, and `sizeof()` validation for any embedded C++ structs. |
| **Version-bump ordering rule** | Require version bump **before** full regeneration, compile, upload, curl, and device evidence. |
| **Device evidence rule** | State that no automatable device evidence may be deferred post-merge. If serial/UART evidence is unavailable, the PR must explicitly record the limitation and get operator acceptance before marking ready. |
| **Section 5 proof table** | Require the prompt producer to output a short compliance table against `Docs/multi-phase-session-run-instructions.md` §5, not merely imply it was checked. |
| **Methodology conflict resolution** | Explicitly say `Docs/development-process-guide.md` overrides older `Docs/writing-guide/methodology.md` language where they conflict. The writing guide still contains older “§9 — Post-merge deliverables” wording, which likely contributed to the original drift. |

---

## 3. Do the New Produced Prompts Follow `development-process-guide.md` and `methodology.md`?

### Development process guide

**Mostly yes.**

They now follow the major §2.5 requirement: in-PR deliverables include `CURRENT-STATE.md`, changelog, consolidated audit, session log, and recommendation routing. The development guide is explicit that post-merge work is limited to tagging, closing linked issues, and milestone bookkeeping.

**Partial failure:** device testing is improved but still imperfect. The guide gives compile/upload/curl commands and says curl output should be posted as PR evidence. The v7.7.1.3 prompt still leaves the key hourly-persist proof partly to the operator after merge.

### Writing methodology

**Structurally yes; code-quality-wise no.**

The new prompts have strong structure:

- required reading
- pre-checks
- scope boundaries
- do-not lists
- implementation steps
- acceptance criteria
- pipeline commands
- pre-PR gate
- post-merge bookkeeping

But the methodology also says prompt-provided code must be reviewed like repository code, with comments/docstrings matching actual behavior. The new prompts fail that standard in at least two places:

- v7.7.1.2 likely has incorrect struct-size comments.
- v7.7.1.4 uses an incompatible `find_partition_size_bytes_()` call pattern.

That means the prompt quality is **not yet publication-grade**.

---

## 4. Was the New Session’s “What Went Wrong” Analysis Accurate?

**Mostly accurate, but incomplete.**

| Claimed root cause | Verdict |
|---|---|
| Pre-merge vs post-merge confusion | **Accurate.** The operator notes and development guide clearly support this. |
| Device testing punted to operator | **Accurate in practical terms.** The guide allows agent/operator wording, but the project’s intended rule is clear: agent does automatable compile/upload/curl; operator does only non-automatable checks. |
| Stale board info | **Accurate.** PR #226 final body uses the corrected WROOM YAML and IP: `firmware/esp32-wroom-32d-gw.yaml`, `.170`. |
| Scope boundary vs `bump-version.sh` | **Accurate.** PR #226 changed many version/generated artifacts, confirming the original scope gate was too narrow. |
| Assembly `--check` before `--write` | **Accurate.** This matches the reported PR #226 stop/recovery. |
| CI trigger explanation | **Accurate.** CI ran because code/build paths changed in the same PR, not because a prompt/audit file was added. |

### Missing from the root cause analysis

1. **Document conflict:** the newer development guide says §9 is only bookkeeping, while the older methodology still contains “§9 — Post-merge deliverables.” That conflict should be resolved in the docs.
2. **Prompt-authored code not validated:** the new prompts themselves show this weakness.
3. **Version-bump ordering:** the new prompts still put device testing before version bump in two implementation steps.

---

## 5. Were the New Prompts Checked Against §5 of `multi-phase-session-run-instructions.md`?

**Partly.**

The new prompts clearly incorporate the spirit of §5 troubleshooting: avoid stale analysis, verify files from the repo, use current `tests/browser/*` paths, and avoid stale board values.

But there is no explicit **§5 compliance table** in the produced bundle. For future prompt-production sessions, require this output:

| §5 check | Required proof |
|---|---|
| Stale analysis check | Show current `VERSION`, `firmware/core/*.h` count, board IP table, key function signatures. |
| Output/context degradation | State whether later prompts are less detailed than earlier prompts. |
| Measurement mismatch | Quote exact board/partition values used. |
| Decision contradiction | List checked decision-log entries relevant to the batch. |
| File-path drift | Show `find tests -name "*.spec.js"` output used. |

---

## 6. Quality of the New Prompts

### What improved

The **process scaffolding is stronger** than Batch 1:

- Better mandatory reading.
- Better scope control.
- Better artifact whitelist.
- Better in-PR deliverable placement.
- Better board/path verification.
- Better handoff consistency.
- Better Phase 7 continuity.

The prompts also reflect several key decisions from `Docs/multi-phase-planning-session-summary.md`: retention correction, board inventory/partition planning, binary `EventLog`, recommendation routing, and updated Phase 7 step order.

### Where quality degraded

The **implementation precision is weaker than it should be** for a storage-engine phase.

| Prompt | Quality concern |
|---|---|
| v7.7.1.2 | Struct byte-size comments likely wrong; grep checkpoint for constants likely false-positive/false-failure because usages are counted. |
| v7.7.1.3 | Device testing before version bump; post-merge operator verification still present for key persist evidence. |
| v7.7.1.4 | Compile-breaking function-signature mismatch; device testing before version bump; boot-path write behavior not sufficiently justified. |
| Two-step prompts | Too generic; they should explicitly check the newly discovered risk areas: bump-before-flash, prompt-code signature validation, in-PR device evidence, struct-size validation. |

**Bottom line:** process quality improved; technical prompt-code quality still needs correction.

---

## 7. Required Corrections Before Use

### Must fix in `phase7-batch-production-prompt.md`

Add these rules:

```text
For every versioned implementation step, run `bash scripts/bump-version.sh <version>` before the first full regeneration, compile, upload, curl, or device test. Device evidence must come from firmware reporting the target version.
```

```text
If the prompt contains C++/YAML/JS/Shell code blocks, validate them against current repo signatures before publication. For C++, verify called function signatures with grep and add compile-time/static size checks for storage structs.
```

```text
Automatable evidence cannot be deferred post-merge. If the agent cannot capture serial/UART evidence, the PR must record the limitation and wait for explicit operator acceptance before ready-for-merge.
```

```text
If `Docs/writing-guide/methodology.md` conflicts with `Docs/development-process-guide.md`, the development-process-guide wins.
```

### Must fix in Batch 2 prompts

| Prompt | Correction |
|---|---|
| v7.7.1.2 | Move version bump before compile/regeneration, or rerun full compile after bump. Replace struct-size comments with `static_assert(sizeof(...))` or measured compiler output. Fix grep-count checkpoint for constants. |
| v7.7.1.3 | Move version bump before compile/upload/curl. Remove post-merge persist-log dependency or require pre-merge operator acceptance if serial is unavailable. |
| v7.7.1.4 | Fix `find_partition_size_bytes_()` call to match the current signature. Move version bump before device test. Add explicit boot-path write risk note and acceptance criteria. |
| Two-step prompts | Add reviewer checks for: version reported by device equals target version, prompt-provided code matches current signatures, in-PR device evidence exists, §9 contains no docs. |

---

## 8. Why This Happened Despite the Guide Existing

The guide existed, but the prompt producer was given **competing procedural memories**:

1. The newer `development-process-guide.md` says documentation/audit/handoff updates are **in-PR** and post-merge is bookkeeping only.
2. The older writing methodology still contains the inherited “§9 — Post-merge deliverables” pattern.
3. The prompt producer followed the older prompt anatomy habit instead of treating the development guide as the governing authority.
4. The prompt production prompt originally said “read §2–3,” but the actual governing rules also depended on §4.1 and §7.
5. The process checked structure better than it checked embedded code accuracy.

So the failure was not just “the agent ignored instructions.” It was a **spec hierarchy problem plus insufficient verification gates**.

---

## Final Recommendation

Use this Batch 2 bundle only after a **small but mandatory correction pass**. The new process template is on the right track, but the produced prompts still contain enough technical and sequencing defects that an implementation agent is likely to hit avoidable failures.

**Confidence:** high on the process findings; medium-high on code-specific findings because the prompt bundle and key current repo files were inspected, but a full local compile of the generated prompt code was not executed.

---

## Source References

The findings above were based on the uploaded Batch 2 prompt bundle, operator notes, and these repository sources:

- `Docs/development-process-guide.md`
- `Docs/writing-guide/methodology.md`
- `Docs/multi-phase-session-run-instructions.md`
- `Docs/multi-phase-planning-session-summary.md`
- `firmware/core/nvs-persistence.h`
- `firmware/core/data-model.h`
- PR #226: `v7.7.1.1: stream history CSV responses to avoid BUG-082`
- PR #226 changed-file list and review discussion
