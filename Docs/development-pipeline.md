# Development Pipeline

_Last updated: 2026-03-10 — v7.4.1.0_

This document defines how development works for the ESP32 Multi-Sensor BLE Gateway, from code changes through CI validation to device deployment.

---

## Operating Model

**GitHub is the canonical source of truth.** All code, documentation, scripts, and CI configuration live in the repository. ZIP bundles are no longer used for delivery or continuity.

### Role Summary

| Role | Who | What |
|------|-----|------|
| Code author | Claude (assistant) | Provides complete replacement files |
| Commit gateway | You | Applies files, commits, pushes |
| CI validation | GitHub Actions | Automatic on push/PR |
| Device testing | You | Flash, curl, browser check |
| Bug diagnosis | Claude (assistant) | From your reported output/logs |
| Release tagging | You | After merge + device confirmation |

---

## Development Workflow

### For each feature or fix

```
1.  Create feature branch
      git checkout -b feature/<name>

2.  Apply code changes (complete replacement files from assistant)

3.  Quick local validation
      ./scripts/test-local.sh --quick

4.  Local compile (if quick test passes)
      esphome compile firmware/esp32-c3-multi-sensor.yaml

5.  Commit and push
      git add <changed files>
      git commit -m "<description>"
      git push origin feature/<name>

6.  Open draft PR on GitHub

7.  CI runs automatically — check Actions tab

8.  If CI green: flash to ESP and test on real device
      esphome run firmware/esp32-c3-multi-sensor.yaml

9.  Device validation
      - curl endpoints
      - browser dashboard check
      - fill in test report if significant change

10. If device test fails:
      - report the failure (curl output, browser console, ESPHome logs)
      - assistant provides fixed replacement files
      - repeat from step 2 on same branch

11. When everything passes:
      - convert draft PR to ready
      - merge PR
      - pull main locally
      - delete feature branch
      - tag if milestone version
```

### After merge

```bash
cd ~/config/ESP32-GW-multi-sensor
git checkout main
git pull --ff-only
git branch -d feature/<name>

# If milestone version:
git tag v<x.y.z>
git push origin --tags
```

---

## CI Pipeline

GitHub Actions runs on every push to `main`, every PR targeting `main`, and manual `workflow_dispatch`.

> **Note:** Documentation-only commits also trigger CI (~4.5 min compile). Batch all doc-only changes into a single commit to minimize CI runs.

### What CI validates

1. Preflight checks (file existence, cross-reference integrity, JS syntax + runtime smoke)
2. ESPHome firmware compile
3. Build summary output
4. Firmware artifact staging and upload

### What CI does NOT cover (manual)

- Flashing firmware to the real device
- BLE sensor validation
- Browser testing against the live gateway
- Cloudflare/internet path validation

### Branch protection on `main`

- Requires pull request before merging
- Requires the `preflight-and-compile` status check to pass
- No direct pushes to `main`

> **Exception:** Documentation-only normalization commits may be pushed directly to `main` by the repository owner when no code changes are involved and CI is expected to pass without review.

---

## Versioning

### Scheme

The project uses a four-part version: `major.minor.patch.hotfix`

- **Major** (7.x) — Significant architecture changes
- **Minor** (7.4.x) — New features
- **Patch** (7.3.5.x) — Bug fixes, small additions
- **Hotfix** (7.3.4.2) — Targeted fixes within a patch

### Version locations (must stay synchronized)

- `VERSION` file (root)
- YAML header comment (`firmware/esp32-c3-multi-sensor.yaml`)
- `App.version` in `dashboard/dashboard.js`
- `register_history_handler()` call in YAML lambda
- HTML header comment in `dashboard/dashboard.html`

### Tags

Tag every accepted build with `v` prefix: `v7.3.5.0`, `v7.4.0`, etc.

---

## Scripts Reference

| Script | Purpose | Usage |
|--------|---------|-------|
| `scripts/test-local.sh` | Full local validation | `./scripts/test-local.sh` or `--quick` |
| `scripts/preflight.sh` | Cross-reference and syntax checks | `./scripts/preflight.sh` |
| `scripts/compile-with-log.sh` | Compile with timestamped log | `./scripts/compile-with-log.sh` |
| `scripts/generate-header.sh` | Regenerate dashboard.h from HTML | `./scripts/generate-header.sh` |
| `scripts/minify-dashboard.sh` | Minify dashboard.html → dashboard.min.html | `./scripts/minify-dashboard.sh` |
| `scripts/deploy-to-esphome.sh` | Checkout version + preflight + compile | `./scripts/deploy-to-esphome.sh v7.3.5.0` |

---

## File Delivery Model

The assistant delivers complete replacement files, not patches or diffs. This means:

- Every modified file is delivered as a full, ready-to-copy replacement
- You copy the file into the repo, overwriting the existing version
- No manual merging is required
- The preflight script validates cross-references after replacement

When HTML changes, `dashboard.h` must be regenerated via the full pipeline:

```bash
./scripts/minify-dashboard.sh
./scripts/generate-header.sh
```

---

## Documentation Updates Per Build

For each accepted build, update:

- `VERSION` file
- `Docs/changelog.md` (add entry)
- `Docs/build-history.md` (add entry)
- `Docs/esp32-gateway-fresh-start-handoff.md` (update current state)
- `Docs/bugs-and-lessons-learned.md` (if applicable)
- Add a session log: `Docs/session-log-<date>-v<version>.md`

The assistant will prepare these updates alongside the code changes.

---

## Generated Files Policy

Generated files are committed to Git:

- `dashboard.h` (generated from dashboard.html via minification pipeline)
- Documentation and notes

This ensures every tagged version is self-contained and buildable without running generation steps first.

---

## Secrets Handling

Real secrets never enter Git.

- `secrets/secrets-example.yaml` — committed, public template
- `secrets/secrets.yaml` — local only, gitignored
- `firmware/secrets.yaml` — symlink to `../secrets/secrets.yaml`, gitignored
- CI generates temporary compile-only dummy secrets per run

---

## Local Build Environment

### Prerequisites

- ESPHome 2025.11.0 or later
- Node.js + `html-minifier-terser` (for dashboard pipeline: `npm install -g html-minifier-terser`)
- Git

### LXC Container Setup (one-time)

```bash
cd /root/config
git clone https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor.git
cd ESP32-GW-multi-sensor
cp secrets/secrets-example.yaml secrets/secrets.yaml
# Edit secrets/secrets.yaml with real credentials
ln -s ../secrets/secrets.yaml firmware/secrets.yaml
```

### Building a specific tagged version

```bash
cd /root/config/ESP32-GW-multi-sensor
git fetch --all --tags
git checkout v7.3.5.0
esphome compile firmware/esp32-c3-multi-sensor.yaml
```

---

## Gitignore Rules

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

Raw build logs go in `build-logs/` (gitignored). Curated documentation goes in `Docs/` (committed).
