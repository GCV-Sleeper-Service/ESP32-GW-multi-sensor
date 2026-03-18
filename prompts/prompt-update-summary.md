# Prompt Update Summary — Post-BUG-043

_Which instruction files need changes and what changed._

---

## Files that need NO changes (use as-is)

These instruction files are correct and can be used without modification:

| File | Reason |
|---|---|
| `v7_5_3_5-implementation-instructions.md` | Already done. Mark as ✅ Complete in the templates. |
| `v7_5_3_6-implementation-instructions.md` | /api/v2/live — no history handler changes, no impact from BUG-043 |
| `v7_5_3_9-implementation-instructions.md` | Phase 3 closure — testing/docs only |
| `v7_5_4_0-implementation-instructions.md` | Manifest schema only — no firmware response handlers |
| `v7_5_4_1-implementation-instructions.md` | Ping adapter — RTOS task, not HTTP handler |
| `v7_5_4_2-implementation-instructions.md` | Dashboard card renderer only |
| `v7_5_4_3-implementation-instructions.md` | Test fixtures only |
| `v7_5_4_4-implementation-instructions.md` | Phase 4 closure — testing/docs only |
| `v7_5_5_0-implementation-instructions.md` | Config schema only |
| `v7_5_5_4-implementation-instructions.md` | Playwright tests only |
| `v7_5_5_5-implementation-instructions.md` | Phase 5 closure — docs only |

## Files that need UPDATES (included in package)

| File | What changed |
|---|---|
| `v7_5_3_7-implementation-instructions.md` | **CRITICAL** — Must use pre-reserved string pattern (LESSON-OPS-056). Added explicit code example. Must NOT use beginResponseStream. Updated file included in package. |
| `v7_5_3_8-implementation-instructions.md` | Add note: handle_history_ was rewritten during BUG-043 — the switchover must preserve the pre-reserved string pattern, not revert to beginResponseStream. Add to Required Reading: LESSON-OPS-055, LESSON-OPS-056. |
| `v7_5_5_1-implementation-instructions.md` | Aggregator polling task — any proxied history responses must use pre-reserved string pattern. Add LESSON-OPS-056 reference. |
| `v7_5_5_2-implementation-instructions.md` | Aggregator API endpoints — proxy history responses must follow LESSON-OPS-056. |
| `v7_5_5_3-implementation-instructions.md` | Aggregator dashboard — add note: dashboard.h is now gzip-compressed, `generate-header.sh` handles this automatically. |

## Key rule additions for ALL future prompts

Add to the "Critical rules" section of every prompt that touches `sensor_history_multi.h`:

```
- NEVER use beginResponseStream() for responses that could exceed ~10KB.
  Use pre-reserved std::string + zero-copy beginResponse instead (LESSON-OPS-056).
- dashboard.h is gzip-compressed. generate-header.sh handles this automatically.
  The firmware serves with Content-Encoding: gzip (LESSON-OPS-055).
```

