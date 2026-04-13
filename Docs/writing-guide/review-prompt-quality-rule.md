# Review Prompt Quality Rule

_Added: 2026-04-13_
_Source: Phase V prompt production — three iterations required to reach acceptable review prompt detail_

---

## Rule

Review prompts must be as specific and detailed as the agent prompts they review. A review prompt that says "check the PR" or "verify the implementation" without listing concrete verification items is insufficient and will produce shallow, unhelpful reviews.

## Rationale

During Phase V prompt production, initial review prompt versions were half a page per step with no specific details on what to focus on. It took three rounds of iteration to produce review prompts with concrete verification items (12–15 per step), per-step focus areas, and structured three-turn patterns.

The same principle that governs agent prompts — constraints must appear at the point of risk, not in a preamble — applies to review prompts. A reviewer who is told "check auth guards" will skim for `authenticate_management_()` and move on. A reviewer told "verify that `handle_api_ingest_()` has `authenticate_management_()` as its FIRST line, before any parameter parsing" will catch the placement error.

## Quality Criteria for Review Prompts

1. **Concrete verification items:** Each step's review section must list 10+ specific checks, each referencing a function name, file path, or grep pattern.

2. **Step-specific focus areas:** 5–6 bullets per step telling the reviewer exactly what to look for in the diff. Generic checks ("code quality", "test coverage") are insufficient.

3. **Structured output format:** The review prompt must specify the output format (verdict + table + severity annotation). Without this, reviewers produce narrative prose that's hard to action.

4. **Cross-reference to acceptance criteria:** Every acceptance criterion in §6 of the agent prompt must have a corresponding verification item in the review prompt. If an acceptance criterion can't be verified by the reviewer (e.g., device testing), it must be explicitly noted as "operator verification — not reviewable from diff."

## Reference Templates

- Phase Y review prompts: `prompts/phaseY/v7.6.6.1-review-prompt.md`
- Phase V review prompts: `prompts/phaseV/phaseV-review-prompts-perplexity.md`
- Phase V Claude two-step Step 2 sections: the "review specifically checking" lists
- Phase V PR audit template: `prompts/phaseV/pr-audit-question-template-phaseV.md` (per-step focus areas)
