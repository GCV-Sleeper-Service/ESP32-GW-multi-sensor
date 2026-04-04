# Bugs Fixed & Lessons Learned

_Last updated: 2026-04-04 — v7.6.0.5 (PR #129): Added LESSON-OPS-112, LESSON-OPS-113, LESSON-OPS-114._

This file tracks significant bugs, root causes, fixes, and operational lessons.
It is also the place where project guardrails are recorded so they are not re-learned in later sessions.

Both sections are in **reverse chronological order** — most recent entry first.

## Bug Fixes

### LESSON-OPS-114 — Stub `window.requestManagementCredentials` before the click that triggers it (2026-04-04)

**Date:** 2026-04-04  
**Version:** v7.6.0.5  
**Source:** PR #129 Round 2 Fix 4 — delete regression test stubbed auth after the click; the dashboard invoked the credential prompt synchronously on click before the `page.evaluate()` could complete.

**Lesson:**  
When stubbing `window.requestManagementCredentials` (or any synchronous callback called on a click event) in Playwright tests, the stub must be installed via `page.evaluate()` **before** the click that triggers it. If you call `page.evaluate()` after the click, the dashboard may invoke the original function synchronously during the click handler before your evaluate can install the stub.

**Rule:** Always stub synchronous callbacks before the trigger action. Pattern:  
```js
await page.evaluate(() => {
  window.requestManagementCredentials = async () => 'mock-token';
});
await page.click('#trigger-button');  // stub is already in place
```

---

### LESSON-OPS-113 — Use `page.waitForResponse()` with URL predicate for network-triggered state changes (2026-04-04)

**Date:** 2026-04-04  
**Version:** v7.6.0.5  
**Source:** PR #129 Round 2 Fixes 2 & 3 — multiple regression tests used `waitForTimeout()` where `page.waitForResponse()` was correct.

**Lesson:**  
`page.waitForResponse()` with a URL predicate is always preferable to `waitForTimeout()` for network-triggered state changes. The response guarantees the state has actually been written server-side, not merely that time has passed. `waitForTimeout()` is a fixed sleep: it will be either too short (flaky on slow CI) or too long (wasted CI time).

**Rule:** When a test triggers a network request and then verifies state that depends on that request completing, use `page.waitForResponse(urlOrPredicate)` instead of `waitForTimeout(N)`. Only use `waitForTimeout()` for UI animation delays or other non-network timing that has no observable network signal.

```js
// ❌ Unreliable
await page.click('#add-btn');
await page.waitForTimeout(1000);
// state may or may not have been written

// ✅ Reliable
const responsePromise = page.waitForResponse(r => r.url().includes('/api/aggregator/add-satellite'));
await page.click('#add-btn');
await responsePromise;
// state is guaranteed written
```

---

### LESSON-OPS-112 — Response shape mismatch between mock and firmware contract (2026-04-04)

**Date:** 2026-04-04  
**Version:** v7.6.0.5  
**Source:** PR #129 Round 2 Fix 1 — mock `POST /api/aggregator/add-satellite` returned nested `{ok, satellite:{id,name,url,poll}}` but the firmware contract is flat `{ok, id, name, satellite_count}`.

**Lesson:**  
When implementing a mock endpoint, always cross-check the mock's success response field names and nesting structure against the firmware handler's actual `httpd_resp_sendstr` payload — not just the status code. Status code correctness does not imply response shape correctness. This class of error passes mock-level contract tests but fails assertion-level tests that check specific fields.

**Rule:** Before publishing any mock endpoint implementation, locate the exact `httpd_resp_sendstr` (or equivalent) call in the live firmware handler (`dashboard/sensor_history_multi.h`) and verify:
1. Each field name in the mock response matches the firmware exactly
2. The nesting structure matches (flat vs nested object)
3. The field types match (string vs int vs bool)

Mock-first development (writing the mock from a prompt example without reading the firmware) will produce this defect. The firmware handler is the canonical contract source — not the prompt, not the audit document, not the test.

---
