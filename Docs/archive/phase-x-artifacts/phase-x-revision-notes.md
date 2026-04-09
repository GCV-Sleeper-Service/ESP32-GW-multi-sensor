# Phase X Plan — Revision Notes for Handoff Session

_Date: 2026-04-04_
_These items were identified after the plan draft was completed and must be incorporated during the revision session._

---

## Item 1: Documentation Split as Pre-Step v7.6.4.0

### Problem

The current plan places the documentation restructuring at v7.6.5.8 (the last step). This means every Phase X coding agent from v7.6.5.0 through v7.6.5.7 still reads the full 3,069-line `Docs/bugs-and-lessons-learned.md`. That's ~15K tokens of documentation context before the agent even opens a source file — directly contradicting the plan's own goal of fitting tasks within 30K–40K tokens.

### Resolution

Add **v7.6.4.0 — Documentation Restructuring** as a standalone pre-step before the code refactor begins. This is pure documentation work: no code changes, no test impact, no risk, no Playwright dependency.

### v7.6.4.0 scope

**Split `Docs/bugs-and-lessons-learned.md` (3,069 lines) into domain-scoped files:**

| File | Content scope | Est. lines |
|---|---|---|
| `Docs/lessons/index.md` | Cross-reference: which file covers which domain; how to find a lesson by number | ~100 |
| `Docs/lessons/dashboard.md` | Dashboard-specific: LESSON-OPS-043, -050, -052, -055, -065, -099, -111; BUG-039, -054, -056, -080, -081 | ~600 |
| `Docs/lessons/firmware.md` | Firmware/ESP-IDF/NVS: LESSON-OPS-056, -068, -069, -070, -072, -074, -100, -101, -102, -103, -104, -105, -106, -107, -108, -109; BUG-057, -061, -062, -064, -075, -076, -077, -078, -079 | ~800 |
| `Docs/lessons/build-pipeline.md` | Build, generators, regeneration: LESSON-OPS-066, -067, -071, -077, -090, -091, -097, -098 | ~400 |
| `Docs/lessons/testing.md` | Playwright, CI, fixtures, mocks: LESSON-OPS-057, -063, -080, -083, -112, -113, -114; BUG-051 | ~500 |
| `Docs/lessons/operations.md` | Device testing, flashing, USB, deployment: LESSON-OPS-051, -058, -069, -073 | ~300 |

`Docs/bugs-and-lessons-learned.md` becomes a redirect file: "This file has been split into domain-scoped files. See `Docs/lessons/index.md`."

**Consider splitting `Docs/writing-prompts-for-coding-agents-guide.md` (1,593 lines):**

The writing guide is a methodology document (how to write prompts) rather than a reference document (what the constraints are). At 1,593 lines it's borderline — not as urgent as the 3,069-line bugs/lessons file, but it will keep growing as new patterns are discovered.

Recommended split:

| File | Content | Est. lines |
|---|---|---|
| `Docs/writing-guide/methodology.md` | §1–3: Core prompt anatomy, required sections, how to structure a prompt | ~600 |
| `Docs/writing-guide/gap-catalog.md` | §4: All 17 gap categories with examples — reference material, not always needed in context | ~900 |
| `Docs/writing-guide/checklists/dashboard.md` | Dashboard-specific prompt patterns: async safety, CSS mirroring (pre-Phase-X), module-scoped prompts (post-Phase-X), POST body requirements | ~100+ |
| `Docs/writing-guide/checklists/firmware.md` | Firmware-specific prompt patterns: deferred task pattern, NVS namespace isolation, Arduino-ism detection, `canHandle()` registration | ~100+ |

The checklist files are thin initially but grow as each phase adds domain-specific prompt lessons. A coding agent writing a dashboard prompt reads `methodology.md` + `checklists/dashboard.md` (~700 lines, ~4K tokens) instead of the full 1,593-line guide.

Writing guide split should be done before dashboard refactoring as part of v7.6.4.0: it's low-risk, and the Phase X prompts themselves would immediately benefit from the slimmer methodology file. 

### Impact on subsequent steps

After v7.6.4.0, every Phase X implementation prompt references only the relevant domain file:

```
Required Reading:
- Docs/lessons/dashboard.md          ← instead of full bugs-and-lessons-learned.md
- Docs/writing-guide/methodology.md  ← instead of full writing guide (if split)
```

This reduces documentation context from ~15K–23K tokens to ~4K–6K tokens per prompt.

### Acceptance criteria for v7.6.4.0

- [ ] `Docs/lessons/` directory exists with all domain files
- [ ] Every LESSON-OPS and BUG entry from the original file appears in exactly one domain file
- [ ] `Docs/lessons/index.md` cross-references all entries with file locations
- [ ] Original `Docs/bugs-and-lessons-learned.md` contains redirect notice
- [ ] If writing guide is split: `Docs/writing-guide/` directory exists with methodology + gap catalog + checklists
- [ ] `prompts/prompt-index-and-workflow.md` updated to reference new file paths
- [ ] No code changes, no test changes

---

## Item 2: Implementation Prompts as a Revision Session Deliverable

### Problem

The Phase X plan and the session handoff prompt both omit prompt generation as a deliverable. Without prompts, the plan cannot be executed by coding agents.

### Resolution

Add prompt generation as an explicit deliverable of the revision session. The prompts should be produced after the plan is verified against the actual codebase, using the verified plan sections as source material.

### Recommended prompt production scope for revision session

| Priority | Prompts | Rationale |
|---|---|---|
| Must produce | v7.6.4.0 (doc split) | Pre-step; needed first; low complexity |
| Must produce | v7.6.5.0 (module split) | Highest-risk step; needs the most detailed prompt |
| Must produce | v7.6.5.1 (CI wiring) | Small but distinct deliverable |
| Must produce | v7.6.5.2 (template creation) | Level 2 start; needs careful equivalence gate spec |
| Must produce | v7.6.5.3 (retire manual mirror) | Level 2 closure; pipeline update details |
| Should produce | v7.6.5.4–v7.6.5.6 (Level 3 steps) | Lower priority; can be produced in follow-up if context runs low |
| Can defer | v7.6.5.7–v7.6.5.8 (test split + closure) | Depend on Level 3 structure being proven |

All prompts go into `prompts/phaseX/` following the established naming convention:
```
prompts/phaseX/v7.6.4.0-implementation-instructions-for-coding-agent.md
prompts/phaseX/v7.6.5.0-implementation-instructions-for-coding-agent.md
...
```

### Prompt structure

Each prompt follows the established anatomy from `Docs/writing-prompts-for-coding-agents-guide.md` §3:

1. Header with version and prerequisite
2. Required Reading with specific callouts (now referencing domain-scoped docs)
3. Current status
4. Pre-condition checks (CI-exact fixture set commands)
5. Exact scope with file lists
6. Do-NOT list
7. Critical rules table
8. Documentation updates
9. Validation and regeneration pipeline
10. Mandatory deliverables (session log, compliance table, validation evidence)

---

## Item 3: SVG Board Images — Future Enhancement Under Component Model

### Problem

`dashboard.html` embeds an inline SVG representation of the ESP32-C3 SuperMini board. Other board types (ESP32-S3-DevKitC1, ESP32-WROOM-32D) don't have SVGs yet but will eventually need them. Currently the SVG is buried in the HTML monolith — there's no clean way to add board-specific SVGs without editing the full file.

### Resolution

Note this as a **future enhancement** in the Phase X plan under the `device-info` component, not as a Phase X deliverable. The component model makes it naturally solvable.

### Proposed structure (post-Phase X, when SVGs are created)

```
dashboard/components/device-info/
  index.js           — board info logic, GPIO display
  styles.css         — device-info CSS
  template.html      — device info HTML with {{BOARD_SVG}} marker
  boards/
    esp32-c3-supermini.svg
    esp32-s3-devkitc1.svg
    esp32-wroom-32d.svg
```

### How it would work

1. The firmware's `/api/status` response already includes board identification.
2. The dashboard JS (in `components/device-info/index.js`) reads the board type and selects the correct SVG.
3. During build, `build-dashboard.sh` either:
   - (a) Inlines all SVGs into `template.html` and the JS shows/hides the correct one at runtime, or
   - (b) Uses a `{{BOARD_SVG:name}}` marker and the build script inlines the SVG for the target board (requires build-time board selection — less flexible).

Option (a) is simpler and supports runtime board detection. The total SVG payload for 3 boards would be small (~5–10KB uncompressed, <2KB gzipped).

### Phase X plan update

Add a sentence to the `device-info` component description in §4.3:

> **Future enhancement:** Board-specific SVG images can be added under `components/device-info/boards/` as they are created. The component's `index.js` selects the correct SVG at runtime based on the board identifier from `/api/status`. This is not a Phase X deliverable — it is noted here for architectural alignment.

Also consider: during v7.6.5.5 (HTML template extraction), the existing C3 SVG should be extracted from `dashboard.tmpl.html` into `components/device-info/template.html` as part of the normal template extraction work. This doesn't require any new SVG creation — just moving the existing one to its component home.

---

## Summary of Changes to Plan and Handoff

| Item | Change to plan | Change to handoff |
|---|---|---|
| Documentation split | Add v7.6.4.0 as pre-step; move doc restructuring from v7.6.5.8 to v7.6.4.0; update v7.6.5.8 to be code closure only | Add "produce prompts" to Step 3 deliverables |
| Writing guide split | Add to v7.6.4.0 scope as "decide and optionally execute" | Add to Step 1 verification checklist |
| Implementation prompts | Add §"Implementation Prompts" section to plan referencing `prompts/phaseX/` | Add prompt generation as explicit deliverable in Step 3 |
| SVG board images | Add future-enhancement note under `device-info` component in §4.3 | No change needed |
| Version range | Expand to v7.6.4.0–v7.6.5.8 (was v7.6.5.0–v7.6.5.8) | Update version range in Key Facts |

---

_End of revision notes._
