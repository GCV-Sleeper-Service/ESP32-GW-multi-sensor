# Prompt Index Update — Phase VX Section

_Insert this section into `prompts/prompt-index-and-workflow.md` after the Phase V section and before the Phase 7 section._
_Also update line 4 (the "Last updated" line) to reflect Phase VX._
_Updated: 2026-05-05 — corrected IPs, v7.6.10.0 status marked complete._

---

## Update Instructions

### 1. Update the header line (line 4)

Change:
```
_Last updated: 2026-04-22 — Phase V closure (v7.6.9.5). Phase V complete. Critical Rule 64 added. Current Phase: **Phase VX** (pending)._
```

To:
```
_Last updated: 2026-05-05 — Phase VX in progress (v7.6.10.0 merged). Current Phase: **Phase VX** (board onboarding sprint)._
```

### 2. Insert Phase VX section

Insert after the Phase V step table and before `### Phase 7`:

```markdown
### Phase VX — Board Onboarding Sprint (v7.6.10.0–v7.6.10.3+)

Phase VX is an infrastructure sprint between Phase V closure and Phase 7. ESPHome upgraded from 2026.2.1 to 2026.4.1 (ESP-IDF 5.5.4). Up to 3 new boards (S3 SuperMini, C6 SuperMini, C5 WROOM-1U) onboarded into the provisioning pipeline. Measurement dataset produced for multi-phase planning.

Phase VX uses the same prompt methodology as Phase V: Claude advisory sessions producing agent prompts (two-step pattern), Kiro/GPT/Codex executing those prompts, Perplexity three-turn PR review.

**Version range:** v7.6.10.0–v7.6.10.3 (+ optional v7.6.10.4)
**Sprint prompt:** `prompts/handoff/phaseVX/phaseVX-board-onboarding-sprint-prompt.md`
**Sprint assessment:** `prompts/handoff/phaseVX/phaseVX-sprint-assessment.md`
**Audit Template:** `prompts/phaseVX/consolidated-audit-template-phaseVX.md`
**Measurement Protocol:** `Docs/board-measurement-protocol-v7.6.10.md`
**Measurement Log:** `Docs/board-measurement-log-v7.6.10.md`

| Version | Scope | Prompt File | Handoff | Status |
|---------|-------|-------------|---------|--------|
| v7.6.10.0 | ESPHome 2026.4.1 upgrade verification + local component re-patch | `prompts/phaseVX/v7.6.10.0-agent-prompt-gpt-codex.md` | `prompts/handoff/phaseVX/session-handoff-v7.6.10.0.md` | ✅ Complete (PR #200) |
| v7.6.10.1 | Board profiles + partition tables for 3 new boards | `prompts/phaseVX/v7.6.10.1-agent-prompt-gpt-codex.md` | `prompts/handoff/phaseVX/session-handoff-v7.6.10.1.md` | 🔜 Queued |
| v7.6.10.2 | Flash, measure, document | _(operator-driven, see measurement protocol)_ | _(no agent handoff)_ | 🔜 Queued |
| v7.6.10.3 | Capacity study + board selection guide update | _(Claude advisory session)_ | _(no agent handoff)_ | 🔜 Queued |
| v7.6.10.4 | Dashboard auth refactor (optional) | _(TBD if included)_ | _(TBD)_ | 🔜 Optional |

**New boards onboarded:**

| board_id | Name | Chip | Flash | PSRAM | IP | Compiled? |
|----------|------|------|-------|-------|----|-----------|
| esp32-s3-supermini-4m | sat-s3-4m-173 | ESP32-S3 | 4 MB | 2 MB quad | 192.168.120.173 | ___ |
| esp32-c5-wroom1u-8m | sat-c5-8m-180 | ESP32-C5 | 8 MB | 8 MB quad | 192.168.120.180 | ___ |
| esp32-c6-supermini-4m | sat-c6-4m-184 | ESP32-C6 | 4 MB | None | 192.168.120.184 | ___ |

**Findings:**
- BUG-084: Heap exhaustion under 8 concurrent HTTP connections on non-PSRAM boards (C3, WROOM). Stack is fine (watermark ~12,900 B on 16 KB stack). Stress test script needs concurrent request reduction.
- S3 watermark dropped from 12,528 B to 10,036 B after ESPHome 2026.4.1 — monitor.
- IRAM optimization (`sram1_as_iram`) not applicable — would worsen heap pressure on WROOM. N/A for RISC-V boards.
```

### 3. Update step status as each step completes

After each step merges, change its status from `🔜 Queued` to `✅ Complete` and fill in the PR number and compiled status.

---

_End of prompt index update instructions._
