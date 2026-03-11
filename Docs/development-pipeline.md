# Development Pipeline

_Last updated: 2026-03-10 — v7.4.1.0 normalized workflow_

This document defines how development proceeds for the ESP32 Multi-Sensor BLE Gateway, from repo edit through CI validation and device testing.

---

## 1. Operating Model

**GitHub is the canonical source of truth.**

All code, documentation, scripts, and CI configuration belong in the repository.
ZIP bundles may still be used as a delivery convenience during collaboration, but the repo is the durable record.

### Role summary

| Role | Who | Responsibility |
|------|-----|----------------|
| Design / implementation support | Assistant | Provides complete replacement files, plans, and normalization guidance |
| Repo operator | You | Applies files, commits, pushes, merges, tags |
| CI validation | GitHub Actions | Runs preflight + compile on push/PR |
| Device validation | You | Flashes and tests on the real ESP |
| Release control | You | Decides when a validated state is accepted and tagged |

---

## 2. Standard Workflow

### For each feature or fix

```bash
# 1. Create a branch
git checkout -b feature/<name>

# 2. Apply changes (code, docs, scripts)

# 3. Ensure scripts are executable (important after fresh clone / some API-created files)
chmod +x scripts/*.sh

# 4. Run quick validation
./scripts/test-local.sh --quick

# 5. Run full preflight if the quick pass is clean
./scripts/preflight.sh

# 6. Compile locally
esphome compile firmware/esp32-c3-multi-sensor.yaml

# 7. Commit and push
git add .
git commit -m "<message>"
git push origin feature/<name>

# 8. Open PR / review CI

# 9. If CI is green, flash and test on real device
esphome run firmware/esp32-c3-multi-sensor.yaml
```

### If device validation fails

- Keep the same feature branch
- Capture browser console output, curl output, compile log, and ESPHome log
- Fix with complete replacement files
- Rerun validation from preflight onward

### After merge

```bash
git checkout main
git pull --ff-only
git branch -d feature/<name>

# Tag only when the build is actually accepted
git tag v<version>
git push origin --tags
```

---

## 3. CI Pipeline

GitHub Actions runs on:

- Pushes to `main`
- Pull requests targeting `main`
- Manual `workflow_dispatch`

### What CI validates

- Helper/script existence and integrity
- Dashboard/source cross-reference checks
- JavaScript syntax/runtime smoke checks
- Dashboard minification + regeneration path
- ESPHome compile
- Artifact staging / build summary

### What CI does not validate

- Real BLE sensor reception
- Real-device boot health after flash
- Cloudflare path behavior
- Browser behavior against the live gateway
- Battery / RSSI / physical-environment edge cases

### Practical note

Documentation-only commits still trigger compile CI.
Batch doc-only normalization work into a single commit when possible to avoid unnecessary runs.

---

## 4. Versioning

### Scheme

The project uses a four-part version scheme:

```
major.minor.patch.hotfix
```

Examples:

- `7.4.0.0` — feature baseline
- `7.4.0.2` — hotfix within the same feature track
- `7.4.1.0` — next feature in the 7.4 line

### Version-bearing locations (must stay synchronized)

There are **six** version-bearing locations that must be kept aligned:

1. Root `VERSION` file
2. YAML header comment in `firmware/esp32-c3-multi-sensor.yaml`
3. `register_history_handler()` version string in YAML/C++ lambda path
4. `dashboard_link` publish_state version text in YAML
5. `App.version` in `dashboard/dashboard.js`
6. Version comment/header text in `dashboard/dashboard.html`

If one moves, all six must move.

### Additional normalization note

Other files may also contain historical version references in comments or documentation.
Those do not all need to match the current version if they are explicitly documenting past behavior.
Only current-state version locations and misleading stale headers must be synchronized.

---

## 5. Dashboard Build Discipline

The dashboard pipeline is:

```bash
./scripts/minify-dashboard.sh
./scripts/generate-header.sh
./scripts/preflight.sh
esphome compile firmware/esp32-c3-multi-sensor.yaml
```

### Source-of-truth rules

- `dashboard.html` is the editable source of truth
- `dashboard.js` must stay synchronized with the JS embedded in `dashboard.html`
- `dashboard.min.html` is build output only and remains gitignored
- `dashboard.h` is generated but committed
- After any HTML or embedded-JS change, regenerate `dashboard.h`

---

## 6. Script Permissions

A recurring operational issue is execute-bit loss on shell scripts.
This can happen after fresh clone, after some API-created file writes, or after certain replacement-file workflows.

Always run:

```bash
chmod +x scripts/*.sh
```

at least once after clone, and again after any session that introduced new script files.

This requirement should be reflected in:

- `README.md`
- Fresh-start handoff
- Local setup instructions

---

## 7. Documentation Update Rules

For every accepted build, update as applicable:

- `VERSION`
- `Docs/changelog.md`
- `Docs/build-history.md`
- `Docs/esp32-gateway-fresh-start-handoff.md`
- `Docs/bugs-and-lessons-learned.md`
- Relevant planning docs
- A session log in `Docs/session-log-<date>-<version>-<topic>.md`

### Documentation/code alignment rules

To keep the repo coherent:

- `README.md` must describe current checked-in behavior only
- `architecture.md` must describe the current design and explicitly mark planned capability as planned
- `future-plans.md` and the implementation-plan docs hold the roadmap
- If a session changes next steps, delivery process, or constraints, update both the session log and the fresh-start handoff
- If a doc makes a concrete claim about behavior, that claim should be traceable to either code, build output, or a validated operational result

---

## 8. Local Environment Baseline

### Prerequisites

- ESPHome 2025.11.0 or later
- Node.js tooling needed for dashboard minification
- Git

### Initial local setup

```bash
cd /root/config
git clone https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor.git
cd ESP32-GW-multi-sensor
cp secrets/secrets-example.yaml secrets/secrets.yaml
# edit secrets/secrets.yaml
ln -s ../secrets/secrets.yaml firmware/secrets.yaml
chmod +x scripts/*.sh
```

### Build a specific tagged version

```bash
cd /root/config/ESP32-GW-multi-sensor
git fetch --all --tags
git checkout v7.4.1.0
chmod +x scripts/*.sh
esphome compile firmware/esp32-c3-multi-sensor.yaml
```

---

## 9. Gitignore Baseline

```
firmware/secrets.yaml
secrets/*.yaml
!secrets/secrets-example.yaml
.build/
.pio/
build-logs/
artifacts/
firmware/.esphome/
dashboard/dashboard.min.html
node_modules/
```

---

## 10. Release-Readiness Checklist

Before tagging a build:

- [ ] Preflight passes
- [ ] Compile passes
- [ ] Dashboard regeneration path used if dashboard changed
- [ ] Version synchronized in all six locations
- [ ] Docs updated
- [ ] Device test performed
- [ ] Session log written
- [ ] Handoff updated
