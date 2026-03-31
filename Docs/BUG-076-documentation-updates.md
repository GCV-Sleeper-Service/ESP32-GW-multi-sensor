# Documentation Updates for BUG-075/076 Final Fix

All updates apply to the PR #105 branch. Each section shows the file,
what to find, and the exact replacement text.

---

## 1. `Docs/bugs-and-lessons-learned.md`

### 1a. Update the header line

FIND:
```
_Last updated: 2026-03-31 — v7.6.0.0 post-merge fixups (BUG-075/076, LESSON-OPS-097–101)._
```

REPLACE WITH:
```
_Last updated: 2026-03-31 — v7.6.0.0 post-merge fixups (BUG-075/076, LESSON-OPS-097–102)._
```

### 1b. Replace BUG-075 Fix section

FIND (the **Fix:** paragraph only, around line 53-58):
```
**Fix:** Deferred task pattern. `handle_reset_satellites_()` and
`handle_delete_data_()` now authenticate + send HTTP response immediately +
spawn a dedicated `xTaskCreate` task (8192-byte stack) that performs all NVS
work. Pattern mirrors the existing `schedule_reboot_()` implementation.
`handle_reboot_()` was already correct.

**Prevention:** See LESSON-OPS-100 and LESSON-OPS-101.
```

REPLACE WITH:
```
**Fix (primary):** Local ESPHome component override. The `web_server_idf`
component is copied into `firmware/local_components/web_server_idf/` and patched
to set `config.stack_size = 16384` after `HTTPD_DEFAULT_CONFIG()`. Board profiles
reference this via `external_components`. Managed by
`scripts/patch-esphome-httpd-stack.sh`; re-run after every ESPHome upgrade.

**Fix (secondary):** Deferred task pattern. `handle_reset_satellites_()` and
`handle_delete_data_()` authenticate + send HTTP response immediately + spawn a
dedicated `xTaskCreate` task (8192-byte stack) for NVS work. Even with the
16 KB httpd stack, NVS operations should not run on the httpd task. Pattern
mirrors the existing `schedule_reboot_()` implementation.

**Note:** Testing proved that the deferred task pattern alone is NOT sufficient.
Even the lightest handler (unauthenticated request → `send_json_error_(401)`)
overflows the 4 KB stack. The component override is mandatory.

**Prevention:** See LESSON-OPS-100, LESSON-OPS-101, and LESSON-OPS-102.
```

### 1c. Add LESSON-OPS-102 (after LESSON-OPS-101)

INSERT after the LESSON-OPS-101 block (before LESSON-OPS-097):
```markdown
### LESSON-OPS-102: ESPHome httpd stack must be patched via local component override (2026-03-31)

Because `CONFIG_HTTPD_STACK_SIZE` is inert (LESSON-OPS-100), the only way to
increase the httpd task stack is to override ESPHome's `web_server_idf` component
locally. The script `scripts/patch-esphome-httpd-stack.sh` copies the upstream
component into `firmware/local_components/web_server_idf/` and patches
`config.stack_size = 16384` into `AsyncWebServer::begin()`. Board profiles must
include an `external_components` block pointing to `local_components`. The script
must be re-run after every ESPHome version upgrade. Use `--check` to verify.
Codified as Critical Rule 42.
```

---

## 2. `Docs/changelog.md`

### 2a. Replace the entire fixup-1 entry (lines 5-18)

FIND:
```
## [v7.6.0.0-fixup-1] — 2026-03-30 — httpd Stack Overflow Fix (BUG-049)

### Bug Fixes

- **BUG-049: httpd task stack overflow (aggregator boot loop):** ...
  ... (the entire fixup-1 section down to the --- separator)
```

REPLACE WITH:
```
## [v7.6.0.0-fixup-1] — 2026-03-31 — httpd Stack Overflow Fix (BUG-075/076)

### Bug Fixes

- **BUG-075/076: httpd task stack overflow — every POST with a body crashes S3
  aggregator.** Root cause: ESP-IDF's `HTTPD_DEFAULT_CONFIG()` hardcodes
  `.stack_size = 4096`. ESPHome never overrides it. `CONFIG_HTTPD_STACK_SIZE`
  in `sdkconfig_options` is dead config with zero runtime effect.
  - *Primary fix:* Local ESPHome component override via
    `firmware/local_components/web_server_idf/` — patches `config.stack_size = 16384`.
    Managed by `scripts/patch-esphome-httpd-stack.sh`.
  - *Secondary fix:* `handle_reset_satellites_()` and `handle_delete_data_()` now use
    deferred task pattern (`xTaskCreate`, 8192-byte stack) for NVS work.
  - *Content-type fix:* Dashboard POST calls changed from `application/json` to
    `application/x-www-form-urlencoded` with `body: 'a=1'`. ESPHome only consumes
    form-encoded POST bodies.
  - *Dead config removed:* `CONFIG_HTTPD_STACK_SIZE` removed from all board profiles.
  - Board profiles now include `external_components` pointing to the patched component.
  - `render_sensor_config.py` updated to emit `external_components` from board profiles.

### New Files

- `scripts/patch-esphome-httpd-stack.sh` — copies and patches ESPHome's
  `web_server_idf` component. Re-run after ESPHome upgrades.
- `firmware/local_components/web_server_idf/` — patched component override.
- `Docs/postmortem-BUG-075-076-httpd-stack.md` — full investigation post-mortem.

### New Lessons & Critical Rules

- LESSON-OPS-097 through LESSON-OPS-102
- Critical Rules 38–42
```

---

## 3. `prompts/prompt-index-and-workflow.md`

### 3a. Update header line

FIND:
```
_Last updated: 2026-03-31 — v7.6.0.0 post-merge fixups complete; Critical Rules 38–41 added, LESSON-OPS-099–101_
```

REPLACE WITH:
```
_Last updated: 2026-03-31 — v7.6.0.0 post-merge fixups complete; Critical Rules 38–42 added, LESSON-OPS-099–102_
```

### 3b. Add Critical Rule 42 (after rule 41)

INSERT after the Rule 41 row:
```
| 42 | All board profiles must include an `external_components` block referencing `firmware/local_components` for the patched `web_server_idf` component. Without this, the httpd task runs at 4 KB and all POST handlers crash. Run `scripts/patch-esphome-httpd-stack.sh --check` to verify. | BUG-075 / LESSON-OPS-102 |
```

### 3c. Update the revision history entry

FIND:
```
| **Critical Rules 38–41 added** | httpd stack hardcoded at 4 KB by ESPHome — CONFIG_HTTPD_STACK_SIZE inert. Deferred task pattern required for NVS handlers. ESPHome only supports form-urlencoded POST. Rules 38/39 content-type corrected from application/json to application/x-www-form-urlencoded. |
```

REPLACE WITH:
```
| **Critical Rules 38–42 added** | httpd stack hardcoded at 4 KB by ESPHome — CONFIG_HTTPD_STACK_SIZE inert. Local component override (`firmware/local_components/web_server_idf/`) patches stack to 16 KB. Deferred task pattern required for NVS handlers. ESPHome only supports form-urlencoded POST. |
```

---

## 4. `Docs/writing-prompts-for-coding-agents-guide.md`

### 4a. Update §16.2 — add component override info

FIND (at the start of §16.2):
```
### 16.2 httpd task stack hardcoded at 4 KB (Critical Rules 40–41)

`CONFIG_HTTPD_STACK_SIZE` in `sdkconfig_options` has no effect. ESPHome
hardcodes `.stack_size = 4096`. Any handler touching NVS, mutexes, or
heavy string ops will overflow it. Use the deferred task pattern.
See LESSON-OPS-100/101.
```

REPLACE WITH:
```
### 16.2 httpd task stack hardcoded at 4 KB (Critical Rules 40–42)

`CONFIG_HTTPD_STACK_SIZE` in `sdkconfig_options` has no effect. ESPHome
hardcodes `.stack_size = 4096`. Even the lightest handler (auth check +
401 response) overflows 4 KB.

**Primary fix:** Local component override. `scripts/patch-esphome-httpd-stack.sh`
copies ESPHome's `web_server_idf` component into `firmware/local_components/`
and patches `config.stack_size = 16384`. Every board profile must include:

```yaml
external_components:
  - source:
      type: local
      path: local_components
    components: [web_server_idf]
```

Re-run the script after every ESPHome upgrade. Use `--check` in CI/preflight.

**Secondary fix:** Deferred task pattern for NVS-heavy handlers (still required
even with 16 KB stack). See LESSON-OPS-100/101/102.
```

### 4b. Update §16.3 — add preflight items

FIND:
```
### 16.3 Pre-flight checklist additions (§9)

- Every `curl` POST → uses `-d 'a=1'`, NOT `-d '{}'`, NOT `-d ''`
- Every `fetch()` POST → `Content-Type: application/x-www-form-urlencoded`, `body: 'a=1'`
- Every new POST handler touching NVS → uses deferred task pattern with 8192+ bytes
- No `CONFIG_HTTPD_STACK_SIZE` in any real board profile (i.e., none under `firmware/boards/*.yaml` or in generated board YAMLs; the legacy `firmware/esp32-c3-multi-sensor.yaml` template still contains it and will be cleaned up separately if the setting remains inert).
```

REPLACE WITH:
```
### 16.3 Pre-flight checklist additions (§9)

- `bash scripts/patch-esphome-httpd-stack.sh --check` passes
- Every board profile has `external_components` referencing `local_components`
- Every `curl` POST → uses `-d 'a=1'`, NOT `-d '{}'`, NOT `-d ''`
- Every `fetch()` POST → `Content-Type: application/x-www-form-urlencoded`, `body: 'a=1'`
- Every new POST handler touching NVS → uses deferred task pattern with 8192+ bytes
- No `CONFIG_HTTPD_STACK_SIZE` in any board profile under `firmware/boards/*.yaml`
```

---

## 5. `LESSON-OPS-100` update in `Docs/bugs-and-lessons-learned.md`

FIND:
```
### LESSON-OPS-100: ESPHome httpd task stack is hardcoded at 4 KB — CONFIG_HTTPD_STACK_SIZE has no effect (2026-03-30)

`HTTPD_DEFAULT_CONFIG()` in ESP-IDF hardcodes `.stack_size = 4096` as a literal.
ESPHome's `web_server_idf.cpp` never overrides this. `CONFIG_HTTPD_STACK_SIZE` in
`sdkconfig_options` is completely inert — do not add it to any board profile.
The only way to get more stack to an HTTP handler is to offload heavy work to a
separately spawned `xTaskCreate` task. Codified as Critical Rules 40 and 41.
```

REPLACE WITH:
```
### LESSON-OPS-100: ESPHome httpd task stack is hardcoded at 4 KB — CONFIG_HTTPD_STACK_SIZE has no effect (2026-03-30)

`HTTPD_DEFAULT_CONFIG()` in ESP-IDF hardcodes `.stack_size = 4096` as a literal.
ESPHome's `web_server_idf.cpp` never overrides this. `CONFIG_HTTPD_STACK_SIZE` in
`sdkconfig_options` is completely inert — do not add it to any board profile.
The only way to increase the httpd stack is via a local ESPHome component override
(see LESSON-OPS-102). NVS-heavy handlers must additionally use the deferred task
pattern (see LESSON-OPS-101). Codified as Critical Rules 40, 41, and 42.
```

---

## 6. Other board profiles — add `external_components`

### `firmware/boards/esp32-c3-supermini.yaml`

ADD the following block (same location as in the S3 profile — after sdkconfig_options):
```yaml
external_components:
  - source:
      type: local
      path: local_components
    components: [web_server_idf]
```

### `firmware/boards/esp32-wroom-32d.yaml`

ADD the same block.

---

## 7. New file: `Docs/postmortem-BUG-075-076-httpd-stack.md`

Place the post-mortem document (already produced in this session) into Docs/.

---

## 8. Files to commit summary

New files:
- `scripts/patch-esphome-httpd-stack.sh`
- `firmware/local_components/web_server_idf/` (6 source files + __init__.py + PATCH_INFO.md)
- `Docs/postmortem-BUG-075-076-httpd-stack.md`

Modified files:
- `scripts/render_sensor_config.py` (external_components pass-through)
- `firmware/boards/esp32-s3-devkitc1-n16r8.yaml` (external_components + path: local_components)
- `firmware/boards/esp32-c3-supermini.yaml` (external_components)
- `firmware/boards/esp32-wroom-32d.yaml` (external_components)
- `firmware/esp32-s3-devkitc1-n16r8-gw.yaml` (regenerated)
- `Docs/bugs-and-lessons-learned.md` (BUG-075 fix update, LESSON-OPS-100 update, LESSON-OPS-102 new)
- `Docs/changelog.md` (fixup-1 rewrite)
- `Docs/writing-prompts-for-coding-agents-guide.md` (§16.2 and §16.3 updates)
- `prompts/prompt-index-and-workflow.md` (Critical Rule 42, revision history)

---

## 9. Commit message suggestion

```
BUG-075/076: local ESPHome component override — httpd stack 4KB → 16KB

Primary fix: patch ESPHome's web_server_idf component locally to set
config.stack_size = 16384 after HTTPD_DEFAULT_CONFIG(). The deferred
task pattern (PR #106) is necessary but insufficient — even the lightest
handler (auth check + 401 response) overflows the 4KB default.

- firmware/local_components/web_server_idf/ — patched component
- scripts/patch-esphome-httpd-stack.sh — copy + patch script
- scripts/render_sensor_config.py — external_components pass-through
- Board profiles: external_components added, path: local_components
- Docs: LESSON-OPS-102, Critical Rule 42, post-mortem, changelog rewrite

Fixes: BUG-075, BUG-076
```
