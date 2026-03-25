Prompts Audit — Phase 5 and Phase 6

### v7.5.5.4 (Aggregator Playwright Tests)

**Issues found against the prompt writing guide:**

1. **Stale codebase assumptions (Guide §11):** The prompt was written pre-v7.5.5.3 merge. Now that v7.5.5.3 introduced significant changes (DOM-safe rendering via `createElement`/`textContent`, namespaced IDs with `_deviceId`/`_domId` preserved, environmental card live updates, per-gateway tab refresh), the v7.5.5.4 prompt's Required Reading section and mock server patterns need updating.

2. **Missing anti-patterns from v7.5.5.3 review findings (Guide §10):** The PR #70 review revealed:
   - The `api-status.json` fixture keeps losing its heap fields and trailing newline — the prompt needs an explicit warning
   - The agent repeatedly produced fixtures with literal `\n` instead of real newlines — the prompt should warn about JSON fixture formatting
   - The `FIXTURE_SET` environment variable pattern needs explicit instruction on how to add the `aggregator` variant

3. **Missing reference to aggregator mock endpoints in server.js:** The v7.5.5.3 PR already added mock `/api/aggregator/gateways` returning 404 in satellite mode. The v7.5.5.4 prompt should reference this existing route and explain how to extend it for aggregator fixtures rather than creating from scratch.

4. **No explicit `waitForAggregatorReady` helper specification (Guide §5 — specify function signatures):** The prompt mentions it but doesn't give the exact implementation pattern. Given that the guide emphasizes "state the correct behavior precisely," the helper should be fully specified.

5. **Pre-condition check commands are stale:** Should include the `FIXTURE_SET=aggregator` variant that will be added in this step.

### v7.5.5.5 (Phase 5 Closure)

**Issues found:**

1. **Stale current status (Guide §11):** States "v7.5.5.4 complete and merged" but the pre-condition checks and documentation update instructions don't account for any bugs/lessons discovered during v7.5.5.3 or v7.5.5.4.

2. **Missing new BUGs/LESSONs from v7.5.5.3:** The closure step should reference the new findings from PR #70 (escaping issues, namespaced ID breakage, environmental card live update gap, `out.reserve()` sizing for manifest JSON). These need to be in `bugs-and-lessons-learned.md` entries and the prompt should explicitly list them.

3. **`aggregator-setup.md` section lacks the escaping/security context:** The user-facing setup guide should mention that gateway names should be plain text (no HTML special characters), given the review findings.

4. **Closure gate doesn't mention fixture formatting validation:** Given the recurring `api-status.json` issue, the closure gate should include "all fixture JSON files are valid JSON with proper formatting and trailing newlines."

### v7.5.6.0 (Phase 6 — POST /api/ingest)

**Issues found:**

1. **Stale codebase context (Guide §11 — cascading decisions):** The prompt was written against a v7.5.4.x codebase. Phase 5 added:
   - `AGGREGATOR_ENABLED` conditional compilation
   - New `#include` files in the firmware
   - `sensor_history_multi.h` changes (aggregator endpoints, `base_url`, cached manifests)
   - The `add_common_headers_()` method pattern
   - New aggregator routes that the ingest endpoint must coexist with

2. **Missing Required Reading entries:** Should include `dashboard/sensor_history_multi.h` (current version with aggregator endpoints), `src/aggregator_config.h`, and the BUG-063 proxy URL lesson.

3. **Missing aggregator interaction consideration:** The `/api/ingest` endpoint receives data from external sources. In aggregator mode, should the aggregator accept ingest requests and forward them to satellites? The prompt is silent on this. At minimum, it should state: "In aggregator mode, `/api/ingest` operates on local devices only — it does NOT proxy to satellites."

4. **Pre-condition checks are stale:** Should reference the current test suite size (now 98+ tests, not 88+) and include `FIXTURE_SET=aggregator` tests if v7.5.5.4 has been merged by then.

5. **Missing anti-pattern from v7.5.5.2 (Guide §10):** The `/api/ingest` endpoint will need `add_common_headers_()` (not manual `Cache-Control` headers) — this was a review finding on PR #68 that should be called out explicitly.

6. **No mention of `LESSON-OPS-056` compliance:** The response handling should use `beginResponse` not `beginResponseStream` for small JSON responses, per the lesson from v7.5.5.2.

