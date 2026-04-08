You are performing a documentation reorganization for the following repository:
https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

## Your Task

Reorganize the `Docs/` folder and `prompts/` folder so that the repository documentation is clean, well-structured, and ready for Phase Y implementation work.

This task addresses GitHub Issue #140 (Documentation reorder) and also includes prompt-index optimization.

This is a **documentation/reorganization task only**. Do **not** modify any source code, scripts, tests, or firmware files.

---

## Context

The project has completed Phase 6 (v7.5.6.x), Phase D (v7.6.0.x), and Phase X (v7.6.4.0 + v7.6.5.x). The repository documentation has accumulated organically across these phases. Phase Y (v7.6.6.x — firmware refactor) is next. Before producing Phase Y implementation prompts, the documentation needs to be cleaned up so that:

1. Agents have a clear, minimal reference surface
2. Historical artifacts are archived, not cluttering active docs
3. The prompt-index reflects current state, not stale history
4. File organization follows consistent categories

---

## Reading List

Read in this order:

1. `prompts/prompt-index-and-workflow.md` — current prompt index; understand what it tracks and what's stale
2. `prompts/handoff/phaseX-results.md` — Phase X delivery summary and open items
3. `prompts/handoff/phaseX-results-quality-check.md` — quality check with cosmetic issues to address
4. `Docs/changelog.md` — understand current size and structure (read first 100 lines + scan structure)
5. `Docs/lessons/index.md` — current lessons index
6. `Docs/lessons/firmware.md`, `Docs/lessons/dashboard.md`, `Docs/lessons/operations.md`, `Docs/lessons/build-pipeline.md`, `Docs/lessons/testing.md` — domain-scoped lessons files
7. `Docs/writing-guide/methodology.md`, `Docs/writing-guide/gap-catalog.md`, `Docs/writing-guide/checklists/dashboard.md`, `Docs/writing-guide/checklists/firmware.md` — current writing guide structure
8. `Docs/phase-Y-architecture-and-refactor-plan-sensor-history.md` — Phase Y plan (recently committed)
9. `Docs/phase-Y-current-state-inventory-sensor-history-v2.md` — Phase Y inventory
10. `Docs/phase-X-architecture-and-refactor-plan-dashboard.md` — Phase X plan (reference for what to keep)
11. `Docs/phase-d-implementation-plan.md` — Phase D plan (reference)
12. `README.md` — current README state

Also scan the full directory listings:
- `ls -la Docs/` — identify all files and what category they belong to
- `ls -la Docs/archive/` — what's already archived
- `ls -la Docs/lessons/` — domain files
- `ls -la Docs/writing-guide/` and `ls -la Docs/writing-guide/checklists/`
- `ls -la prompts/handoff/` — handoff files and results
- `ls -la prompts/handoff/phase6/`, `prompts/handoff/phaseD/`, `prompts/handoff/phaseX/`
- `ls -la prompts/phaseX/` — agent prompts
- `ls -la prompts/phase7/` — Phase 7 prompts (if any)

---

## Deliverables

### 1. Bugs and Lessons Audit

**Verify integrity of the lessons index and domain files:**
- Every `BUG-xxx` and `LESSON-OPS-xxx` entry must appear in **exactly one** domain file
- Every entry must be listed in `Docs/lessons/index.md`
- Within each domain file, entries should follow **reverse chronological order** (newest first)
- Check for duplicates across domain files
- Check for entries missing from the index

Produce a brief audit summary as a comment in the PR or as a section in the commit message. Fix any issues found directly.

### 2. Session Log Consolidation

The `Docs/` folder contains many individual session logs (`session-log-2026-*.md`). These are historical records, not active references.

**Action:**
- Move all `Docs/session-log-*.md` files to `Docs/archive/session-logs/`
- Keep the archive accessible but out of the active documentation path
- If a consolidated session-log archive already exists (`session-log-archive-v7.5.x.md`), move it to the same archive folder

### 3. Changelog Assessment

`Docs/changelog.md` is large. Evaluate its current size and structure:
- If it's manageable (under ~5,000 lines), keep it as a single file
- If it's excessively large, propose a split strategy (e.g., by major phase) but **do not implement the split** — just document the recommendation

**Also fix the known issues from Phase X quality check:**
- Add missing `## [v7.6.5.3]` section heading (quality check Issue #5)
- Add post-merge note for PR #150 race-condition test fix (quality check Issue #3)
- Add version-skip annotation for v7.6.5.7 (quality check Issue #4)

### 4. Architecture Documentation Update

The main architecture narrative needs to reflect current state:

**Evaluate whether a single architecture document should exist** that covers:
- Project overview and current state
- Phase history (Phase 3–6, Phase D, Phase X, Phase Y planned)
- Forward-looking items: Phase 7 (per-device persistence), Phase E (captive portal), Phase 8 (cloud/notifications)
- Current system architecture (hardware, firmware, dashboard, build pipeline)

**Options:**
- A) Update an existing file (e.g., `Docs/architecture-revision-and-action-plan.md`) to become the canonical architecture doc
- B) Create a new `Docs/architecture-overview.md` that consolidates relevant content and archive the old files
- C) Keep separate files but add a clear index/README in `Docs/`

Pick the best option, implement it, and archive files that are superseded.

### 5. File Consolidation and Archival

Move files that are no longer active references to `Docs/archive/`:

**Candidates for archival** (verify each before moving — some may still be actively referenced):
- `Docs/BUG-076-documentation-updates.md` — postmortem detail, now captured in lessons
- `Docs/postmortem-BUG-075-076-httpd-stack.md` — same
- `Docs/aggregator-satellite-gateway-principles.txt` — early design notes
- `Docs/architecture-forward-looking-notes.md` — if superseded by updated architecture doc
- `Docs/architecture-revision-and-action-plan.md` — if superseded
- `Docs/data-ingest-setup.md` — evaluate if still current
- `Docs/device-test-report-template.md` — evaluate if still used
- `Docs/esp32-board-selection-guide.md` — evaluate if still current or needs update
- `Docs/nvs_persistence_v7_vs_v8.svg` — evaluate if referenced from active docs
- `Docs/phase-x-dependency-audit.md` — Phase X is complete
- `Docs/phase-x-revision-changelog.md` — Phase X is complete
- `Docs/phase-x-revision-notes.md` — Phase X is complete
- `Docs/phase3-implementation-plan.md` through `Docs/phase6-implementation-plan.md` — historical, phases complete
- `Docs/v7.5-v7.6-architecture-plan.md` — historical
- `Docs/prompt-phaseY-companion.md` — v1 companion prompt, superseded by v2
- `Docs/prompt-phaseY-plan.md` — v1 plan prompt, superseded by v2
- `Docs/phase-Y-current-state-inventory-sensor-history.md` — v1 inventory, superseded by v2
- `Docs/phase-X-context-for-phase-Y.md` — context document, consumed by Phase Y plan
- Redirect stubs: `Docs/bugs-and-lessons-learned.md`, `Docs/writing-prompts-for-coding-agents-guide.md` — these are redirect stubs pointing to the split files; archive them

**Do NOT archive:**
- `Docs/changelog.md` — active
- `Docs/lessons/` — active
- `Docs/writing-guide/` — active
- `Docs/phase-d-implementation-plan.md` — still referenced by Phase 7 prompts
- `Docs/phase-X-architecture-and-refactor-plan-dashboard.md` — methodology reference
- `Docs/phase-Y-architecture-and-refactor-plan-sensor-history.md` — active Phase Y plan
- `Docs/phase-Y-current-state-inventory-sensor-history-v2.md` — active inventory
- `Docs/v7.7-implementation-plan.md` — Phase 7 plan (active future)
- `Docs/v7.7-v7.8-persistence-architecture.md` — Phase 7 architecture (active future)
- `Docs/aggregator-setup.md` — operator documentation (evaluate if current)

### 6. README Update

Verify `README.md` reflects:
- Current project state (Phase X complete, Phase Y planned)
- Current dashboard architecture (component model from Phase X)
- Current build pipeline
- Correct file paths (no stale references to deleted monolithic files)
- Link to architecture doc (from deliverable #4)

### 7. Prompt Index Reorganization

`prompts/prompt-index-and-workflow.md` needs to reflect current state:

**Keep:**
- Related Documents section (update file paths if any moved during archival)
- Prompt Anatomy section (methodology reference)
- Critical Rules table (1–57, all current)
- Canonical regeneration pipeline
- Board provisioning table
- Phase Y section (active, update with plan reference)
- Phase 7 section (pending future, keep as-is but note stale references)

**Archive or trim:**
- Phase 6 completed step table → summarize as "Phase 6: Complete (v7.5.6.0–v7.5.6.3)" with reference to archived plan
- Phase D completed step table → summarize as "Phase D: Complete (v7.6.0.0–v7.6.0.5)" with reference to phaseD-results.md
- Phase X completed step table → summarize as "Phase X: Complete (v7.6.4.0–v7.6.5.8)" with reference to phaseX-results.md
- Detailed delivery summaries per completed step → these are historical; keep only the summary line, archive detailed notes if needed
- Revision history entries that are purely historical

**Add:**
- Phase Y section with version range (v7.6.6.x), link to plan document, and status "Planned"
- Clear "Current Phase: Phase Y" indicator at the top

### 8. Move Phase X Handoffs to Folder

Phase X session handoffs are currently in `prompts/handoff/` root alongside the results files. Move them to the existing `prompts/handoff/phaseX/` subfolder:
- `prompts/handoff/session-handoff-v7.6.4.0.md` → `prompts/handoff/phaseX/`
- `prompts/handoff/session-handoff-v7.6.5.0.md` through `session-handoff-v7.6.5.8.md` → `prompts/handoff/phaseX/`
- `prompts/handoff/phase-x-two-session-prompts.md` → `prompts/handoff/phaseX/`

Keep in `prompts/handoff/` root:
- `phaseX-results.md` — active reference
- `phaseX-results-quality-check.md` — active reference

---

## Commit Strategy

Use a single commit for all changes:
- Commit message: `docs: documentation reorganization (Issue #140) — audit, consolidate, archive, update index`
- Or if the scope is large, use a small number of logical commits (e.g., one for archival moves, one for content edits, one for index update)

---

## Verification Checklist

Before committing:

- [ ] Every BUG-xxx and LESSON-OPS-xxx appears in exactly one domain file and is in the index
- [ ] All session logs moved to `Docs/archive/session-logs/`
- [ ] Changelog issues from Phase X quality check are fixed
- [ ] Architecture documentation has a clear entry point
- [ ] Archived files are in `Docs/archive/` with appropriate subdirectories
- [ ] No active documents were accidentally archived
- [ ] README reflects current project state with correct file paths
- [ ] Prompt index has been trimmed: completed phases summarized, Phase Y section added
- [ ] Phase X handoffs moved to `prompts/handoff/phaseX/`
- [ ] No broken cross-references (grep for archived file names in remaining active docs)
- [ ] `scripts/preflight.sh` still passes (it may check for file existence)

---

## Important Notes

- **Check before archiving:** some files may be referenced by prompts, scripts, or other docs. Grep for the filename before moving.
- **Preserve git history:** use `git mv` for moves so history is retained.
- **Do not modify source code, scripts, tests, or firmware.** This is documentation-only work.
- If `scripts/preflight.sh` checks for specific file paths that you're moving, note this as an issue to resolve but do not modify the script in this task.
