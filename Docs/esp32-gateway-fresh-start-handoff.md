# ESP32 Gateway — Fresh Start Handoff

_Last updated: 2026-03-08_
_Repo: `GCV-Sleeper-Service/ESP32-GW-multi-sensor`_
_Current version: v7.3.5.0_
_Branch: `main`_

This is the single-source continuity document for resuming development in a fresh session. It provides everything needed to pick up where the last session left off without reconstructing context from memory.

---

## Project Summary

An ESP32-C3 SuperMini BLE gateway that receives ThermoPro TP357 temperature/humidity broadcasts and serves an embedded browser dashboard. The device retains 24h of history in RAM and up to 45 days of hourly history persisted to a dedicated NVS flash partition. No cloud services, database, or Home Assistant required.

See [architecture.md](architecture.md) for the full technical design.

---

## Current State

### What is working

- 3-sensor BLE reception (Office, First Floor, Outside)
- Live dashboard with real-time and 15-minute averaged charts
- 45-day hourly persistence to dedicated 512 KiB history partition
- Boot-time restore of persisted history
- CSV export (per-sensor and serialized Export All)
- Dark/light mode with proper chart redraw
- `/api/status` health endpoint (version, uptime, sensor health, heap)
- `/api/storage-stats` (partition sizes, NVS usage, retention estimates)
- Management actions (reboot, delete data) with Basic auth + lockout
- GitHub Actions CI: preflight + compile on every push/PR to `main`
- Branch protection on `main` requiring CI green before merge

### Repository coordinates

- **Repo:** `https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor`
- **Current version:** v7.3.5.0 (VERSION file + App.version in dashboard.js)
- **Branch:** `main` (only branch, feature branches created per-task)
- **Last CI status:** Green
- **Device status:** Running, accessible on LAN and via Cloudflare

### Resource usage (last measured)

| Metric | Value |
|--------|-------|
| RAM | ~15.8% of 327 KiB |
| Flash | ~87.5% of 1.69 MiB (per OTA slot) |
| Free heap | ~84 KiB |
| History partition | 512 KiB dedicated |
| NVS entries | ~1274 / 16128 (7.9%) |

---

## Development Environment

### Infrastructure

- **ESPHome container:** LXC container on same LAN as ESP devices, with internet access
- **Repo clone location:** `/root/config/ESP32-GW-multi-sensor` (on the LXC container)
- **Windows workstation:** GitHub Desktop, Visual Studio Code, Git — same LAN
- **ESP device:** ESP32-C3 SuperMini at 192.168.120.189
- **Cloudflare:** Reverse proxy for internet access (separate from development)

### Local workflow

```bash
cd /root/config/ESP32-GW-multi-sensor
git fetch --all --tags
git checkout -b feature/<name>

# Make changes...

./scripts/test-local.sh --quick    # Preflight only
./scripts/test-local.sh            # Preflight + compile

git add <changed files>
git commit -m "<description>"
git push origin feature/<name>

# Open PR on GitHub → CI runs → flash and test → merge
```

### Secrets

The real `secrets/secrets.yaml` is gitignored. For compile, `firmware/secrets.yaml` must be a symlink:

```bash
ln -s ../secrets/secrets.yaml firmware/secrets.yaml
```

CI generates temporary dummy secrets automatically.

---

## Completed Work Summary

### v7.3.5.0 (current) — /api/status endpoint

- Added `GET /api/status` returning version, uptime, sensor count, per-sensor health, heap
- Fixed JSON truncation bug caused by 64-byte `snprintf` buffer (split into multiple print calls)
- First real PR (#1) through the GitHub workflow: feature branch → draft PR → CI green → device test → merge
- Branch protection configured and validated

### v7.3.4.2 (baseline) — Dashboard hotfix + repo normalization

- Fixed `Export All` HTTP 502 (serialized retained-history fetches)
- Fixed chart point markers not following sensor recolor
- Fixed 15-minute markers being oversized
- Fixed theme toggle not forcing chart redraw
- Repository normalized to canonical paths (no more versioned filenames)
- GitHub Actions CI pipeline established
- Helper scripts added (preflight, test-local, compile-with-log, deploy)

### Earlier history

v7.3.4.1 fixed startup blocker. v7.3.4 introduced Phase 1 structural work (App.State chokepoints, centralized bindEvents). v7.3.3 was the stabilization baseline. See [changelog.md](changelog.md) for full history back to v1.

---

## What Comes Next — Priority Order

### 1. Import v1 (next feature)

A `POST /api/import` endpoint that accepts CSV data and writes it to the history partition.

**Key design decisions:**
- Replacement-first model (imported data replaces, not merges)
- Strong validation before write: sensor ID, timestamps, value ranges, duplicates, storage impact
- Import report returned as JSON (accepted/rejected rows with reasons)
- Basic auth protected
- Dashboard UI: import button in management section, file picker, validation report

**Delivery approach:** Feature branch `feature/import-v1`, files as complete replacements, incremental commits (endpoint first → dashboard UI → integration testing).

**Files to modify:** `sensor_history_multi.h`, `dashboard.html`, `dashboard.js`, `dashboard.h` (regenerated), `preflight.sh`, `VERSION`.

### 2. Custom date range selector

Additional "Custom Range" button in dashboard history controls. Date picker based on dates actually present in stored history. Dashboard-only change, no backend modifications.

### 3. Playwright browser test automation

Mock backend serving dashboard HTML locally. Automated checks for: dashboard loads, theme toggle, export button, sensor cards, import UI. Second CI workflow (`browser-tests.yml`) running alongside the existing compile CI.

### 4. Configurable sensor count

Comments-based configuration in the source to easily add a 4th sensor or reduce to fewer without breaking anything.

See [future-plans.md](future-plans.md) for the complete roadmap beyond these immediate items.

---

## Key Lessons & Patterns

These patterns have been established through trial and error and should be followed:

1. **Any `snprintf` targeting a fixed buffer must be audited for worst-case output length.** The `char num[64]` pattern is used throughout `sensor_history_multi.h`. Use the split-print pattern or increase buffer size with a documented rationale.

2. **File renames require updating all internal references.** Scripts, YAML, and header includes must be normalized together.

3. **Comments in YAML do not affect ESPHome behavior.** Only actual configuration matters for `!secret` resolution and path handling.

4. **Cloud CI and local compile have different secrets models.** Local uses symlink to real secrets; CI generates temporary compile-only values.

5. **Hidden build directories break artifact uploads.** Firmware binaries must be staged into visible directories for GitHub Actions artifacts.

6. **Dashboard event wiring, chart redraw, and request concurrency are fragile areas.** Always regression-test these surfaces.

See [bugs-and-lessons-learned.md](bugs-and-lessons-learned.md) for the full accumulated record.

---

## Documentation Map

| Document | Purpose |
|----------|---------|
| This file | Complete context for resuming development |
| [architecture.md](architecture.md) | Software design, data flows, retention model, configuration |
| [development-pipeline.md](development-pipeline.md) | Workflow, CI, process, and phases |
| [changelog.md](changelog.md) | Version history |
| [build-history.md](build-history.md) | Curated build ledger |
| [bugs-and-lessons-learned.md](bugs-and-lessons-learned.md) | Fixes, patterns, pitfalls |
| [future-plans.md](future-plans.md) | Roadmap and feature assessment |
| [device-test-report-template.md](device-test-report-template.md) | Post-flash testing checklist |

---

## How to Start the Next Session

Provide the assistant with:

1. This document (or the repo URL — the assistant can clone and read it)
2. Current branch and any uncommitted state
3. What you want to work on

Example opening message:

> Continuing the ESP32 BLE gateway project.
> Repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor
> Main is current at v7.3.5.0. No uncommitted changes.
> Next step: Import v1 feature.
> Please clone the repo and begin designing the Import v1 endpoint.

The assistant should clone the repo, review the Docs, and begin preparing the implementation.
