---
applyTo: "dashboard/core/**,dashboard/components/**"
---
## Dashboard Module Rules

These JS/CSS files are bundled into `dashboard/dashboard.js` and `dashboard/dashboard.html` by `scripts/bundle-dashboard.sh`. Never edit the bundled output directly.

Key constraints:
- Auth-gated fetches MUST use `authFetch()` from `dashboard/core/auth.js`
- POST requests MUST use `Content-Type: application/x-www-form-urlencoded` with `body: 'a=1'`
- Never use `credentials: 'same-origin'` — the auth modal handles credentials via Authorization header
- After editing any module, run `bash scripts/bundle-dashboard.sh --write` then `bash scripts/build-dashboard.sh --write`
- Chart.js instances are managed by `dashboard/components/charts/` — do not create global chart variables
