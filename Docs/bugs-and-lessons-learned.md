# Bugs Fixed & Lessons Learned

_Last updated: 2026-03-16 — v7.5.2.2 (LESSON-OPS-049 added)_

This file tracks significant bugs, root causes, fixes, and operational lessons.
It is also the place where project guardrails are recorded so they are not re-learned in later sessions.

Both sections are in **reverse chronological order** — most recent entry first.

---

## Bug Fixes

### BUG-042: `dashboard/dashboard.h` version check fails due to minification (post-v7.5.2.0)

**Symptom:** PR #25 added `dashboard_h_version_matches` to `scripts/preflight.sh` and CI failed with `dashboard_h_version_matches: FAIL` even though `dashboard.js` and `dashboard.html` had the correct version string `App.version = 'v7.5.2.0'`.

**Root cause:** CI runs `minify-dashboard.sh` then `generate-header.sh` before `preflight.sh`. The minifier (terser) converts `App.version = 'v7.5.2.0'` to `App.version="v7.5.2.0"` (removes spaces, converts single quotes to double quotes). The original `dashboard_h_version_matches` check used `grep -Fq "App.version = '${VER_TAG}'"` (fixed-string with spaces and single quotes), which never matches the minified form in the regenerated `dashboard.h`. The committed `dashboard.h` had the unminified form but is discarded when CI regenerates it.

**Fix:** Changed `dashboard_h_version_matches` to use `grep -Eq` with a regex pattern `App\.version[[:space:]]*=[[:space:]]*['\"]${VER_TAG}['\"]` that matches both the unminified source form and the minified generated form. Added `check_contains_regex()` helper to `scripts/preflight.sh` for future regex-based checks.

**Lesson:** See LESSON-OPS-048.

---

### BUG-041: Fixture generator VERSION bumped independently from canonical VERSION file (v7.5.1.3)

**Symptom:** CI preflight failed with "Generated files are out of sync with config/sensors.json." The diff showed `manifest.json` containing `v7.5.1.3` while the Python generator (using VERSION from `render_sensor_config.py`) expected `v7.5.1.0`.

**Root cause:** PR #20 changed `tests/fixtures/generate-fixtures.js` VERSION from `v7.5.1.0` to `v7.5.1.3` and regenerated the fixture files with the new version string, but did not update the canonical VERSION sources (`VERSION` file, `render_sensor_config.py` VERSION constant). The Python generator (`render_sensor_config.py --check`) regenerates expected fixtures from the canonical VERSION and compares against on-disk fixtures — since JS fixtures said `v7.5.1.3` but Python expected `v7.5.1.0`, the check failed.

**Fix:** Bumped all version references atomically to `7.5.1.3`: `VERSION` file, `render_sensor_config.py` VERSION constant, `generate-fixtures.js` VERSION constant, `dashboard.js` App.version, `dashboard.html` App.version, `sensor_history_multi.h` header comment, YAML header comment, and `register_history_handler()` string. Regenerated all artifacts via `python3 scripts/render_sensor_config.py --write` and `bash scripts/generate-header.sh`. Added a preflight check (`fixture_generator_version_sync`) to catch future drift.

**Lesson:** See LESSON-OPS-047.

---

### BUG-040: No automated validation of manifest v2 schema (v7.5.1.1)

**Symptom:** Generator could produce malformed JSON or missing required fields without detection until runtime or manual inspection.

**Root cause:** Preflight only validated that `src/gateway_manifest.h` existed, was included, and that the generator sync check passed. It did not verify the content of the generated manifest against the v2 schema contract.

**Fix:** Added preflight checks that validate `gateway_manifest.h` contains all required v2 schema fields: top-level fields, `gateway` block fields, `history` block fields, `metrics` array fields, and that `schema_version` is exactly `2`.

**Lesson:** See LESSON-OPS-046.

---

### BUG-039: Dashboard source and generated artifacts drifted after Phase 1 work (v7.5.0.1)

**Symptom:** `dashboard.html` was updated during Phase 1 manifest work but `dashboard.min.html` and `dashboard.h` were not regenerated. The embedded firmware payload still ran stale client logic — manifest-first boot and `/api/status` hydration were absent from what actually flashed.

**Root cause:** The workflow assumed edits to `dashboard.html` would propagate automatically. They do not — the minification and header-embedding steps must be run explicitly after every source edit.

**Fix:** Patched `dashboard/dashboard.html` directly as the source of truth, then regenerated `dashboard.min.html` and `dashboard.h` from that corrected source. Kept `dashboard.js` aligned to the same runtime logic.

**Lesson:** See LESSON-OPS-043.

---

### BUG-038: Dashboard Free Heap and Uptime showed "loading…" after Phase 1 OTA (v7.5.0.1)

**Symptom:** After flashing Phase 1 firmware, `/api/manifest` and `/api/status` both responded correctly, but the dashboard displayed `loading...` indefinitely for Free Heap and Uptime.

**Root cause:** The dashboard still expected `/sensor/Free Heap` and `/sensor/Uptime` — legacy entity-polling paths that the firmware no longer provided as ESPHome entities. The authoritative data was already available from `GET /api/status` but the dashboard code was not reading from it.

**Fix:** Switched all dashboard device-status widget hydration to `GET /api/status`. Removed dependency on legacy entity-polling paths for those values.

**Lesson:** See LESSON-OPS-042.

---

### BUG-037: Built-in ESPHome diagnostics disappeared from the built-in web page after Phase 1 (v7.5.0.1)

**Symptom:** The ESPHome built-in web page no longer showed Free Heap, Uptime, or Loop Time after Phase 1 firmware changes.

**Root cause:** The `debug.free`, `debug.loop_time`, and `uptime` sensor blocks were removed or were missing from `firmware/esp32-c3-multi-sensor.yaml` during Phase 1 YAML changes.

**Fix:** Restored `debug.free`, `debug.loop_time`, and `uptime: type: seconds` blocks in the YAML. Confirmed both the custom dashboard and the built-in ESPHome page show all three diagnostics after reflash.

**Lesson:** See LESSON-OPS-044.

---

### BUG-036: YAML generator reintroduced broken indentation after hotfix — preflight passed but compile failed (v7.5.0.1)

**Symptom:** After the initial YAML indentation fix, running `python3 scripts/render_sensor_config.py --write` again silently reintroduced bad indentation into the YAML. `bash ./scripts/preflight.sh` passed. `esphome compile` failed near the averaging block with `expected <block end>`.

**Root cause:** The hotfix had corrected one call site but `render_yaml_file()` still routed some YAML marker regions through `replace_marker_block()` instead of `apply_yaml_marker_block()`. Those paths produced correct YAML body content but inserted it without preserving the indentation level from the marker location.

**Fix:** Switched all YAML marker replacements in `render_sensor_config.py` to `apply_yaml_marker_block()`. Confirmed idempotence by running `--write` twice.

**Lesson:** See LESSON-OPS-041.

---

### BUG-035: YAML generator produced invalid indentation in ESPHome block scalars (v7.5.0.0)

**Symptom:** `esphome compile firmware/esp32-c3-multi-sensor.yaml` failed immediately after `render_sensor_config.py --write` with `expected <block end>, but found '<scalar>'` near line 135.

**Root cause:** The YAML generation path reinserted block content without preserving the indentation level of the marker location. The content was semantically correct but structurally invalid YAML inside lambda block scalar sections, `web_server.sorting_groups`, `sensor`, and `text_sensor` blocks.

**Fix:** Routed all YAML marker replacements through `apply_yaml_marker_block()`, which captures the indentation column of the marker line and re-applies it to every inserted line.

**Lesson:** See LESSON-OPS-040.

---

### BUG-034: `render_sensor_config.py` crashed with `re.PatternError: bad escape \x` on generated content (v7.5.0.0)

**Symptom:** Running `python3 scripts/render_sensor_config.py --write` raised `re.PatternError: bad escape \x at position N` during the replacement phase for generated strings containing Unicode escape sequences like `\xC2\xB0` (the degree symbol).

**Root cause:** Generated replacement text was passed directly to `re.sub()` in string replacement mode. Python's `re.sub` interprets backslash sequences in the replacement string as regex back-references or escapes. `\xC2\xB0` was not a valid regex escape, causing the error.

**Fix:** Changed all `re.sub()` calls for generated content to use lambda/function replacements. In lambda mode, the replacement value is treated as a literal string, so backslash sequences in generated output are not interpreted.

**Lesson:** See LESSON-OPS-039.

---

### BUG-033: Phase 1 patch script failed against compacted one-line source blocks (v7.5.0.0)

**Symptom:** `scripts/apply_phase1_manifest_patch.py` failed repeatedly when targeting `dashboard/sensor_history_multi.h`. Exact-string matches could not find their targets, even when the content appeared visually correct.

**Root cause:** The header file uses compacted one-line formatting for several function bodies and handler blocks. Patch scripts that matched on long multi-line strings or comment text failed when those strings had been compacted into a single line.

**Fix:** Rewrote the patch approach to use function-anchor detection, regex-based matching, and brace-aware block insertion rather than exact long-string matching. Going forward, this is a known constraint of the codebase.

**Lesson:** See LESSON-OPS-039.

---

### BUG-032: Multi-sensor CLI restore could erase retained history without an explicit confirmation prompt (v7.4.5.1)

The first v7.4.5.0 CLI backup/restore helper correctly routed merged CSVs through the existing erase-first `/api/import/begin` path, but it did so without an explicit operator confirmation.

**Fix:** `scripts/history_backup.py import` now prompts before erase-first multi-sensor import unless `--yes` is provided, and it also supports `--single-sensor <id>` to intentionally force the merge route from a merged CSV.

---

### BUG-031: `change_sensor_number.py` rollback messaging was too optimistic for structural renderer failures (v7.4.5.1)

The initial rollback path restored `config/sensors.json` and attempted a best-effort re-render, but it could still leave the operator uncertain if recovery was incomplete.

**Fix:** rollback now preserves the backup file on failure, prints manual recovery commands, and surfaces restore/re-render errors explicitly instead of assuming a clean rollback.

---

### BUG-030: Manifest validation normalized MACs by mutating caller data in place (v7.4.5.1)

The original validation helper silently normalized MAC addresses inside the caller-provided list.

**Fix:** manifest validation is now side-effect free. Canonicalization is explicit through `canonicalize_sensors()`, and save/load/render flows use normalized copies rather than mutating input objects.

---

### BUG-029: Session-level import design details were not propagated into the durable docs (v7.4.5.0)

**Symptom:** The repo behavior for single-sensor merge import existed in firmware and dashboard logic, but the high-value explanation — epoch-to-slot mapping, overlay of one sensor into an existing segment, reuse of the same slot when possible, and ~7 KB temporary overhead — was not consistently carried into changelog and handoff documentation.

**Root cause:** Documentation captured the user-visible feature but not enough of the internal design rationale.

**Fix:** Expanded changelog, `Docs/configuring-sensors.md`, and the per-session handoff to explicitly describe the merge-first single-sensor import model and how it differs from full multi-sensor replacement.

**Lesson:** See LESSON-OPS-036.

---

### BUG-028: Sensor-count changes depended on four-file manual edits, creating configuration drift risk (v7.4.5.0)

**Symptom:** Changing sensor count or replacing a sensor required hand-editing `sensor_history_multi.h`, the firmware YAML, `dashboard.js`, and `tests/fixtures/sensors.json`. It was easy to update three files and miss the fourth, which produced confusing preflight failures or worse — a compile-valid repo whose dashboard fallback / test fixtures no longer matched the active firmware configuration.

**Root cause:** The repo had no canonical source of truth for configured sensors. The same facts (sensor id, display name, MAC, count) were duplicated in multiple files.

**Fix:** Introduced a canonical manifest (`config/sensors.json`) plus a generator (`scripts/render_sensor_config.py`) and an interactive manager (`scripts/change_sensor_number.py`). The renderer now drives generated sections in the header, firmware YAML, dashboard fallback metadata, and baseline fixture manifest.

**Guardrail:** `scripts/preflight.sh` now runs `python3 scripts/render_sensor_config.py --check` so generated-file drift is caught before compile.

**Lesson:** See LESSON-OPS-037.

---

### BUG-027: Chromium missing shared libraries in ESPHome container — libnspr4.so not found (v7.4.4.0)

**Symptom:** All Playwright tests fail with `error while loading shared libraries: libnspr4.so: cannot open shared object file`. The binary exists and `--no-sandbox` is in the launch args, but the process crashes at the dynamic linker stage.

**Root cause:** `npx playwright install chromium` downloads the Chromium binary but does NOT install the required OS-level shared libraries. The ESPHome Docker container does not include them by default.

**Fix:** Use `npx playwright install --with-deps chromium`. This installs both the binary and all required system packages via `apt`.

**Lesson:** See LESSON-OPS-034.

---

### BUG-026: Chromium crashes silently in ESPHome/Docker containers — sandbox kernel feature missing (v7.4.4.0)

**Symptom:** All Playwright tests fail immediately with `browserType.launch: Target page, context or browser has been closed` — even after a successful install. The browser binary exists but the process crashes on startup.

**Root cause:** Chromium's default sandbox uses Linux user namespaces, which are disabled in many container environments including the ESPHome Docker container.

**Fix:** Add `launchOptions: { args: ['--no-sandbox', '--disable-setuid-sandbox'] }` to the `use` block in `playwright.config.js`.

**Lesson:** See LESSON-OPS-033.

---

### BUG-025: Fixture generate-fixtures.js used milliseconds for CSV timestamps (v7.4.4.0)

**Symptom:** Sensor-count variant fixtures would render completely empty charts. No error — just no data points.

**Root cause:** `Date.UTC()` returns epoch milliseconds. The dashboard's chart renderer calls `new Date(epoch * 1000)` — interpreting the value as seconds. A millisecond timestamp gets multiplied by 1000, producing dates in year ~58000, which fall outside any time range filter and are silently dropped.

**Fix:** Use epoch seconds throughout `generate-fixtures.js`. Anchor to `ANCHOR_EPOCH_SEC = 1741694400`.

**Lesson:** See LESSON-OPS-029.

---

### BUG-024: Second round of browser test failures — DOM behavior mismatches (v7.4.3.0 CI)

**Symptom:** 4 of 28 tests failed on second CI run after element ID fixes.

**Root causes — three distinct issues:**
1. Canvas selector wrong container — chart canvases live inside `.chart-card` divs, not `.sensor-card`
2. Theme class applied to `document.documentElement` (`<html>`), not `document.body`
3. `_onPreset()` calls `_applyAndClose()` directly — clicking Apply after a preset attempts to click an already-dismissed modal

**Fixes:** Assert named chart IDs with `toBeAttached()`; change theme assertions to `page.locator('html')`; remove the Apply click after preset.

**Lesson:** See LESSON-OPS-028.

---

### BUG-023: Output bundle file naming caused confusion about destination paths (v7.4.3.0)

**Fix:** Files renamed and placed in correct locations after clarification.

**Lesson:** See LESSON-OPS-025.

---

### BUG-022: `package-lock.json` not committed — CI failed on `npm ci` (v7.4.3.0)

**Symptom:** Browser CI job failed immediately: `Dependencies lock file is not found`.

**Fix:** `npm install` on device, then `git add package-lock.json && git commit`.

**Lesson:** See LESSON-OPS-024.

---

### BUG-021: `browser-tests.yml` committed to wrong branch — workflow never appeared in CI (v7.4.3.0)

**Symptom:** GitHub Actions showed no "Browser Tests" workflow.

**Root cause:** Workflow file was committed on the wrong feature branch. GitHub only registers workflow files from the default branch.

**Fix:** `git log --oneline --all -- .github/workflows/browser-tests.yml` identified the commit. `git checkout <sha> -- .github/workflows/browser-tests.yml` recovered and committed it to the correct branch.

**Lesson:** See LESSON-OPS-023.

---

### BUG-020: Browser test suite used wrong element IDs throughout — 14 of 28 tests failed (v7.4.3.0)

**Root cause:** Tests were written against assumed element IDs without verifying the actual dashboard HTML. Six distinct mismatches:

| Used in test | Actual ID in HTML |
|---|---|
| `#themeToggle` | `#themeBtn` |
| `#crApply` | `#customRangeApply` |
| `#crCancel` | `#customRangeCancel` |
| `.card-title` | `.sensor-card-header` |
| `data-history-range="7d"` | `data-history-range="168"` |
| `button[hasText=Export]` count | `[data-export-all]` + `[data-export-sensor]` attributes |

**Fix:** Audited all element IDs against the actual HTML before writing tests.

**Lesson:** See LESSON-OPS-022.

---

### BUG-019: "Data available: unknown" in custom range dialog on freshly-flashed device (v7.4.2.0)

**Fix:** Three-state availability display: both bounds non-zero → range shown; only newest non-zero → "up to [newest]"; both zero → "No persisted history yet."

---

### BUG-018: Duplicate `<script>` tag caused `Unexpected token '<'` dashboard failure (v7.4.2.0)

**Fix:** `sed -i '859d' dashboard/dashboard.html`. Prevention: use `head -n $((SCRIPT_LINE - 1))`, not `head -n $SCRIPT_LINE`. Verify with `grep -c '^<script>$' dashboard/dashboard.html` — must return `1`.

---

### BUG-017: `MAX_HISTORY_RANGE_HOURS` was 720, silently truncating 45d history display (v7.4.2.0)

**Fix:** `MAX_HISTORY_RANGE_HOURS = 1080`.

---

### BUG-016: `html-minifier-terser` CLI flags wrong (v7.4.1.0)

**Fix:** Use positional input plus `--output`.

---

### BUG-015: Single-sensor import "Unknown sensor ID" — off-by-one in URL path parsing (v7.4.0.2)

**Fix:** Corrected prefix length comparison and pointer offset. Prefer `sizeof("literal") - 1` over hand-counted lengths.

---

### BUG-014: Single-sensor import erased all flash data (v7.4.0.2)

**Fix:** Added `POST /api/import/begin/single/<id>` and merge-first behavior.

---

### BUG-013: Import over Cloudflare returned HTTP 502 (v7.4.0.1)

**Fix:** Suspend non-essential background activity during import and add pacing/backoff.

---

### BUG-012: Single-sensor export schema mismatch (v7.4.0.1)

**Fix:** Standardized on prefixed column headers for all export formats.

---

### BUG-011: Non-JSON server response crashed import error handling (v7.4.0)

**Fix:** Added safer text-first JSON response handling.

---

### BUG-010: `time()` ambiguous in ESPHome context (v7.4.0)

**Fix:** Use `::time(nullptr)`.

---

### BUG-009: Import POST body never delivered (v7.4.0)

**Fix:** Moved import payload transport into the URL path. **URL path is the reliable data channel** on this stack.

---

### Earlier important fixes

- **BUG-008:** Switched dashboard serving away from `beginResponseStream()` panic path
- **BUG-007:** Abandoned LittleFS-hosted dashboard in favor of embedded payload
- **BUG-006:** Fixed dashboard startup / event-binding ordering issue
- **BUG-005:** Theme switch now forces chart redraw
- **BUG-004:** 15-minute markers normalized to the intended visual size
- **BUG-003:** Chart markers now follow recolor changes
- **BUG-002:** Export All serialized to avoid socket-pool overload
- **BUG-001:** `/api/status` JSON truncation fixed by splitting output formatting

---

## Operational Lessons

### LESSON-OPS-049: `dashboard.html` must be manually updated after every version bump and every code change — `bump-version.sh` does not sync it (v7.5.2.1/v7.5.2.2)

`dashboard/dashboard.html` embeds all dashboard JavaScript inline (no `<script src>`). It is
the source of truth that `generate-header.sh` uses to produce `dashboard/dashboard.h` (the
embedded firmware payload). However, `bump-version.sh` and `render_sensor_config.py --write`
only update `dashboard/dashboard.js` — they do **not** touch `dashboard.html`.

**Gap:** `bump-version.sh` calls `generate-header.sh`, which auto-selects `dashboard.min.html`
if it exists. If `dashboard.min.html` is stale (not re-minified yet), `dashboard.h` is
regenerated from the stale min file and the version check in `preflight.sh` fails.

**Workaround (until bump-version.sh is extended):**
1. Run `bash scripts/bump-version.sh <new-version>` (will fail at preflight if dashboard.html is stale — that is expected).
2. Manually update `App.version` in `dashboard/dashboard.html` to the new version.
3. Apply the same code changes to `dashboard/dashboard.html` that were applied to `dashboard/dashboard.js`.
4. Run `bash scripts/generate-header.sh dashboard/dashboard.html dashboard/dashboard.h` (pass the html source explicitly to bypass the stale min.html).
5. Confirm `bash scripts/preflight.sh` passes.

**Future fix:** Extend `bump-version.sh` to `sed` the `App.version` string in `dashboard.html`
the same way `render_sensor_config.py --write` updates it in `dashboard.js`.

---

### LESSON-OPS-048: Use `bump-version.sh` for all version bumps — never update version sources partially (post-v7.5.2.0)

Version drift occurs when the developer updates some canonical sources but misses others, or forgets to regenerate dependent artifacts. The version surfaces in at least seven places in this repo (VERSION, render_sensor_config.py, generate-fixtures.js, dashboard.js, sensor_history_multi.h, firmware YAML, and the generated dashboard.h). Manually tracking all of them is error-prone.

**Rule:** Use `bash scripts/bump-version.sh <new-version>` for all version bumps. This script updates all three canonical sources atomically, runs `render_sensor_config.py --write` to regenerate all derived artifacts, runs `generate-header.sh` to regenerate `dashboard.h`, and then runs `preflight.sh` to verify sync. Do not manually edit individual version strings.

**Enforcement:** Preflight now includes `dashboard_h_version_matches` (detects missing `generate-header.sh`; uses regex to match both minified and non-minified forms) and `render_sensor_config_py_version_sync` (detects missing `render_sensor_config.py` VERSION update) in addition to the existing `fixture_generator_version_sync` and `render_sensor_config --check`.

**Version bump sources of truth (all updated by bump-version.sh):**
1. `VERSION` file (canonical root)
2. `scripts/render_sensor_config.py` VERSION constant
3. `tests/fixtures/generate-fixtures.js` VERSION constant

**Derived artifacts (all regenerated by bump-version.sh):**
- `dashboard/dashboard.js` (App.version — via render_sensor_config.py --write)
- `dashboard/sensor_history_multi.h` (header comment — via render_sensor_config.py --write)
- `firmware/esp32-c3-multi-sensor.yaml` (header + register_history_handler — via render_sensor_config.py --write)
- `src/gateway_manifest.h` (firmware_version — via render_sensor_config.py --write)
- `tests/fixtures/manifest.json` and `api-status.json` (version fields — via render_sensor_config.py --write)
- `dashboard/dashboard.h` (embedded App.version — via generate-header.sh)

Related: BUG-042

---

### LESSON-OPS-047: Version strings in test fixture generators must match the canonical VERSION file (v7.5.1.3)

The fixture generator (`tests/fixtures/generate-fixtures.js`) embeds a VERSION constant that is stamped into generated fixture JSON files. The Python generator (`render_sensor_config.py --check`) independently derives the expected version from the canonical `VERSION` file and its own VERSION constant. If these two sources drift, the `--check` comparison will fail even though the generated fixture files are otherwise valid.

**Rule:** All version references must be bumped atomically in a single commit: `VERSION` file, `render_sensor_config.py` VERSION constant, `generate-fixtures.js` VERSION constant, `dashboard.js` App.version, `dashboard.html` App.version, `sensor_history_multi.h` header comments, YAML header comment, and `register_history_handler()` string. Never bump the fixture generator VERSION independently.

**Enforcement:** Preflight checks `fixture_generator_version_sync` that the VERSION extracted from `generate-fixtures.js` matches the canonical `VERSION` file. If they differ, preflight fails immediately.

Related: BUG-041

---

### LESSON-OPS-046: Generated artifacts with structured schemas need compile-time validation (v7.5.1.1)

For any generated file with a required schema (JSON, YAML, etc.), preflight must validate structure, not just existence. A generator bug or incomplete update can produce syntactically valid but semantically broken output — for example, a JSON file that parses correctly but is missing required fields. Existence checks and generator sync checks (`--check`) do not catch this class of failure.

Add field-level validation for every generated artifact that has a documented schema contract. This catches regressions early and prevents malformed output from reaching `main`.

Related: BUG-040

---

### LESSON-OPS-045: Preflight must include a YAML/ESPHome parse gate, not just generated-file sync checks (v7.5.0.1)

The existing preflight catches version drift and generator sync failures. It does not catch structurally invalid YAML that passes the sync check because the generator produced syntactically invalid output. Add a step that runs `esphome config firmware/esp32-c3-multi-sensor.yaml` (or equivalent YAML parse) to block bad YAML from reaching the compile stage.

Without this gate, a generator bug can produce invalid YAML that passes preflight, passes `--check`, and only fails at `esphome compile`. The gap between "preflight green" and "compile fails" wastes time and creates false confidence.

**Implementation**: v7.5.1.2 — preflight runs `esphome config firmware/esp32-c3-multi-sensor.yaml`

---

### LESSON-OPS-044: Runtime validation must cover both the custom dashboard and the built-in ESPHome web page (v7.5.0.1)

Dashboard-only runtime checks can mask regressions in the built-in ESPHome diagnostics page. After any YAML change, verify:
1. The custom dashboard loads correctly and all status fields hydrate
2. The ESPHome built-in web page at `/` shows Free Heap, Uptime, and Loop Time

These are served from different code paths. One can regress without the other showing symptoms.

---

### LESSON-OPS-043: `dashboard.html` is the source of truth — regenerate artifacts after every edit (v7.5.0.1)

Edit order must always be:
1. Edit `dashboard/dashboard.html` (source of truth)
2. Run `bash ./scripts/minify-dashboard.sh` → produces `dashboard.min.html`
3. Run `bash ./scripts/generate-header.sh dashboard/dashboard.min.html dashboard/dashboard.h`

Editing `dashboard.js` alone is not sufficient. The script block inside `dashboard.html` must also be updated, and both the minified intermediate and the embedded header must be regenerated. A preflight rule should verify that `dashboard.h` reflects the current state of `dashboard.html`.

---

### LESSON-OPS-042: Dashboard device-status widgets should hydrate from `GET /api/status`, not entity polling (v7.5.0.1)

Do not rely on `/sensor/<entity-name>` paths for dashboard status fields. The firmware already exposes authoritative status data — version, uptime, free heap, sensor validity, storage settings — from `GET /api/status`. Entity-polling paths are implementation details of ESPHome's built-in web interface and may not be stable across firmware changes.

---

### LESSON-OPS-041: YAML generator correctness requires both idempotent marker replacement and indentation preservation (v7.5.0.1)

YAML generation that passes content-only sync checks can still produce invalid YAML if indentation context is lost during marker replacement. Two properties must both hold:
1. Running `--write` twice produces no diff (idempotence)
2. Inserted block content inherits the indentation column of the marker line

`replace_marker_block()` satisfies (1) but not (2). Use `apply_yaml_marker_block()` for all YAML-targeted marker regions.

---

### LESSON-OPS-040: YAML generator must use indentation-aware insertion for all block scalar sections (v7.5.0.0)

When generating content for YAML files that contain block scalars (lambda bodies, sorting_groups, nested sensor blocks), the generator must preserve the indentation level of the target marker location. Content-correct YAML with wrong indentation is not valid YAML — ESPHome will reject it at parse time, not compile time.

---

### LESSON-OPS-039: Use lambda replacements in `re.sub()` when generated content may contain backslashes (v7.5.0.0)

Generated text that contains escape sequences like `\xC2\xB0`, `\n`, or `\t` is unsafe as a raw string argument to `re.sub()`. Use a lambda function as the replacement instead: `re.sub(pattern, lambda m: generated_text, source)`.

Also: do not use brittle exact-string patching against compacted one-line C++ source blocks. Use function-anchor detection, regex-based matching, or brace-aware insertion instead.

---

### LESSON-OPS-038: Safety prompts belong on destructive CLI paths, not only in prose documentation (v7.4.5.1)

Documenting that a path is destructive is not enough. If a CLI command can erase retained state, the operator should have to acknowledge that at runtime or opt into bypassing the prompt deliberately.

---

### LESSON-OPS-037: Design-level behavior needs to be documented, not just shipped (v7.4.5.0)

When a feature has a non-obvious internal model, preserve that model in durable documentation. The single-sensor import path is a good example: the useful fact is not only that it is "non-destructive," but *how* it works — epoch-to-slot scan, segment overlay, same-slot rewrite, new-slot allocation only for missing hours, and temporary memory overhead.

**Carry forward:** When a feature changes retained-history semantics, endpoint contract, or state-management design, record the internal mechanism in the changelog and session handoff, not only the user-facing label.

---

### LESSON-OPS-036: Repeated configuration belongs in one canonical manifest (v7.4.5.0)

If the same sensor facts appear in multiple repo files, manual editing will eventually drift. Move those facts into one canonical manifest and generate the dependent files from it.

**Carry forward:** `config/sensors.json` is the source of truth. Future sensor-related changes should flow through the manifest and renderer first.

---

### LESSON-OPS-035: Preflight checks that depend on npm packages must skip when node_modules is absent (v7.4.4.0)

The build CI (`ci.yml`) runs preflight before `npm ci` — `node_modules` does not exist at that point. Any preflight check that requires an npm package must guard with `[[ -d "node_modules/@playwright" ]]` and emit `SKIP` rather than `FAIL` when the guard is not met.

---

### LESSON-OPS-034: Always use --with-deps when installing Playwright in containers (v7.4.4.0)

`npx playwright install chromium` downloads the binary only. `npx playwright install --with-deps chromium` also installs the required OS shared libraries via apt. In any container or fresh Linux environment, always use `--with-deps`. See BUG-027.

---

### LESSON-OPS-033: Playwright in Docker/ESPHome containers requires --no-sandbox (v7.4.4.0)

Always add `launchOptions: { args: ['--no-sandbox', '--disable-setuid-sandbox'] }` to `playwright.config.js` when running in a container. The error `Target page, context or browser has been closed` immediately after browser launch is the signature of a sandbox crash. See BUG-026.

---

### LESSON-OPS-032: NVS count-mismatch protection is already in place — no new C++ guard needed (v7.4.4.0)

The `meta.num_sensors == NUM_SENSORS` check in the NVS restore path already rejects history segments from a different sensor count cleanly. The correct response to a count change is: load nothing from the old segments, require an explicit history delete, and document the procedure.

---

### LESSON-OPS-031: DEFAULT_SENSOR_META in dashboard.js is a required consistency target (v7.4.4.0)

The `DEFAULT_SENSOR_META` array in `dashboard.js` is a fallback used when `/sensors.json` fails to load. It must match `NUM_SENSORS`. Preflight checks this explicitly.

---

### LESSON-OPS-030: Preflight sensor-count checks belong in Node.js, not bash regex (v7.4.4.0)

Counting occurrences of patterns in YAML and C++ using bash `grep -c` and `sed` is fragile. Inline Node.js scripting within the bash preflight is more readable, reliable, and straightforward to extend.

---

### LESSON-OPS-029: CSV fixture timestamps must be epoch seconds (v7.4.4.0)

The dashboard's history chart pipeline uses `new Date(epoch * 1000)` — it expects epoch **seconds** as integers from CSV files. `Date.UTC()` and `Date.now()` return **milliseconds** and must not be used directly as CSV timestamp values. See BUG-025.

---

### LESSON-OPS-028: Verify DOM behavior, not just element IDs (v7.4.3.0)

Verifying element IDs with `grep` is necessary but not sufficient. Three categories require runtime understanding:

1. **CSS class targets** — `toggleTheme()` applies `light` to `document.documentElement` (`<html>`), not `document.body`.
2. **Interaction side-effects** — `_onPreset()` calls `_applyAndClose()` immediately. A preset click closes the modal; there is no confirmation step.
3. **Container relationships** — chart canvases are in `.chart-card` divs, not inside `.sensor-card`.

Rule: before writing any Playwright assertion, read both the HTML and the JS handler for that element.

---

### LESSON-OPS-027: New GitHub Actions workflows only appear after merging to main

GitHub registers workflow files from the default branch only. A new `.github/workflows/*.yml` file on a feature branch will not appear in the Actions sidebar until it is merged to `main`.

---

### LESSON-OPS-026: `data-history-range` button values are in hours, not human-readable labels

| Label | Attribute value |
|-------|----------------|
| 24h | `24` |
| 7d | `168` |
| 30d | `720` |
| 45d | `1080` |
| Custom | `custom` |

---

### LESSON-OPS-025: Output bundle files must clearly indicate their destination path

When delivering files that belong in subdirectories, document the full destination path explicitly in session notes or in the delivery message.

---

### LESSON-OPS-024: Commit `package-lock.json` in the same commit as `package.json`

Any time `package.json` is introduced or changed, commit `package-lock.json` in the same commit. `npm ci` requires the lockfile and will not generate one.

---

### LESSON-OPS-023: Verify new workflow files are committed to the correct branch and appear in git log

After committing a new workflow file: `git show --name-only HEAD | grep workflow`. Do not assume file-system presence equals committed state.

---

### LESSON-OPS-022: Always `grep` the actual HTML for element IDs before writing Playwright selectors

Never assume an ID from a variable name, comment, or context.

Specific gotchas in this codebase:
- Range button values are **hours**, not labels: 24, 168, 720, 1080, custom
- Export buttons use `data-export-all` and `data-export-sensor` attributes, not text matching
- Sensor names are raw text nodes inside `.sensor-card-header` — there is no `.card-title` class
- Export and sensor card elements are built dynamically — use `waitForFunction` before asserting them

---

### LESSON-OPS-021: Zero return values from API need explicit handling distinct from fetch errors

Do not conflate a successful API response containing `0` with a missing/failed response.

---

### LESSON-OPS-020: "Data available: unknown" is expected on a freshly-flashed device

The first NVS history persist runs at 2:10 AM. Until then, `retention_oldest_epoch` returns 0. This is not a bug or a fetch failure.

---

### LESSON-OPS-019: Minification savings are a correctness signal

After running `minify-dashboard.sh`, expected savings are ~30–35% of source size. If savings are below 10%, the script block was almost certainly doubled (embedded twice).

---

### LESSON-OPS-018: Script block sync must use N-1, not N, for `head` cut

When syncing `dashboard.js` into the `<script>` block of `dashboard.html`, use `head -n $((SCRIPT_LINE - 1))`, not `head -n $SCRIPT_LINE`. After every sync, verify: `grep -c '^<script>$' dashboard/dashboard.html` must return `1`.

---

### LESSON-OPS-017: Code and docs should be normalized in the same pass when possible

If a comment/header is clearly stale, normalize it during the same session that fixes the related documentation drift.

---

### LESSON-OPS-016: Every substantial development session should leave continuity breadcrumbs

For meaningful sessions, update: a session log, the fresh-start handoff, and any changed roadmap/implementation-plan docs.

---

### LESSON-OPS-015: Documentation must distinguish current behavior from planned behavior

- `README.md` = current shipped behavior only
- `architecture.md` = current architecture only
- `future-plans.md` / implementation plans = planned behavior

Do not advertise a roadmap item as if it is already merged.

---

### LESSON-OPS-014: `dashboard.h` shrinkage is the easiest signal that minification is active

If the generated header barely changed, the minified intermediate may not have been used.

---

### LESSON-OPS-013: `git pull` can fail after a broken or partial prior pull

If Git says local changes would be overwritten and the changes are unwanted, reset the affected file(s) before retrying.

---

### LESSON-OPS-012: Script execute permissions may be lost

After a fresh clone or after pulling new scripts, run `chmod +x scripts/*.sh`.

---

### LESSON-OPS-011: `html-minifier-terser` uses positional input plus `--output`

Do not script imaginary flags. Test the exact command in a shell first.

---

### LESSON-OPS-010: Cached builds may not reflect header-only changes clearly

If behavior looks stale after header or generated-file changes, use `esphome compile --clean`.

---

### LESSON-OPS-009: Version strings live in six places

1. `VERSION`
2. YAML header comment
3. `register_history_handler()` version string
4. `dashboard_link` publish-state text
5. `App.version` in `dashboard.js`
6. Version comment/header in `dashboard.html`

When a version bump happens, update all six together.

---

### LESSON-OPS-008: `CONFIG_HTTPD_MAX_REQ_HDR_LEN` is a RAM multiplier

Increasing it increases per-connection cost. On this device class, overly large header buffers can create new failures.

---

### LESSON-OPS-007: ESPHome ESP-IDF data-channel constraints matter

- POST body: not reliable for this use case
- Query params: not reliable in this path
- Headers: too limited once proxies add overhead
- **URL path: reliable**

---

### LESSON-OPS-006: Prefer local CLI or editor-driven updates over ad hoc web editing

This reduces accidental truncation, missing execute bits, and inconsistent file state.

---

### LESSON-OPS-005: Raw logs and curated docs stay separate

- Raw logs → `build-logs/` (gitignored)
- Durable documentation → `Docs/`

---

### LESSON-OPS-004: Hidden build directories break GitHub Actions artifact collection

Stage artifacts explicitly into known output directories.

---

### LESSON-OPS-003: Cloud CI and local compile need different secret handling

Local uses the symlinked real secrets file. CI uses temporary dummy secrets.

---

### LESSON-OPS-002: Comments in YAML do not affect ESPHome behavior

Only actual configuration matters.

---

### LESSON-OPS-001: File renames must update internal references

Preflight should catch cross-reference drift, but docs should still be reviewed after any rename.

---

## Regression Checklist

Any significant dashboard or data-path modification should re-check:

- Startup ordering
- Event binding
- Theme redraw
- Chart marker/background/border consistency
- History/min-max calculations
- Export All concurrency behavior
- SSE and polling behavior
- Import over LAN
- Import over Cloudflare
- Browser compatibility across the major test targets
- Dashboard manifest boot sequence (primary `/api/manifest`, fallback `/sensors.json`, fallback built-in defaults)
- Both custom dashboard and built-in ESPHome web page diagnostics (Free Heap, Uptime, Loop Time)

---

## Known Open Issues

### ISSUE-001: Export still causes a noticeable heap drop

The current export path remains acceptable for the present dataset sizes, but it is still not the most memory-efficient design for worst-case full-retention exports.

### ISSUE-002: Multi-sensor import remains erase-first

Single-sensor import is now safe/merge-based, but multi-sensor import still clears existing history before writing.

### ISSUE-003: `/api/manifest` response is a partial v2 schema

The endpoint was implemented as Phase 1, but the response does not yet include the full v2 schema as specified in `Docs/v7.5-v7.6-architecture-plan.md` — specifically: the `gateway` identity block, the `history` retention policy block, and per-measurement `class`, `data_type`, and `display` hints. These are required before Phase 2 (dashboard consuming full manifest) can be fully implemented.

### ISSUE-004: ✅ RESOLVED (v7.5.1.2) — Preflight does not gate on ESPHome YAML validity

`preflight.sh` validates version strings, generator sync, and fixture alignment but does not run `esphome config` to verify YAML parse. A generator bug can produce structurally invalid YAML that passes all preflight checks. See LESSON-OPS-045.

**Resolution**: Preflight now runs `esphome config` to validate YAML structure before allowing merge
