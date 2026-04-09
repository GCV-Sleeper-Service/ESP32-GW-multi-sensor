# Session Log — 2026-03-31 — BUG-076 Remaining Fixes (Dashboard Content-Type + Docs)

**Branch:** `codex/fix-crash-on-post-/api/system/reset-satellites-9yv175` (PR #105)
**Date:** 2026-03-31
**Scope:** Dashboard content-type fixes, generated file regeneration, documentation updates

---

## Context

This session continues the BUG-075/076 stabilization work from PR #105. The core C++ fix
(deferred task pattern in `sensor_history_multi.h`) was already delivered by PR #106 and
merged into this branch. This session handles only:

1. Dashboard content-type fixes (`dashboard.js` and `dashboard.html`)
2. Generated file regeneration (`dashboard.h`, board YAMLs)
3. Documentation updates (bugs-and-lessons-learned, changelog, prompt-index, writing-prompts-guide)

---

## Changes Made

### 1. `dashboard/dashboard.js` — Content-Type Fix

Changed all 4 POST `fetch()` call sites (in `executeImport` and `postManagementAction`):

- `'Content-Type': 'application/json'` → `'Content-Type': 'application/x-www-form-urlencoded'`
- `body: '{}'` → `body: 'a=1'`

**Why:** ESPHome's `web_server_idf` component only reads POST body bytes for
`Content-Type: application/x-www-form-urlencoded` and `multipart/form-data`. For
`application/json`, it logs "Unsupported content type for POST" and routes to the GET
handler path without consuming body bytes. Unconsumed bytes corrupt socket state when
the response is sent.

### 2. `dashboard/dashboard.html` — Same Content-Type Fix

Identical changes to dashboard.js — 4 POST `fetch()` call sites updated.

### 3. Generated Files Regenerated

After source file edits, ran in order:

```bash
bash scripts/minify-dashboard.sh
# Output: Minified: 229228 bytes → 144940 bytes (saved 84288 bytes, 36%)

bash scripts/generate-header.sh
# Output: Generated dashboard/dashboard.h from dashboard/dashboard.min.html
#         Raw: 144940 bytes -> Gzip: 35629 bytes

python3 scripts/render_sensor_config.py --write
# Output: No generated-file changes were needed.

python3 scripts/render_sensor_config.py --check
# Output: render_sensor_config: PASS
```

Regenerated files:
- `dashboard/dashboard.min.html`
- `dashboard/dashboard.h`

### 4. Documentation Updated

#### `Docs/bugs-and-lessons-learned.md`
- Updated header line: `v7.6.0.0 post-merge fixups (BUG-075/076, LESSON-OPS-097–101)`
- Replaced BUG-076 entry with correct root cause (stack overflow via BUG-075, secondary
  socket corruption from JSON body)
- Replaced BUG-075 entry with accurate root cause (httpd stack hardcoded at 4 KB by
  `HTTPD_DEFAULT_CONFIG()`, `CONFIG_HTTPD_STACK_SIZE` is inert)
- Added LESSON-OPS-099: ESPHome IDF httpd only consumes x-www-form-urlencoded POST bodies
- Added LESSON-OPS-100: ESPHome httpd task stack hardcoded at 4 KB
- Added LESSON-OPS-101: Deferred task pattern for NVS-heavy HTTP handlers

#### `Docs/changelog.md`
- Replaced BUG-075/076 bullets in `v7.6.0.0-fixup-1` section with accurate description
  of deferred task fix and content-type fix

#### `prompts/prompt-index-and-workflow.md`
- Updated header line to `2026-03-31`
- Added Critical Rules 38–41 to the rules table
- Added revision history entry for 2026-03-31

#### `Docs/writing-prompts-for-coding-agents-guide.md`
- Added new Section 16: Lessons from v7.6.0.0 Post-Merge Stabilization (BUG-075/076)
  - 16.1: ESPHome POST content type constraint (Critical Rules 38–39)
  - 16.2: httpd task stack hardcoded at 4 KB (Critical Rules 40–41)
  - 16.3: Pre-flight checklist additions

---

## Files Changed

| File | Change |
|------|--------|
| `dashboard/dashboard.js` | 4 content-type + body changes |
| `dashboard/dashboard.html` | 4 content-type + body changes |
| `dashboard/dashboard.min.html` | Regenerated |
| `dashboard/dashboard.h` | Regenerated |
| `Docs/bugs-and-lessons-learned.md` | BUG-075/076 rewritten; LESSON-OPS-099/100/101 added |
| `Docs/changelog.md` | v7.6.0.0-fixup-1 bullets updated |
| `prompts/prompt-index-and-workflow.md` | Critical Rules 38–41; revision history entry |
| `Docs/writing-prompts-for-coding-agents-guide.md` | Section 16 added |
| `Docs/session-log-2026-03-31-bug076-remaining-fixes.md` | This file (new) |

---

## What Was NOT Changed

Per the session handoff instructions:

- ❌ `dashboard/sensor_history_multi.h` — already fixed by PR #106
- ❌ Board YAML files — `CONFIG_HTTPD_STACK_SIZE` already removed
- ❌ Any version numbers — `v7.6.0.0-fixup-1` stays
- ❌ `handle_reboot_()` — already correct
- ❌ Import handlers — no changes needed
- ❌ Any httpd_req_recv drain loop

---

## Critical Rules Codified This Session

| Rule | Summary |
|------|---------|
| 38 | All dashboard `fetch()` POST calls: `Content-Type: application/x-www-form-urlencoded`, `body: 'a=1'` |
| 39 | All `curl` POST commands: `-d 'a=1'`. Never `-H "Content-Type: application/json"`, never `-d ''` |
| 40 | Any HTTP handler performing NVS operations must use deferred task pattern (8192+ byte stack) |
| 41 | Never add `CONFIG_HTTPD_STACK_SIZE` to board profile `sdkconfig_options` — has zero effect |
