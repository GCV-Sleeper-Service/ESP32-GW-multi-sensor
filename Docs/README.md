# ESP32-GW-multi-sensor

ESP32-C3 multi-sensor BLE gateway for ThermoPro TP357 sensors.

This project receives BLE broadcasts from multiple ThermoPro sensors, exposes a browser-based dashboard, keeps recent history in RAM plus longer persisted history in flash, and supports local or internet-accessed monitoring where applicable.

## Current project status

- Canonical source: **GitHub repository**
- Current known-good product baseline before the next feature phase: **v7.3.4.2**
- Current workflow focus: **repo/CI hardening first, then `/api/status`, then Import v1**

## What the gateway does

- live temperature and humidity monitoring
- multi-sensor dashboard UI
- charted history review
- CSV export features
- gateway management actions
- preflight validation and cloud compile via GitHub Actions

## Repository layout

```text
ESP32-GW-multi-sensor/
  .github/workflows/         GitHub Actions CI
  dashboard/                 HTML/JS/UI assets and embedded header sources
    dashboard.html
    dashboard.js
    dashboard.h
    sensor_history_multi.h
  firmware/                  ESPHome firmware entrypoint
    esp32-c3-multi-sensor.yaml
  partitions/                Partition table definitions
    esp32-c3-multi-partitions.csv
  scripts/                   Local helper scripts
    preflight.sh
    generate-header.sh
    deploy-to-esphome.sh
    compile-with-log.sh
    test-local.sh            # if present in current branch
  secrets/
    secrets-example.yaml     Public template only
    secrets.yaml             Local only, gitignored
  Docs/                      Continuity, build history, notes, worksheets
  VERSION
```

## Quick start

### 1. Clone the repo

```bash
git clone https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor.git
cd ESP32-GW-multi-sensor
```

### 2. Provide local secrets

The local canonical secrets file is:

```text
secrets/secrets.yaml
```

For local ESPHome compile, `firmware/secrets.yaml` must also resolve correctly. On Linux/LXC, the recommended approach is a symlink:

```bash
ln -s ../secrets/secrets.yaml firmware/secrets.yaml
```

### 3. Run local validation

Quick preflight only:

```bash
./scripts/test-local.sh --quick
```

Full local validation:

```bash
./scripts/test-local.sh
```

Direct compile, if needed:

```bash
esphome compile firmware/esp32-c3-multi-sensor.yaml
```

## Development workflow

The repository is the source of truth. The intended workflow is:

1. work in a local clone
2. run preflight / compile locally
3. push to a feature branch
4. let GitHub Actions validate
5. flash and test on the real device only after CI is green
6. merge after code review + device validation

### Recommended branch flow

```bash
git checkout -b feature/import-v1
./scripts/test-local.sh --quick
git add .
git commit -m "Start Import v1"
git push origin feature/import-v1
```

## CI

GitHub Actions is intended to handle all checks that do **not** require the physical device, including:

- preflight file/reference validation
- JavaScript syntax/runtime smoke checks
- ESPHome compile
- artifact staging
- workflow summaries

Real-device validation remains manual:

- flashing firmware
- BLE sensor validation
- browser testing against the real gateway
- Cloudflare/internet path validation

## Documentation map

Start here:

- `Docs/esp32-gateway-master-fresh-start-handoff-2026-03-08.md` — primary continuity / restart document
- `Docs/development-pipeline.md` — workflow/process reference
- `Docs/build-history.md` — curated build ledger

Operational/version docs:

- versioned `documentation.md`
- versioned `development-notes.md`
- versioned test worksheet(s)
- `Docs/device-test-report-template.md` — structured post-flash testing template

## Planned next steps

Near-term sequence:

1. verify CI artifact contents end-to-end
2. add `/api/status`
3. add Playwright browser automation with mocked backend data
4. implement **Import v1**

Import v1 should stay narrow and low risk:

- replacement-first import model
- strong validation before write
- accepted/rejected row reporting
- protected destructive path

## Notes

- Do not commit real secrets.
- Prefer local editing plus Git commits over GitHub web edits for firmware/dashboard changes.
- Git history preserves older artifacts and docs even when the Docs folder is later consolidated.

## License

MIT
