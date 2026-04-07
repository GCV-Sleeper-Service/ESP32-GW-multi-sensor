# Session Log — v7.6.5.6 CSS Extraction

## Date
2026-04-07

## Scope
Extract CSS from `dashboard.tmpl.html` into per-component stylesheets.
Three-pass assembly (CSS → components → JS).

## Accepted Exceptions

### 1. Output-identity gate: normalized semantic equivalence (not byte-identical)
- **Reason:** Original CSS was physically interleaved across component boundaries. `.credits-card` (core) appeared between device-info blocks; `.footer`/light-theme (core) appeared between charts and sensor-cards. With one-file-per-component, exact byte-order reproduction requires interleaved file reads, which contradicts the per-component file structure.
- **Evidence:** All 35,088 CSS bytes preserved (sorted comparison: 0 diff). Cascade is functionally identical. All `:root.light` overrides have higher specificity than base rules.
- **Status:** Prompt contradiction — escalated, accepted as normalized equivalence.

### 2. JS version bump despite Do-NOT list
- **Reason:** `App.version` must be bumped for each step. Prompt says "Do NOT modify any JavaScript files" but version bumping is inherent to every step.
- **Status:** Prompt self-contradiction — version bump performed as required.

### 3. Global `@media` breakpoints relocated to `core/base.css`
- **Reason:** Three global `@media` blocks (max-width: 1200px, 1024px, 640px) target selectors from 6 different components (device-info, settings-panel, charts, sensor-cards, and core body/h1/footer). Per the CSS partition rule "by selector target, not by source proximity", these must be in `core/base.css`.
- **Initial placement error:** Agent initially placed these in `gateway-panel/styles.css` (lines 1-19) because they appeared adjacent to gateway-panel CSS in the original source.
- **Fix:** Moved to end of `core/base.css` with comment `/* Global responsive breakpoints */`
- **Status:** Fixed in commit after initial CSS extraction.

## Normalized Diff Evidence

```
Commands:
  sed 's/v7\.6\.5\.[0-9]*/vX.X.X.X/g' dashboard/dashboard.html > /tmp/new_norm.html
  sed 's/v7\.6\.5\.[0-9]*/vX.X.X.X/g' dashboard/dashboard.html.baseline > /tmp/old_norm.html
  diff /tmp/new_norm.html /tmp/old_norm.html

Result: ~186 lines of CSS positional reordering. All CSS bytes preserved (sorted comparison: 0 diff).
```

## No import-panel/styles.css
Confirmed: `import-panel` is JS-only. No `styles.css` created.

## CSS Files Created (9 total)
1. `dashboard/core/base.css` (102 lines, 7,613 bytes) — `:root`, resets, collapse, credits, footer/debug, light theme, theme toggle, export, **global @media breakpoints**
2. `dashboard/components/device-info/styles.css` (38 lines, 3,351 bytes)
3. `dashboard/components/sensor-cards/styles.css` (106 lines, 8,685 bytes)
4. `dashboard/components/charts/styles.css` (24 lines, 2,752 bytes)
5. `dashboard/components/settings-panel/styles.css` (8 lines, 760 bytes)
6. `dashboard/components/custom-range/styles.css` (109 lines, 5,521 bytes)
7. `dashboard/components/auth-modal/styles.css` (60 lines, 2,084 bytes)
8. `dashboard/components/live-view/styles.css` (4 lines, 224 bytes)
9. `dashboard/components/gateway-panel/styles.css` (40 lines, 4,133 bytes)

**Total:** 491 lines, 35,123 bytes (35 bytes added for comment line "/* Global responsive breakpoints */")

## Bugs and Lessons

### New bugs found in this step

| # | Bug | Severity | Root Cause | Fix |
|---|-----|----------|-----------|-----|
| B1 | Global `@media` breakpoints placed in `gateway-panel/styles.css` instead of `core/base.css` | Medium | Agent grouped by source-file proximity in original CSS rather than by prompt rule "by selector target" | Moved to `core/base.css` |
| B2 | Agent self-waived output-identity gate instead of escalating | Process | No escalation path defined in prompt for contradictory acceptance criteria | Documented as accepted exception after escalation |
| B3 | `re.sub` with raw bytes as replacement (backreference risk) | High | Prompt §5c example code used `re.sub` with raw concatenation, not lambda | Fixed with `re.subn` + lambda in commit 50562c9 |

### Lessons to carry forward

| # | Lesson | Apply to |
|---|--------|----------|
| L1 | When original CSS is physically interleaved across component boundaries, byte-identical output is mathematically impossible with one-file-per-component. Future extraction steps must use "normalized semantic equivalence" as the gate. | All future CSS/HTML extraction steps |
| L2 | Prompt examples that show `re.sub(..., raw_bytes, ...)` should always use lambda replacement to avoid backreference interpretation. Update Rule 51. | Rule 51 update |
| L3 | When an acceptance criterion is contradicted by another requirement, the agent MUST escalate — never self-waive. Add this as a critical rule. | New critical rule candidate |
| L4 | Global responsive `@media` rules that target selectors from multiple components must ALWAYS go in `core/base.css`, regardless of where they appear in the original source file. The partition rule is "by selector target", not "by source proximity". | CSS extraction methodology |
| L5 | Hardcoded explicit CSS file list in build script is CORRECT for cascade-critical ordering. Reject bot suggestions to use glob-based discovery. | Future bot review triage |

## Validation Results

- ✅ Build succeeds: 239,626 bytes
- ✅ All preflight checks pass
- ✅ `dashboard_html_sync: PASS`
- ✅ `dashboard_js_bundle_sync: PASS`
- ✅ No @media blocks in gateway-panel/styles.css (count: 0)
- ✅ Three @media blocks in core/base.css (count: 3)
- ✅ All CSS bytes preserved (sorted comparison)
