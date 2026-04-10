# Lessons — Operations

_Split from Docs/bugs-and-lessons-learned.md at v7.6.4.0._

## Bug Fixes

### BUG-019: "Data available: unknown" in custom range dialog on freshly-flashed device (v7.4.2.0)

**Fix:** Three-state availability display: both bounds non-zero → range shown; only newest non-zero → "up to [newest]"; both zero → "No persisted history yet."

---


---

## Lessons Learned

### LESSON-OPS-010: Cached builds may not reflect header-only changes clearly

If behavior looks stale after header or generated-file changes, use `esphome compile --clean`.

---


---

### LESSON-OPS-051: Dashboard code changes that affect network behavior require real-device validation with dashboard open (v7.5.3.3-hotfix)

Playwright tests validate rendering and data flow against a mock server with unlimited HTTP capacity. They do **NOT** validate HTTP connection pressure on a real ESP32-C3 (~4-7 concurrent connections). BUG-037 passed all 73 Playwright tests but crashed the real device within seconds of opening the dashboard.

**Rule:** Any dashboard change that modifies `setInterval()` / `setTimeout()` scheduling, `fetch()` call sites, SSE event handlers, boot sequence request ordering, or polling/refresh cadence **must** be validated on a real device with the dashboard open before the PR is merged.

**Real-device validation checklist:**
1. Open local dashboard — no crash for 5+ minutes
2. Close and reopen — no crash
3. Open remote dashboard (polling mode) — no crash for 3+ polling cycles
4. Check browser Network tab — no request storms or duplicate fetches
5. Check device logs — no `httpd_accept_conn: error in accept` warnings

Related: BUG-043

---


---

### LESSON-OPS-058: Prompt template device testing sections must include full local workflow (2026-03-18)

**Date:** 2026-03-18

Phase 3 prompt templates (e.g., v7.5.3.7) included device testing commands like `curl -s http://192.168.120.189/api/v2/history/office/temp` but did not include the prerequisite steps: pulling the repo, compiling, and flashing. An operator starting from scratch would not know the full workflow.

**Rule:** Every prompt's device testing section must include the complete sequence: (1) pull latest from main, (2) compile, (3) OTA flash, (4) verification commands, (5) expected output descriptions. Assume the operator is starting from a fresh terminal. Use the v7.5.3.7 instructions as the quality bar for detail level.

Related: BUG-044

---


---

### LESSON-OPS-073: LXC USB passthrough requires chmod after every device reconnect (2026-03-23)

**Context:** In unprivileged Proxmox LXC containers, bind-mounted USB devices (`/dev/ttyACM0`) lose permissions when the device disconnects and reconnects — which happens when entering download mode, after board reset, or after flashing. The host creates a fresh device node with default permissions that the container's unprivileged user cannot access.

**Rule:** Either install a udev rule on the Proxmox host that sets `MODE="0666"` for ESP32 vendor IDs (`303a:1001` for S3 USB-JTAG, `10c4:ea60` for CP2102, `1a86:7523` for CH340), or flash directly from the host by navigating to the container's rootfs path. The udev rule is the permanent fix; manual `chmod 0666 /dev/ttyACM0` is the per-flash workaround.

**Applies to:** Any LXC-based ESPHome setup with USB-connected boards.

Related: BUG-061

---


---

### LESSON-OPS-121: Full Pipeline Automation in provision.sh (v7.6.6.0)

**Root cause:** After Phase X added the 8-step regeneration pipeline (bundle → render → fixtures → render → build → minify → header → check), operators had to run 8 manual commands after every `provision.sh` switch. This was error-prone — steps were skipped or run in the wrong order.

**Fix:** `provision.sh` now runs the full pipeline automatically after switching board configurations. `--dry-run` flag prints steps without executing. Dependency pre-checks verify `node` and `node_modules` exist before starting.

**Rule:** `provision.sh` is the single entry point for board switching AND pipeline execution (Critical Rule 49, updated).

---
