# Lessons — Build Pipeline

_Split from Docs/bugs-and-lessons-learned.md at v7.6.4.0._

## Bug Fixes

### BUG-028: Sensor-count changes depended on four-file manual edits, creating configuration drift risk (v7.4.5.0)

**Symptom:** Changing sensor count or replacing a sensor required hand-editing `sensor_history_multi.h`, the firmware YAML, `dashboard.js`, and `tests/fixtures/sensors.json`. It was easy to update three files and miss the fourth, which produced confusing preflight failures or worse — a compile-valid repo whose dashboard fallback / test fixtures no longer matched the active firmware configuration.

**Root cause:** The repo had no canonical source of truth for configured sensors. The same facts (sensor id, display name, MAC, count) were duplicated in multiple files.

**Fix:** Introduced a canonical manifest (`config/sensors.json`) plus a generator (`scripts/render_sensor_config.py`) and an interactive manager (`scripts/change_sensor_number.py`). The renderer now drives generated sections in the header, firmware YAML, dashboard fallback metadata, and baseline fixture manifest.

**Guardrail:** `scripts/preflight.sh` now runs `python3 scripts/render_sensor_config.py --check` so generated-file drift is caught before compile.

**Lesson:** See LESSON-OPS-037.

---


---

### BUG-035: YAML generator produced invalid indentation in ESPHome block scalars (v7.5.0.0)

**Symptom:** `esphome compile firmware/esp32-c3-multi-sensor.yaml` failed immediately after `render_sensor_config.py --write` with `expected <block end>, but found '<scalar>'` near line 135.

**Root cause:** The YAML generation path reinserted block content without preserving the indentation level of the marker location. The content was semantically correct but structurally invalid YAML inside lambda block scalar sections, `web_server.sorting_groups`, `sensor`, and `text_sensor` blocks.

**Fix:** Routed all YAML marker replacements through `apply_yaml_marker_block()`, which captures the indentation column of the marker line and re-applies it to every inserted line.

**Lesson:** See LESSON-OPS-040.

---


---

### BUG-036: YAML generator reintroduced broken indentation after hotfix — preflight passed but compile failed (v7.5.0.1)

**Symptom:** After the initial YAML indentation fix, running `python3 scripts/render_sensor_config.py --write` again silently reintroduced bad indentation into the YAML. `bash ./scripts/preflight.sh` passed. `esphome compile` failed near the averaging block with `expected <block end>`.

**Root cause:** The hotfix had corrected one call site but `render_yaml_file()` still routed some YAML marker regions through `replace_marker_block()` instead of `apply_yaml_marker_block()`. Those paths produced correct YAML body content but inserted it without preserving the indentation level from the marker location.

**Fix:** Switched all YAML marker replacements in `render_sensor_config.py` to `apply_yaml_marker_block()`. Confirmed idempotence by running `--write` twice.

**Lesson:** See LESSON-OPS-041.

---


---

### BUG-040: No automated validation of manifest v2 schema (v7.5.1.1)

**Symptom:** Generator could produce malformed JSON or missing required fields without detection until runtime or manual inspection.

**Root cause:** Preflight only validated that `src/gateway_manifest.h` existed, was included, and that the generator sync check passed. It did not verify the content of the generated manifest against the v2 schema contract.

**Fix:** Added preflight checks that validate `gateway_manifest.h` contains all required v2 schema fields: top-level fields, `gateway` block fields, `history` block fields, `metrics` array fields, and that `schema_version` is exactly `2`.

**Lesson:** See LESSON-OPS-046.

---


---

### BUG-041: Fixture generator VERSION bumped independently from canonical VERSION file (v7.5.1.3)

**Symptom:** CI preflight failed with "Generated files are out of sync with config/sensors.json." The diff showed `manifest.json` containing `v7.5.1.3` while the Python generator (using VERSION from `render_sensor_config.py`) expected `v7.5.1.0`.

**Root cause:** PR #20 changed `tests/fixtures/generate-fixtures.js` VERSION from `v7.5.1.0` to `v7.5.1.3` and regenerated the fixture files with the new version string, but did not update the canonical VERSION sources (`VERSION` file, `render_sensor_config.py` VERSION constant). The Python generator (`render_sensor_config.py --check`) regenerates expected fixtures from the canonical VERSION and compares against on-disk fixtures — since JS fixtures said `v7.5.1.3` but Python expected `v7.5.1.0`, the check failed.

**Fix:** Bumped all version references atomically to `7.5.1.3`: `VERSION` file, `render_sensor_config.py` VERSION constant, `generate-fixtures.js` VERSION constant, `dashboard.js` App.version, `dashboard.html` App.version, `sensor_history_multi.h` header comment, YAML header comment, and `register_history_handler()` string. Regenerated all artifacts via `python3 scripts/render_sensor_config.py --write` and `bash scripts/generate-header.sh`. Added a preflight check (`fixture_generator_version_sync`) to catch future drift.

**Lesson:** See LESSON-OPS-047.

---


---

### BUG-042: `dashboard/dashboard.h` version check fails due to minification (post-v7.5.2.0)

**Symptom:** PR #25 added `dashboard_h_version_matches` to `scripts/preflight.sh` and CI failed with `dashboard_h_version_matches: FAIL` even though `dashboard.js` and `dashboard.html` had the correct version string `App.version = 'v7.5.2.0'`.

**Root cause:** CI runs `minify-dashboard.sh` then `generate-header.sh` before `preflight.sh`. The minifier (terser) converts `App.version = 'v7.5.2.0'` to `App.version="v7.5.2.0"` (removes spaces, converts single quotes to double quotes). The original `dashboard_h_version_matches` check used `grep -Fq "App.version = '${VER_TAG}'"` (fixed-string with spaces and single quotes), which never matches the minified form in the regenerated `dashboard.h`. The committed `dashboard.h` had the unminified form but is discarded when CI regenerates it.

**Fix:** Changed `dashboard_h_version_matches` to use `grep -Eq` with a regex pattern `App\.version[[:space:]]*=[[:space:]]*['\"]${VER_TAG}['\"]` that matches both the unminified source form and the minified generated form. Added `check_contains_regex()` helper to `scripts/preflight.sh` for future regex-based checks.

**Lesson:** See LESSON-OPS-048.

---


---

### BUG-055 — `bump-version.sh` produces stale `dashboard.h` when `dashboard.min.html` exists (2026-03-21)

**Date:** 2026-03-21
**Version observed:** v7.5.4.5 (during deployment)
**Status:** FIXED (v7.5.4.5)

**Symptom:** `bash scripts/bump-version.sh 7.5.4.5` completes but `preflight.sh` reports
`dashboard_h_version_matches: FAIL`. The generated `dashboard.h` still contains the old version.

**Root cause:** `generate-header.sh` auto-detects `dashboard/dashboard.min.html` and prefers it
over `dashboard.html`. `bump-version.sh` updates `dashboard.html` (via `sed`) and calls
`render_sensor_config.py --write` (updates `dashboard.js`), but never re-minifies. The stale
`.min.html` from the prior build still contains the old `App.version`, and `generate-header.sh`
embeds that stale content into `dashboard.h`.

**Fix:** `bump-version.sh` now checks for a stale `.min.html` after `render_sensor_config.py`.
If `html-minifier-terser` is installed, it re-runs `minify-dashboard.sh`. If the minifier is
not available, it removes the stale `.min.html` so `generate-header.sh` falls back to the
freshly-updated `dashboard.html`.

**Prevention:** LESSON-OPS-066.

---


---

## Lessons Learned

### LESSON-OPS-001: File renames must update internal references

Preflight should catch cross-reference drift, but docs should still be reviewed after any rename.



---

### LESSON-OPS-002: Comments in YAML do not affect ESPHome behavior

Only actual configuration matters.

---


---

### LESSON-OPS-030: Preflight sensor-count checks belong in Node.js, not bash regex (v7.4.4.0)

Counting occurrences of patterns in YAML and C++ using bash `grep -c` and `sed` is fragile. Inline Node.js scripting within the bash preflight is more readable, reliable, and straightforward to extend.

---


---

### LESSON-OPS-040: YAML generator must use indentation-aware insertion for all block scalar sections (v7.5.0.0)

When generating content for YAML files that contain block scalars (lambda bodies, sorting_groups, nested sensor blocks), the generator must preserve the indentation level of the target marker location. Content-correct YAML with wrong indentation is not valid YAML — ESPHome will reject it at parse time, not compile time.

---


---

### LESSON-OPS-041: YAML generator correctness requires both idempotent marker replacement and indentation preservation (v7.5.0.1)

YAML generation that passes content-only sync checks can still produce invalid YAML if indentation context is lost during marker replacement. Two properties must both hold:
1. Running `--write` twice produces no diff (idempotence)
2. Inserted block content inherits the indentation column of the marker line

`replace_marker_block()` satisfies (1) but not (2). Use `apply_yaml_marker_block()` for all YAML-targeted marker regions.

---


---

### LESSON-OPS-045: Preflight must include a YAML/ESPHome parse gate, not just generated-file sync checks (v7.5.0.1)

The existing preflight catches version drift and generator sync failures. It does not catch structurally invalid YAML that passes the sync check because the generator produced syntactically invalid output. Add a step that runs `esphome config firmware/esp32-c3-multi-sensor.yaml` (or equivalent YAML parse) to block bad YAML from reaching the compile stage.

Without this gate, a generator bug can produce invalid YAML that passes preflight, passes `--check`, and only fails at `esphome compile`. The gap between "preflight green" and "compile fails" wastes time and creates false confidence.

**Implementation**: v7.5.1.2 — preflight runs `esphome config firmware/esp32-c3-multi-sensor.yaml`

---


---

### LESSON-OPS-046: Generated artifacts with structured schemas need compile-time validation (v7.5.1.1)

For any generated file with a required schema (JSON, YAML, etc.), preflight must validate structure, not just existence. A generator bug or incomplete update can produce syntactically valid but semantically broken output — for example, a JSON file that parses correctly but is missing required fields. Existence checks and generator sync checks (`--check`) do not catch this class of failure.

Add field-level validation for every generated artifact that has a documented schema contract. This catches regressions early and prevents malformed output from reaching `main`.

Related: BUG-040

---


---

### LESSON-OPS-047: Version strings in test fixture generators must match the canonical VERSION file (v7.5.1.3)

The fixture generator (`tests/fixtures/generate-fixtures.js`) embeds a VERSION constant that is stamped into generated fixture JSON files. The Python generator (`render_sensor_config.py --check`) independently derives the expected version from the canonical `VERSION` file and its own VERSION constant. If these two sources drift, the `--check` comparison will fail even though the generated fixture files are otherwise valid.

**Rule:** All version references must be bumped atomically in a single commit: `VERSION` file, `render_sensor_config.py` VERSION constant, `generate-fixtures.js` VERSION constant, `dashboard.js` App.version, `dashboard.html` App.version, `sensor_history_multi.h` header comments, YAML header comment, and `register_history_handler()` string. Never bump the fixture generator VERSION independently.

**Enforcement:** Preflight checks `fixture_generator_version_sync` that the VERSION extracted from `generate-fixtures.js` matches the canonical `VERSION` file. If they differ, preflight fails immediately.

Related: BUG-041

---


---

### LESSON-OPS-048: Use `bump-version.sh` for all version bumps — never update version sources partially (post-v7.5.2.0)

Version drift occurs when the developer updates some canonical sources but misses others, or forgets to regenerate dependent artifacts. The version surfaces in at least eight places in this repo (VERSION, render_sensor_config.py, generate-fixtures.js, dashboard.html, dashboard.js, sensor_history_multi.h, firmware YAML, and the generated dashboard.h). Manually tracking all of them is error-prone.

**Rule:** Use `bash scripts/bump-version.sh <new-version>` for all version bumps. This script updates all four canonical sources atomically, runs `render_sensor_config.py --write` to regenerate all derived artifacts, runs `generate-header.sh` to regenerate `dashboard.h`, and then runs `preflight.sh` to verify sync. Do not manually edit individual version strings.

**Enforcement:** Preflight now includes `dashboard_h_version_matches` (detects missing `generate-header.sh`; uses regex to match both minified and non-minified forms) and `render_sensor_config_py_version_sync` (detects missing `render_sensor_config.py` VERSION update) in addition to the existing `fixture_generator_version_sync` and `render_sensor_config --check`.

**Version bump sources of truth (all updated by bump-version.sh):**
1. `VERSION` file (canonical root)
2. `scripts/render_sensor_config.py` VERSION constant
3. `tests/fixtures/generate-fixtures.js` VERSION constant
4. `dashboard/dashboard.html` App.version (**added in v7.5.3.0** — see LESSON-OPS-049)

**Derived artifacts (all regenerated by bump-version.sh):**
- `dashboard/dashboard.js` (App.version — via render_sensor_config.py --write)
- `dashboard/sensor_history_multi.h` (header comment — via render_sensor_config.py --write)
- `firmware/esp32-c3-multi-sensor.yaml` (header + register_history_handler — via render_sensor_config.py --write)
- `src/gateway_manifest.h` (firmware_version — via render_sensor_config.py --write)
- `tests/fixtures/manifest.json` and `api-status.json` (version fields — via render_sensor_config.py --write)
- `dashboard/dashboard.h` (embedded App.version — via generate-header.sh)

Related: BUG-042

---


---

### LESSON-OPS-049: `dashboard.html` must be kept in sync with `dashboard.js` for all code changes — `bump-version.sh` now handles the version string automatically (v7.5.2.1/v7.5.2.2; **fixed in v7.5.3.0**)

`dashboard/dashboard.html` embeds all dashboard JavaScript inline (no `<script src>`). It is
the source of truth that `generate-header.sh` uses to produce `dashboard/dashboard.h` (the
embedded firmware payload). Prior to v7.5.3.0, `bump-version.sh` and `render_sensor_config.py --write`
only updated `dashboard/dashboard.js` — they did **not** touch `dashboard.html`.

**✅ Fixed in v7.5.3.0:** `bump-version.sh` now runs `sed -i "s/App\.version = 'v[0-9.]*'/..."` on
`dashboard/dashboard.html` immediately after updating `tests/fixtures/generate-fixtures.js`. The
`App.version` string is now updated atomically by the bump script.

**Remaining manual requirement:** Code changes to `App.Boot.start()` or any other JS logic in
`dashboard.js` must still be manually mirrored to `dashboard.html`. There is no automated tool that
propagates non-version JS edits from `dashboard.js` → `dashboard.html`. After any such edit:
1. Apply identical code changes to `dashboard/dashboard.html`.
2. Run `bash scripts/generate-header.sh` to regenerate `dashboard/dashboard.h`.
3. Confirm `bash scripts/preflight.sh` passes.

**Historical workaround (v7.5.2.x, no longer needed for version bumps):**
1. Run `bash scripts/bump-version.sh <new-version>` (will fail at preflight if dashboard.html is stale — that is expected).
2. Manually update `App.version` in `dashboard/dashboard.html` to the new version.
3. Apply the same code changes to `dashboard/dashboard.html` that were applied to `dashboard/dashboard.js`.
4. Run `bash scripts/generate-header.sh dashboard/dashboard.html dashboard/dashboard.h` (pass the html source explicitly to bypass the stale min.html).
5. Confirm `bash scripts/preflight.sh` passes.

---


---

### LESSON-OPS-066: Build pipelines with intermediate artifacts must re-derive them on version bumps (2026-03-21)

**Date:** 2026-03-21

When a build pipeline has a chain like `source.html → minified.min.html → header.h`, a version
bump that only updates `source.html` leaves `minified.min.html` stale. If the next step
(`generate-header.sh`) auto-selects the minified file, it embeds the old version.

**Rule:** Any script that bumps version strings must re-derive ALL intermediate build artifacts
in the chain before generating final outputs. If a tool in the chain is optional (e.g.,
`html-minifier-terser` may not be installed), the script must either re-run the tool or
delete the stale intermediate so downstream scripts fall back to the updated source.

Related: BUG-055

---


---

### LESSON-OPS-071: Module-level imports for optional dependencies must be lazy (2026-03-23)

**Context:** `import yaml` at the top of `sensor_manifest_lib.py` crashed the satellite workflow on systems without PyYAML, even though PyYAML was only needed for the `load_board_profile()` function which satellites never call.

**Rule:** If a Python module is only needed by one function (e.g., `yaml` for `load_board_profile()`), import it inside that function, not at the top of the file. Top-level imports break all callers of the module, even those that never use the optional dependency. This is especially important in ESPHome containers where pip packages beyond the standard library are not guaranteed.

Related: BUG-060

---


---

### LESSON-OPS-077: api-status.json fixture requires generator-produced free_heap fields — never manually edit (2026-03-25)

**Context:** The root fixture `tests/fixtures/api-status.json` must contain `free_heap`,
`free_heap_internal`, and `free_heap_total` fields. These fields are produced by
`render_sensor_config.py --write` (template at line ~1228) and validated by `--check`.
The variant fixture generator (`generate-fixtures.js`) was missing these fields until
this fix.

**Failure pattern:** Across PRs #68, #69, #70, #72, and #73, coding agents either
manually edited `api-status.json` (stripping the fields) or ran `--write` in an
environment where the output differed from CI expectations. Each occurrence required
fix-up commits, making this the single most expensive recurring regression in Phase 5.

**Root cause:** Two generators produce `api-status.json` files:
- `render_sensor_config.py` produces the root fixture — included `free_heap` in template
- `generate-fixtures.js` produces variant fixtures — did NOT include `free_heap`

When agents ran `generate-fixtures.js --overwrite-baseline`, it would overwrite the root
fixture without `free_heap`, breaking `--check`. Conversely, when agents manually edited
the root fixture for version bumps instead of running `--write`, they often dropped fields.

**Fix (v7.5.5.5-hotfix):**
1. Added `free_heap` fields to `generate-fixtures.js` api-status template
2. Added preflight guards: `fixture_api_status_has_free_heap`, `_internal`, `_total`
3. Established Critical Rule 28: version bumps require both generators + verification

**Rule:** NEVER manually edit `tests/fixtures/api-status.json` or any variant fixture.
Always use the generators:
```bash
python3 scripts/render_sensor_config.py --write    # root fixtures
node tests/fixtures/generate-fixtures.js           # variant fixtures
python3 scripts/render_sensor_config.py --check    # verify
grep -q "free_heap" tests/fixtures/api-status.json # sanity check
```

**Detection:** `render_sensor_config.py --check` fails. Preflight guards
`fixture_api_status_has_free_heap*` fail.

Related: BUG-062, LESSON-OPS-072

---


---

### LESSON-OPS-115: Aggregator fixture `live` field must be a JSON object, not a JSON string (2026-03-25)

**Context:** The v7.5.5.4 prompt example showed `"live": "{...JSON string...}"` in
`aggregator-live.json`. This is the actual wire format from the firmware (the satellite's
cached `/api/v2/live` response is stored as a raw string in `SatelliteCache`).

**Rule:** When the mock server serves `aggregator-live.json`, the test sees `gwLive.live`
as whatever JSON value the file contains. The dashboard's `_populateGatewayDeviceLive()`
checks `gwLive.live.devices` directly — it does NOT call `JSON.parse()` on the live field.
Therefore the fixture MUST use a JSON object `{ "devices": {...} }`, not a JSON string.

If the firmware ever changes to ship a pre-parsed object in the aggregator live endpoint,
this remains correct. If the API changes to ship a string, the fixture and/or code must
both change together.

**Detection:** Tests 7 and 8 (env + network live values) stay in "—"/waiting state if
the live field is a string instead of an object.

Related: BUG-071

---


---

### LESSON-OPS-097: Never commit generated artifacts while operator configs are present (2026-03-30)

When local operator config files (`config/gateway.json`, `config/aggregator.json`) are present, running `render_sensor_config.py --write` can produce environment-specific generated files that diverge from CI defaults. Move operator configs aside before generating commit-bound artifacts to prevent accidental local-state leakage.

---

## LESSON-OPS-096 — Boot-time init vs runtime mutation mutex ordering (v7.6.0.0)

**Context:** `init_satellite_caches_()` in v7.6.0.0 runs without acquiring `s_cache_mutex`. The ESPHome startup sequence guarantees `aggregator_poll_task()` init completes before the web server accepts connections, so the current implementation is safe. However, the absence of a mutex creates technical debt if startup ordering ever changes.

**Status:** Accepted as technical debt for v7.6.0.0. For v7.6.0.1+, any code added during init must be verified to run before web handlers can fire. Future consideration: wrap init in the same mutex for defense-in-depth once runtime mutators are active.

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

## LESSON-OPS-095 — All-or-nothing NVS array load must be explicit in prompt (v7.6.0.0)

**Context:** v7.6.0.0 prompt said `load_satellites_from_nvs_()` "returns 0 if NVS is empty or corrupt" but did not define what "corrupt" means for partial reads within a counted array. The agent used `break` on per-entry NVS read failure, silently truncating the satellite list at the first bad entry.

**Fix (PR #99):** On any per-entry read failure, the function now closes the NVS handle and returns 0, triggering full fallback to compile-time defaults.

**Rule:** Prompts for NVS array loading must specify: "On any per-entry read failure (`nvs_get_str`, `nvs_get_u16` returning non-`ESP_OK`), close the NVS handle and return 0. Partial loads are worse than no load — they create invisible topology shrink."

---

## LESSON-OPS-094 — NVS seeding on first boot must be explicit in prompt (v7.6.0.0)

**Context:** v7.6.0.0 prompt said "if NVS count key is absent, populate from compile-time arrays" but did not say "and write them to NVS." The agent loaded compile-time defaults into the cache but did not persist them to NVS. The first runtime mutation (add/remove) would write only the delta; on reboot, all compile-time defaults were lost.

**Fix (PR #99):** `init_satellite_caches_()` now calls `save_satellites_to_nvs_()` after loading compile-time defaults as fallback.

**Rule:** When NVS is the single source of truth for runtime data that starts from compile-time defaults, prompts must explicitly state: "After loading compile-time defaults into the cache, call `save_satellites_to_nvs_()` to seed NVS. This prevents the first runtime mutation from orphaning the defaults."

---

## LESSON-OPS-093 — Management endpoints must have explicit auth requirement in prompt (v7.6.0.0)

**Context:** v7.6.0.0 prompt added `POST /api/system/reset-satellites` without specifying that it must call `authenticate_management_()`. The agent implemented the endpoint without authentication. The Copilot reviewer caught it during PR review; fixed in PR #99.

**Root cause:** Security conventions from neighbouring code are not inherited by the coding agent. Every other management endpoint in the codebase calls `authenticate_management_()`, but the agent did not infer this pattern.

**Rule:** Every prompt that adds a destructive or persistent-state-mutating endpoint must explicitly state: "This endpoint MUST call `authenticate_management_()` as the first action." For non-destructive endpoints (e.g. add-satellite), the prompt must explicitly state whether auth is required or not, with a rationale.

---

## LESSON-OPS-092 — NVS key buffer sizing must be explicit in prompts (v7.6.0.0)

**Context:** v7.6.0.0 prompt specified the NVS key scheme (`s{i}_id`, `s{i}_name`, etc.) but not buffer sizes for key construction variables. The coding agent chose `char key_*[8]`, which overflows for satellite indices ≥ 10 (e.g. `s10_name` = 8 chars + NUL = 9 bytes).

**Fix (PR #99):** All NVS key buffers changed to `char key_*[16]`. NVS max key length is 15 chars + NUL = 16 bytes.

**Rule:** When a prompt specifies an indexed NVS key scheme, it must explicitly state the buffer size for key construction. Use `char key_*[16]` for all NVS key buffers and state this in prompt code blocks.

---

## LESSON-OPS-091 — Regeneration pipeline must include dashboard bundle and minification before header generation (v7.6.0.0, updated v7.6.5.1, updated v7.6.5.3)

**Context:** The regeneration pipeline documented in prompts and `Docs/aggregator-setup.md` originally listed four steps: `render_sensor_config.py --write`, `generate-fixtures.js`, `generate-header.sh`, and `render_sensor_config.py --check`. The `minify-dashboard.sh` step and the `bundle-dashboard.sh` step were absent from all references.

**Root cause:** `generate-header.sh` auto-detects `dashboard.min.html` and uses it if present, falling back to unminified `dashboard.html` otherwise. This "silent fallback" masked the missing step — the build succeeds either way, but produces a larger firmware payload without minification. More dangerously, if a stale `dashboard.min.html` exists from a previous run, the header embeds the outdated minified copy instead of the current source.

Additionally, at v7.6.5.0, the dashboard JS was split into 21 source modules under `dashboard/src/`. The bundle step must run before the generator injects version markers, otherwise the bundler would overwrite `dashboard/dashboard.js` and wipe the markers the generator had just injected.

**Fix:** Added `bash scripts/bundle-dashboard.sh --write` as Step 1 and `bash scripts/minify-dashboard.sh` as Step 4 in the regeneration pipeline (after fixture generation, before header generation) in `Docs/aggregator-setup.md` Sections 7.1 and 15, and in all Phase D prompt device testing sections. Updated at v7.6.5.1 to include the bundle step.

**Updated at v7.6.5.3:** `bash scripts/build-dashboard.sh --write` added as Step 5 (after re-injecting markers, before minification). `dashboard.html` is now a generated artifact produced by this step. The canonical pipeline is now eight steps:

**Rule:** The canonical regeneration pipeline (full manual regeneration) is eight steps in this exact order:

1. `bash scripts/bundle-dashboard.sh --write`          — bundle BEFORE render to avoid wiping markers
2. `python3 scripts/render_sensor_config.py --write`   — inject version markers
3. `node tests/fixtures/generate-fixtures.js`          — generate fixture variants
4. `python3 scripts/render_sensor_config.py --write`   — re-inject markers after fixture generation
5. `bash scripts/build-dashboard.sh --write`           — template + JS → dashboard.html
6. `bash scripts/minify-dashboard.sh`                  — minify dashboard.html
7. `bash scripts/generate-header.sh`                   — generate dashboard.h
8. `python3 scripts/render_sensor_config.py --check`   — verify all artifacts in sync

Any prompt or documentation that references "the regeneration pipeline" must include all eight steps. Omitting the bundle step risks source module drift. Omitting `build-dashboard.sh` produces a `dashboard.html` without the `<!-- GENERATED -->` header and without current JS content. Omitting the minification step risks stale embedded dashboard content.

**Note:** `scripts/bump-version.sh` runs a subset (Steps 1, 2, 5, 6, 7, 8) because it does not regenerate test fixtures.

**Critical Rule 37 updated.**

---

## LESSON-OPS-090 — Device testing sections must reference the correct generated YAML for the target board (v7.6.0.0)

**Context:** All six Phase D prompt device testing sections (v7.6.0.0 through v7.6.0.5) contained `esphome clean firmware/esp32-c3-multi-sensor.yaml` and `esphome run firmware/esp32-c3-multi-sensor.yaml` in the aggregator build instructions. This is the committed C3 satellite template — it does not produce aggregator firmware and targets the wrong chip architecture for S3 boards.

**Root cause:** The prompt author wrote the device testing section by copying the C3 compile command (the only committed YAML) without accounting for the fact that non-C3 boards use **generated** YAML files that only exist after `render_sensor_config.py --write`. The generated S3 YAML is `firmware/esp32-s3-devkitc1-n16r8-gw.yaml` — it is gitignored and not visible in the repo file listing.

**Impact:** The operator compiled C3 satellite firmware and flashed it to the S3 aggregator. The device booted as a satellite with all local sensors displayed instead of as an aggregator with the Gateways card. Device testing could not proceed.

**Fix:** Corrected all Phase D prompts to reference `firmware/esp32-s3-devkitc1-n16r8-gw.yaml` for aggregator builds. Added Section 7.2 "Which YAML Do I Compile?" decision table to `Docs/aggregator-setup.md`.

**Rule:** Prompt device testing sections must use the exact YAML path that the generator produces for the target board. For non-C3 boards, this is always a **generated** gitignored file — never the committed C3 template. The correct path can be determined from the `get_yaml_output_path()` function in `render_sensor_config.py` or from the output of `render_sensor_config.py --write`.

**Critical Rule 36 added.**

---

## LESSON-OPS-089 — Unauthenticated constructive mutation endpoints need explicit rationale (2026-03-31)

**Context:** v7.6.0.1 `POST /api/aggregator/add-satellite` does not call `authenticate_management_()`,
unlike neighboring destructive endpoints.

**Policy decision:** Constructive mutation (adding a new satellite) is deliberately unauthenticated
in v7.6.0.1. An attacker on the LAN could add a rogue satellite and redirect polling, but cannot
delete or corrupt existing data. This is an acceptable risk for a LAN-only device in the current
deployment model.

**Required action before any internet-facing deployment:** Add auth to all runtime-management
mutation endpoints (add/delete/test-satellite) in Phase E or a dedicated security hardening step.

**Prevention:** Any future endpoint that mutates runtime/NVS state must explicitly declare in a
code comment whether auth is required and why. If omitted, auth is assumed required.

---

## LESSON-OPS-089-LEGACY — Preflight checks must be environment-aware

**Context:** Historically (before PR #96), `scripts/preflight.sh` hardcoded `check_contains "fixture_manifest_sensor_count" tests/fixtures/manifest.json '"sensor_count": 5'`. This was correct for the C3 satellite profile (3 ThermoPro + wan_ping + nas01 = 5 sensors) but broke when `config/gateway.json` pointed to the S3 aggregator sensor file (`config/sensors-agg-s3-16m-1.json`) which has only 1 sensor (wan_ping).

**Root cause:** The preflight check assumed all deployments had the same sensor count. When multi-board support was added (v7.5.5.0), the check was not updated to handle board-specific sensor manifests.

**Fix (PR #96):** Replaced the hardcoded value with a Python snippet that uses `sensor_manifest_lib.load_gateway_config()` and `load_manifest()` to dynamically compute the expected count — the exact same resolution logic as `render_sensor_config.py`. Errors fail loudly (no silent fallback). The `# Do NOT re-hardcode` comment guards against regression.

**Rule:** Preflight validation checks that depend on configuration-derived values (sensor count, device names, gateway metadata) must compute expected values dynamically using the same library functions as the generators. Never hardcode values that vary by board profile, sensor manifest, or deployment configuration.

---

## LESSON-OPS-088 — Mandatory deliverable tables should be templated with placeholder rows (v7.5.7.0)

**Version:** v7.5.7.0
**Source:** PR #93 — prompt required Instruction Compliance Output table (§8b) but the agent omitted it from the session log entirely.

When a prompt requires a specific table as a deliverable (e.g., Instruction Compliance Output), include a template with placeholder rows in the session log section. An empty template is harder to overlook than a prose instruction to "provide a table."

**Rule:** The session log section of any prompt that requires a compliance table must include a template with at least one placeholder row, not just the table header.

---

## LESSON-OPS-087 — Prompt-provided code blocks must apply the same constant policy as the target codebase (v7.5.7.0)

**Version:** v7.5.7.0
**Source:** PR #93 — prompt introduced C++ named constant `AGG_MANIFEST_BUF_SIZE` but provided Python code with bare literal `8192`.

When a prompt introduces a named constant in one language (C++ `AGG_MANIFEST_BUF_SIZE`), the corresponding value in prompt-provided code for another language (Python) should also use a named constant, not a bare literal. The agent copies prompt code faithfully — including inconsistencies. The Gemini reviewer caught the mismatch and it was fixed in the fixup commit by extracting `SATELLITE_CAP_PSRAM = 8` and `AGG_MANIFEST_BUF_SIZE_BYTES = 8192` as module-level constants.

**Rule:** Before publishing a prompt that contains code blocks in multiple languages, verify that each named constant defined in language A has a corresponding named constant (not a literal) in language B.

---

## LESSON-OPS-086 — Prompt Do-NOT lists must exclude expected regeneration side-effects (v7.5.7.0)

**Version:** v7.5.7.0
**Source:** PR #93 — Do-NOT list said "no dashboard JS/HTML changes" but `bump-version.sh` necessarily updates `App.version` in those files.

When a prompt says "Do NOT change file X" but also requires a version bump or regeneration pipeline that necessarily touches file X, the prompt contains an internal contradiction. The agent correctly ran the bump (version churn is expected), but the Do-NOT list was technically violated.

**Rule:** Future prompts should qualify: "No *functional* changes to file X; version bump and regeneration churn is expected and does not violate this rule."

---


---

### LESSON-OPS-098: `sdkconfig_options` must be updated in board profiles, not only templates (2026-03-30)

For multi-board builds, generated YAMLs inherit `sdkconfig_options` from `firmware/boards/*.yaml`. Updating only a template YAML can appear to fix one local build while leaving other board builds unchanged. Apply socket/stack changes to all relevant board profiles and verify generated outputs before release testing.

---


---
