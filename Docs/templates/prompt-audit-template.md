# Prompt-Bundle Audit Template

_Canonical audit-prompt skeleton for the ESP32-GW-multi-sensor prompt-audit gate._

- **Template version:** v1.0
- **Authority:** [Docs/prompt-producing-methodology-audit-claude-opus-4.7-2026-05-10.md](../prompt-producing-methodology-audit-claude-opus-4.7-2026-05-10.md) §6 (as revised by §11)
- **Worked example this template was extracted from:** [prompts/handoff/phase7/pr-233-third-independent-audit-prompt.md](../../prompts/handoff/phase7/pr-233-third-independent-audit-prompt.md)
- **CHANGELOG:** see end of this file

> **How to use this file.** Copy this template to `prompts/handoff/<phase>/<bundle>-audit-prompt-v<N>.md`, fill in every `<<…>>` placeholder, and dispatch to ≥ 2 independent auditors in parallel (≥ 3 if the bundle is high-risk per §0 below). Do NOT modify this template in place when running an audit — versioning is preserved here so methodology drift is traceable. To amend the template itself, increment the template version and append a CHANGELOG entry.

---

## §0 Pre-use freshness checklist (binding before audit dispatch)

The operator (or the auditor running this template the first time on a new branch) must confirm all four checks below pass. If any fail, update the template (or the bundle) before dispatching the audit.

- [ ] §1 board fleet references match the current `CURRENT-STATE.md` Board Fleet table (no stale IPs, no removed boards, no missing additions).
- [ ] §1 doctrinal-source references resolve on the current `main` (`Docs/development-process-guide.md`, `Docs/writing-guide/methodology.md`, `Docs/llm-assisted-development-guide.md`).
- [ ] §2.B grep targets exist in the live repo at the cited paths.
- [ ] §1 input list matches the bundle's actual file set (`git diff --name-only <base>..<head>` of the bundle PR).

**Risk classification (determines auditor count):**

- **High-risk bundle** (≥ 3 independent auditors required): boot path, NVS / persistence, authentication, OTA / partition, dashboard data path, multi-board validation, or any bundle whose prior batch had a HIGH-severity audit finding.
- **Standard bundle** (≥ 2 independent auditors required): everything else not on the low-risk list.
- **Low-risk bundle** (operator may opt out, with written justification in PR body): planning supplements, doc-only changes, prompt-template version bumps, lint-rule additions.

This bundle's classification: `<<HIGH-RISK | STANDARD | LOW-RISK>>` — justification: `<<one-sentence rationale>>`.

---

## Audit prompt body (dispatch this section to each auditor)

You are an independent auditor. A separate producer session emitted a prompt bundle (`<<bundle name / PR number>>`) targeting `<<phase / batch>>` of the GitHub repository `GCV-Sleeper-Service/ESP32-GW-multi-sensor`. The operator intends to dispatch the implementation prompts in this bundle to a coding agent on the basis of your audit.

**Your job:** confirm zero remaining HIGH-severity defects in the merged or proposed-merged state of this bundle. The audit is the gate; if you find HIGH-severity defects, the bundle CANNOT be dispatched until they are fixed.

### §1 Inputs to read (in order)

1. The bundle PR file diff at the head commit: `<<https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor/pull/NNN/files>>`. Review every file change at commit `<<sha>>`.
2. The originating issue's acceptance criteria, scoped: `<<issue #NNN — sections covered by this audit, e.g. §A and §B9 only; §C-§E are separate>>`.
3. Prior audit reports the bundle was meant to address (named explicitly):
   - `<<path/to/prior-audit-1.md>>`
   - `<<path/to/prior-audit-2.md>>`
   - `<<… or "none — first audit on this bundle">>`
4. Files this bundle modified, segregated by purpose:
   - **<<acceptance §A>>:** `<<file1>>`, `<<file2>>`, `<<file3>>`
   - **<<acceptance §B>>:** `<<file4>>`, `<<file5>>`
5. Live source-of-truth files referenced by the bundle (re-grep these; do NOT trust the bundle's quoted snippets):
   - `<<firmware/core/<header>.h>>` — for `<<symbol / signature / value>>`
   - `CURRENT-STATE.md` Board Fleet table — for `<<board IPs in scope>>`
   - `<<other canonical sources>>`
6. Doctrinal sources (cite live, not from the bundle):
   - `Docs/development-process-guide.md` — especially §2.5 (in-PR mandatory deliverables, merge gate), §3.2 (checkpoint authoring rules), §3.3 (self-containedness), §4.1 (assumption audit gate).
   - `Docs/writing-guide/methodology.md` §3.10 / §4.3 (device-testing all boards; required-reading specificity).
   - `Docs/llm-assisted-development-guide.md` §1.3 / §1.4 / §2.2 / §2.5 (truth-seeking discipline; assumption audit; source-of-truth hierarchy).
   - `prompts/handoff/<<phase>>-batch-production-prompt-update.md` — for the canonical scope-guard whitelist and Errata.
7. The PR review thread (all rounds + inline comments) **after** you have independently completed §2 (read prior audit reports only after independent inspection — preserves auditor independence).

### §2 Required checks (HIGH-severity gate)

For each item, run the listed verification command (or its read-equivalent) against the head commit. Pass = ✅, Fail = ❌ with citation.

#### §2.A — Doctrinal compliance (one row per acceptance-criteria item)

| Check | Pass condition |
|---|---|
| <<A1>> | <<grep / live-file read; pass condition stated as a query, not assertion>> |
| <<A2>> | <<…>> |
| <<…>> | <<…>> |

Mechanically verifiable. Pass condition is a literal grep or a live-file read.

#### §2.B — Cross-cutting integrity checks (lint blind-spots and pan-bundle properties)

| Check | Pass condition |
|---|---|
| C1 — Rule 61 delay value | All `pdMS_TO_TICKS(N)` references in modified files that pertain to Rule 61 use `N=<<canonical>>`, matching `firmware/core/nvs-persistence.h: maybe_yield_nvs_scan_()`. Zero hits of `pdMS_TO_TICKS(<<wrong value>>)`. |
| C2 — board IPs | Zero stale-IP references (`<<list stale IPs from prior errata>>`) in any modified file. All board references match `CURRENT-STATE.md` Board Fleet. |
| C3 — YAML filenames | All board YAML references match the canonical filenames in `firmware/boards/`. |
| C4 — pipeline order | Zero instances of `assemble-sensor-history.sh --check` ordered before `--write`; zero instances of `bundle-dashboard.sh --check` before `--write`. |
| C5 — `esphome run` | Zero `esphome run` references; all flashes use `timeout 300 esphome upload <yaml> --device=<ip>`. |
| C6 — curl timeouts | All `curl -s` lines targeting board IPs in §6 device-test blocks include `--connect-timeout 5 --max-time 10`. |
| C7 — self-containedness | No cross-prompt scope references (`see v\d`, `see other prompt`, `as defined in <other-prompt>`) in any modified prompt's §3 (Scope). |
| C8 — evidence consistency (Codex §7.4) | The bundle's §6 reviewer-check section, §7 PR-body template, §8 acceptance criteria, §9 in-PR deliverables, and any inline reviewer-checklist all require the **same** evidence. Mismatches (e.g. §6 lists C3 + WROOM but PR-body template only mentions C3) are HIGH defects. |
| C9 — lint baseline | `bash scripts/lint-prompts.sh --baseline main` exits 0; no new ERROR; EXISTING count not increased over PR base. |
| <<C10+ — bundle-specific>> | <<…>> |

#### §2.C — Adversarial inspection (six scenario classes — non-mechanical)

This class is explicitly NOT mechanical; it is where coherence, declaration order, unverified factual claims, scope-boundary leakage, and doctrinal drift not caught by lint surface. Read each prompt end-to-end. For each of the six scenario classes below, write out what you looked for and what you found.

1. **Compliant-but-wrong** — a prompt obeys every rule but produces incorrect output. Detection: walk file declaration order for any prompt that injects new types/functions and modifies existing call sites; mentally compile. The PR #233 H-1 (`RetentionBudget` declared after its use site) was a compliant-but-wrong defect — every other rule was followed.
2. **Evidence-theater** — a prompt requires evidence that is technically collectible but does not prove what the prompt claims it proves. Detection: for each evidence requirement in §6 / §9, ask "if the agent collects exactly this evidence, does it prove the acceptance criterion?"
3. **Scope-boundary-leakage** — the scope guard is too loose (allows agent to touch unintended files) or too tight (forbids files the agent must touch to satisfy §8). Detection: cross-reference the scope-guard whitelist against the file set §6 implicitly modifies. Includes line-number anchor drift (a `:NNN` reference that rots the moment another prompt inserts text above it).
4. **Deferred-ambiguity** — two instructions individually clear combine to create ambiguity. Detection: for each pair of constraints in §3 / §6, ask "what if both are tight at the same time?"
5. **Compliant-but-redundant / non-idempotent** — procedures that work on first run but break on re-run (insert-then-remove patterns; SIZING-log insertion that lacks a guard against double insert).
6. **Doctrinal drift not caught by lint** — subtle violations of `Docs/development-process-guide.md` §2.5 (in-PR vs post-merge framing), `Docs/writing-guide/methodology.md` §3.10 (device-testing-all-boards), or `Docs/llm-assisted-development-guide.md` §2.2 (assumption audit) that no current lint rule covers.

In addition to the six scenarios, perform these specific traces if applicable to the bundle:

- **Declaration-order trace** — for any new type/function introduced, `grep -n` it in every modified file; confirm smallest line number is the declaration.
- **Searchable-anchor check** — for any `<file>:NNN` line-number reference, confirm a re-verify-with-grep follow-on accompanies it; flag any bare line number as a defect.
- **Byte-for-byte verification** — for any inlined whitelist or canonical list, quote both the bundle's version and the canonical source in your report; a single bullet difference is HIGH.

### §3 Output format

Produce a single Markdown report titled `<<bundle name>> audit — <auditor name / model> — <date>` and commit it to `prompts/handoff/<<phase>>/<<bundle-name>>-audit-report-<auditor-slug>-<date>.md`.

Required sections:

1. **Verdict** — one of:
   - **PASS** — zero HIGH and zero CRITICAL findings; merge and dispatch.
   - **CONDITIONAL PASS** — only LOW/MEDIUM findings; merge but track findings as follow-up issues.
   - **FAIL** — ≥ 1 HIGH or CRITICAL finding; do NOT merge until fixed.
2. **Audit lane self-attribution** (Codex §5.2) — state which of the four lanes this report primarily covers: **Doctrine** (§2.A), **Code-coherence** (§2.C declaration-order, byte-for-byte), **Device/evidence** (§2.A device-test rows + §2.B C6), **Drift/lint** (§2.B + §2.C scenario 6). A single report may cover more than one lane; the consolidated audit package must collectively prove all four are covered.
3. **Summary table** — one row per check from §2.A / §2.B / §2.C with PASS / FAIL / N/A and a one-sentence note.
4. **CRITICAL findings** — file path, line, verbatim quote, why CRITICAL (data loss / credential exposure / unrecoverable device risk), concrete fix.
5. **HIGH findings** — file path, line, verbatim quote, why HIGH (compile failure / false evidence / missing merge-gate deliverables), concrete fix.
6. **MEDIUM / LOW findings** — same structure, lower bar.
7. **Disposition recommendation per finding** — `fix-in-PR` / `track-as-followup` / `accept-as-is`.
8. **Confidence statement** — explicit numeric confidence on (a) each HIGH finding's reality, (b) probability of additional HIGH defects missed, (c) any mechanical check the auditor was unable to run.
9. **Producer self-report verification** (Codex §11) — if the bundle PR body contains a producer self-report table, walk each row and confirm the claim against the live repo. Note any discrepancy as a finding.

> Cross-audit reconciliation is **NOT** part of this report. It is a separate artifact (see §4 reconciliation step below) committed only after all peer audits land.

### §4 Constraints (binding)

1. **No invented file contents, function signatures, or line numbers.** If your tooling cannot retrieve a file, the related check is `unable to verify`, not `PASS`.
2. **No proposed new functionality.** The audit is whether the bundle correctly fixes the stated acceptance criteria, not whether the bundle could do more.
3. **Quote verbatim** when claiming a defect. Paraphrasing a defect is a methodology violation.
4. **If a verdict swing depends on an unverifiable check, say so** and recommend the operator manually verify that one check before merging.
5. **Read the bundle PR body before writing the report** to avoid duplicating findings the producer self-disclosed.
6. **Read prior audit reports for the same bundle (if any) only AFTER independently completing §2.** This preserves independence; copy-paste of a peer's finding without independent confirmation is a methodology violation.

### §5 Out of scope (typical — adjust per bundle)

- Acceptance §s not listed in §1.2 (separate audits).
- Operator infrastructure (status-check configuration, branch-protection bypass, etc.).
- Phase implementation correctness of the prompts themselves once executed (those are audited by the existing PR review pipeline once the agent runs).
- Lint-rule additions (note their absence as findings, but do not block on them — they are tracked under the issue's §C / lint-rule backlog).

---

## §6 Reconciliation step (operator-orchestrated, after all peer audits land)

Reconciliation is a separate Markdown file committed at:

```
prompts/handoff/<phase>/<bundle-name>-audit-reconciliation-<date>.md
```

The reconciliation writer (one of the auditors, designated by the operator, OR a third reviewer) must:

1. **Quote each peer's verdict** verbatim.
2. **Per-finding triage** — for every finding raised by any peer, mark one of:
   - `agreement` — this report also raised it.
   - `accept` — peer raised, this report did not, on review accept.
   - `decline` — peer raised, this report did not, declined with reason.
   - `disagreement-on-severity` — raised at different severity.
3. **List unique findings per auditor.**
4. **Update verdict** — if reconciliation reveals an additional HIGH not in any single peer's report, the bundle verdict becomes FAIL.
5. **Attribution table** — map each finding in the reconciled output to its source auditor.
6. **Lane-coverage proof** — confirm the consolidated peer reports collectively cover all four audit lanes (Doctrine / Code-coherence / Device-evidence / Drift-lint). If a lane is uncovered, the reconciliation writer must explicitly perform that lane's checks before issuing a final verdict.

**Escalation rules (binding):**

- Any single auditor `FAIL` → bundle FAIL.
- Any single auditor `CONDITIONAL PASS` combined with another auditor `FAIL` → bundle FAIL.
- Two `CONDITIONAL PASS` verdicts with **non-overlapping** findings → escalate to a third auditor before issuing a final verdict.
- For high-risk bundles (per §0 risk classification), three or more auditors are required before reconciliation may issue a final verdict.

---

## §7 Operator pre-dispatch checklist (GPT-5.5 §11)

Before the producer's bundle PR may be dispatched to a coding agent:

1. Confirm all bundle files exist on the bundle PR head commit.
2. Open the bundle PR (status: draft or ready-for-review).
3. Run `bash scripts/lint-prompts.sh --baseline main` and confirm exit 0.
4. Launch ≥ 2 (or ≥ 3 for high-risk) independent auditors using this template, in parallel.
5. Collect peer audit reports as separate Markdown files in `prompts/handoff/<phase>/`.
6. Assemble the action list (HIGH + CRITICAL findings → fix-in-PR; MEDIUM → track as follow-up issue under the bundle's tracking issue; LOW → triage at operator discretion).
7. Apply fixes in the bundle PR; commit and push.
8. Re-audit the changed sections only (mini-audit; same template, scoped §1 input list).
9. Issue the reconciliation report (per §6) confirming zero HIGH / CRITICAL.
10. Dispatch the bundle to the coding agent only after the reconciliation report is committed.

---

## §8 Triage heuristics for time-constrained audits (Perplexity §5)

If the operator has explicitly recorded time pressure and accepted the residual risk **AND** the bundle is not high-risk, an auditor may run a "minimum viable audit":

1. **Stale-fact grep suite** (fast, objective, high-precision) — `grep -rEn '192\.168\.120\.190|esp32-wroom-32d-multi-sensor\.yaml|esphome run' prompts/`
2. **§9 doctrine checklist** (fast, objective) — verify in-PR vs post-merge framing per `Docs/development-process-guide.md` §2.5.
3. **Embedded C++ inspection** (slow but highest defect yield) — read every embedded code block; mentally compile; cross-reference each cited symbol against the live header.

§2.A row-by-row mechanical checks may be skipped under minimum-viable; §2.B C7 (self-containedness) and C8 (evidence consistency) and §2.C scenarios 1, 3, 5 must always run.

For high-risk bundles: minimum viable is NOT permitted. Full audit is mandatory regardless of time pressure.

---

## CHANGELOG

| Version | Date | Change |
|---|---|---|
| v1.0 | 2026-05-10 | Initial template extracted from `prompts/handoff/phase7/pr-233-third-independent-audit-prompt.md` and structured per [Docs/prompt-producing-methodology-audit-claude-opus-4.7-2026-05-10.md](../prompt-producing-methodology-audit-claude-opus-4.7-2026-05-10.md) §6 (with §11 revisions: Codex four-lane coverage, Codex severity model, Codex evidence-consistency check C8, Perplexity adversarial scenario taxonomy in §2.C, Perplexity separate-file reconciliation, Perplexity freshness checklist §0, Perplexity triage heuristics §8, GPT-5.5 operator checklist §7). |

---

_End of template._
