# Pre-Planning-Session Checklist — Post Phase VX

_Complete these items AFTER Phase VX finishes and BEFORE running the multi-phase planning session._

---

## Documents to Update

### 1. `prompts/handoff/multi-phase-planning-supplement-post-vx.md`

This file assumes 4 new boards and ESPHome 2026.4.0. Update:

- **ESPHome version:** change `2026.4.0` → `2026.4.1` throughout
- **Board table:** remove C6-DevKitC-1 row (not available), update C5 specs:
  - Flash: 4 MB → 8 MB
  - PSRAM: "TBD" → 8 MB quad
  - board_id: use `esp32-c5-wroom1u-8m`
- **Board count:** "up to 4 new boards" → "3 new boards"
- **"What the measurements revealed" table:** fill with actual values from `Docs/board-measurement-log-v7.6.10.md`
- **ESP-IDF version:** add "5.5.4" where relevant

### 2. `prompts/prompt-index-and-workflow.md`

Apply the update from `prompts/phaseVX/prompt-index-phaseVX-update.md`:
- Insert Phase VX section between Phase V and Phase 7
- Update header line with current phase
- Fill in step statuses, PR numbers, compile results

### 3. `Docs/board-measurement-log-v7.6.10.md`

Must be fully populated with measured values. The planning session reads this file. Empty cells make the planning session less effective.

### 4. `Docs/phase-V-capacity-study.md` and `Docs/esp32-board-selection-guide.md`

If v7.6.10.3 (docs update advisory session) was completed, these are already updated. If not, the planning session can still run — it will use the measurement log directly.

---

## Verification Before Starting Planning Session

```bash
# Confirm measurement log exists and has data
grep -c '___' Docs/board-measurement-log-v7.6.10.md
# Expected: 0 (all blanks filled)

# Confirm prompt index has Phase VX section
grep -c 'Phase VX' prompts/prompt-index-and-workflow.md
# Expected: ≥ 2

# Confirm VERSION reflects Phase VX completion
cat VERSION
# Expected: 7.6.10.X (whatever the final VX version is)

# Confirm post-VX supplement is updated
grep '2026.4.1' prompts/handoff/multi-phase-planning-supplement-post-vx.md
# Expected: at least 1 match
```

---

## Planning Session Entry Point

```
Append both supplements to the main planning prompt:

1. prompts/handoff/multi-phase-planning-prompt.md
2. prompts/handoff/multi-phase-planning-supplement-v7.6.9.5.md
3. prompts/handoff/multi-phase-planning-supplement-post-vx.md

Then run as a single Claude advisory session.
```

---

_End of pre-planning-session checklist._
