# ESP32 Gateway Master Fresh-Start Handoff

_Last updated: 2026-03-08_

## Purpose

This document is the single-source continuity brief for restarting the ESP32 BLE gateway project in a fresh conversation without reconstructing context from memory or from multiple scattered notes.

It consolidates and supersedes the earlier handoff/pipeline notes from this phase of work, including:
- project summary and goals
- current repository/canonical-source model
- what was completed in the latest normalization + CI session
- current repo/workflow operating model
- documentation and delivery expectations
- next steps in the correct order
- operational instructions for local Git/GitHub/ESPHome workflow
- known lessons learned and risk areas

---

## Project summary

This project is an **ESP32-C3 multi-sensor BLE gateway** that receives ThermoPro TP357 BLE broadcasts, exposes a browser-based dashboard, and provides:
- live temperature/humidity monitoring
- history retention and review
- exports
- gateway management actions
- LAN/local/internet-accessed dashboard usage where applicable

The recent work has focused on making the dashboard and repository safer to maintain before adding the next functional feature set.

---

## Current strategic direction

### Already established direction
The project moved through stabilization and dashboard refactoring stages and is now in a position where the repository is being treated as the canonical source of truth rather than chat-delivered ZIP bundles.

### Immediate goal now
The immediate goal is **not** a new product feature first.

The immediate goal is:
1. finish streamlining the development workflow around GitHub and CI,
2. make the repo/workflow reliable from a fresh clone,
3. then resume product feature work.

### Next major feature after workflow hardening
The next scoped product feature should remain:
- **Import v1**

That feature should be kept narrow and low risk.

---

## High-level project goals

### Completed / in-progress goals
- stabilize dashboard startup and connection behavior
- reduce dashboard regression risk through structural cleanup
- keep the dashboard usable in local-file mode, LAN mode, and internet-facing mode where applicable
- reduce fragility around state/event binding and chart redraw behavior
- make GitHub the canonical project source
- normalize repo layout so fresh clones are buildable
- establish first cloud CI workflow for preflight + compile

### Planned goals still ahead
1. **Import v1**
   - replacement-first import model
   - strong validation/sanity checking before write
   - clear acceptance/rejection reporting
   - auth-protected destructive path

2. **Custom date range**
   - `Custom Range` button after predefined history-range buttons
   - range based on dates actually available in persisted history

3. **Browser and theme validation automation**
   - desktop browser coverage
   - mobile browser coverage
   - light/dark theme consistency checks
   - chart redraw/theme-switch regression coverage

4. **Optional later hardware-in-loop automation**
   - OTA upload automation
   - live endpoint checks against the real ESP device
   - self-hosted LAN runner if justified

---

## Current known-good status

### Firmware/dashboard baseline context
- The last known successfully compiled and deployed functional baseline before this workflow-hardening work was **v7.3.4.2**.
- The repo content was then normalized so canonical filenames/paths match the GitHub-first operating model.
- Local preflight passed after normalization.
- Local `esphome compile firmware/esp32-c3-multi-sensor.yaml` succeeded after the secrets-path issue was corrected.
- The normalized changes were committed and pushed.
- The first GitHub Actions workflow was added and reached a green run state.
- The workflow then required one refinement so firmware binaries are staged into a non-hidden artifact directory rather than relying on hidden `.esphome` paths.
- The corrected workflow file was merged and pushed after resolving a local-vs-remote Git conflict.

### What this means now
The repository should now be treated as **functionally normalized** and ready for continued workflow automation work.

---

## What was completed in the latest session

### 1. Repository normalization completed
The repo was normalized around canonical paths and filenames so that scripts, firmware config, headers, and partition definitions all refer to the same structure.

#### Canonical structure now expected
```text
ESP32-GW-multi-sensor/
  .github/workflows/
  dashboard/
    dashboard.html
    dashboard.js
    dashboard.h
    sensor_history_multi.h
  firmware/
    esp32-c3-multi-sensor.yaml
  partitions/
    esp32-c3-multi-partitions.csv
  scripts/
    deploy-to-esphome.sh
    generate-header.sh
    preflight.sh
    normalize-repo-content.sh   # optional helper, if intentionally kept
  Docs/
    build-history.md
    development-pipeline.md
    esp32-gateway-fresh-start-handoff.md
    ...versioned docs...
  secrets/
    secrets-example.yaml
    secrets.yaml                # local only, ignored
  VERSION
  .gitignore
```

### 2. Script/YAML path coupling to old versioned filenames was removed
The following areas were normalized:
- firmware YAML references
- preflight checks
- header-generation script targets
- deploy script canonical target
- partition filename references

### 3. Secrets-path issue was diagnosed and solved
A key lesson from normalization:
- comments in the YAML such as `# - ../secrets.yaml` are documentation only
- ESPHome `!secret` resolution expects a usable `secrets.yaml` where ESPHome can resolve it for the active config file

Current practical local model:
- `secrets/secrets.yaml` remains the local canonical secrets file
- for local compile, `firmware/secrets.yaml` must exist as either:
  - a copy of `secrets/secrets.yaml`, or
  - a symlink to `../secrets/secrets.yaml`

Recommended local approach on Linux/LXC:
```bash
ln -s ../secrets/secrets.yaml firmware/secrets.yaml
```

### 4. Local preflight and local compile were validated
Normalization was confirmed by:
- `./scripts/preflight.sh`
- `esphome compile firmware/esp32-c3-multi-sensor.yaml`

### 5. Logging model was clarified
The project now distinguishes between:
- curated human-facing docs in `Docs/`
- raw local build logs in `build-logs/` (gitignored)
- workflow artifacts in GitHub Actions

### 6. GitHub Actions Phase 1 was added
A first CI workflow was introduced to perform:
- checkout
- Node setup
- Python setup
- ESPHome install
- temporary compile-only secrets file generation
- preflight
- firmware compile
- job summary writing
- artifact upload

### 7. Git conflict handling was exercised and resolved
A real rebase conflict occurred in `.github/workflows/ci.yml`, and the clean operating rule was established:
- local repo is the working/tested source of changes
- when conflict occurs in workflow YAML, replace with the intended final version, stage it, continue the rebase, then push using `--force-with-lease` only if rebase requires it

---

## Important recent bug-fix continuity from the product side

The latest hotfix line before workflow hardening had addressed these dashboard issues:
1. `Export All` failing with `HTTP 502`
2. sensor color changes updating chart lines but not chart point markers
3. 15-minute chart markers larger than desired
4. theme-switch redraw behavior requiring hard refresh in some cases

### Root-cause summary
- merged export path was too bursty / overly concurrent
- recolor logic updated only part of dataset visual state
- 15-minute chart point-radius settings were inconsistent with real-time charts
- theme switch updated UI state but did not fully force chart redraw/update paths

### Fix intent
- serialize merged export requests
- update all marker-related chart properties during recolor
- reduce 15-minute marker sizing
- force redraw/update on theme switch

This continuity matters because future browser automation should explicitly cover these regression surfaces.

---

## Current repo operating model

## Canonical source of truth
GitHub repo is now the canonical project source.

### Meaning of that rule
- new work should start from the repo, not from ad hoc ZIP bundles
- local working changes should be tested, committed, and pushed
- CI should validate the repo state, not a side copy
- fresh sessions should rely on repo + docs in `Docs/`

### What ZIP bundles are now for
ZIP bundles are still acceptable as transport for build delivery if needed, but they are no longer the primary continuity mechanism.

---

## Current local workflow

### Recommended local flow for development
1. sync repo
2. edit locally
3. run preflight
4. run local compile if needed
5. commit and push
6. run/inspect CI
7. perform user-side device validation where needed

### Recommended commands
```bash
cd /root/config/ESP32-GW-multi-sensor

git fetch --all --tags
# if needed: git pull --rebase origin main

./scripts/preflight.sh
esphome compile firmware/esp32-c3-multi-sensor.yaml
```

### If the local branch diverges from remote
Preferred reconciliation model:
```bash
git pull --rebase origin main
```

If rebase is blocked by unstaged local changes:
- restore/discard unwanted changes, or
- commit/stash first, then rebase

If `.github/workflows/ci.yml` conflicts during rebase:
- replace the file with the intended final YAML
- `git add .github/workflows/ci.yml`
- `git rebase --continue`
- push when rebase completes

---

## Current GitHub Actions operating model

### Phase 1 CI scope
Current Phase 1 CI should remain intentionally narrow:
- repo checkout
- install Node.js
- install Python + ESPHome
- create temporary compile-only `firmware/secrets.yaml`
- run `./scripts/preflight.sh`
- run `esphome compile firmware/esp32-c3-multi-sensor.yaml`
- write concise build summary
- upload logs and firmware artifacts

### Why temporary CI secrets are used
The workflow only needs values sufficient for compile-time `!secret` resolution.
It does **not** need real Wi-Fi or management credentials for compile-only CI.

### Important artifact lesson
GitHub artifact upload excluded hidden `.esphome` paths by default, so firmware binaries must be copied into a visible staging directory such as:
- `artifacts/firmware/`

That staging step should remain part of the workflow.

### What to verify on each CI run
- no summary-shell quoting errors
- summary renders cleanly
- preflight passes
- compile passes
- artifact ZIP contains:
  - `build-logs/`
  - `artifacts/firmware/`
- staged firmware files include expected binaries when produced

---

## Documentation and delivery rules locked in by the user

These remain active unless explicitly changed.

### Per-build delivery expectations
- every build should have aligned versioning across code and docs
- build documentation should include what changed, why, lessons learned, and test expectations
- user wants strong fresh-start continuity notes preserved in docs
- combined test worksheet model should be used rather than scattered worksheets

### Required documentation categories
For accepted builds, maintain/update:
- versioned documentation file
- versioned development notes file
- consolidated test worksheet
- build history ledger entry for milestone/accepted builds

### `Docs/build-history.md`
This should remain a curated ledger for accepted/milestone builds rather than a dump of every raw log.

### Raw build logs
Keep raw logs in:
- `build-logs/` locally
- workflow artifacts in GitHub Actions

Do **not** turn `Docs/` into a raw log archive.

---

## Current `.gitignore` expectations

The repo should keep secrets and local build output out of version control.

Current intended ignore model includes at least:
```gitignore
firmware/secrets.yaml
secrets/*.yaml
!secrets/secrets-example.yaml
.build/
.pio/
build-logs/
artifacts/
firmware/.esphome/
```

This supports:
- local-only secrets
- local raw logs
- local staged artifacts
- local ESPHome build directories

---

## Important project principles

### Design principles
- prioritize user benefit
- avoid overengineering
- prefer simple, reliable, low-risk changes
- preserve working backend/storage behavior unless there is a strong reason to change it
- treat dashboard event wiring, redraw behavior, and request pressure as fragile areas

### Practical regression checklist mindset
Future dashboard changes should always consider:
1. startup ordering
2. event binding completeness
3. full chart redraw/update behavior
4. all dataset visual properties, not only line color
5. concurrency pressure on backend/export/history fetch paths

---

## Recommended next steps in the correct order

## Phase A — verify the repaired CI workflow end-to-end
This is the first next step.

### Goal
Confirm that the current workflow is not only green, but also producing the intended summary and artifact contents.

### Verify
1. summary step renders without shell/backtick errors
2. artifact ZIP contains:
   - `build-logs/`
   - `artifacts/firmware/`
3. firmware binaries are present in artifact staging

### Why this is first
There is no benefit in piling more automation on top of a workflow whose outputs have not been fully verified.

---

## Phase B — broaden CI triggers
After Phase A is confirmed, ensure CI triggers cover:
- `workflow_dispatch`
- `push` to `main`
- `pull_request` targeting `main`

### Purpose
- automatic validation of pushed changes
- automatic validation of future feature branches/PRs
- keep manual run capability

---

## Phase C — add local helper scripts for repeatable logging
Add a standard helper such as:
- `scripts/compile-with-log.sh`

### Purpose
- standardize local compile logging with `tee`
- make local behavior parallel the CI workflow
- reduce repeated manual command entry

Recommended pattern:
```bash
mkdir -p build-logs
STAMP="$(date +%F-%H%M%S)"
esphome compile firmware/esp32-c3-multi-sensor.yaml 2>&1 | tee "build-logs/compile-${STAMP}.log"
```

---

## Phase D — add Playwright browser automation
This should be the next major automation layer after basic CI is stable.

### Scope for initial Playwright workflow
Use a mocked backend or harness, not the real ESP device.

### First regression targets to automate
- dashboard loads
- basic sensor UI renders
- theme toggle redraw path works
- export button wiring is exercised
- color recolor path updates chart markers
- key controls are bound and clickable

### Why mocked backend first
- faster
- repeatable
- cloud-runner friendly
- avoids coupling browser regressions to live-device availability

---

## Phase E — artifact/report refinement
After CI and browser tests are stable, refine outputs so each successful cloud run reliably preserves:
- compile logs
- firmware binaries
- browser-test report artifacts
- screenshots/traces on browser-test failure
- concise run summary

---

## Phase F — optional self-hosted LAN runner
Only after cloud CI is stable should the project consider a self-hosted runner on the home/LAN side.

### Purpose
- OTA upload to real ESP
- live endpoint checks
- hardware-in-loop smoke tests
- browser tests against the actual gateway

### Why this is later
Cloud CI should first prove that repo integrity, compile repeatability, and browser behavior can be validated without involving the real device.

---

## Recommended next product feature after workflow hardening

### Import v1
Once the CI/browser-automation foundation is in place, the next product feature should still be **Import v1**.

### Recommended shape of Import v1
- replacement-first model
- strong validation before write
- import report showing accepted/rejected rows and reasons
- auth-protected destructive action path

### Validation concepts to include
At minimum:
- sensor identity / supported sensors
- timestamp parsing and ordering
- numeric parsing for temperature/humidity
- duplicate or overlapping rows
- impossible or future timestamps
- malformed/missing values
- storage impact sanity

### Why Import v1 next
It provides direct functional value and was already identified as the next narrow useful feature after dashboard fragility reduction.

---

## Current documentation structure recommendation

## Repo-level continuity docs
Keep/update in `Docs/`:
- `esp32-gateway-fresh-start-handoff.md`
- `development-pipeline.md`
- `build-history.md`
- versioned `documentation.md`
- versioned `development-notes.md`
- versioned consolidated test worksheet

## What this master handoff document should become
This file should serve as the new, comprehensive fresh-start entry point for the next session.

It can either:
- live as a new master continuity file in `Docs/`, or
- replace/absorb the earlier fragmented handoff notes if you want a single continuity artifact.

---

## Known lessons learned from this session

### Lesson 1 — file renames are not enough
Renaming files in the repo tree is not sufficient. Internal references in scripts and YAML must also be normalized.

### Lesson 2 — comments in YAML do not change ESPHome behavior
Human comments about required files do not affect `!secret` resolution or path handling.

### Lesson 3 — cloud CI and local compile have different secrets models
Local compile can use local secrets/symlink conventions.
Cloud compile should generate temporary compile-only secrets on the runner.

### Lesson 4 — hidden build directories can break artifact expectations
If build output stays under hidden paths such as `.esphome`, GitHub artifact uploads may skip it unless files are staged elsewhere.

### Lesson 5 — raw logs and curated docs should stay separate
Machine logs belong in `build-logs/` or workflow artifacts.
Human continuity belongs in `Docs/`.

### Lesson 6 — local CLI + Git remains the best default editing model
For this project, scripts/YAML/workflow files should generally be edited in the local clone, validated, then committed/pushed.
Use GitHub web editing only sparingly for tiny non-critical changes.

---

## What a fresh next session should do first

When resuming from a fresh start, the next session should follow this order:

1. confirm current repo state from GitHub
2. confirm current CI workflow YAML matches intended latest version
3. inspect the latest successful CI run summary and artifact contents
4. if artifact verification is complete, move to Playwright/browser automation design
5. only after workflow automation is stable, resume product feature work with Import v1

---

## Fresh-start checklist for the next conversation

### First questions/status checks
- What is the current branch/commit/tag?
- Did the latest CI run upload logs **and** firmware binaries correctly?
- Is `firmware/secrets.yaml` present locally as symlink or copy for LXC compile?
- Are there any uncommitted local changes before new work starts?

### First technical checks
```bash
cd /root/config/ESP32-GW-multi-sensor
git status
git fetch --all --tags
./scripts/preflight.sh
```

### If local compile is needed
```bash
esphome compile firmware/esp32-c3-multi-sensor.yaml
```

---

## Immediate recommendation from this handoff

The next step should be:

**Verify the repaired GitHub Actions workflow output end-to-end, then add Playwright-based dashboard automation as the next automation layer.**

Do **not** jump into a new feature before that verification is complete.

---

## Optional future consolidation recommendation

If desired, the earlier fragmented documents can now be folded into a simpler structure:
- one master handoff / continuity file
- one development pipeline / process file
- one curated build history file
- per-version docs for accepted builds

That would reduce duplication and make future fresh starts faster.

