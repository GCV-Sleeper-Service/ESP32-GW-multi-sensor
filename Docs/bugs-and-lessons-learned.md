# Bugs Fixed & Lessons Learned

_Last updated: 2026-03-10 — v7.4.1.0 normalized baseline_

This file tracks significant bugs, root causes, fixes, and operational lessons.
It is also the place where project guardrails are recorded so they are not re-learned in later sessions.

---

## Bug Fixes

### BUG-019: "Data available: unknown" in custom range dialog on freshly-flashed device (v7.4.2.0)

**Symptom:** Custom date range modal shows "Data available: unknown" immediately after flash.

**Root cause:** `/api/storage-stats` returns `retention_oldest_epoch = 0` when no data has been persisted to NVS yet. The original dialog code treated any zero bound as "unknown". On a fresh device, the first persist happens at 2:10 AM — until then, oldest epoch is genuinely 0.

**Fix:** Three-state availability display:
- Both bounds non-zero → "Data available: [oldest] – [newest]"
- Only newest non-zero → "Data available: up to [newest]"
- Both zero → "No persisted history yet — range applies to RAM data only"

**Lesson:** Distinguish between "API returned an error" and "API returned a valid zero value." Zero oldest epoch is a valid state, not a missing value.

---

### BUG-018: Duplicate `<script>` tag caused `Unexpected token '<'` dashboard failure (v7.4.2.0 deployment)

**Symptom:** Dashboard stuck on "connecting" after flash. Browser console: `Uncaught SyntaxError: Unexpected token '<'`.

**Root cause:** The script block sync command used `head -n 858` (inclusive of the `<script>` line), then echoed `<script>` again, producing two consecutive `<script>` tags. The browser's HTML parser closed the script block at the second `<script>`, then fed the remaining JavaScript as HTML, causing the syntax error.

**Fix:** `sed -i '859d' dashboard/dashboard.html` — deleted the duplicate tag.

**Prevention:** The sync command must use `head -n $((SCRIPT_LINE - 1))` (one line before the `<script>` tag), not `head -n $SCRIPT_LINE`. After every sync, verify with `grep -c '^<script>$' dashboard/dashboard.html` — must return exactly `1`. A minification savings of ~33% also confirms correct single-script-block sync; savings <10% indicate the block was doubled.

---

### BUG-017: `MAX_HISTORY_RANGE_HOURS` was 720, silently truncating 45d history display (v7.4.2.0)

**Symptom:** Selecting the 45d range button displayed only 30 days of data.

**Root cause:** `MAX_HISTORY_RANGE_HOURS` was set to `720` (30 days). The history store trim logic uses this constant to cap stored chart points: `store.temp.length > (MAX_HISTORY_RANGE_HOURS * 4 + 32)`. At 4 points/hour, 720 hours = 2912 points max, while 45d needs 4352 points. Data beyond 30 days was trimmed silently.

**Fix:** `MAX_HISTORY_RANGE_HOURS = 1080`.

**Lesson:** `MAX_HISTORY_RANGE_HOURS` must equal the highest `data-history-range` value in the HTML. A preflight check to validate this pairing would catch this class of bug automatically.

---

### BUG-016: `html-minifier-terser` CLI flags wrong (v7.4.1.0)

**Symptom:** `./scripts/minify-dashboard.sh` exited with `unknown option '--input-path'`.

**Root cause:** `html-minifier-terser` CLI does not use `--input-path` / `--output-path`.

**Fix:** Use positional input plus `--output`.

**Lesson:** Verify npm CLI syntax with `--help` before embedding commands into wrapper scripts.

---

### BUG-015: Single-sensor import "Unknown sensor ID" — off-by-one in URL path parsing (v7.4.0.2)

**Symptom:** Single-sensor import failed even though the sensor ID looked correct.

**Root cause:** The path prefix `/api/import/begin/single/` was counted incorrectly, leaving a leading slash on the extracted sensor ID.

**Fix:** Corrected both the prefix length comparison and pointer offset.

**Lesson:** Prefer `sizeof("literal") - 1` or `strlen()` over hand-counted path lengths.

---

### BUG-014: Single-sensor import erased all flash data (v7.4.0.2)

**Symptom:** Importing one sensor destroyed history for all sensors.

**Root cause:** The original import path erased the whole history partition before writing.
Because each persisted segment stores all sensors together, one-sensor replacement could not safely reuse the destructive path.

**Fix:** Added `POST /api/import/begin/single/<id>` and merge-first behavior.

**Lesson:** If storage blobs are multi-entity structures, partial import must merge, not replace.

---

### BUG-013: Import over Cloudflare returned HTTP 502 (v7.4.0.1)

**Symptom:** Import worked partially, then failed through the tunnel with 502.

**Root cause:** Background dashboard traffic and sustained import requests contended for the same limited HTTP/socket resources.

**Fix:** Suspend non-essential background activity during import and add pacing/backoff.

**Lesson:** On a constrained ESP origin, long-running operations must reduce concurrent background traffic.

---

### BUG-012: Single-sensor export schema mismatch (v7.4.0.1)

**Symptom:** Single-sensor export/import could map data to the wrong sensor.

**Root cause:** Single-sensor export used bare column names while merged export used sensor-prefixed columns.

**Fix:** Standardized on prefixed headers.

**Lesson:** Export and import must share one canonical schema.

---

### BUG-011: Non-JSON server response crashed import error handling (v7.4.0)

**Symptom:** Browser threw a JSON parse error instead of showing the real ESP/server error.

**Root cause:** Fetch handlers assumed JSON unconditionally.

**Fix:** Added safer text-first JSON response handling.

**Lesson:** Anything talking to ESP-IDF httpd must tolerate non-JSON error responses.

---

### BUG-010: `time()` ambiguous in ESPHome context (v7.4.0)

**Symptom:** Compile failure due to namespace ambiguity.

**Root cause:** ESPHome's `time` namespace collided with C standard library `time()`.

**Fix:** Use `::time(nullptr)`.

**Lesson:** Qualify standard-library calls when ESPHome namespaces can shadow them.

---

### BUG-009: Import POST body never delivered (v7.4.0)

**Symptom:** Import body appeared empty at the custom handler.

**Root cause:** On this ESPHome / ESP-IDF path, custom handlers do not receive request bodies in the way the original design assumed.

**Fix:** Moved import payload transport into the URL path.

**Lesson:** On this stack, **URL path is the reliable data channel** for custom import operations.

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

### BUG-020: Browser test suite used wrong element IDs throughout — 14 of 25 tests failed (v7.4.3.0)

**Symptom:** 14 CI browser test failures on first run. All failures traced to elements not found.

**Root cause:** Tests were written against assumed element IDs without verifying the actual dashboard HTML. Six distinct mismatches:

| Used in test | Actual ID in HTML |
|---|---|
| `#themeToggle` | `#themeBtn` |
| `#crApply` | `#customRangeApply` |
| `#crCancel` | `#customRangeCancel` |
| `#crPrevMonth` | `#crPrev` |
| `#crMonthLabel` | `#crCalHeader` |
| `.card-title` | `.sensor-card-header` (name is a raw text node, no title class) |
| `data-history-range="7d"` | `data-history-range="168"` (values are in hours, not labels) |
| `button[hasText=Export]` count ≥ 4 | `[data-export-all]` + `[data-export-sensor]` separate attributes |

**Fix:** Audited all element IDs against the actual HTML before writing tests. Replaced every selector.

**Lesson:** Always `grep` the actual HTML for element IDs before writing selectors. Never assume IDs from variable names or context — verify them. See LESSON-OPS-022.

---

### BUG-021: `browser-tests.yml` committed to wrong branch — workflow never appeared in CI (v7.4.3.0)

**Symptom:** GitHub Actions showed no "Browser Tests" workflow. The file existed on disk but `git show --name-only HEAD` returned nothing for it.

**Root cause:** `browser-tests.yml` was committed on `feature/custom-date-range` (an earlier branch) rather than `feature/playwright-tests`. The rebase that followed picked up all other files but the workflow file was never in the HEAD commit of the feature branch.

**Fix:** `git log --oneline --all -- .github/workflows/browser-tests.yml` identified the commit. `git checkout <sha> -- .github/workflows/browser-tests.yml` recovered the file and it was committed to the correct branch.

**Additional factor:** GitHub does not register a new workflow file until it appears on the default branch (`main`). Even with the file correctly committed to a feature branch, the workflow tab won't show it until the PR is merged.

**Lesson:** After committing a new workflow file, verify with `git show --name-only HEAD | grep workflow`. See LESSON-OPS-023.

---

### BUG-022: `package-lock.json` not committed — CI failed on `npm ci` (v7.4.3.0)

**Symptom:** Browser CI job failed immediately: `Dependencies lock file is not found`.

**Root cause:** `npm install` was run locally to generate `package.json` and install Playwright, but `package-lock.json` was never staged or committed. `npm ci` (used in CI) requires the lockfile — unlike `npm install`, it will not generate one.

**Fix:** `npm install` on device, then `git add package-lock.json && git commit`.

**Lesson:** Any time `package.json` is introduced, commit `package-lock.json` in the same commit. See LESSON-OPS-024.

---

### BUG-023: Output bundle file naming caused confusion about destination paths (v7.4.3.0)

**Symptom:** `mock-server.js` in outputs needed to be placed as `tests/mock-server/server.js`. Three JSON fixture files needed to go into `tests/fixtures/`. The flat output bundle gave no indication of subdirectory placement.

**Fix:** Files renamed and placed in correct locations after clarification.

**Lesson:** When delivering files that go into subdirectories, prefix the output filename with the path (e.g. `tests--mock-server--server.js`) or document the copy list explicitly in the session notes. See LESSON-OPS-025.

---

## Operational Lessons

### LESSON-OPS-001: File renames must update internal references

Preflight should catch cross-reference drift, but docs should still be reviewed after any rename.

### LESSON-OPS-002: Comments in YAML do not affect ESPHome behavior

Only actual configuration matters.

### LESSON-OPS-003: Cloud CI and local compile need different secret handling

Local uses the symlinked real secrets file.
CI uses temporary dummy secrets.

### LESSON-OPS-004: Hidden build directories break GitHub Actions artifact collection

Stage artifacts explicitly into known output directories.

### LESSON-OPS-005: Raw logs and curated docs stay separate

- Raw logs → `build-logs/` (gitignored)
- Durable documentation → `Docs/`

### LESSON-OPS-006: Prefer local CLI or editor-driven updates over ad hoc web editing

This reduces accidental truncation, missing execute bits, and inconsistent file state.

### LESSON-OPS-007: ESPHome ESP-IDF data-channel constraints matter

For custom handlers on this platform:

- POST body: not reliable for this use case
- Query params: not reliable in this path
- Headers: too limited once proxies add overhead
- **URL path: reliable**

### LESSON-OPS-008: `CONFIG_HTTPD_MAX_REQ_HDR_LEN` is a RAM multiplier

Increasing it increases per-connection cost.
On this device class, overly large header buffers can create new failures.

### LESSON-OPS-009: Version strings live in six places

Those six synchronized locations are:

1. `VERSION`
2. YAML header comment
3. `register_history_handler()` version string
4. `dashboard_link` publish-state text
5. `App.version` in `dashboard.js`
6. Version comment/header in `dashboard.html`

When a version bump happens, update all six together.

### LESSON-OPS-010: Cached builds may not reflect header-only changes clearly

If behavior looks stale after header or generated-file changes, use `esphome compile --clean`.

### LESSON-OPS-011: `html-minifier-terser` uses positional input plus `--output`

Do not script imaginary flags.
Test the exact command in a shell first.

### LESSON-OPS-012: Script execute permissions may be lost

Files introduced or rewritten through some repo workflows can lose the execute bit.
After a fresh clone or after pulling new scripts, run:

```bash
chmod +x scripts/*.sh
```

This instruction should appear in setup docs and handoff docs.

### LESSON-OPS-013: `git pull` can fail after a broken or partial prior pull

If Git says local changes would be overwritten and the changes are unwanted, reset the affected file(s) before retrying.

### LESSON-OPS-014: `dashboard.h` shrinkage is the easiest signal that minification is active

If the generated header barely changed, the minified intermediate may not have been used.

### LESSON-OPS-015: Documentation must distinguish current behavior from planned behavior

This project now has enough maturity that documentation drift becomes a real risk.
Use this rule:

- `README.md` = current shipped behavior only
- `architecture.md` = current architecture only
- `future-plans.md` / implementation plans = planned behavior

Do not advertise a roadmap item as if it is already merged.

### LESSON-OPS-016: Every substantial development session should leave continuity breadcrumbs

For meaningful sessions, update:

- A session log
- The fresh-start handoff
- Any changed roadmap/implementation-plan docs

That way a new session can restart cleanly without reconstructing history from chat logs.

### LESSON-OPS-017: Code and docs should be normalized in the same pass when possible

If a comment/header is clearly stale, normalize it during the same session that fixes the related documentation drift.
This reduces "almost aligned" repo states.

### LESSON-OPS-018: Script block sync must use N-1, not N, for `head` cut

When syncing `dashboard.js` into the `<script>` block of `dashboard.html`, use:
```bash
SCRIPT_LINE=$(grep -n "^<script>$" dashboard/dashboard.html | head -1 | cut -d: -f1)
head -n $((SCRIPT_LINE - 1)) dashboard/dashboard.html > /tmp/out.txt
echo '<script>' >> /tmp/out.txt
cat dashboard/dashboard.js >> /tmp/out.txt
echo '</script>' >> /tmp/out.txt
tail -n +$((END_LINE + 1)) dashboard/dashboard.html >> /tmp/out.txt
```
After every sync, verify: `grep -c '^<script>$' dashboard/dashboard.html` must return `1`.

### LESSON-OPS-019: Minification savings are a correctness signal

After running `minify-dashboard.sh`, expected savings are ~30–35% of source size. If savings are below 10%, the script block was almost certainly doubled (embedded twice). Use this as a fast sanity check before committing.

### LESSON-OPS-020: "Data available: unknown" is expected on a freshly-flashed device

The first NVS history persist runs at 2:10 AM. Until then, `retention_oldest_epoch` returns 0. The custom range dialog handles this gracefully as of v7.4.2.0 — it is not a bug or a fetch failure.

### LESSON-OPS-021: Zero return values from API need explicit handling distinct from fetch errors

Do not conflate a successful API response containing `0` with a missing/failed response. Use separate code paths for "API succeeded but returned zero" vs "API call failed."

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

---

## Known Open Issues

### ISSUE-001: Export still causes a noticeable heap drop

The current export path remains acceptable for the present dataset sizes, but it is still not the most memory-efficient design for worst-case full-retention exports.

### ISSUE-002: Multi-sensor import remains erase-first

Single-sensor import is now safe/merge-based, but multi-sensor import still clears existing history before writing.
A future staging/swap approach would be safer.


### LESSON-OPS-022: Always verify element IDs against actual HTML before writing browser tests

Before writing any Playwright selector, grep the dashboard HTML for the actual ID:
```bash
grep -n 'id="theme\|id="cr\|id="custom\|data-history-range\|data-export' dashboard/dashboard.html
```
Never assume an ID from a variable name, comment, or context. The cost of one grep is zero; the cost of 14 CI failures is not.

Specific gotchas in this codebase:
- Range button values are **hours**, not labels: 24, 168, 720, 1080, custom
- Export buttons use `data-export-all` and `data-export-sensor` attributes, not text matching
- Sensor names are raw text nodes inside `.sensor-card-header` — there is no `.card-title` class
- Export and sensor card elements are built dynamically — use `waitForFunction` before asserting them

### LESSON-OPS-023: Verify new workflow files are in the correct commit before pushing

After adding a `.github/workflows/` file, confirm it is in the current HEAD commit:
```bash
git show --name-only HEAD | grep workflows
```
If it returns nothing, the file was either committed on a different branch or never staged.

Also: GitHub will not show a new workflow in the Actions sidebar until the workflow file has been merged to the default branch (`main`). This is expected — do not try to trigger it from the feature branch UI before merging.

### LESSON-OPS-024: Commit `package-lock.json` in the same commit as `package.json`

`npm ci` (used in all CI environments) requires a lockfile and will not generate one. `npm install` generates the lockfile locally but does not commit it. Always stage and commit `package-lock.json` alongside `package.json`.

```bash
npm install
git add package.json package-lock.json
git commit -m "..."
```

### LESSON-OPS-025: Output bundle files must clearly indicate their destination path

When delivering files that belong in subdirectories, document the full destination path explicitly in session notes or in the delivery message. A flat bundle with `mock-server.js` does not communicate that it should be placed at `tests/mock-server/server.js`.

Preferred format in session handoff:
```
mock-server.js   →  tests/mock-server/server.js
sensors.json     →  tests/fixtures/sensors.json
```

### LESSON-OPS-026: `data-history-range` button values are in hours, not human-readable labels

The range toggle buttons use numeric hour values as their `data-history-range` attribute:

| Label | Attribute value |
|-------|----------------|
| 24h | `24` |
| 7d | `168` |
| 30d | `720` |
| 45d | `1080` |
| Custom | `custom` |

Any test, script, or documentation referencing these buttons must use the hour values, not the display labels.

### LESSON-OPS-027: New GitHub Actions workflows only appear after merging to main

GitHub registers workflow files from the default branch only. A new `.github/workflows/*.yml` file on a feature branch will not appear in the Actions sidebar and cannot be triggered manually until it is merged to `main`. This is not a bug — just push the PR and merge. The workflow will appear and run automatically on the next push to main.
