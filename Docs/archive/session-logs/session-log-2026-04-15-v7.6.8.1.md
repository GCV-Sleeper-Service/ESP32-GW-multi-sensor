# Session Log - v7.6.8.1

Date: 2026-04-15
PR: #181
Branch: codex/v7.6.8.1-auth-heapcap-dos-cooldown

## Scope Implemented

1. Added management auth guard to history endpoints:
- handle_history_()
- handle_api_v2_history_()

2. Capped history CSV reserve allocations with:
- std::min(est_bytes, (size_t)60000)

3. Added per-URL DoS cooldown for POST /api/aggregator/add-satellite:
- 60-second cooldown window for repeated failed probes of the same URL
- static URL+epoch storage and overwrite-oldest strategy
- HTTP 429 with Retry-After during active cooldown

4. Added ADR folder README:
- Docs/decisions/README.md

5. Ran version bump workflow:
- bash scripts/bump-version.sh 7.6.8.1

## CHECKPOINT A Evidence

- grep -A2 "handle_history_|handle_api_v2_history_" firmware/core/web-handler.h | grep -c "authenticate_management_" -> 2
- grep -c "std::min.*60000" firmware/core/web-handler.h -> 2
- bash scripts/assemble-sensor-history.sh --write -> PASS
- bash scripts/assemble-sensor-history.sh --check -> PASS

## Validation Evidence

- bash scripts/preflight.sh -> PASS (all checks)
- bash scripts/assemble-sensor-history.sh --check -> PASS

### Playwright Fixture Runs

| Command | Result |
|---|---|
| FIXTURE_SET=3sensor npx playwright test --project=chromium | PASS (99 passed, 45 skipped) |
| FIXTURE_SET=3sensor npx playwright test --project=firefox | PASS (99 passed, 45 skipped) |
| FIXTURE_SET=mixed npx playwright test --grep "Mixed" --project=chromium | PASS (7 passed) |
| FIXTURE_SET=system npx playwright test --grep "System" --project=chromium | PASS (8 passed) |
| FIXTURE_SET=aggregator npx playwright test --grep "Aggregator" --project=chromium | PASS (11 passed, 1 skipped) |

## ESPHome Output

No device flash/run was executed in this coding session. Validation was CI-style (preflight + Playwright + assembly checks) only.

## Files Changed

- firmware/core/web-handler.h
- Docs/changelog.md
- Docs/decisions/README.md
- Version/pipeline artifacts from bump script:
  - VERSION
  - dashboard/core/app-shell.js
  - dashboard/dashboard.js
  - dashboard/dashboard.html
  - dashboard/dashboard.h
  - dashboard/sensor_history_multi.h
  - firmware/core/config.h
  - firmware/core/data-model.h
  - firmware/esp32-c3-multi-sensor.yaml
  - scripts/render_sensor_config.py
  - src/gateway_manifest.h
  - tests/fixtures/generate-fixtures.js
  - tests/fixtures/manifest.json

## Notes

- Docs/decisions/SEC-ADR-001-residual-vulnerabilities.md already exists in the repository and remains part of this PR's committed tree.
