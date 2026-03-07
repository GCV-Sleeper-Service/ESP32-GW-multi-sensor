# ESP32 Gateway Fresh-Start Handoff

_Last updated: 2026-03-06_

## Purpose

This document is the continuity brief for restarting the ESP32 gateway work in a fresh conversation without having to reconstruct the project state from memory.

It consolidates:
- project goals
- current branch status
- recent fixes
- user-required delivery rules
- implementation principles
- next recommended development steps
- testing expectations
- development-pipeline recommendations

---

## Project summary

This project is an **ESP32-C3 multi-sensor BLE gateway** with a dashboard that receives ThermoPro TP357 broadcasts, shows live temperature/humidity, maintains history, and provides a browser-facing UI for monitoring, history review, exports, and gateway management.

The project has evolved through multiple stabilization and dashboard refactor iterations and is currently in the **v7.3.x** branch where the emphasis has been on making the dashboard safer to modify before larger feature additions.

---

## High-level development goals

### Completed / in-progress direction
- stabilize dashboard startup and connection behavior
- reduce dashboard regression risk through structural cleanup
- preserve existing backend/history behavior unless there is a strong reason to change it
- keep the dashboard useful in local file mode, LAN mode, and internet-accessed mode where applicable

### Planned next major goals
1. **Import v1**
   - import historical data into flash
   - strong validation/sanity checks before write
   - replacement-first model before broader merge/edit behavior

2. **Custom date range**
   - additional `Custom Range` button after the existing predefined range buttons
   - range should be based on available stored history dates

3. **Cross-browser / theme validation discipline**
   - desktop browser checks across major browsers
   - mobile browser checks
   - consistency checks for light/dark themes

4. **Continue reducing dashboard fragility**
   - prefer narrow, low-risk changes
   - keep event/state surfaces under control

---

## Current known status at handoff

### Branch status
- active branch context: **v7.3.x**
- current working area: **post-7.3.4.x hotfix/stabilization stage**
- architecture direction: keep Phase 1 structural improvements, then move to Import v1

### Recent build status
User reported that the newest build **compiled successfully**.

### Recent issue set addressed in the latest hotfix cycle
The most recent hotfix scope targeted these dashboard issues:

1. `Export All` failing with `HTTP 502`
2. sensor color changes updating lines but not chart point markers
3. 15-minute chart dots appearing larger than desired
4. theme-switch cases where some visual elements, including chart legend/telemetry visibility, were not corrected until `Ctrl+F5`

### Root-cause summary for the recent hotfix set
- merged export path was too bursty and likely overloaded the ESP/proxy/tunnel path due to concurrent history fetches
- recolor logic updated line color but not point-marker color properties
- 15-minute chart datasets used larger point-radius settings than real-time charts
- theme switching updated state/class but did not fully force the chart redraw/update path, which allowed stale rendering state until hard refresh

### Intent of the recent hotfix approach
Keep the fix narrow and low-risk:
- serialize merged export requests
- update all point-marker color properties during recolor
- reduce 15-minute marker size to match real-time charts
- force runtime chart re-render/update on theme switch

---

## Important project principles locked in by the user

These rules should be followed in future work unless the user changes them.

### Build delivery format
- every build should be delivered as a **ZIP named with the version**
- inside the ZIP there should be a **Docs** directory
- Docs should include versioned markdown files

### Required documentation files
For each build, include:
- `Docs/v7.x.x-documentation.md`
- `Docs/v7.x.x-development-notes.md`
- `Docs/v7.x.x-consolidated-test-worksheet.md`
- relevant carry-forward opinion/review file if applicable

### Documentation requirements
`documentation.md` should include:
- changelog for that specific build
- documented bug fixes
- what caused the bugs
- lessons learned
- how to avoid similar issues in future
- summary of third-party opinion if the user asks for such evaluation, plus whether the conclusion is agreed with or not

### Development notes requirements
`development-notes.md` should include:
- comprehensive fresh-start memory notes
- request understanding
- deliverables
- implementation approach
- branch/stage position in the overall development plan
- files included and their purpose
- assistant-side smoke/preflight results
- expected user-side validation steps

### Delivery discipline
- version comments/headers across code and docs must stay aligned
- if latest known-good files are not available, ask the user to upload them rather than reconstructing from memory
- test worksheets should be combined into one file
- provided documentation should include pass/fail results where applicable

### Design principles
- always prioritize user benefit
- do not overengineer
- simple, fast, reliable solutions are preferred over extra complexity
- if something is unclear, ask

---

## Important continuity history

### Earlier branch progression
- **v7.1.x** completed earlier dashboard feature/cosmetic work and documentation updates
- **v7.2.x** focused on stabilization and planned transition to the import-enabled branch
- **v7.3.x** became the branch for dashboard regression resistance and preparation for Import work

### v7.3 direction that was already established
The user defined v7.3 goals to include:
- re-architect dashboard to reduce regressions and make it more modular
- import data to flash with validation/sanity checking
- add a custom date-range selection feature
- validate new dashboard builds across major desktop and mobile browsers

### Pre-Phase-1 architectural conclusion
The earlier expert/opinion review established this direction:
- v7.3.3 was a good stabilization baseline
- but it was still too close to a wrapped monolith
- before Import, the dashboard needed tighter event/state discipline
- Phase 1 should therefore focus on:
  - shared state chokepoints
  - centralized event binding
  - lower regression risk

### 7.3.4.x hotfix continuity
- **v7.3.4** introduced the structural work
- **v7.3.4.1** restored startup after a `SENSORS`/initialization ordering regression
- latest hotfix cycle then focused on export behavior, chart recolor completeness, 15-minute marker sizing, and theme redraw correctness

---

## Current technical direction

### What should remain stable unless a strong reason appears
- backend/history storage behavior
- partition/storage model unless directly required by a feature
- gateway management/auth semantics
- general transport approach already stabilized in prior branches

### What is still the more fragile area
- dashboard event wiring
- chart update/redraw behavior
- cross-theme rendering consistency
- browser-side shared state around history/chart data
- any feature that increases request pressure on the ESP backend

### Practical lesson from recent bugs
Most recent dashboard regressions were not deep backend failures. They came from:
- startup ordering
- UI redraw timing
- incomplete dataset property updates
- request concurrency pressure

That means future changes should always check:
1. startup ordering
2. event binding completeness
3. chart full-state redraw behavior
4. all dataset visual properties, not just line-level ones
5. concurrency/fan-out pressure on the ESP side

---

## Recommended next implementation step

### Next feature gate
Proceed to **Import v1** only after the current hotfix build is functionally validated by the user.

### Recommended shape of Import v1
Keep it intentionally narrow:
- replacement-first import
- validation and sanity report before write
- auth-protected destructive path
- clear user feedback on imported rows, rejected rows, and reasons

### Validation concepts that should be part of Import v1
At minimum, validate:
- sensor identity / supported sensor list
- timestamp format and ordering
- temperature/humidity numeric parsing
- duplicate or overlapping rows
- future timestamps / impossible timestamps
- missing values / malformed rows
- row count and storage impact sanity

### Why this should be the next step
This directly helps the user because imported history is a functional feature with immediate utility, and the branch has already spent time reducing dashboard fragility so that Import is less likely to land on unstable UI foundations.

---

## Browser and theme validation expectations for future dashboard changes

For future iterations, explicitly check:
- Chrome desktop
- Edge desktop
- Firefox desktop
- at least one common mobile browser
- light theme
- dark theme
- theme switch without hard refresh

Special attention areas:
- chart legends and telemetry visibility
- axis/label contrast
- point markers after recolor/theme change
- card text/readability after live theme toggle

---

## Recommended assistant-side preflight focus for future changes

Before packaging future builds, the assistant should verify as much as possible of the following:
- HTML/JS/header sync
- version-family file alignment
- startup ordering guards
- no accidental inline handler regressions
- chart redraw/update path after theme change
- dataset recolor updates line + point properties
- request concurrency remains reasonable for export/history actions
- header regenerated from latest HTML
- syntax checks pass
- lightweight runtime smoke evaluation passes

---

## Expected user-side validation scenarios

When a future build is delivered, the user should be able to test these as applicable:

### Core access paths
- local downloaded dashboard file
- LAN-served dashboard from ESP
- internet-served dashboard path if used

### Core smoke tests
- startup leaves `connecting...`
- sensor cards render
- real-time values populate
- history loads
- theme toggle works without manual `Ctrl+F5`
- range buttons work
- export buttons work
- management/auth-required actions still behave correctly

### Browser/theme checks
- Chrome / Edge / Firefox desktop
- one mobile browser
- light/dark theme consistency

---

## Recommended development workflow improvement

The suggested improved workflow is:
- make GitHub the canonical project source
- tag accepted known-good versions
- build the ESPHome container directly from Git checkout
- use chat ZIPs only as temporary handoff artifacts when needed

A separate file named `development-pipeline.md` contains the detailed recommended workflow, repo structure, release approach, and LXC commands.

---

## Best way to continue from a fresh session

At the start of the next session, provide:
- current GitHub repo URL if available
- latest known-good tag/version
- whether the latest hotfix build passed only compile or also full device/browser validation
- next requested scope (likely Import v1 unless priorities changed)
- any new logs, screenshots, or edge-case observations

Suggested opening prompt template:

> This is a continuation of the ESP32 gateway project.  
> Baseline version: `v7.3.4.2` (or latest known-good actual tag).  
> Compile status: successful.  
> Runtime validation status: [fill in].  
> Please use the attached fresh-start handoff and development pipeline documents as baseline.  
> Next task: [describe next implementation/fix].

---

## Minimal fresh-session checklist

Before starting new work, confirm:
- latest known-good files are available
- requested version target is clear
- intended scope is narrow and testable
- documentation/update obligations are understood
- user-side validation scenarios are defined

---

## Closing continuity note

The project is now at a reasonable point to move away from repeated ad hoc file-transfer cycles and toward a cleaner GitHub-centered workflow.

Technically, the project’s most important short-term priority remains the same:
- keep dashboard changes stable and low-risk
- move into **Import v1** in a controlled way
- continue browser/theme validation discipline
- maintain strong handoff documentation so fresh sessions do not lose context
