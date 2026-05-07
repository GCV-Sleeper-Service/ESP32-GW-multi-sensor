---
applyTo: "tests/**"
---
## Playwright Test Rules

Tests use 4 fixture sets: 3sensor, mixed, system, aggregator. Mock server in `tests/mock-server/server.js`.

Key constraints:
- Use stable locators: `getByRole()`, `getByText()`, `getByTestId()` preferred over CSS selectors
- Test files are in `tests/browser/` — each `.spec.js` file covers one functional area
- Fixtures in `tests/fixtures/` — each set has its own manifest and mock data
- Mock server responses must match the actual firmware API contracts exactly
- Generated files (`dashboard.h`, `sensor_history_multi.h`) should be excluded from test-related diffs
- Run tests: `npx playwright test` or `npx playwright test tests/browser/specific.spec.js`
