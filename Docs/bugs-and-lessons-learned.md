# Bugs and Lessons Learned — Redirect

_This file has been split into domain-scoped files at v7.6.4.0._
_See `Docs/lessons/index.md` for the complete cross-reference._

| Domain | File |
|--------|------|
| Dashboard | `Docs/lessons/dashboard.md` |
| Firmware | `Docs/lessons/firmware.md` |
| Build Pipeline | `Docs/lessons/build-pipeline.md` |
| Testing | `Docs/lessons/testing.md` |
| Operations | `Docs/lessons/operations.md` |

## Latest Operational Addendum

- `LESSON-OPS-126` moved into `Docs/lessons/operations.md`: checkpoint grep assertions must be validated against the actual replacement block in the same prompt.
- Critical Rule: checkpoint grep counts must be mechanically derived from the replacement block in the same prompt, not estimated from memory.
