# Phase Y — PR Audit Question Template

_Use this template for every Phase Y PR audit. Stable core applies to all steps. Phase Y supplements are C++ split-specific._

---

## Stable Core (apply to every PR)

### Internal (agent self-review)

1. Did the PR match the scope defined in the step prompt? List any deviations as omission/addition/substitution.
2. Did the codebase state match the prompt's assumptions when the agent started?
3. What autonomous decisions did the agent make that were not in the prompt?
4. Were any new lessons or critical rules discovered during execution?
5. What context does the next step need from this step?

### External (reviewer verification)

6. Are all acceptance criteria from §6 of the implementation prompt met?
7. Do all Playwright tests pass across all 4 fixture sets (3sensor, mixed, system, aggregator)?
8. Does `bash scripts/preflight.sh` pass?
9. Does `esphome config` validate for all relevant board profiles?
10. Were any files modified outside the declared scope? (Check `git diff --name-only`)
11. Is the changelog entry present and accurate?
12. Is the consolidated audit document produced?
13. Was the next step's handoff inspected and updated if needed?

---

## Phase Y Supplements (C++ split-specific)

14. Does the `#include` order in the assembly file (`assemble-sensor-history.sh` MODULES array) match the plan's specified order?
15. Are all `static` declarations intentional and correctly scoped after the split?
16. Are mutex/lock primitives (`s_cache_mutex`, `AGG_LOCK`/`AGG_UNLOCK`) visible from all files that access shared state?
17. Are deferred-task functions visible from their scheduling call sites? (All 4 pairs: reboot, delete-data, reset-satellites, save-satellites-nvs)
18. Did `render_sensor_config.py --check` pass after the split?
19. Is the YAML `includes:` list correct for the current step's file structure? (Should still reference only `dashboard/sensor_history_multi.h`)
20. Was the verification gate (compile/assembly-identity/device-test) executed and documented?

---

## Retrospective

21. What prompt change would have prevented any failures encountered during this step?

---

## Step-Specific Supplement Selection

| Step | Additional focus areas |
|------|----------------------|
| v7.6.6.0 | Pipeline automation: `--dry-run` works? All board modes covered? `status` non-mutating? |
| v7.6.6.1 | Fragment extraction: line counts sum to 4,325? SHA-256 identity verified? All 8 fragments exist? |
| v7.6.6.2 | Pipeline wiring: assembly step active in provision.sh? New preflight checks added and passing? |
| v7.6.6.3 | Workflow validation: edit→assemble→pipeline→check cycle works? Deliberate-break test executed? |
| v7.6.6.4 | PingAdapter fragment: compile-guard boundary (`#ifdef PING_DEVICE_INDEX`) intact? |
| v7.6.6.5 | NVS device test: boot restore confirmed? History retention survives reboot? Hourly persist writes? |
| v7.6.6.6 | Aggregator device test: poll task starts? All aggregator endpoints respond? Satellite NVS survives reboot? |
| v7.6.6.7 | Full smoke test: all 21 endpoint handlers verified? Both C3 and S3 board profiles? |
| v7.6.6.8 | Closure: all new preflight checks pass? README + lessons + prompt-index updated? Critical Rules 58–62 added? |

---

_End of Phase Y PR Audit Question Template._
