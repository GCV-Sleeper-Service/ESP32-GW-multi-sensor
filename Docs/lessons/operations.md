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

---

### LESSON-OPS-126: Checkpoint grep assertions must be validated against the actual replacement block in the same prompt (2026-04-17)

**Context:** v7.6.9.4 Checkpoint B contained two grep assertions that were inconsistent with the replacement block defined in the same §5 Step 2 of the prompt. The agent correctly stopped and escalated instead of silently proceeding.

**Defect 1 - symbol-count mismatch:**
The prompt expected `grep -c _v7_9_4_historyKicked` = 2, but the replacement block it specified necessarily produces 3 occurrences (declaration + guard read + assignment). The expected value was likely written against an earlier draft of the replacement block, or the author confused the two versioned symbol names (`_historyKicked` vs `_kickHistoryOnce`).

**Defect 2 - multiline diff grep:**
The prompt's removal check was `git diff ... | grep -c '^-.*historyBootstrapTimerId.*10000'`. The old block being removed is a 4-line `setTimeout` call where `historyBootstrapTimerId` appears on line 1 and `10000` appears on line 4 of the diff hunk. A single-line grep anchored to `^-` can never match both tokens from different lines.

**Rule:** When writing a checkpoint grep against a replacement block defined in the same prompt, count occurrences in the block directly before writing the expected value. For removal checks against multiline constructs, split into separate greps - one per token - rather than combining tokens from different lines into a single pattern.

**Anti-pattern to avoid:** Writing checkpoint greps from memory of what the code should look like rather than mechanically counting from the actual block pasted into the prompt.

**Critical Rule:** Checkpoint grep counts must be mechanically derived from the replacement block in the same prompt, not estimated from memory.

Before finalising any checkpoint assertion of the form `grep -c SYMBOL FILE - expected: N`, count the literal occurrences of `SYMBOL` in the replacement or removal block defined in the same prompt document. If the block spans multiple lines, verify that the grep pattern can match across a single line; if the verification requires detecting a token removed from one line and another token removed from a different line, use separate single-token greps rather than a combined pattern. A wrong expected count is an instruction inconsistency that forces correct agent implementations to stop and escalate.

