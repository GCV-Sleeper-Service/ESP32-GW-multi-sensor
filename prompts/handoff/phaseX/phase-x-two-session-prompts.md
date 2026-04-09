# Phase X — Two-Session Execution Prompts

_All 10 steps. Each step has two prompts:_
_Step 1 = agent session (does the work). Step 2 = review session (checks it)._
_Repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor_
_Date: 2026-04-05_

---
---

# v7.6.4.0 — Documentation Restructuring

## Step 1 — Agent's Prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Before making ANY changes, read the following files completely and in order:

1. Read `prompts/handoff/session-handoff-v7.6.4.0.md` — session context.
2. Read `prompts/phaseX/v7.6.4.0-implementation-instructions-for-coding-agent.md` in full.
3. Read every file listed in the "Required Reading" section of that document (§2).
   Pay special attention to:
   - `Docs/bugs-and-lessons-learned.md` — read the ENTIRE 3,069-line file cover to cover.
     Count every `### BUG-` and `### LESSON-OPS-` heading. Record the counts.
     These are the numbers you must reproduce exactly across the split files.
   - `Docs/writing-prompts-for-coding-agents-guide.md` — read the full 1,593-line file.
     Understand the section structure (§1–3 methodology, §4 gap catalog).
   - `Docs/phase-X-architecture-and-refactor-plan-dashboard.md` — read §6 v7.6.4.0 and §8.
     These define the exact split targets and domain file assignments.

Then — before writing any content — plan the split:

  a. List every BUG-NNN entry with its primary domain (dashboard / firmware / testing / build / ops).
  b. List every LESSON-OPS-NNN entry with its primary domain.
  c. Cross-check: does any entry span two domains? If so, assign it to the domain where
     the FIX lives, and add a cross-reference note in the other domain file.

Only after completing the plan, implement in this order:

  1. Create `Docs/lessons/` directory
  2. Create `Docs/lessons/index.md` — cross-reference table (every BUG and LESSON-OPS with its file)
  3. Create `Docs/lessons/dashboard.md` — dashboard-domain entries, copied verbatim
  4. Create `Docs/lessons/firmware.md` — firmware-domain entries, copied verbatim
  5. Create `Docs/lessons/build-pipeline.md` — build/generator entries, copied verbatim
  6. Create `Docs/lessons/testing.md` — Playwright/CI/fixture entries, copied verbatim
  7. Create `Docs/lessons/operations.md` — device testing/flashing entries, copied verbatim
  8. Convert `Docs/bugs-and-lessons-learned.md` to redirect stub
  9. Create `Docs/writing-guide/` directory and `Docs/writing-guide/checklists/` subdirectory
  10. Create `Docs/writing-guide/methodology.md` — §1–3 from the writing guide
  11. Create `Docs/writing-guide/gap-catalog.md` — §4 from the writing guide
  12. Create `Docs/writing-guide/checklists/dashboard.md` — dashboard prompt patterns
  13. Create `Docs/writing-guide/checklists/firmware.md` — firmware prompt patterns
  14. Convert `Docs/writing-prompts-for-coding-agents-guide.md` to redirect stub
  15. Update `prompts/prompt-index-and-workflow.md` — add Phase X section, update Related Documents,
      update file path references, add revision history entry
  16. Run validation: count BUG entries across all `Docs/lessons/*.md` — must match original.
      Count LESSON-OPS entries — must match original. Check for duplicates. Check for omissions.
  17. Session log + Instruction Compliance Output table

Do not start writing files until you confirm you have counted all entries in the original.

Follow all rules listed under "Critical Rules" in §7 of the implementation instructions.
After implementation, run `bash scripts/preflight.sh` and create a PR.

Provide in the PR description:
  - Instruction Compliance Output table (§10 format)
  - Entry count verification: "Original: X BUG entries, Y LESSON-OPS entries.
    Split: X BUG entries across N files, Y LESSON-OPS entries across N files.
    Duplicates: 0. Omissions: 0."
  - Confirmation: "Zero code changes. Zero test changes."

Do NOT modify any source code, test files, or build scripts.
Do NOT delete the original files — convert them to redirect stubs only.
Do NOT rewrite, rephrase, or summarize any entry — copy content verbatim.
Do NOT create a changelog entry — this is not a code release.
Do NOT run `bump-version.sh` — version stays at v7.6.0.5; tag v7.6.4.0 is applied after merge.

## Step 2 — Review Prompt

After the agent creates its PR, open a second fresh session and ask for a review
specifically checking:

  • Entry count parity — do the total BUG and LESSON-OPS counts across all domain
    files exactly match the original? (The agent should have provided counts in the PR.)
  • No duplicates — does any BUG-NNN or LESSON-OPS-NNN appear in more than one domain file?
    Run: `grep "^### BUG-" Docs/lessons/*.md | sed 's/.*BUG-/BUG-/' | sort | uniq -d`
    Run: `grep "^### LESSON-OPS-" Docs/lessons/*.md | sed 's/.*LESSON-OPS-/LESSON-OPS-/' | sort | uniq -d`
  • No omissions — does every entry from the original appear somewhere?
  • Cross-references — do entries that span domains have a "See also" note?
  • Redirect stubs — do the original files contain only a redirect notice?
  • Index completeness — does `Docs/lessons/index.md` list every entry with its file?
  • Writing guide split — are §1–3 in methodology.md and §4 in gap-catalog.md?
  • Zero code changes — `git diff --name-only` shows only Docs/ and prompts/ files?
  • prompt-index updated — Phase X section added, file path references updated?
  • Consolidated audit exists — `prompts/phaseX/v7.6.4.0-consolidated-audit.md` produced?
  • Next step artifacts inspected — any updates needed to v7.6.5.0 handoff or prompt?

IMPORTANT: Once PR is merged, please double-check Workflow and Post-PR Closure Deliverables sections and produce what is required 

Post-merge deliverables — produce these BEFORE closing the session:
  - `prompts/phaseX/v7.6.4.0-consolidated-audit.md` using questions from
    `prompts/phaseX/pr-audit-question-template.md` (stable core + pre-step supplement)
  - Review `prompts/handoff/session-handoff-v7.6.5.0.md` and
    `prompts/phaseX/v7.6.5.0-implementation-instructions-for-coding-agent.md` —
    update any stale references if the doc split changed file paths or structure
	
Only then merge and tag: `git tag -a v7.6.4.0 -m "Phase X Pre-step: Documentation restructuring" && git push origin v7.6.4.0`

---
---

# v7.6.5.0 — Module Split (21 Source Modules)

## Step 1 — Agent's Prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Before making ANY changes, read the following files completely and in order:

1. Read `prompts/handoff/session-handoff-v7.6.5.0.md` — session context and module boundary table.
2. Read `prompts/phaseX/v7.6.5.0-implementation-instructions-for-coding-agent.md` in full.
3. Read every file listed in the "Required Reading" section of that document (§2).
   Pay special attention to:
   - `dashboard/dashboard.js` — read the ENTIRE 3,955-line file. This is the monolith being split.
   - `Docs/phase-X-architecture-and-refactor-plan-dashboard.md` — §4.1 (module list with line
     ranges), §5 (migration safety rules), §6 v7.6.5.0 (scope).
   - `scripts/render_sensor_config.py` — understand that the generator writes into `dashboard.js`
     at lines 196–202. After bundling, the generator must re-inject.
4. Verify module boundaries match the plan. Run:
   ```
   bash scripts/verify-module-boundaries.sh --pre-split
   ```
   All 22 checks must pass. If any fail, STOP and report the drift.

Then — before splitting any code — record the identity baseline:

  a. `SHA_BEFORE=$(sha256sum dashboard/dashboard.js | cut -d' ' -f1) && echo "$SHA_BEFORE"`
  b. Record the exact line count: `wc -l dashboard/dashboard.js` — must be 3955.

Only after confirming boundaries and baseline, implement in this order:

  1. Create `dashboard/src/` directory
  2. Extract all 21 modules using the exact line ranges from §5b of the prompt — use `sed -n`
  3. Verify extraction: `wc -l dashboard/src/*.js | tail -1` must show 3955 total
  4. Verify concatenation reproduces original: `cat dashboard/src/*.js | diff - dashboard/dashboard.js`
     must exit 0 (no differences)
  5. Create `scripts/bundle-dashboard.sh` with the exact MODULES array from the prompt
  6. Make executable: `chmod +x scripts/bundle-dashboard.sh`
  7. Run `bash scripts/bundle-dashboard.sh --write`
  8. Identity gate: `sha256sum dashboard/dashboard.js | cut -d' ' -f1` must match $SHA_BEFORE
  9. Run `bash scripts/bundle-dashboard.sh --check` — must say "OK"
  10. Version bump: `bash scripts/bump-version.sh 7.6.5.0`
  11. Full pipeline: render → fixtures → bundle → render (re-inject) → minify → header → check
  12. Changelog entry
  13. Full Playwright suite across all four fixture sets
  14. `bash scripts/preflight.sh`
  15. Session log + Instruction Compliance Output table

Do not start splitting until you confirm the pre-split SHA-256 and boundary verification.

Follow all rules listed under "Critical Rules" in §7 of the implementation instructions.
After implementation, run the full CI-exact validation suite and create a PR.

Provide in the PR description:
  - Pre-split SHA-256 and post-bundle SHA-256 (must match)
  - `bundle-dashboard.sh --check` output
  - Instruction Compliance Output table (§10 format)
  - Exact validation evidence with pass/skip counts for all four fixture sets
  - Confirmation: "dashboard.html UNCHANGED. No behavioral changes."

Do NOT reorder any functions within or between modules.
Do NOT add header comments, module separators, or blank lines to module files.
Do NOT change `dashboard.html` — it is unchanged at Level 1.
Do NOT change any test files or build scripts (except creating `bundle-dashboard.sh`).
Do NOT change `render_sensor_config.py`.
No functional changes to dashboard behavior.

## Step 2 — Review Prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor
Read thoughtfully `prompts/handoff/session-handoff-v7.6.5.0.md` to understand the current stage and deliveries

After the agent creates its PR, open a second fresh session and ask for a review
specifically checking:

  • Identity gate — do the pre-split and post-bundle SHA-256 hashes match exactly?
  • Module count — are there exactly 21 files in `dashboard/src/`?
  • Contiguous slices — is each module a contiguous line range with no function reordering?
    Spot-check 3 modules: verify first and last function match the plan's boundary table.
  • No code changes — `diff <(cat dashboard/src/*.js) dashboard/dashboard.js` exits 0?
  • Bundle script — does MODULES array list all 21 in the correct 00→20 order?
  • dashboard.html unchanged — not in the diff at all?
  • Pipeline order — does the agent's pipeline include the re-inject step (render after bundle)?
  • Generator markers — do lines 196–202 of `dashboard/src/02-sensor-defs.js` contain the
    `SENSOR_MANIFEST:DEFAULT_SENSOR_META` markers?
  • All fixture sets green — 402/0 total?
  • Consolidated audit exists?
  • Next step artifacts inspected?

IMPORTANT: Once PR is merged, please double-check Workflow and Post-PR Closure Deliverables sections and produce what is required 

Post-merge deliverables — produce these BEFORE closing the session:
  - `prompts/phaseX/v7.6.5.0-consolidated-audit.md` using questions from
    `prompts/phaseX/pr-audit-question-template.md` (stable core + Level 1 supplement)
  - Review `prompts/handoff/session-handoff-v7.6.5.1.md` and
    `prompts/phaseX/v7.6.5.1-implementation-instructions-for-coding-agent.md` —
    update any stale references if the split changed anything unexpected
	
Only then merge and tag: `git tag -a v7.6.5.0 -m "Phase X Level 1: Split dashboard.js into 21 source modules" && git push origin v7.6.5.0`

---
---

# v7.6.5.1 — Wire Bundle into CI and Preflight

## Step 1 — Agent's Prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Before making ANY changes, read the following files completely and in order:

1. Read `prompts/handoff/session-handoff-v7.6.5.1.md` — session context.
2. Read `prompts/phaseX/v7.6.5.1-implementation-instructions-for-coding-agent.md` in full.
3. Read every file listed in the "Required Reading" section of that document (§2).
   Pay special attention to:
   - `scripts/preflight.sh` — understand the existing check function pattern (how `pass` and
     `fail` are called, where new checks are added in the sequence).
   - `.github/workflows/browser-tests.yml` — understand the step ordering. Your new step goes
     AFTER existing preflight/fixture steps and BEFORE Playwright.
   - `scripts/bundle-dashboard.sh` — the script you are integrating. Understand `--check` mode.

Only after completing all reading, implement in this order:

  1. Add `dashboard_js_bundle_sync()` function to `scripts/preflight.sh` — follows existing
     function pattern, calls `bundle-dashboard.sh --check`
  2. Add function call to the main check sequence in `preflight.sh`
  3. Add `bash scripts/bundle-dashboard.sh --check` step to `.github/workflows/browser-tests.yml`
     — positioned after existing preflight steps, before Playwright test step
  4. Update LESSON-OPS-091 in `Docs/lessons/build-pipeline.md` — add bundle step to pipeline
  5. Update `Docs/aggregator-setup.md` — add bundle step to pipeline section
  6. Version bump: `bash scripts/bump-version.sh 7.6.5.1`
  7. Full pipeline: render → fixtures → bundle → render → minify → header → check
  8. Verify negative case: `echo "// test" >> dashboard/src/00-app-shell.js && bash scripts/bundle-dashboard.sh --check`
     must FAIL. Then `git checkout dashboard/src/00-app-shell.js`.
  9. Changelog entry
  10. Full Playwright suite across all four fixture sets
  11. `bash scripts/preflight.sh`
  12. Session log + Instruction Compliance Output table

Provide in the PR description:
  - Instruction Compliance Output table
  - Negative-case test result (edit module → check fails → revert)
  - Exact validation evidence with pass/skip counts for all four fixture sets
  - Preflight output showing the new bundle sync check passing

Do NOT modify any source module files in `dashboard/src/`.
Do NOT modify `dashboard.js`, `dashboard.html`, or `dashboard.h`.
Do NOT modify any test files or `bundle-dashboard.sh` itself.
No functional changes to dashboard behavior.



## Step 2 — Review Prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor
Read thoughtfully `prompts/handoff/session-handoff-v7.6.5.1.md` to understand the current stage and deliveries

  • Preflight function pattern — does `dashboard_js_bundle_sync()` follow the existing
    `pass`/`fail` function pattern in `preflight.sh`?
  • CI step positioning — is the bundle check BEFORE Playwright and AFTER fixture generation?
  • Negative case verified — did the agent demonstrate that editing a module without
    rebundling triggers a preflight failure?
  • Pipeline documentation — does LESSON-OPS-091 now include the bundle step with the
    re-inject note (render after bundle)?
  • No source module changes — no files in `dashboard/src/` modified?
  • All fixture sets green — 402/0?
  • Consolidated audit exists?
  • Next step artifacts inspected?

IMPORTANT: Once PR is merged, please double-check Workflow and Post-PR Closure Deliverables sections and produce what is required 

Post-merge deliverables — produce these BEFORE closing the session:
  - `prompts/phaseX/v7.6.5.1-consolidated-audit.md` (stable core + Level 1 supplement)
  - Review `prompts/handoff/session-handoff-v7.6.5.2.md` and
    `prompts/phaseX/v7.6.5.2-implementation-instructions-for-coding-agent.md` —
    update if CI workflow positioning differs from what the next prompt assumes
	
Only then merge and tag: `git tag -a v7.6.5.1 -m "Phase X Level 1: Wire bundle sync into CI and preflight" && git push origin v7.6.5.1`

---
---

# v7.6.5.2 — Create dashboard.tmpl.html and build-dashboard.sh

## Step 1 — Agent's Prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Before making ANY changes, read the following files completely and in order:

1. Read `prompts/handoff/session-handoff-v7.6.5.2.md` — session context.
2. Read `prompts/phaseX/v7.6.5.2-implementation-instructions-for-coding-agent.md` in full.
3. Read every file listed in the "Required Reading" section of that document (§2).
   Pay special attention to:
   - `dashboard/dashboard.html` — read enough to identify the EXACT line numbers where
     `<script>` opens and `</script>` closes. Run:
     `grep -n "<script>" dashboard/dashboard.html | head -1`
     `grep -n "</script>" dashboard/dashboard.html | tail -1`
     Record both line numbers. Everything between them (inclusive) is replaced by the placeholder.
   - `dashboard/dashboard.js` — this is what gets injected at `{{JS_PLACEHOLDER}}`.

Then — before creating any files — verify the script block boundaries:

  a. Record the `<script>` and `</script>` line numbers.
  b. Save the original: `cp dashboard/dashboard.html dashboard/dashboard.html.orig`

Only after confirming boundaries and saving the original, implement in this order:

  1. Create `dashboard/dashboard.tmpl.html` — copy `dashboard.html`, replace the entire
     `<script>...</script>` block with `<script>\n{{JS_PLACEHOLDER}}\n</script>`
  2. Verify the template: `grep -c '{{JS_PLACEHOLDER}}' dashboard/dashboard.tmpl.html` — must be 1
  3. Create `scripts/build-dashboard.sh` using the Python exact-substitution approach from the prompt
  4. Make executable: `chmod +x scripts/build-dashboard.sh`
  5. Run the bit-for-bit gate:
     ```
     bash scripts/bundle-dashboard.sh --write
     python3 scripts/render_sensor_config.py --write
     bash scripts/build-dashboard.sh --write
     diff dashboard/dashboard.html dashboard/dashboard.html.orig
     ```
     The diff MUST exit 0 (no differences). If it doesn't, fix the template before proceeding.
  6. Add `dashboard_tmpl_has_placeholder()` check to `scripts/preflight.sh`
  7. Version bump: `bash scripts/bump-version.sh 7.6.5.2`
  8. Full pipeline: render → fixtures → bundle → render → build-html → minify → header → check
  9. Re-run bit-for-bit gate after version bump (version string changes in JS, so dashboard.html
     changes — but `build-dashboard.sh --check` must pass)
  10. Changelog entry
  11. Full Playwright suite across all four fixture sets
  12. `bash scripts/preflight.sh`
  13. Session log + Instruction Compliance Output table

Provide in the PR description:
  - Bit-for-bit gate result (diff output — should be empty)
  - `build-dashboard.sh --check` output
  - Instruction Compliance Output table
  - Exact validation evidence with pass/skip counts for all four fixture sets

Do NOT modify `dashboard.js` or any `dashboard/src/*.js` module files.
Do NOT modify `dashboard.html` content — only verify it matches the build output.
Do NOT beautify, prettify, or reformat any HTML/CSS.
Do NOT change any test files.
No functional changes to dashboard behavior.

## Step 2 — Review Prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor
Read thoughtfully `prompts/handoff/session-handoff-v7.6.5.2.md` to understand the current stage and deliveries

  • Bit-for-bit gate — did the agent demonstrate `diff` exiting 0 (pre-version-bump)?
  • Template has exactly one placeholder — `grep -c '{{JS_PLACEHOLDER}}' dashboard/dashboard.tmpl.html` = 1?
  • Build script uses Python exact substitution — no regex, no prettification?
  • Build script supports --write and --check modes?
  • Whitespace preservation — no encoding changes, no line ending changes?
  • Preflight check added — `dashboard_tmpl_has_placeholder` function exists?
  • dashboard.js unchanged — not in the diff?
  • Source modules unchanged — no files in `dashboard/src/` modified?
  • All fixture sets green — 402/0?
  • Consolidated audit exists?
  • Next step artifacts inspected?

IMPORTANT: Once PR is merged, please double-check Workflow and Post-PR Closure Deliverables sections and produce what is required 

Post-merge deliverables — produce these BEFORE closing the session:
  - `prompts/phaseX/v7.6.5.2-consolidated-audit.md` (stable core + Level 2 supplement)
  - Review `prompts/handoff/session-handoff-v7.6.5.3.md` and
    `prompts/phaseX/v7.6.5.3-implementation-instructions-for-coding-agent.md` —
    update if the template structure or build script contract differs from what those assume

Only then merge and tag: `git tag -a v7.6.5.2 -m "Phase X Level 2: Create dashboard.tmpl.html and build-dashboard.sh" && git push origin v7.6.5.2`

---
---

# v7.6.5.3 — Make Generated HTML Canonical; Retire Manual Mirror

## Step 1 — Agent's Prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Before making ANY changes, read the following files completely and in order:

1. Read `prompts/handoff/session-handoff-v7.6.5.3.md` — session context, device testing protocol.
2. Read `prompts/phaseX/v7.6.5.3-implementation-instructions-for-coding-agent.md` in full.
3. Read every file listed in the "Required Reading" section of that document (§2).
   Pay special attention to:
   - `scripts/bump-version.sh` — find the `sed` command that edits `dashboard.html` directly
     (approximately line 66). You are REMOVING this and replacing it with a pipeline re-run.
   - `scripts/build-dashboard.sh` — you are modifying this to add the `<!-- GENERATED -->` header.
   - `.github/workflows/browser-tests.yml` — you are adding `build-dashboard.sh --check`.
   - `Docs/lessons/dashboard.md` — you are adding the LESSON-OPS-043 resolution note.

Only after completing all reading, implement in this order:

  1. Modify `scripts/build-dashboard.sh` — prepend `<!-- GENERATED — Do not edit. Source: dashboard/src/*.js + dashboard.tmpl.html -->` to the output
  2. Add `build-dashboard.sh --check` step to `.github/workflows/browser-tests.yml` — after
     bundle check, before Playwright
  3. Update `scripts/bump-version.sh` — remove the `sed` on `dashboard.html`, replace with:
     `bash scripts/bundle-dashboard.sh --write && python3 scripts/render_sensor_config.py --write && bash scripts/build-dashboard.sh --write`
  4. Add `dashboard_html_matches_build()` check to `scripts/preflight.sh`
  5. Add LESSON-OPS-043 resolution note to `Docs/lessons/dashboard.md`
  6. Version bump: `bash scripts/bump-version.sh 7.6.5.3`
  7. Full pipeline: render → fixtures → bundle → render → build-html → minify → header → check
  8. Verify: `grep "sed.*dashboard\.html" scripts/bump-version.sh` should return nothing
  9. Verify: `head -1 dashboard/dashboard.html` should show the GENERATED comment
  10. Changelog entry
  11. Full Playwright suite across all four fixture sets
  12. `bash scripts/preflight.sh`
  13. Session log + Instruction Compliance Output table
  14. Produce device testing checklist for operator to execute post-merge

Provide in the PR description:
  - `grep "sed.*dashboard\.html" scripts/bump-version.sh` output (should be empty)
  - `head -1 dashboard/dashboard.html` output (should show GENERATED comment)
  - `build-dashboard.sh --check` output
  - Instruction Compliance Output table
  - Exact validation evidence with pass/skip counts for all four fixture sets
  - Device testing checklist

Do NOT modify any `dashboard/src/*.js` module files.
Do NOT modify `dashboard.tmpl.html` (only modify `build-dashboard.sh` and `bump-version.sh`).
Do NOT delete the `sed` command for `dashboard.js` in `bump-version.sh` — only remove the one
for `dashboard.html`.
Do NOT modify any test files.
No functional changes to dashboard behavior.

⚠️ DEVICE TESTING REQUIRED after merge — operator must load dashboard on real device and verify
page loads, SSE/polling connects, charts render, management actions work.


## Step 2 — Review Prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor
Read thoughtfully `prompts/handoff/session-handoff-v7.6.5.3.md` to understand the current stage and deliveries

  • sed removal — does `bump-version.sh` no longer contain any `sed` targeting `dashboard.html`?
    Does it still have the `sed` for `dashboard.js` and other source files?
  • Pipeline replacement — did the agent add `bundle → render → build-html` to `bump-version.sh`?
  • GENERATED header — does `dashboard.html` start with the `<!-- GENERATED -->` comment?
  • CI step positioning — is `build-dashboard.sh --check` AFTER bundle check and BEFORE Playwright?
  • Preflight check — does `dashboard_html_matches_build()` exist and call `build-dashboard.sh --check`?
  • LESSON-OPS-043 resolved — is the resolution note added to `Docs/lessons/dashboard.md`?
  • No source module changes — no files in `dashboard/src/` modified?
  • All fixture sets green — 402/0?
  • Consolidated audit exists?
  • Next step artifacts inspected?
  • Device testing checklist provided for operator?

IMPORTANT: Once PR is merged, please double-check Workflow and Post-PR Closure Deliverables sections and produce what is required 

Post-merge deliverables — produce these BEFORE closing the session:
  - `prompts/phaseX/v7.6.5.3-consolidated-audit.md` (stable core + Level 2 supplement)
  - Review `prompts/handoff/session-handoff-v7.6.5.4.md` and
    `prompts/phaseX/v7.6.5.4-implementation-instructions-for-coding-agent.md` —
    update if the pipeline or build script contract changed from what those assume


Only then merge, execute device testing, and tag: `git tag -a v7.6.5.3 -m "Phase X Level 2: Generated HTML canonical; manual mirror retired; LESSON-OPS-043 resolved" && git push origin v7.6.5.3`

---
---

# v7.6.5.4 — Component Directory Scaffolding

## Step 1 — Agent's Prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Before making ANY changes, read the following files completely and in order:

1. Read `prompts/handoff/session-handoff-v7.6.5.4.md` — session context and file move table.
2. Read `prompts/phaseX/v7.6.5.4-implementation-instructions-for-coding-agent.md` in full.
3. Read every file listed in the "Required Reading" section of that document (§2).
   Pay special attention to:
   - `dashboard/src/` — list all 21 files and their sizes. These are being moved.
   - `scripts/bundle-dashboard.sh` — the MODULES array being updated with new paths.
   - `Docs/phase-X-architecture-and-refactor-plan-dashboard.md` — §4.3 (Level 3 target
     structure) and §6 v7.6.5.4 (file moves table).

Then — before moving any files — record the identity baseline:

  a. `SHA_BEFORE=$(sha256sum dashboard/dashboard.js | cut -d' ' -f1) && echo "$SHA_BEFORE"`

Only after confirming the baseline, implement in this order:

  1. Create all directories: `dashboard/core/` and 8 component directories under `dashboard/components/`
  2. Move simple files (1:1 moves — no concatenation)
  3. Concatenate grouped files:
     - `cat src/09-export.js src/10-storage-stats.js src/13-import.js > components/settings-panel/index.js`
     - `cat src/14-cards.js src/15-minmax.js > components/sensor-cards/index.js`
     - `cat src/17-live-updates.js src/18-transport.js > components/live-view/index.js`
  4. Update `scripts/bundle-dashboard.sh` — replace MODULES array with new 17-entry paths
     (order must produce identical concatenation as the old 21-entry order)
  5. Identity gate: `bash scripts/bundle-dashboard.sh --write` then compare SHA-256
  6. Remove `dashboard/src/` directory
  7. Version bump: `bash scripts/bump-version.sh 7.6.5.4`
  8. Full pipeline: render → fixtures → bundle → render → build-html → minify → header → check
  9. Changelog entry
  10. Full Playwright suite across all four fixture sets
  11. `bash scripts/preflight.sh`
  12. Session log + Instruction Compliance Output table

Provide in the PR description:
  - Pre-move and post-bundle SHA-256 (must match before version bump)
  - Confirmation that `dashboard/src/` is removed
  - Instruction Compliance Output table
  - Exact validation evidence for all four fixture sets

Do NOT modify any code within the files — only move/concatenate.
Do NOT reorder the concatenation sequence.
Do NOT add headers, separators, or blank lines during concatenation.
Do NOT change `dashboard.tmpl.html`, `dashboard.html`, or `dashboard.h`.
Do NOT change any test files.
No functional changes to dashboard behavior.


## Step 2 — Review Prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor
Read thoughtfully `prompts/handoff/session-handoff-v7.6.5.4.md` to understand the current stage and deliveries

  • Identity gate — SHA-256 match before version bump?
  • Concatenation order — settings-panel = 09+10+13 (not 09+10+11 or other misordering)?
    sensor-cards = 14+15? live-view = 17+18?
  • Bundle script paths — all 17 entries point to correct core/ or components/ paths?
  • Bundle script order — concatenation order produces same byte sequence as old 21-module order?
  • src/ removed — `dashboard/src/` directory no longer exists?
  • No code changes — only file moves and path updates?
  • All fixture sets green — 402/0?
  • Consolidated audit exists?
  • Next step artifacts inspected?

IMPORTANT: Once PR is merged, please double-check Workflow and Post-PR Closure Deliverables sections and produce what is required 

Post-merge deliverables — produce these BEFORE closing the session:
  - `prompts/phaseX/v7.6.5.4-consolidated-audit.md` (stable core + Level 3 supplement)
  - Review `prompts/handoff/session-handoff-v7.6.5.5.md` and
    `prompts/phaseX/v7.6.5.5-implementation-instructions-for-coding-agent.md` —
    update if the directory structure differs from what those assume (e.g., device-info
    component may or may not have an index.js depending on whether device-info JS was
    split from core)


Only then merge and tag: `git tag -a v7.6.5.4 -m "Phase X Level 3: Component directory scaffolding" && git push origin v7.6.5.4`

---
---

# v7.6.5.5 — Component HTML Template Extraction

## Step 1 — Agent's Prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Before making ANY changes, read the following files completely and in order:

1. Read `prompts/handoff/session-handoff-v7.6.5.5.md` — session context and component targets.
2. Read `prompts/phaseX/v7.6.5.5-implementation-instructions-for-coding-agent.md` in full.
3. Read every file listed in the "Required Reading" section of that document (§2).
   Pay special attention to:
   - `dashboard/dashboard.tmpl.html` — read the ENTIRE file. Identify the HTML section for each
     of the 8 components by their DOM identifiers. Record the line ranges.
   - `scripts/build-dashboard.sh` — you are updating this for two-pass assembly.

Then — before extracting any templates — save the baseline:

  a. `bash scripts/build-dashboard.sh --write`
  b. `cp dashboard/dashboard.html dashboard/dashboard.html.baseline`

Only after saving the baseline, implement in this order:

  1. For each component (device-info, sensor-cards, charts, settings-panel, custom-range,
     auth-modal, live-view, gateway-panel):
     a. Identify the HTML section in `dashboard.tmpl.html` by DOM identifiers
     b. Extract it verbatim into `dashboard/components/<name>/template.html`
     c. Replace the extracted section with `{{COMPONENT:<name>}}` on its own line
  2. Update `scripts/build-dashboard.sh` for two-pass assembly:
     Pass 1: resolve all `{{COMPONENT:name}}` markers
     Pass 2: inject JS at `{{JS_PLACEHOLDER}}`
  3. Run the diff gate:
     `bash scripts/build-dashboard.sh --write && diff dashboard/dashboard.html dashboard/dashboard.html.baseline`
     Must exit 0. If not, a template boundary is wrong — fix before proceeding.
  4. Version bump: `bash scripts/bump-version.sh 7.6.5.5`
  5. Full pipeline: render → fixtures → bundle → render → build-html → minify → header → check
  6. Changelog entry
  7. Full Playwright suite across all four fixture sets
  8. `bash scripts/preflight.sh`
  9. Session log + Instruction Compliance Output table

Provide in the PR description:
  - Diff gate result (should be empty)
  - List of all 8 component `template.html` files with line counts
  - Instruction Compliance Output table
  - Exact validation evidence for all four fixture sets

Do NOT modify any JavaScript files.
Do NOT modify any CSS — CSS extraction is v7.6.5.6.
Do NOT split DOM elements across component boundaries (a `<div>` and its `</div>` must be in
the same template).
Do NOT reformat, prettify, or change whitespace in extracted HTML.
Do NOT change any test files.
No functional changes to dashboard behavior.


## Step 2 — Review Prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor
Read thoughtfully `prompts/handoff/session-handoff-v7.6.5.5.md` to understand the current stage and deliveries

  • Diff gate — did two-pass assembly produce identical output (before version bump)?
  • All 8 templates exist — device-info, sensor-cards, charts, settings-panel, custom-range,
    auth-modal, live-view, gateway-panel?
  • No DOM splitting — spot-check 2 templates: does each contain balanced opening/closing tags?
  • Marker format — each `{{COMPONENT:name}}` on its own line in `dashboard.tmpl.html`?
  • Two-pass build script — does Pass 1 resolve components, Pass 2 inject JS?
  • Whitespace exact — no prettification in extracted templates?
  • No JS changes — no files in `dashboard/core/` or `dashboard/components/*/index.js` modified?
  • All fixture sets green — 402/0?
  • Consolidated audit exists?
  • Next step artifacts inspected — CSS partition table still matches?

IMPORTANT: Once PR is merged, please double-check Workflow and Post-PR Closure Deliverables sections and produce what is required 

Post-merge deliverables — produce these BEFORE closing the session:
  - `prompts/phaseX/v7.6.5.5-consolidated-audit.md` (stable core + Level 3 supplement)
  - Review `prompts/handoff/session-handoff-v7.6.5.6.md` and
    `prompts/phaseX/v7.6.5.6-implementation-instructions-for-coding-agent.md` —
    update if the template extraction changed which CSS selectors remain in the shell vs.
    components, or if the `<style>` block line numbers shifted
	
Only then merge and tag: `git tag -a v7.6.5.5 -m "Phase X Level 3: Component HTML template extraction" && git push origin v7.6.5.5`

---
---

# v7.6.5.6 — Component CSS Extraction

## Step 1 — Agent's Prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Before making ANY changes, read the following files completely and in order:

1. Read `prompts/handoff/session-handoff-v7.6.5.6.md` — session context and CSS partition table.
2. Read `prompts/phaseX/v7.6.5.6-implementation-instructions-for-coding-agent.md` in full.
3. Read every file listed in the "Required Reading" section of that document (§2).
   Pay special attention to:
   - `dashboard/dashboard.tmpl.html` — read the `<style>` block (approximately lines 23–515).
     Identify every CSS selector family and map it to a component using the §3.3 table.
   - `Docs/phase-X-architecture-and-refactor-plan-dashboard.md` — §3.3 (CSS partition table).
     This is your primary reference for which selectors go where.

Then — before extracting any CSS — save the baseline:

  a. `bash scripts/build-dashboard.sh --write`
  b. `cp dashboard/dashboard.html dashboard/dashboard.html.baseline`

Only after saving the baseline, implement in this order:

  1. Create `dashboard/core/base.css` — extract global CSS (`:root`, theme tokens, resets,
     responsive breakpoints, shared structural selectors like `.collapse-*`, `.credits-*`)
  2. For each component, create `styles.css` — extract CSS selector families per the partition table
  3. Replace `<style>` content in `dashboard.tmpl.html` with `{{CSS_PLACEHOLDER}}`
  4. Update `scripts/build-dashboard.sh` for three-pass assembly:
     Pass 0: concatenate `core/base.css` + each `components/*/styles.css` → replace `{{CSS_PLACEHOLDER}}`
     Pass 1: resolve `{{COMPONENT:name}}` markers
     Pass 2: inject JS at `{{JS_PLACEHOLDER}}`
  5. CSS concatenation order in build script must match original cascade order — do NOT alphabetize
  6. Run the diff gate:
     `bash scripts/build-dashboard.sh --write && diff dashboard/dashboard.html dashboard/dashboard.html.baseline`
     Must exit 0. If CSS extraction changed cascade order, the diff will show differences — fix.
  7. Version bump: `bash scripts/bump-version.sh 7.6.5.6`
  8. Full pipeline
  9. Visual regression: open dashboard in browser from disk, compare to pre-extraction screenshot
  10. Changelog entry
  11. Full Playwright suite across all four fixture sets
  12. `bash scripts/preflight.sh`
  13. Session log + Instruction Compliance Output table

Provide in the PR description:
  - Diff gate result
  - CSS file list with line counts
  - CSS concatenation order in build script
  - Visual regression observation (any rendered differences?)
  - Instruction Compliance Output table
  - Exact validation evidence for all four fixture sets

Do NOT modify any JavaScript files.
Do NOT modify any component `template.html` files.
Do NOT change the CSS cascade order.
Do NOT add vendor prefixes, auto-format, or prettify CSS.
Do NOT change any test files.
No functional changes to dashboard behavior.
If a CSS rule targets elements across component boundaries, keep it in `core/base.css`.


## Step 2 — Review Prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor
Read thoughtfully `prompts/handoff/session-handoff-v7.6.5.6.md` to understand the current stage and deliveries

  • Diff gate — did three-pass assembly produce identical output (before version bump)?
  • Cascade order preserved — is the CSS concatenation order in `build-dashboard.sh` explicit
    (not glob-based) and matching the original `<style>` block order?
  • Cross-component rules — are CSS rules targeting elements from multiple components in
    `core/base.css` (not in a component file)?
  • Responsive rules — are component-specific `@media` rules with the component, and global
    breakpoints in `core/base.css`?
  • All 9 CSS files exist — `core/base.css` + 8 component `styles.css`?
  • No JS changes?
  • Visual regression — any rendered differences noted?
  • All fixture sets green — 402/0?
  • Consolidated audit exists?
  • Next step artifacts inspected?

IMPORTANT: Once PR is merged, please double-check Workflow and Post-PR Closure Deliverables sections and produce what is required 

Post-merge deliverables — produce these BEFORE closing the session:
  - `prompts/phaseX/v7.6.5.6-consolidated-audit.md` (stable core + Level 3 supplement)
  - Review `prompts/handoff/session-handoff-v7.6.5.7.md` and
    `prompts/phaseX/v7.6.5.7-implementation-instructions-for-coding-agent.md` —
    update if the component structure changed in a way that affects test group assignments
	
Only then merge and tag: `git tag -a v7.6.5.6 -m "Phase X Level 3: Component CSS extraction" && git push origin v7.6.5.6`

---
---

# v7.6.5.7 — Test Spec Split

## Step 1 — Agent's Prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Before making ANY changes, read the following files completely and in order:

1. Read `prompts/handoff/session-handoff-v7.6.5.7.md` — session context and proposed test structure.
2. Read `prompts/phaseX/v7.6.5.7-implementation-instructions-for-coding-agent.md` in full.
3. Read every file listed in the "Required Reading" section of that document (§2).
   Pay special attention to:
   - `tests/browser/dashboard.spec.js` — read the ENTIRE 1,853-line file. Identify every
     `test.describe()` group, its number, and its content. This is the monolith being split.
   - Note the `loadDashboard()` helper and skip guard patterns — these become shared helpers.
   - Check `playwright.config.js` — does `testMatch` auto-discover `*.spec.js` in the directory?

Then — before splitting any tests — record the baseline counts:

  a. Run all four fixture sets and record exact pass/skip counts for each:
     ```
     FIXTURE_SET=3sensor npx playwright test --project=chromium 2>&1 | tail -1
     FIXTURE_SET=mixed npx playwright test --grep "Mixed" --project=chromium 2>&1 | tail -1
     FIXTURE_SET=system npx playwright test --grep "System" --project=chromium 2>&1 | tail -1
     FIXTURE_SET=aggregator npx playwright test --grep "Aggregator" --project=chromium 2>&1 | tail -1
     ```

Only after recording baseline counts, implement in this order:

  1. Create `tests/browser/test-helpers.js` — extract `loadDashboard()`, fixture detection,
     skip guard utilities, and any other shared setup used by multiple test groups
  2. Split test groups into domain files per the plan table. Adjust group assignments if needed
     based on actual content — the plan table is a starting point, not absolute.
  3. Each domain file imports from `test-helpers.js`
  4. Handle `dashboard.spec.js` — remove or convert to empty file (check if Playwright
     auto-discovers `*.spec.js`)
  5. Run all four fixture sets — counts must match baseline EXACTLY
  6. Run each domain file independently:
     `for spec in tests/browser/*.spec.js; do FIXTURE_SET=3sensor npx playwright test "$spec" --project=chromium 2>&1 | tail -1; done`
  7. Version bump: `bash scripts/bump-version.sh 7.6.5.7`
  8. Full pipeline
  9. Changelog entry
  10. Full Playwright suite
  11. `bash scripts/preflight.sh`
  12. Session log + Instruction Compliance Output table

Provide in the PR description:
  - Pre-split counts and post-split counts (must match: 402/0)
  - Per-file independent run results
  - Instruction Compliance Output table
  - Exact validation evidence for all four fixture sets

Do NOT modify any dashboard source code, CSS, HTML, or build scripts.
Do NOT change any test logic — only move tests between files.
Do NOT delete or disable any tests.
Do NOT change the mock server.
No functional changes to test behavior.


## Step 2 — Review Prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor
Read thoughtfully `prompts/handoff/session-handoff-v7.6.5.7.md` to understand the current stage and deliveries

  • Count parity — do pre-split and post-split test counts match exactly (402/0)?
  • No lost tests — is every `test.describe` group from the original present in exactly one file?
  • No duplicate tests — count total tests across all new files; must equal 402.
  • Skip guards preserved — do aggregator-only tests still have `test.skip(fixtureSet !== 'aggregator')`?
  • Shared helpers — does `test-helpers.js` contain `loadDashboard()` and fixture detection?
  • Independent execution — can each `*.spec.js` run alone without errors?
  • Unused fixture arguments — does any test declare `{ page, request }` but only use one? (Rule 32)
  • No source code changes — no files outside `tests/browser/` modified (except changelog/docs)?
  • All fixture sets green — 402/0?
  • Consolidated audit exists?
  • Next step artifacts inspected?

IMPORTANT: Once PR is merged, please double-check Workflow and Post-PR Closure Deliverables sections and produce what is required 

Post-merge deliverables — produce these BEFORE closing the session:
  - `prompts/phaseX/v7.6.5.7-consolidated-audit.md` (stable core + test/closure supplement)
  - Review `prompts/handoff/session-handoff-v7.6.5.8.md` and
    `prompts/phaseX/v7.6.5.8-implementation-instructions-for-coding-agent.md` —
    update if the test file structure or component names differ from what those assume
    (especially the preflight component-existence check list in v7.6.5.8)

Only then merge and tag: `git tag -a v7.6.5.7 -m "Phase X: Test spec split into domain-scoped files" && git push origin v7.6.5.7`

---
---

# v7.6.5.8 — Phase X Closure

## Step 1 — Agent's Prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Before making ANY changes, read the following files completely and in order:

1. Read `prompts/handoff/session-handoff-v7.6.5.8.md` — session context and closure scope.
2. Read `prompts/phaseX/v7.6.5.8-implementation-instructions-for-coding-agent.md` in full.
3. Read every file listed in the "Required Reading" section of that document (§2).
   Pay special attention to:
   - `prompts/prompt-index-and-workflow.md` — the Critical Rules table and Step Index you are updating.
   - `scripts/preflight.sh` — you are adding component/core file existence checks.
   - `prompts/handoff/phaseD-results.md` — format reference for the Phase X results document.
   - `README.md` — you are adding a Dashboard Architecture section.

Then — before making any changes — verify the current state:

  a. Confirm all component files exist:
     `for comp in sensor-cards charts custom-range auth-modal settings-panel gateway-panel live-view device-info; do ls dashboard/components/$comp/{index.js,template.html,styles.css} 2>/dev/null || echo "MISSING in $comp"; done`
  b. Confirm core files exist:
     `ls dashboard/core/{app-shell,config,sensor-defs,history,manifest,status-snapshot,ui-helpers,staleness-derived,suspend-resume,boot}.js dashboard/core/base.css 2>/dev/null`
  c. Full Playwright to confirm 402/0 baseline.

Only after confirming state, implement in this order:

  1. Add `dashboard_component_files()` check to `scripts/preflight.sh` — verify all expected
     component/core files exist
  2. Update `prompts/prompt-index-and-workflow.md`:
     a. Mark all 10 Phase X steps as `✅ Complete` with dates
     b. Update Critical Rule 6 — mark as "Structurally resolved by Phase X v7.6.5.3"
     c. Update Critical Rule 37 — full three-pass pipeline
     d. Add Critical Rule 47 — "Source modules in dashboard/core/ and dashboard/components/*/"
     e. Add Critical Rule 48 — "After any module edit, run the full pipeline"
     f. Add revision history entry
  3. Update `Docs/writing-guide/checklists/dashboard.md` — add Phase X patterns
  4. Update `Docs/lessons/dashboard.md` — add Phase X lessons
  5. Update `README.md` — add Dashboard Architecture section
  6. Create `prompts/handoff/phaseX-results.md` — Phase X delivery record (follow phaseD-results format)
  7. Version bump: `bash scripts/bump-version.sh 7.6.5.8`
  8. Full pipeline
  9. Changelog entry
  10. Full Playwright suite across all four fixture sets
  11. `bash scripts/preflight.sh` (including new component checks)
  12. Session log + Instruction Compliance Output table

Provide in the PR description:
  - Preflight output showing new component checks passing
  - Instruction Compliance Output table
  - Exact validation evidence for all four fixture sets
  - Confirmation: "Phase X is COMPLETE. All 10 steps delivered."

Do NOT modify any dashboard source code, CSS, or HTML templates.
Do NOT modify any test logic.
Do NOT modify build pipeline scripts (only preflight).
No functional changes to dashboard behavior.


## Step 2 — Review Prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor
Read thoughtfully `prompts/handoff/session-handoff-v7.6.5.8.md` to understand the current stage and deliveries

  • Preflight component checks — does the new check verify all expected files? Does it
    fail if a file is removed? (Test: `mv dashboard/core/boot.js /tmp/ && bash scripts/preflight.sh` — should fail. Then restore.)
  • Critical rules accuracy — does Rule 6 say "structurally resolved"? Does Rule 37
    include the full three-pass pipeline? Are Rules 47–48 correct?
  • Phase X results document — does `prompts/handoff/phaseX-results.md` exist and
    accurately summarize all 10 steps?
  • prompt-index complete — are all 10 steps marked `✅ Complete`?
  • README architecture section — does it match the actual delivered structure?
  • All fixture sets green — 402/0?
  • Consolidated audit exists?
  • Phase 7 artifacts inspected (if they exist)?

IMPORTANT: Once PR is merged, please double-check Workflow and Post-PR Closure Deliverables sections and produce what is required 

Post-merge deliverables — produce these BEFORE closing the session:
  - `prompts/phaseX/v7.6.5.8-consolidated-audit.md` (stable core + test/closure supplement)
  - Review Phase 7 artifacts if they exist:
    `prompts/phase7/v7.7.0.0-implementation-instructions-for-coding-agent.md` —
    update Required Reading to reference domain-scoped docs instead of monolithic files,
    update any `dashboard.js` or `dashboard.html` references to use module/component paths

Only then merge and tag: `git tag -a v7.6.5.8 -m "Phase X Closure: Dashboard architecture refactor complete" && git push origin v7.6.5.8`

**Phase X is COMPLETE.**

---
---

_End of Phase X two-session execution prompts._
