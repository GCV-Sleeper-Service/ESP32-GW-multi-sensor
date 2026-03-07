# ESP32 Gateway Development Pipeline

_Last updated: 2026-03-06_

## Purpose

This document defines the recommended development and delivery workflow for the ESP32 Multi-Sensor BLE Gateway project so future iterations are faster, more reproducible, and less dependent on one-off ZIP transfers.

The goal is to reduce friction in this cycle:

1. user reports build/test results
2. assistant prepares next version
3. user downloads ZIP, unpacks, copies to ESPHome LXC, archives old files manually
4. user runs compile/build and tests again
5. if files expire in-chat, baseline must be re-uploaded

The recommended solution is to make **GitHub the canonical source of truth** and use ZIP bundles only as a temporary transport format when needed.

---

## Recommended operating model

### Canonical source of truth
Use a GitHub repository as the permanent project record.

That repository should contain:
- firmware files
- dashboard source and generated header
- partition layout
- helper scripts
- versioned documentation
- versioned development notes
- test worksheet(s)

### Delivery model
Use this hybrid model:
- **GitHub repo** = system of record
- **chat-delivered ZIP** = temporary handoff artifact only when needed
- **tagged GitHub versions** = official known-good build checkpoints

This gives the best balance between reliability and convenience.

---

## Why this is better

### 1. Fewer re-uploads
If the repository is public, a fresh chat session can start from the repo/tag instead of requiring all files to be uploaded again.

### 2. Better rollback
Any known-good tag can be checked out directly in the ESPHome LXC and rebuilt.

### 3. Cleaner deployment
Instead of unzip + SCP + manual folder juggling, the container can `git pull`, `git checkout <tag>`, and compile.

### 4. Better continuity
Version headers, docs, changelog, and code can all stay synchronized under source control.

---

## Important constraint

The assistant can prepare code, documentation, commit-ready content, release notes, and exact file-level changes, but cannot directly push to your GitHub repository from this chat environment.

So the working model is:
- assistant prepares the versioned update
- user commits/pushes accepted changes to GitHub
- future sessions use GitHub as baseline

---

## Recommended repository structure

```text
ESP32-Gateway/
├─ firmware/
│  └─ esp32-c3-multi-sensor.yaml
├─ dashboard/
│  ├─ dashboard.html
│  ├─ dashboard.js
│  ├─ dashboard.h
│  └─ sensor_history_multi.h
├─ partitions/
│  └─ esp32-c3-multi-partitions.csv
├─ scripts/
│  ├─ generate-header.sh
│  ├─ preflight.sh
│  └─ deploy-to-esphome.sh
├─ Docs/
│  ├─ v7.x.x-documentation.md
│  ├─ v7.x.x-development-notes.md
│  ├─ v7.x.x-consolidated-test-worksheet.md
│  └─ v7.x.x-pre-phase1-expert-opinion.md
├─ secrets/
│  └─ secrets-example.yaml
├─ VERSION
├─ README.md
└─ .gitignore
```

### Why this structure works well
- it separates firmware, dashboard, scripts, and docs cleanly
- it keeps generated deliverables close to their source
- it makes version auditing easier
- it fits the project’s current documentation-heavy workflow

---

## Generated files policy

For this project, generated files should be committed to Git.

That includes at least:
- `dashboard.h` generated from dashboard HTML
- versioned documentation and notes
- test worksheet files

### Why commit generated files here
For this project, reproducibility and handoff reliability matter more than keeping the repo “pure.”

Advantages:
- every tagged version is self-contained
- rebuilds are easier from older tags
- fewer “works only after regeneration” problems
- less ambiguity in fresh-start sessions

---

## Versioning model

### Branching
Keep the workflow simple:
- `main` = latest known-good build
- optional `dev` branch only if you want a staging area

For this project, `main + tags` is usually enough.

### Tags
Tag every accepted build, for example:
- `v7.3.4.1`
- `v7.3.4.2`
- `v7.4.0`

### VERSION file
Add a plain text `VERSION` file in repo root.

Example:

```text
7.3.4.2
```

Use it as the one obvious place to confirm the current build number.

---

## Recommended release discipline

A build becomes a known-good tag only after:
1. assistant-side preflight/static checks pass
2. ESPHome compile succeeds on user side
3. user smoke tests pass on actual device/browser paths
4. version headers/comments/docs are aligned

Only then:
- commit
- tag
- push
- optionally create a GitHub Release

---

## ESPHome LXC workflow

### Initial one-time setup
Clone the repo once into the ESPHome container.

```bash
cd /config
git clone https://github.com/YOUR-USER/YOUR-REPO.git esp32-gateway
cd esp32-gateway
```

### Build latest main
```bash
cd /config/esp32-gateway
git checkout main
git pull --ff-only
esphome compile firmware/esp32-c3-multi-sensor.yaml
```

### Build a specific tagged version
```bash
cd /config/esp32-gateway
git fetch --all --tags
git checkout v7.3.4.2
esphome compile firmware/esp32-c3-multi-sensor.yaml
```

### Why this is better than ZIP + SCP
- no repeated unpacking
- no manual copy into `/config`
- no manual version archive folders needed
- exact rollback is easy

---

## Suggested deploy script

Create `scripts/deploy-to-esphome.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="/config/esp32-gateway"
VERSION="${1:-main}"

cd "$REPO_DIR"

git fetch --all --tags

if git rev-parse "$VERSION" >/dev/null 2>&1; then
  git checkout "$VERSION"
else
  git checkout main
  git pull --ff-only
fi

./scripts/preflight.sh
esphome compile firmware/esp32-c3-multi-sensor.yaml
```

Run it like:

```bash
bash /config/esp32-gateway/scripts/deploy-to-esphome.sh v7.3.4.2
```

or:

```bash
bash /config/esp32-gateway/scripts/deploy-to-esphome.sh main
```

---

## Secrets handling

Do not store real secrets in Git.

### Recommended policy
- keep `secrets-example.yaml` in the repo
- keep the real `secrets.yaml` only locally / in the container
- add the real secrets file to `.gitignore`

Suggested `.gitignore` lines:

```gitignore
secrets/*.yaml
!secrets/secrets-example.yaml
.build/
.pio/
```

---

## Suggested Git workflow for accepted builds

### After accepting a build
From your workstation / repo working copy:

```bash
git add .
git commit -m "v7.3.4.2 hotfix: export serialization, chart recolor, theme redraw"
git tag v7.3.4.2
git push origin main --tags
```

### In ESPHome LXC
```bash
cd /config/esp32-gateway
git fetch --all --tags
git checkout v7.3.4.2
bash scripts/deploy-to-esphome.sh v7.3.4.2
```

---

## Recommended release checklist

Every build should include:
- updated codebase
- aligned version headers/comments
- `Docs/v7.x.x-documentation.md`
- `Docs/v7.x.x-development-notes.md`
- `Docs/v7.x.x-consolidated-test-worksheet.md`
- `Docs/v7.x.x-pre-phase1-expert-opinion.md` when applicable
- regenerated `dashboard.h` if HTML changed
- updated preflight checks if failure modes changed

Before tagging a release, confirm:
- compile success
- dashboard loads and connects
- target feature fix works
- no regression on theme/range/export/auth flows
- browser smoke check done where relevant

---

## Process for future chat sessions

### Best way to start a fresh session
Provide:
- GitHub repo URL
- latest known-good tag
- summary of new requested change
- any new error screenshots/logs

Example:

> Repo: `https://github.com/<user>/<repo>`  
> Baseline: `v7.3.4.2`  
> Next step: Import v1 with validation report before write  
> New issue: theme toggle still leaves legend contrast weak on Firefox mobile

### What the assistant should then do
- review the repo/tag baseline
- inspect the requested change against current code/docs
- produce the next build update with aligned docs and tests
- keep the solution narrow and user-first

---

## Public vs private repository guidance

### Public repo
Best option for continuity across fresh sessions.

Benefit:
- future sessions can reference the same baseline without re-uploading files

### Private repo
Still useful for your workflow, but the assistant will not be able to pull it directly from this chat unless you upload files or use an available connector.

If the main goal is minimizing re-uploads in fresh sessions, a **public repo** is the cleanest option.

---

## Recommended migration plan

### Step 1
Create or use the GitHub repository for this project.

### Step 2
Push the current known-good build as baseline.

### Step 3
Restructure into the recommended repo layout.

### Step 4
Add:
- `.gitignore`
- `VERSION`
- `scripts/deploy-to-esphome.sh`

### Step 5
Clone the repo once into the ESPHome LXC.

### Step 6
From then on:
- GitHub tag = canonical build checkpoint
- LXC builds from Git checkout
- ZIPs become optional transport only

---

## Bottom-line recommendation

The most efficient long-term workflow is:
- GitHub as the canonical source of truth
- tagged known-good builds
- LXC pulling directly from GitHub
- chat-based ZIPs only as a temporary handoff tool when needed

This reduces repetitive file handling, makes rollback trivial, improves fresh-session continuity, and fits the project’s versioned documentation requirements well.
