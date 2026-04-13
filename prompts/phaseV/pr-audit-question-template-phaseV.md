# Phase V — PR Audit Question Template

_Stable core (9 questions) + sub-phase-specific supplements_

---

## Universal Reviewer Prompt

```
PR for v7.6.x.x is PRxxx.
Please do comprehensive analysis of the PRxxx.
Understand what is the current result of the implementation, check diffs (ignore dashboard.h because it is generated artifact), read code audit/comments posted in the PR - do you agree with assessment?
Check follow-up and the last commits and understand what issues have been fixed or are remaining, if any.
Please post your code quality and deliverables analysis findings as a comment for the PRxxx with instructions what to fix and how.
DO NOT open a new PR, just post additional comment for the existing PRxxx.
On the first line annotate - PR review by <>
In the comment, answer following questions:
- Annotate problems with severity: Blocking / High / Medium / Low / Cosmetic.
- Did the agent deliver what the prompt required? Where it didn't, classify the cause: prompt ambiguity, codebase drift, or autonomous decision.
- Are all acceptance criteria from §6 of the implementation prompt met?
- Were any autonomous decisions made that should be back-ported into the prompt for reproducibility?
- What carries forward as required context for the next step?

Please make your comment not too verbose, be brief, stress on facts
```

---

## Stable Core Questions (All Steps)

1. Does `git diff --name-only` show ONLY files listed in §3 (scope) plus expected generated artifacts?
2. Are all acceptance criteria from §6 met? List each with PASS/FAIL.
3. Does the PR include a session log (`Docs/session-log-<DATE>-<VERSION>.md`)?
4. Does the PR include an Instruction Compliance Output table in the description?
5. Did the agent follow every ⛔ CHECKPOINT in §5? Evidence of intermediate verification?
6. Were any autonomous decisions made outside §3 scope? If yes, classify: harmless, risky, or scope violation.
7. Does the changelog entry match the actual changes?
8. Were all Critical Rules from §4 respected? Check each rule individually.
9. Does `bash scripts/preflight.sh` pass in the PR's final state?

---

## V1 Supplement (v7.6.7.x)

10. **Assembly identity:** Does `bash scripts/assemble-sensor-history.sh --check` pass after all fragment edits?
11. **Dead code verification (V1-F):** Does `grep -rn "stream_snapshot_series_\|->stream_to(" firmware/` return zero results?
12. **Deferred task pattern (V1-D):** Is `build_import_epoch_map_()` called inside `xTaskCreate` with ≥ 8192 B stack? Is the httpd response sent BEFORE the task starts?

---

## V2 Supplement (v7.6.8.x)

13. **Auth coverage table delta:** After this PR, update the auth coverage table in SEC-ADR-001. List every endpoint that changed auth state.
14. **Security ADR update check:** If this PR adds or removes an auth guard, is SEC-ADR-001 still accurate? Flag any discrepancy.
15. **Measurement gate verification (V2-H/I/J):** Are the operator's measurement results documented? Was each gate evaluated before the corresponding change was applied?
16. **Auth decision comments (LESSON-OPS-110):** Does every endpoint handler modified in this PR have an explicit `Auth: REQUIRED` or `Auth: NOT REQUIRED` comment?

---

## V3 Supplement (v7.6.9.x)

17. **Dashboard rebuild pipeline compliance:** Were all 4 pipeline commands run (`bundle → build → minify → header`)? Check the generated artifact timestamps or the session log.
18. **Export format backward compatibility:** Is the CSV breaking change (role column at position 3) documented in the changelog and PR description?
19. **Manifest-driven fallback (V3-D):** Does `getMetricColumnsForSensor()` fall back to `['temp', 'hum']` when manifest is unavailable?

---

## Step-Specific Reviewer Focus Areas (Append to Universal Prompt)

### v7.6.7.0

```
Additional focus areas for this PR:
- Verify fetch_to_buffer() signature change is backward-compatible (all existing call sites use default parameters)
- Verify proxy returns 200 with empty body for zero-length satellite response (not 502)
- Verify NAS history buffer deletions: grep for entity_hbuf_nas01_ should return zero results
- Verify lwip_setsockopt (not setsockopt) for timeout — Rule 27
- Verify assemble-sensor-history.sh --write was run after fragment edits
```

### v7.6.7.1

```
Additional focus areas for this PR:
- CRITICAL: Verify build_import_epoch_map_() runs in xTaskCreate (not on httpd task) — Rule 40
- Verify beginResponseStream at line ~817 is replaced with beginResponse() — Rule 8
- Verify /api/import/status has NO auth guard (intentionally public)
- Verify import data endpoints (/api/import/d/, /api/import/w/) gate on s_import_ready
- Verify task stack is >= 8192 bytes
- Check: does s_import_ready use volatile qualifier?
```

### v7.6.7.2

```
Additional focus areas for this PR:
- Verify version badge uses App.version (not hardcoded string)
- Verify dead code deletion: grep returns zero
- Verify no direct edits to dashboard/dashboard.js or dashboard/dashboard.html — Rule 47
- Verify dashboard rebuild pipeline was run
```

### v7.6.8.0

```
Additional focus areas for this PR:
- CRITICAL: Every modified handler must have authenticate_management_() as absolute first line
- Verify LESSON-OPS-089 exception comment is REMOVED from handle_add_satellite_()
- Verify /api/status public response contains ONLY ok, role, id
- Verify /api/status/full requires auth and returns all fields
- Auth decision (LESSON-OPS-110): every endpoint handler should have explicit auth comment
```

### v7.6.8.1

```
Additional focus areas for this PR:
- Verify history endpoints both have auth guards
- Verify csv.reserve() capped at std::min(est_bytes, (size_t)60000)
- Verify DoS cooldown uses static array (no heap allocation)
- Verify SEC-ADR-001 committed as-is
```

### v7.6.8.2

```
Additional focus areas for this PR:
- CRITICAL: Every change is GATED — verify measurement results documented before code changes
- If any gate did NOT pass: verify the corresponding change was NOT made
- Verify httpd stack never set below measured_peak + 2048
- Verify LWIP socket count never reduced below 13
```

### v7.6.9.0

```
Additional focus areas for this PR:
- Verify DEVICE_INFO_MAP changes in dashboard/core/status-snapshot.js
- Verify manifest population in dashboard/core/manifest.js
- Verify new text_sensor entities in YAML
- Verify no direct edits to generated artifacts — Rule 47, 48
```

### v7.6.9.1

```
Additional focus areas for this PR:
- Verify hostname/IP extraction uses gateway object only
- Verify CSV role column at position 3
- Verify backward-compatibility break documented
- Verify Playwright tests cover both export formats
```

### v7.6.9.2

```
Additional focus areas for this PR:
- Verify EXPORT_SENSOR_SUFFIXES replaced with getMetricColumnsForSensor()
- Verify fallback to ['temp', 'hum']
- Verify AGG-ADR-001 committed as-is
- Verify ping and system metrics appear in export
```

### v7.6.9.3

```
Additional focus areas for this PR:
- If heap >= 65 KB: verify NO code changes
- If heap < 65 KB: verify struct changes don't affect NVS serialisation
- Verify measurement result documented in issue #165
```

---

_End of Phase V PR audit template._
