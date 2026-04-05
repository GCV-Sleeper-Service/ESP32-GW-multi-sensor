# Lessons — Testing

_Split from Docs/bugs-and-lessons-learned.md at v7.6.4.0._

## Bug Fixes

### BUG-021: `browser-tests.yml` committed to wrong branch — workflow never appeared in CI (v7.4.3.0)

**Symptom:** GitHub Actions showed no "Browser Tests" workflow.

**Root cause:** Workflow file was committed on the wrong feature branch. GitHub only registers workflow files from the default branch.

**Fix:** `git log --oneline --all -- .github/workflows/browser-tests.yml` identified the commit. `git checkout <sha> -- .github/workflows/browser-tests.yml` recovered and committed it to the correct branch.

**Lesson:** See LESSON-OPS-023.

---


---

### BUG-026: Chromium crashes silently in ESPHome/Docker containers — sandbox kernel feature missing (v7.4.4.0)

**Symptom:** All Playwright tests fail immediately with `browserType.launch: Target page, context or browser has been closed` — even after a successful install. The browser binary exists but the process crashes on startup.

**Root cause:** Chromium's default sandbox uses Linux user namespaces, which are disabled in many container environments including the ESPHome Docker container.

**Fix:** Add `launchOptions: { args: ['--no-sandbox', '--disable-setuid-sandbox'] }` to the `use` block in `playwright.config.js`.

**Lesson:** See LESSON-OPS-033.

---


---

### BUG-027: Chromium missing shared libraries in ESPHome container — libnspr4.so not found (v7.4.4.0)

**Symptom:** All Playwright tests fail with `error while loading shared libraries: libnspr4.so: cannot open shared object file`. The binary exists and `--no-sandbox` is in the launch args, but the process crashes at the dynamic linker stage.

**Root cause:** `npx playwright install chromium` downloads the Chromium binary but does NOT install the required OS-level shared libraries. The ESPHome Docker container does not include them by default.

**Fix:** Use `npx playwright install --with-deps chromium`. This installs both the binary and all required system packages via `apt`.

**Lesson:** See LESSON-OPS-034.

---


---

### BUG-031: `change_sensor_number.py` rollback messaging was too optimistic for structural renderer failures (v7.4.5.1)

The initial rollback path restored `config/sensors.json` and attempted a best-effort re-render, but it could still leave the operator uncertain if recovery was incomplete.

**Fix:** rollback now preserves the backup file on failure, prints manual recovery commands, and surfaces restore/re-render errors explicitly instead of assuming a clean rollback.

---


---

### BUG-050 — Group 18 Playwright tests fail in CI: `expectedSensorCount` mismatch with `3sensor` fixture (2026-03-20)

**Date:** 2026-03-20
**Version observed:** v7.5.4.3 (PR #57, `copilot/implement-phase4-step-v7543`)
**Status:** FIXED

**Symptom:** `browser-tests (3sensor)` CI job fails with `TimeoutError: page.waitForFunction: Timeout 15000ms exceeded`
in 6 of the 7 Group 18 (`18. Mixed-Category Rendering`) Playwright tests. All other CI jobs
(`1sensor`, `2sensor`, `4sensor`) pass. Failure occurs in `waitForDashboardReady` at the
`sensors.length !== expected` guard.

**Root cause:** Group 18 tests were written for the `mixed` fixture variant (2 environmental
sensors + 1 `wan_ping` network device = 3 sensors total). Every test calls
`loadDashboard(page, { expectedSensorCount: 3 })`, which makes `waitForDashboardReady` wait
until `App.State.getSensors().length === 3`. However, the CI `browser-tests` workflow runs
the full `dashboard.spec.js` suite only under `FIXTURE_SET=3sensor`. The `3sensor` fixture
has 4 sensors (3 BLE environmental + 1 `wan_ping`). With 4 sensors loaded, the condition
`sensors.length === 3` is never satisfied, causing the default 15-second timeout to expire.

**The original v7.5.4.3 PR (before correction)** used `{ timeout: 30000 }` and dynamic
`window._manifest` count reads — both identified as incorrect by post-merge review:
`{ timeout: 30000 }` is a BUG-049 Firefox workaround reserved for Group 13 only, and dynamic
manifest reads allow vacuous passes when the manifest is broken. The corrected tests properly
use `{ expectedSensorCount: 3 }` and hardcoded counts, but this exposed the fixture mismatch.

**Fix:**
1. `tests/browser/dashboard.spec.js` — Group 18 `test.describe()`: added `test.beforeEach`
   with `testInfo.skip()` when `process.env.FIXTURE_SET !== 'mixed'`. Group 18 is skipped
   in all CI jobs except the dedicated `mixed` job.
2. `.github/workflows/browser-tests.yml` — CI matrix: added `mixed` fixture set; added step
   `Run mixed-category suite (mixed — Group 18)` that runs only Group 18 with
   `--grep "18\. Mixed-Category Rendering"` and `FIXTURE_SET=mixed`; updated
   sensor-count smoke step to skip `mixed` (uses `!= '3sensor' && != 'mixed'`).
3. `tests/fixtures/generate-fixtures.js` — added `buildPingCsvLines()` + `generateMixedFixtures()`;
   `main()` now calls `generateMixedFixtures()` to produce `tests/fixtures/variants/mixed/`.
4. `tests/mock-server/server.js` — `icmp_ping` devices now return `ping_ms: 12.5,
   success_pct: 100.0` instead of `null`, so live-value assertions in Group 18 pass.

**Why not detected before merge:**
- The coding agent ran tests locally with `FIXTURE_SET=3sensor` where Group 18 tests were
  originally fixture-agnostic (dynamic counts) and happened to produce a passing result.
- After the post-merge review identified issues #2/#3, the corrected PR used `expectedSensorCount: 3`
  but was not re-validated against the CI fixture matrix (`3sensor` = 4 sensors).
- Human review focused on test logic correctness, not CI fixture compatibility.

**Prevention:** LESSON-OPS-063 (see below).

Related: BUG-049, LESSON-OPS-063

---


---

### BUG-051 — 11 Playwright tests fail when running full suite with FIXTURE_SET=mixed (2026-03-20)

**Date:** 2026-03-20
**Version observed:** v7.5.4.3 (post-PR #59)
**Status:** FIXED

**Symptom:** Running `FIXTURE_SET=mixed npx playwright test --project=chromium` (full suite) fails
with 11 test failures across `tests/browser/dashboard.spec.js` and `tests/browser/manifest.spec.js`:
- Tests asserting exactly 4 sensor cards (`3 environmental + 1 network`) time out or fail on count
- Tests asserting sensor name `'Outside'` fail because the mixed fixture has no `outside` sensor
- Tests expecting `sensors.json` to contain `['office', 'first_floor', 'outside']` fail because
  the mixed `sensors.json` only has 2 entries (`office`, `first_floor`)
- Tests using `loadDashboard(page, { expectedSensorCount: 4 })` time out (mixed has 3 sensors)

The 11 affected tests span:
- `manifest.spec.js`: `dashboard boots from /api/manifest`, `dashboard falls back to /sensors.json`
- `dashboard.spec.js Group 2`: `four sensor cards are rendered`, `sensor card headers contain expected sensor names`
- `dashboard.spec.js Group 11`: `environmental renderer dispatches correctly and produces sensor cards`
- `dashboard.spec.js Group 14`: scenarios 1, 2, and 4
- `dashboard.spec.js Group 15`: `dashboard renders identically with new endpoints`
- `dashboard.spec.js Group 17`: `environmental cards have full ThermoPro layout`, `SENSORS includes network device`

**Root cause:** These tests were written for the `3sensor` fixture (3 env + 1 network = 4 total,
including `outside`). The `mixed` fixture intentionally has a different shape (2 env + 1 network = 3
total, no `outside`). When a developer runs the full suite locally with `FIXTURE_SET=mixed`, none of
these tests had a skip guard, so they all fail. In CI, the `mixed` matrix job only runs Group 18
via `--grep`, so CI never exposed the problem — it was only visible in full local runs.

**Fix:** Added `test.skip(process.env.FIXTURE_SET === 'mixed', '<reason>')` at the start of each
of the 11 affected tests. The skip reason includes the specific counts/names that are
`3sensor`-specific, making the incompatibility self-documenting.

**Why not caught earlier:**
- CI matrix runs `mixed` fixture exclusively with `--grep "18\. Mixed-Category Rendering"`, so
  only Group 18 runs in CI with `FIXTURE_SET=mixed`. All other groups are never exercised with
  that fixture in CI.
- Human reviewers focused on Group 18 correctness and did not run the full suite with
  `FIXTURE_SET=mixed` locally.
- BUG-050 was about Group 18 tests *within* CI breaking the `3sensor` job; this bug is the
  inverse: running the full suite under the `mixed` fixture breaks non-Group-18 tests.

**Prevention:** LESSON-OPS-063 — any fixture-specific test must carry a skip guard.
When adding a new fixture variant to the CI matrix, verify that running the full suite locally
under that fixture does not produce unexpected failures in existing test groups.

Related: BUG-050, PR-057, LESSON-OPS-063

---

### PR-057 — Group 18 tests used wrong `loadDashboard()` signature and dynamic count assertions (2026-03-20)

**Date:** 2026-03-20
**Version observed:** v7.5.4.3 (PR #57 before correction, `copilot/implement-phase4-step-v7543`)
**Status:** FIXED before merge

**Symptom:** Code review of PR #57 (Mixed-Category Rendering — Group 18 Playwright tests) found
two classes of implementation deviation from the specified test template in the coding agent prompt:

1. `loadDashboard()` was called as `loadDashboard(page, { timeout: 30000 })` in all 6 Group-18
   tests instead of the specified `loadDashboard(page, { expectedSensorCount: 3 })`.
2. Count assertions (`toHaveCount()`) used dynamic `window._manifest.sensors` lookups instead of
   hardcoded fixture-specific integers (`3` total, `2` environmental).

**Root cause — Issue 1 (`timeout` vs `expectedSensorCount`):**
The coding agent saw Group 13 using `{ timeout: 30000 }` (BUG-049 fix) and pattern-matched that
style to the new group. It did not distinguish *why* Group 13 uses a raw timeout (Firefox SSE
teardown headroom) versus what the new mixed fixture needs (a count-gated readiness check).
`expectedSensorCount` causes `waitForDashboardReady()` to actively wait until exactly N sensor
cards are present before proceeding — a stronger signal than a raw timeout. A raw timeout can pass
vacuously if the page loads fewer cards than expected.

**Root cause — Issue 2 (dynamic counts):**
The coding agent made tests "fixture-agnostic" by reading counts from `window._manifest` at
runtime rather than hardcoding the known fixture values. This is an anti-pattern for
fixture-specific tests: if the manifest itself is broken and returns 0 sensors, `toHaveCount(0)`
passes vacuously, providing no regression protection.

**Fix:**
- All 6 Group-18 `loadDashboard()` calls changed to `{ expectedSensorCount: 3 }`.
- All dynamic count assertions replaced with hardcoded literals: `3` (total), `2` (environmental).

**Prevention:** LESSON-OPS-063 (see Operational Lessons).

Related: BUG-050, LESSON-OPS-063

---


---

### BUG-053 — `/api/status` outputs ThermoPro-specific fields for all device categories (2026-03-21)

**Date:** 2026-03-21
**Version observed:** v7.5.4.4
**Status:** FIXED (v7.5.4.5)

**Symptom:** `curl /api/status` returned `temp_valid: false, hum_valid: false` for the `wan_ping` device. These fields are semantically meaningless for a network ping probe.

**Root cause:** `handle_status_()` was written before the SensorEntity model existed. It iterated all `NUM_DEVICES` and unconditionally emitted `temp_valid`/`hum_valid` for every entry. Phase 3 (SensorEntity refactor) and Phase 4 (ping adapter) did not scope this handler for updates.

**Fix:** Added `category` field to each sensor entry in the status JSON. `temp_valid`/`hum_valid` are now only emitted for environmental devices (`category_id == 0`).

**Prevention:** LESSON-OPS-064.

---


---

## Lessons Learned

### LESSON-OPS-003: Cloud CI and local compile need different secret handling

Local uses the symlinked real secrets file. CI uses temporary dummy secrets.

---


---

### LESSON-OPS-004: Hidden build directories break GitHub Actions artifact collection

Stage artifacts explicitly into known output directories.

---


---

### LESSON-OPS-006: Prefer local CLI or editor-driven updates over ad hoc web editing

This reduces accidental truncation, missing execute bits, and inconsistent file state.

---


---

### LESSON-OPS-021: Zero return values from API need explicit handling distinct from fetch errors

Do not conflate a successful API response containing `0` with a missing/failed response.

---


---

### LESSON-OPS-024: Commit `package-lock.json` in the same commit as `package.json`

Any time `package.json` is introduced or changed, commit `package-lock.json` in the same commit. `npm ci` requires the lockfile and will not generate one.

---


---

### LESSON-OPS-025: Output bundle files must clearly indicate their destination path

When delivering files that belong in subdirectories, document the full destination path explicitly in session notes or in the delivery message.

---


---

### LESSON-OPS-034: Always use --with-deps when installing Playwright in containers (v7.4.4.0)

`npx playwright install chromium` downloads the binary only. `npx playwright install --with-deps chromium` also installs the required OS shared libraries via apt. In any container or fresh Linux environment, always use `--with-deps`. See BUG-027.

---


---

### LESSON-OPS-035: Preflight checks that depend on npm packages must skip when node_modules is absent (v7.4.4.0)

The build CI (`ci.yml`) runs preflight before `npm ci` — `node_modules` does not exist at that point. Any preflight check that requires an npm package must guard with `[[ -d "node_modules/@playwright" ]]` and emit `SKIP` rather than `FAIL` when the guard is not met.

---


---

### LESSON-OPS-057: Specified tests and checks must be tracked to implementation completion (2026-03-18)

**Date:** 2026-03-18

Two instruction documents (`BUG-043-preflight-enhancement-instructions.md` and `BUG-043-browser-test-implementation-instructions.md`) were written during BUG-043 resolution but never implemented. They fell through the cracks because they were not listed in the step index with explicit completion tracking.

**Rule:** Any instruction document that specifies code to be written must appear in a tracked step index (e.g., `phase3-prompt-templates-updated.md`) with a "Status: Pending/Complete" field. Untracked specifications become dead documents. Post-phase audits should verify all referenced instruction documents have corresponding implementations.

Related: BUG-044

---


---

### LESSON-OPS-063: Fixture-specific Playwright test groups require a dedicated CI fixture job and a skip guard (2026-03-20)

**Date:** 2026-03-20

When a Playwright test group is written for a specific fixture variant (e.g., `mixed` with
2 environmental + 1 network sensor = 3 total), it **must not run** under a different fixture
variant in CI (e.g., `3sensor` with 4 sensors), because:
- `loadDashboard(page, { expectedSensorCount: N })` gates on exactly N sensor cards being
  rendered. If the active fixture has a different count, the wait never resolves and the
  test times out.
- Hardcoded `toHaveCount(N)` assertions are correct by design but will fail vacuously when
  the wrong fixture is served.

**Rule — three-part contract for every fixture-specific test group:**

1. **Skip guard in the test file:** The `test.describe` block must include a `test.beforeEach`
   that calls `testInfo.skip()` when `process.env.FIXTURE_SET` is not the expected value.
   This prevents accidental execution under the wrong fixture in both CI and local runs.

   ```javascript
   test.describe('N. My Fixture-Specific Group', () => {
     test.beforeEach(async ({}, testInfo) => {
       if (process.env.FIXTURE_SET !== 'myfixture') testInfo.skip();
     });
     // ...
   });
   ```

2. **Dedicated CI matrix job:** Add the fixture variant to the `fixture_set` matrix in
   `browser-tests.yml` and add a step that runs only the group-specific tests:

   ```yaml
   - name: Run my-fixture suite (myfixture — Group N)
     if: matrix.fixture_set == 'myfixture'
     env:
       CI: true
       FIXTURE_SET: myfixture
     run: npx playwright test tests/browser/dashboard.spec.js --grep "N\. My Fixture-Specific Group"
   ```

3. **Correct `loadDashboard` signature:** Use `{ expectedSensorCount: N }` (not `{ timeout: T }`).
   `{ timeout: T }` is a BUG-049 Firefox-SSE workaround limited to Group 13. Never copy it
   to new groups. `expectedSensorCount` gates on the exact number of sensor cards rendered,
   which is the correct readiness signal for fixture-specific tests.
   Use hardcoded integer literals in `toHaveCount()` — never read counts dynamically from
   `window._manifest`, as dynamic reads pass vacuously when the manifest is broken or empty.

**Anti-patterns:**
- `loadDashboard(page, { timeout: 30000 })` — wrong; does not gate on sensor count
- `await expect(cards).toHaveCount(await page.evaluate(() => window._manifest.sensors.length))` — wrong; vacuous if manifest broken
- Omitting the `FIXTURE_SET` skip guard — wrong; test runs under wrong fixture in CI

Related: BUG-050, BUG-049

---


---

### LESSON-OPS-064: Adding a new device category requires an endpoint audit (2026-03-21)

**Date:** 2026-03-21

When a new device category is added to the system (e.g., Phase 4 added `network` alongside
`environmental`), ALL existing endpoints must be audited for category assumptions. Endpoints
written before the category system existed will silently output incorrect data for new
categories.

**Specific endpoints that need audit when adding a category:**
- `/sensors.json` — v1 projection: should only include environmental devices
- `/api/status` — per-device fields must be category-appropriate (no `temp_valid` for ping devices)
- `/api/v2/live` — verify non-environmental devices have correct metric keys
- `/history/{id}/{metric}` — verify 404 for non-environmental history paths
- `/api/storage-stats` — verify counts only reference environmental persistence

**Rule for phase prompts:** When a prompt introduces a new device category, include an
"Endpoint Audit Checklist" section that lists every existing endpoint and its expected
behavior for the new category. Coding agents will not proactively check endpoints they
were not told to modify.

Related: BUG-052, BUG-053

---


---

### LESSON-OPS-079 — Fixture variants must include all device categories (deferred to v7.5.6.4)

**Version:** v7.5.6.1
**Symptom:** Fixture variants (3sensor, mixed, 4sensor) include system metrics in the
top-level `metrics` array but do not include an `external_push` device in `sensors`.
The system device manifest/measurement/history-stub code paths are only exercised
by the baseline fixture, not by any Playwright test variant.
**Root cause:** v7.5.6.1 scope was limited to firmware/manifest side. Test fixture
variant updates are deferred to v7.5.6.4 (Phase 6 closure).
**Fix:** v7.5.6.4 must add `nas01` to at least the `mixed` variant sensor list and
add Playwright assertions for system device presence in manifest + v2/live shape.

---


---

### LESSON-OPS-112 — Response shape mismatch between mock and firmware contract (2026-04-04)

**Context:** PR #129 Round 2 — Mock `POST /api/aggregator/add-satellite` returned nested
`{ok, satellite:{id,name,url,poll}}`. The firmware handler's `httpd_resp_sendstr` payload is flat:
`{ok, id, name, satellite_count}`. Three test assertions also expected the wrong shape. The
mismatch survived all four review passes before being caught in the Round 2 review.

**Rule:** When implementing a mock endpoint, always locate the firmware handler's literal
`httpd_resp_sendstr(...)` call and copy the response JSON from there — not from the prompt
description, not from a prior audit table, not from memory. If any prompt example differs from
the live firmware string, the **firmware wins**. Verify both the field names and the nesting level
(flat vs nested). Tests that assert only status codes without checking response body shape will
miss this class of mismatch entirely.

**Scope:** Applies to all mock implementations in `tests/mock-server/server.js` and any future
mock infrastructure added in Phase 7.

---


---

### LESSON-OPS-113 — `page.waitForResponse()` with URL predicate is always preferable to `waitForTimeout()` for network-triggered state changes (2026-04-04)

**Context:** PR #129 initial implementation used `waitForTimeout(2000)` to wait for a poll cycle
to rerender the Settings panel. Round 1 review replaced it with `waitForTimeout(2000)` on the
grounds of simplicity. Round 2 review then correctly replaced all `waitForTimeout` calls with
`page.waitForResponse(url => url.includes('/api/aggregator/gateways'))` because:

1. The timeout is arbitrary — it may pass vacuously on fast CI or fail spuriously on slow CI.
2. The `waitForResponse()` call guarantees the network round-trip has completed, meaning the
   dashboard has received the response and had the opportunity to update state.
3. `waitForResponse()` is no more complex to write and is self-documenting about what event the
   test is actually waiting for.

**Rule:** Never use `waitForTimeout(N)` as a proxy for "wait for a network response to arrive."
Use `page.waitForResponse(urlPredicate)` instead. `waitForTimeout` is only appropriate when:
- testing that something does NOT happen within a time window
- adding intentional breathing room between user-input actions that are not network-gated

**Exception:** `waitForTimeout` may be used in regression tests that verify timing behavior
(e.g., confirming an action does not fire prematurely), but must be accompanied by a comment
explaining why a response-based wait is not sufficient.

---


---

### LESSON-OPS-114 — When stubbing `window.requestManagementCredentials` in Playwright tests, stub before the click (2026-04-04)

**Context:** PR #129 Round 2 fix for the delete regression test (test 19). The original test
structure was:
1. Click the Remove button
2. `page.evaluate(() => window.requestManagementCredentials = ...)` to stub the function

This ordering failed because `dashboard.js` may invoke `requestManagementCredentials` synchronously
on the click event — before the `evaluate` promise resolves. The function stub never took effect,
the auth dialog was shown instead, the test timed out.

**Fix:** Stub `window.requestManagementCredentials` with `page.evaluate()` **before** triggering
any click that could invoke it. The correct sequence is:
1. `await page.evaluate(() => { window.requestManagementCredentials = ... })`
2. `page.on('dialog', handler)` if a browser dialog may also appear
3. Click the button

**Rule:** Any Playwright test that needs to stub a JS function called in response to a user
interaction must complete the stub BEFORE the interaction. Async evaluation (`page.evaluate`)
is not instantaneous — the click handler may fire between the click and the evaluate completing.
Stub-then-click is the only ordering that is deterministically safe.

**Applies to:** All Playwright tests that stub `window.requestManagementCredentials`,
`window.confirm`, or any other synchronously-invoked window function in `dashboard.js`.

---


---
