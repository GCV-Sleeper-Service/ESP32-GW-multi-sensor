# Delivery Manifest — Pre-Phase-D Housekeeping
_Date: 2026-03-28_

---

## How to Apply This Delivery

### Step 1: Unzip over the repo working copy

```bash
cd /path/to/ESP32-GW-multi-sensor
unzip -o /path/to/pre-phaseD-housekeeping-delivery.zip
```

This overwrites/creates the following files (see Updated Files below).

### Step 2: Delete superseded files

```bash
# Phase 6 assessment files (content incorporated into Docs/writing-prompts-for-coding-agents-guide.md)
rm prompts/phase6/phase6-assessment-and-phaseD-readiness-2026-03-26.md
rm prompts/phase6/phase6-comprehensive-assessment-and-phaseD-readiness.md
rm prompts/phase6/phase6-implementation-quality-and-phase-d-readiness-assessment-2026-03-27.md
rm prompts/phase6/writing-prompts-guide-addendum-phase6-audit-2026-03-27.md

# Individual session logs (consolidated into session-log-archive-v7.5.x.md)
rm Docs/session-log-2026-03-25-p3-docs-overhaul.md
rm Docs/session-log-2026-03-26-v7.5.6.0.md
rm Docs/session-log-2026-03-26-v7.5.6.1.md
rm Docs/session-log-2026-03-26-v7.5.6.2.md
rm Docs/session-log-2026-03-26-v7.5.6.3.md
rm Docs/session-log-2026-03-26-v7.5.6.4.md
rm Docs/session-log-2026-03-28-v7.5.7.0.md

# Old handoff file (renamed to session-handoff-v7.6.0.0-phaseD-start.md)
rm prompts/handoff/session-handoff-phaseD-start.md

# Superseded Phase D draft prompts and comparison report
rm -rf prompts/phaseD/other/

# Applied correction documents (corrections now in canonical prompts)
rm prompts/phaseD/v7.6.0.0-prompt-corrections-from-v7.5.7.0-audit.md
rm prompts/phaseD/handoff-remaining-prompt-updates.md
```

### Step 3: Verify

```bash
bash scripts/preflight.sh
python3 scripts/render_sensor_config.py --check
```

### Step 4: Commit

```bash
git add -A
git commit -m "chore: pre-Phase-D housekeeping — prompt corrections, doc consolidation, stale file cleanup"
```

---

## Updated Files (in the zip)

### Deliverable 1 — Prompt Corrections (Phase D + Phase 7)

| File | Changes Applied |
|------|----------------|
| `prompts/phaseD/v7.6.0.0-implementation-instructions-for-coding-agent.md` | All 4 corrections from audit doc applied (Do-NOT wording, compliance table rows, generate_aggregator_config_h description, revision date). Device testing expanded with specific build/flash commands. curl POST fixed. |
| `prompts/phaseD/v7.6.0.1-implementation-instructions-for-coding-agent.md` | Do-NOT wording (LESSON-OPS-086). Device testing prerequisites added. curl POST fixed. IPs replaced. Revision date updated. |
| `prompts/phaseD/v7.6.0.2-implementation-instructions-for-coding-agent.md` | Do-NOT wording (LESSON-OPS-086). Device testing prerequisites added. curl POST fixed. IPs replaced. Revision date updated. |
| `prompts/phaseD/v7.6.0.3-implementation-instructions-for-coding-agent.md` | Do-NOT wording (LESSON-OPS-086). Device testing prerequisites added. curl POST fixed. IPs replaced. Revision date updated. |
| `prompts/phaseD/v7.6.0.4-implementation-instructions-for-coding-agent.md` | Device testing prerequisites added. IPs replaced. Revision date updated. |
| `prompts/phaseD/v7.6.0.5-implementation-instructions-for-coding-agent.md` | Revision date updated. |
| `prompts/phase7/v7.7.0.0-implementation-instructions-for-coding-agent.md` | Device testing expanded with regeneration pipeline + esphome clean. Revision date updated. |
| `prompts/phase7/v7.7.0.1-implementation-instructions-for-coding-agent.md` | Device testing expanded with prerequisites section. Revision date updated. |
| `prompts/phase7/v7.7.1.0-implementation-instructions-for-coding-agent.md` | Device testing expanded with prerequisites section. Revision date updated. |

### Deliverable 2 — Session Handoff

| File | Description |
|------|-------------|
| `prompts/handoff/session-handoff-v7.6.0.0-phaseD-start.md` | Renamed from session-handoff-phaseD-start.md. Expanded with: Workflow section, Post-PR Closure Deliverables section, fixed stale prompt file references, added LESSON-OPS-086/087/088, concrete device IPs, updated infrastructure description (generate_aggregator_config_h). |

### Deliverable 3 — Prompt Index

| File | Description |
|------|-------------|
| `prompts/prompt-index-and-workflow.md` | v7.5.7.0 marked ✅ Complete 2026-03-28. Phase D prompts linked to actual files (no more "_Prompt not yet created_"). Revision history entry added for 2026-03-28. |

### Deliverable 4 — Phase 6 Assessment Files

Deleted (see Step 2 above). Content was already incorporated into:
- `Docs/writing-prompts-for-coding-agents-guide.md` (§3.12, §3.13, Gaps 14–18, §14)
- `Docs/architecture-forward-looking-notes.md`

### Deliverable 5 — Docs Consolidation

| File | Description |
|------|-------------|
| `Docs/session-log-archive-v7.5.x.md` | Consolidated 7 session logs (p3-docs-overhaul, v7.5.6.0–v7.5.6.4, v7.5.7.0). Updated title, date range, and index. |
| `Docs/bugs-and-lessons-learned.md` | Added LESSON-OPS-086 (Do-NOT regeneration exclusion), LESSON-OPS-087 (cross-language constant consistency), LESSON-OPS-088 (compliance table templating). |
| `Docs/writing-prompts-for-coding-agents-guide.md` | Added §15 (v7.5.7.0 lessons — 15.1 through 15.3). Updated header date. |

### Deliverable 6 — Issue #85

**Recommendation:** Close Issue #85 on GitHub. BUG-071 was resolved by v7.5.7.0 (PR #93). Suggested close comment:

> Resolved by PR #93 (v7.5.7.0 merged 2026-03-28):
> - Manifest buffer doubled to 8192 bytes (AGG_MANIFEST_BUF_SIZE)
> - Truncation detection guard added to handle_aggregator_gateways_()
> - PSRAM-aware satellite scaling: no PSRAM → satellite only, PSRAM → up to 8 satellites
> - Documented as BUG-074 and LESSON-OPS-085

---

_End of delivery manifest._
