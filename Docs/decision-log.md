# Decision Log

_One-line index of architectural decisions. Full rationale in linked documents._
_Updated: 2026-05-06_

---

## How to Use This Log

Every architectural decision gets a one-line entry here with date, decision, and a link to the source document. This log is searchable and serves as the discovery index — you read the full ADR/document only when investigating a specific decision.

When making a new architectural decision during any session, add a line here as part of the deliverables.

---

## Decisions

| Date | ID | Decision | Rationale Link |
|---|---|---|---|
| 2026-03-05 | SEC-001 | Basic Auth for management endpoints, public `/api/status` | `Docs/decisions/SEC-ADR-001-residual-vulnerabilities.md` |
| 2026-03-05 | SEC-RV | Accept 5 residual vulnerabilities (no TLS, Basic Auth over HTTP, etc.) | `Docs/decisions/SEC-ADR-001-residual-vulnerabilities.md` |
| 2026-03-19 | ARCH-001 | Per-device persistence engine to replace monolithic SegmentSnapshot | `Docs/v7.7-v7.8-persistence-architecture.md` §1-4 |
| 2026-03-19 | ARCH-002 | FNV-1a hash for NVS key scheme, 15-char limit | `Docs/v7.7-v7.8-persistence-architecture.md` §6 |
| 2026-03-19 | ARCH-003 | Priority-tiered retention budgeting per device | `Docs/v7.7-v7.8-persistence-architecture.md` §7 |
| 2026-03-22 | AGG-001 | Aggregator stores satellite history locally (not proxy-only) | `Docs/decisions/AGG-ADR-001-satellite-history-storage.md` |
| 2026-03-31 | BUILD-001 | `external_components` block mandatory in all board YAMLs for httpd stack override | `Docs/lessons/firmware.md` (LESSON-OPS-097–102) |
| 2026-03-31 | BUILD-002 | Local components go in `firmware/local_components/`, never `custom_components` | `prompts/prompt-index-and-workflow.md` Critical Rule 41 |
| 2026-04-09 | PROMPT-001 | Never use LLM-optimized agent prompt variants for execution | `Docs/writing-guide/multi-llm-prompt-optimization-analysis-2026-04-09.md` |
| 2026-04-10 | ARCH-004 | Deferred task pattern mandatory for HTTP handlers doing NVS operations | `prompts/prompt-index-and-workflow.md` Critical Rule 40 |
| 2026-04-10 | ARCH-005 | All dashboard POST calls must use `application/x-www-form-urlencoded`, never JSON | `Docs/lessons/firmware.md` (LESSON-OPS-103) |
| 2026-04-12 | ARCH-006 | Firmware fragments in `firmware/core/`, assembled by script, never edit generated `sensor_history_multi.h` | Phase Y architecture plan |
| 2026-04-12 | ARCH-007 | Dashboard modular components in `dashboard/core/` + `dashboard/components/`, never edit generated files | Phase X architecture plan |
| 2026-04-14 | HEAP-001 | Heap-adaptive history cap: `clamp(free_heap/3, 12000, 60000)` — safety net until chunked streaming | `Docs/phase-V-implementation-plan-addendum-v7.6.9.4.md` |
| 2026-04-16 | HEAP-002 | `csv.reserve()` does NOT truncate — known BUG-082, full fix deferred to Phase 7 | `Docs/lessons/firmware.md` (BUG-082) |
| 2026-04-20 | SEC-RV03 | v7.6.9.6 (Cloudflare polling fix) dropped as self-resolved; SEC-ADR amendment appended directly | `Docs/decisions/SEC-ADR-001-RV-03-amendment.md` |
| 2026-04-26 | STACK-001 | Uniform 16 KB httpd stack for all boards via local component override | `Docs/lessons/firmware.md` (BUG-083, LESSON-OPS-128) |
| 2026-05-05 | BOARD-001 | 6-board fleet: C3, WROOM, S3-16M, S3-4M, C6, C5. All compile. C5 BLE pending antenna retest. | `Docs/board-measurement-log-v7.6.10.md` |
| 2026-05-06 | AUTH-001 | Application-level auth via `dashboard/core/auth.js` with `authFetch()` wrapper. Browser native dialogs eliminated. | `Docs/session-log-2026-05-06-v7.6.10.4.md` |

---

_Add new entries at the bottom. Format: date, short ID, one-line decision, link to source._
