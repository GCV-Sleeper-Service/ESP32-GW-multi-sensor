# Bugs and lessons learned addendum — runtime/UI source-truth fix

## Latest items first

### 2026-03-13 — generated dashboard artifacts drifted from source
**Bug:** `dashboard.html` and the embedded artifacts (`dashboard.min.html`, `dashboard.h`) were not aligned, so the embedded dashboard could still run stale client logic.

**Lesson:** Edit `dashboard/dashboard.html` first, then regenerate `dashboard/dashboard.min.html` and `dashboard/dashboard.h`. Treat `dashboard.html` as the source of truth.

### 2026-03-13 — dashboard status fields depended on legacy entity polling
**Bug:** The dashboard expected `/sensor/Free Heap` and `/sensor/Uptime`, while the firmware already exposed authoritative status data from `GET /api/status`.

**Lesson:** Dashboard device-status widgets should hydrate from `GET /api/status` directly.

### 2026-03-13 — built-in diagnostics regressed separately from dashboard
**Bug:** The ESPHome built-in web page lost `Free Heap`, `Uptime`, and `Loop Time` because those diagnostic sensors were not exposed in the YAML.

**Lesson:** Runtime validation must cover both:
- the custom dashboard
- the built-in ESPHome web page

### 2026-03-13 — preflight gap
**Bug:** Build/preflight could pass while embedded dashboard artifacts still reflected old client logic.

**Lesson:** Add a preflight rule that verifies generated dashboard artifacts are synchronized with the source and that embedded assets also prefer `/api/manifest` and include `/api/status` hydration.
