# Session Handoff — v7.6.9.5: C3 httpd Stack Override Fix

_Date: 2026-04-20_
_Repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor_
_Status: v7.6.9.4 COMPLETE (PR#193 + PR#194 merged). PR#195 (first attempt) FAILED device gate — root cause identified. This is the corrected v7.6.9.5 scope._

---

## Project State Summary

**v7.6.9.4 is complete.** PR#195 was the first v7.6.9.5 attempt (conditional RISC-V stack bump). It failed the C3 stress test — watermark stayed at 632 bytes on the "bumped" firmware. Investigation revealed the local component override (`firmware/local_components/web_server_idf/`) was never compiled into the C3 firmware because the C3 template YAML (`firmware/esp32-c3-multi-sensor.yaml`) has no `external_components` block.

**Root cause:** `render_sensor_config.py` has two code paths:
- **With `gateway.json`** (WROOM, S3): calls `generate_board_yaml()` which reads the board profile and emits `external_components` → 16 KB stack override active.
- **Without `gateway.json`** (C3 default satellite): calls `render_yaml_file()` which modifies the template in-place via marker blocks but never touches `external_components` → stock ESPHome 4 KB stack.

The board profile at `firmware/boards/esp32-c3-supermini.yaml` has always had the `external_components` entry. But the C3 never goes through the code path that reads it.

**Corrected measurements:**

| Board | Architecture | Actual stack | Watermark | Peak usage |
|---|---|---|---|---|
| C3 | RISC-V | **4,096 B (stock!)** | 636 B | ~3,460 B |
| WROOM | Xtensa LX6 | 16,384 B (override) | 13,044 B | ~3,340 B |
| S3 | Xtensa LX7 | 16,384 B (override) | 13,760 B | ~2,624 B |

C3 and WROOM peak usage are nearly identical (~3,400 B). The original "RISC-V uses 4.7× more stack" analysis was wrong — the 20× watermark gap was caused by different stack sizes (4 KB vs 16 KB), not architecture differences.

---

## Phase V Progress Table

| Version | Scope | Status |
|---|---|---|
| v7.6.7.0 | V1-A/B/C: Proxy fix + NAS disable + logger | ✅ Complete |
| v7.6.7.1 | V1-D: Import crash fix | ✅ Complete |
| v7.6.7.2 | V1-E/F/G: Badge + dead code + comment | ✅ Complete |
| v7.6.7.3 | Operational telemetry in /api/status | ✅ Complete (PR #179) |
| v7.6.8.0 | V2-A/B/C/D: Auth guards + status split | ✅ Complete |
| v7.6.8.1 | V2-E/F/G: History auth + DoS + SEC-ADR (60 KB fixed cap) | ✅ Complete |
| v7.6.8.2 | V2-H/I/J: Gated optimisations | ✅ Complete |
| v7.6.9.0 | V3-A: Device card cleanup (+ hotfix 1, 2) | ✅ Complete (PR #183) |
| v7.6.9.1 | V3-B/C: Hostname/IP + CSV role | ✅ Complete |
| v7.6.9.2 | V3-D/E: Manifest export + AGG-ADR | ✅ Complete |
| v7.6.9.3 | V3-F: Struct audit (conditional) | ✅ Complete |
| v7.6.9.4 | V4: Heap-adaptive history cap + boot sequencing (#139 partial) | ✅ Complete (PR#193 + PR#194) |
| **v7.6.9.5** | **V5: C3 httpd stack override fix** | **⬅️ Current (rework)** |
| v7.6.9.6 | V6: Polling telemetry + SEC-ADR amendment (**Phase V actual closure**) | 🔜 Queued |

---

## v7.6.9.5 Scope (Revised)

### Why this step exists

The C3 board has been running with ESPHome's stock 4 KB httpd stack since the project began. The local component override (`config.stack_size = 16384`) was created in v7.6.8.0 (BUG-076) but only WROOM and S3 boards received it. The C3 template YAML was never updated with the `external_components` block, so the override never compiled in.

### What this step does

1. **C3 template fix:** add `external_components` block to `firmware/esp32-c3-multi-sensor.yaml`
2. **Pipeline guard:** add verification to `scripts/preflight.sh` that all board YAMLs reference the local component
3. **Stress test script:** keep `scripts/stress-test-httpd-stack.sh` from PR#195
4. **Docs:** BUG entry, LESSON-OPS on verify-before-theorize, corrected capacity study, changelog

### What this step does NOT do

- No architecture-conditional stack sizing — 16 KB is sufficient for all architectures
- No handler changes, no dashboard changes, no NVS/partition/SEC-ADR changes

### Files modified

- `firmware/esp32-c3-multi-sensor.yaml` — add `external_components` block
- `scripts/preflight.sh` — add external_components verification
- `scripts/stress-test-httpd-stack.sh` — new file (keep from PR#195)
- `Docs/changelog.md`, `Docs/lessons/firmware.md`, `Docs/lessons/index.md`
- `Docs/phase-V-capacity-study.md` — correct task stack table
- `VERSION` — bump to `7.6.9.5`

---

## Device Testing

### C3 verification (primary gate)

1. Flash C3 with v7.6.9.5 firmware
2. `curl -s -u ESPadmin:ESPpass100 http://192.168.120.189/api/status/full | jq '.httpd_stack_watermark_bytes'`
   - **Expected: ≥ 10000** (was 636 on 4 KB stock stack)
3. Run `bash scripts/stress-test-httpd-stack.sh 192.168.120.189`
   - **Acceptance: minimum watermark ≥ 10000 bytes**

If watermark is still ~636: the override is NOT active. Check build log for local_components references.

### Smoke test — WROOM and S3

- Watermarks unchanged (~13044 and ~13760)
- No crashes or reboots

---

## Context That Carries Forward

### To v7.6.9.6

- v7.6.9.5 fixed the C3's missing local component override. All three boards now run with 16 KB httpd stack.
- v7.6.9.6 scope is unchanged: Cloudflare polling fix + SEC-ADR RV-03 amendment.

### Post-Phase V sequence

Pre-Closure Assessment → Phase V closure docs → Phase VX (board onboarding + ESPHome upgrade) → Phase VY (multi-phase planning) → Phase 7.

### Diagnostic lesson

**Rule: when diagnosing a measurement discrepancy between boards, verify configuration equivalence before theorizing about root causes.** A single `grep external_components firmware/esp32-c3-multi-sensor.yaml` would have caught the real root cause immediately.

---

_End of session handoff document._
