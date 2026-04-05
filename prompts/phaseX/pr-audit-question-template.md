# Phase X — PR Audit Question Template

_Reusable audit structure for every Phase X PR. Carries forward to Phase Y and beyond._
_Created: 2026-04-05_

---

## How This Template Works

Every Phase X PR audit uses a **stable core** of questions (same for every step) plus a **level-specific supplement** (varies by step). This replaces the ad-hoc question lists from Phase D with a reproducible structure.

**Format rule:** For steps with fewer than 5 files modified and no behavioral changes, the audit should fit on one page. Expand only when deviations, bugs, or new lessons require it.

---

## Stable Core — Internal Audit (Architectural Advisor)

Include in every PR audit:

1. Did the agent deliver what the prompt specified? List any deviations with classification: **omission**, **addition**, or **substitution**.
2. Did the codebase state match the prompt's assumptions? If not, what drifted and when?
3. Were any autonomous decisions made that should be back-ported into the prompt for reproducibility?
4. What new lessons or critical rules emerged? (Give each a candidate LESSON-OPS or Critical Rule number.)
5. What carries forward as required context for the next step?

---

## Stable Core — External Reviewer

Include in every PR review request:

1. Annotate problems with severity: **Blocking** / **High** / **Medium** / **Low** / **Cosmetic**.
2. Did the agent deliver what the prompt required? Where it didn't, classify the cause: **prompt ambiguity**, **codebase drift**, or **autonomous decision**.
3. What implementation decisions were NOT specified in the prompt? Were they correct?
4. If there were failures, what prompt change would have prevented them?

---

## Level-Specific Supplements

### Pre-step (v7.6.4.0)

- Is every LESSON-OPS and BUG entry in exactly one domain file with no duplicates and no omissions?
- Do the redirect stubs in the original files correctly point to the new locations?
- Does `Docs/lessons/index.md` cross-reference every entry with its file location?

### Level 1 (v7.6.5.0–v7.6.5.1)

- Did the identity gate pass (SHA-256 before = after)?
- Were all modules contiguous file slices with no function reordering?
- Did the agent introduce any behavioral changes to the code being moved (violating Migration Safety Rule 1)?
- Does `bundle-dashboard.sh --check` pass on a clean tree?

### Level 2 (v7.6.5.2–v7.6.5.3)

- Did the bit-for-bit diff gate pass (generated HTML = original HTML)?
- Was whitespace handling exact (no prettification, no encoding changes)?
- Does `bump-version.sh` now use the pipeline instead of `sed` on `dashboard.html`?
- Did the `<!-- GENERATED -->` header get added to `dashboard.html` output?

### Level 3 (v7.6.5.4–v7.6.5.6)

- Did the identity gate pass after file moves (bundled output unchanged)?
- Did the CSS cascade order survive extraction?
- Were component template boundaries accurate (no DOM elements split across components)?
- Did the multi-pass assembly produce identical output to the previous step?

### Test/Closure (v7.6.5.7–v7.6.5.8)

- Is the total test count unchanged (402/0)?
- Can each test file run independently?
- Are all new critical rules traceable to a specific Phase X step?
- Does the Phase X results document accurately reflect what was delivered?

---

## How to Embed in Implementation Prompts

Each implementation prompt's §11 (Post-PR Audit Questions) should include:

```markdown
## 11. Post-PR Audit Questions

### Internal audit (answer in the consolidated audit document)

1. Did you deliver what the prompt specified? List any deviations as omission/addition/substitution.
2. Did the codebase state match the prompt's assumptions?
3. What autonomous decisions did you make that were not in the prompt?
4. Any new lessons or critical rules? (Assign candidate numbers.)
5. What context does the next step need from this step?

### Level-specific checks

<INSERT LEVEL-SPECIFIC QUESTIONS FROM THE TEMPLATE>
```

The external reviewer questions are sent separately when requesting review — they are not part of the coding agent prompt.

---

_End of PR audit question template._
