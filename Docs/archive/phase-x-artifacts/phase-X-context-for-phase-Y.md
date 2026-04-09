# Phase X — Context, Rationale, and Phase Y Preparation

_Date: 2026-04-05_
_Status: Phase X planning complete; implementation pending_
_Audience: Future session planning Phase Y (firmware refactor, v7.6.6.x)_

---

## 1. Why Phase X Was Necessary

The dashboard had grown into two monolithic files that made every coding-agent task expensive and error-prone:

- **`dashboard.js`** — 3,955 lines of JavaScript. Every task, no matter how small, required the agent to load the entire file (~25K tokens).
- **`dashboard.html`** — 4,900 lines, manually mirrored from `dashboard.js`. Every JS change had to be duplicated into the HTML file (LESSON-OPS-043). Forgetting this mirror step caused multiple bugs (BUG-039 and others).
- **`dashboard.spec.js`** — 1,853 lines of Playwright tests in a single file.
- **`Docs/bugs-and-lessons-learned.md`** — 3,069 lines. Every prompt required loading all domain lessons.

Combined, a typical dashboard feature task required ~55K–70K tokens of context before the agent could write a single line of code. This exceeded the practical context window for coding agents (30K–40K tokens).

Phase D (runtime satellite management) added ~640 lines to the dashboard, making the problem worse. Phase 7 (per-device persistence UI) would add even more. Without restructuring, scaling the dashboard to future features was impractical.

---

## 2. What Phase X Delivers

| Level | Version Range | Outcome |
|-------|--------------|---------|
| Pre-step | v7.6.4.0 | Documentation split into domain-scoped files (~4x token reduction per prompt) |
| Level 1 | v7.6.5.0–v7.6.5.1 | JS monolith → 21 ordered modules. Bundled by `bundle-dashboard.sh`. Identity gate: concatenation reproduces the original byte-for-byte. |
| Level 2 | v7.6.5.2–v7.6.5.3 | HTML mirror eliminated. `dashboard.html` is now a generated artifact from `dashboard.tmpl.html` + `dashboard.js`. LESSON-OPS-043 structurally resolved. |
| Level 3 | v7.6.5.4–v7.6.5.6 | Component model: `dashboard/core/` + `dashboard/components/*/` with JS, HTML template, and CSS per component. Three-pass build: CSS → templates → JS. |
| Test/Closure | v7.6.5.7–v7.6.5.8 | Test monolith split into domain-scoped test files. Documentation, critical rules, and README updated. |

**Result:** A typical dashboard feature task now requires ~8K–15K tokens (one component + core state + domain test file + domain lessons). That is a 6x–8x reduction.

---

## 3. Phase X Methodology (Reusable for Phase Y)

### 3.1 Identity gate pattern

Every step that restructures code produces output that is content-identical to the previous step. This is verified by SHA-256 comparison:

```bash
SHA_BEFORE=$(sha256sum output_file | cut -d' ' -f1)
# ... perform restructuring ...
SHA_AFTER=$(sha256sum output_file | cut -d' ' -f1)
[[ "$SHA_BEFORE" == "$SHA_AFTER" ]] || { echo "IDENTITY GATE FAILED"; exit 1; }
```

For Phase X, the identity gate applies to `dashboard.js` (Level 1) and `dashboard.html` (Level 2). For Phase Y, it would apply to the compiled firmware binary or intermediate object files.

### 3.2 Contiguous-slice splitting

Modules are defined as contiguous line ranges from the original monolith, not logical regroupings. This guarantees the identity gate passes. Functions stay where they physically sit — even if the grouping looks unexpected from a logical perspective.

The plan revision session (documented in `Docs/phase-x-revision-changelog.md`) demonstrated why this matters: the original plan assigned functions by logical affinity, which would have broken the identity gate because functions at line 529 would need to move past functions at line 1512.

### 3.3 Incremental pipeline extension

Each step adds exactly one capability to the build pipeline:
- v7.6.5.0: `bundle-dashboard.sh` (concatenate modules)
- v7.6.5.1: CI integration of bundle check
- v7.6.5.2: `build-dashboard.sh` (template injection)
- v7.6.5.3: CI integration of build check; retire manual mirror
- v7.6.5.5: Two-pass assembly (component templates)
- v7.6.5.6: Three-pass assembly (CSS + templates + JS)

Each step's prompt includes the **full pipeline as of that step**, not just the new addition.

### 3.4 Gate conditions between levels

| Gate | Condition |
|------|-----------|
| Pre-step → Level 1 | v7.6.4.0 merged, no code changes, doc files verified |
| Level 1 → Level 2 | v7.6.5.1 merged, CI green, preflight passes, bundle identity confirmed |
| Level 2 → Level 3 | v7.6.5.3 merged, bit-for-bit gate passed, device testing confirmed |
| Level 3 → Test/docs | v7.6.5.6 merged, three-pass assembly stable, visual regression clean |
| Phase X complete | v7.6.5.8 merged, all tests green, documentation updated |

### 3.5 Migration safety rules

11 rules applied to every Phase X step (documented in the plan §5). Key rules for Phase Y:
1. No behavior changes — structural only
2. All tests must pass after each step
3. Output identity gate
4. Each step independently revertable
5. No heavy toolchain (bash + Python text substitution)

---

## 4. Phase Y Target: sensor_history_multi.h

### Current state

`dashboard/sensor_history_multi.h` — 4,325 lines in a single header file. It contains:

| Area | Description |
|------|-------------|
| Data model | `SatelliteCache` struct, `s_satellites[]`, sensor entity types |
| NVS persistence | `save_satellites_to_nvs_()`, `load_satellites_from_nvs_()`, satellite key/namespace management |
| Ping adapter | ICMP ping probe logic |
| Aggregator polling | `aggregator_poll_task()`, manifest fetch, `fetch_to_buffer()` |
| Web handlers | 15+ HTTP handlers (`handle_live_()`, `handle_history_()`, `handle_aggregator_gateways_()`, etc.) |
| Satellite management | `handle_add_satellite_()`, `handle_delete_satellite_()`, `handle_test_satellite_()` |
| History endpoints | History metric fetch, compact format, proxy history |

### Generator coupling

`render_sensor_config.py` writes into `sensor_history_multi.h` in two places:
1. **Entity block** — sensor entity declarations
2. **Header block** — include directives and configuration

This is more complex than the dashboard's single marker block. The generator modifies multiple sections of the file.

### Build coupling

ESPHome YAML `includes:` list references `sensor_history_multi.h`. After splitting, this list must be updated to include all fragment files.

---

## 5. Phase Y Differences from Phase X

| Aspect | Phase X (dashboard) | Phase Y (firmware) |
|--------|--------------------|--------------------|
| Language | JavaScript | C++ (ESP-IDF) |
| Assembly | `cat` concatenation (bash) | `#include` directives (C++ preprocessor) |
| Manifest | `bundle-dashboard.sh` MODULES array | ESPHome YAML `includes:` list |
| Mirror problem | HTML mirror of JS (LESSON-OPS-043) | No equivalent — single source file |
| Generator | Writes into one marker block (6 lines) | Writes into multiple sections (entity + header blocks) |
| Thread safety | Single-threaded JS | Mutex patterns (`AGG_LOCK`/`AGG_UNLOCK`) must survive split |
| Identity gate | SHA-256 of `dashboard.js` | SHA-256 of compiled binary (or `.o` files) |
| Local component | N/A | `firmware/local_components/web_server_idf/` must stay coordinated |
| Testing | Playwright browser tests | Device testing + serial log verification (no unit test framework) |

### Key Phase Y challenges not present in Phase X

1. **`#include` order matters for C++.** Forward declarations may be needed. The preprocessor concatenates files, but variable/function declarations must be visible before use.
2. **Mutex scope.** `AGG_LOCK()`/`AGG_UNLOCK()` patterns span multiple logical sections. The mutex variable must be accessible from all fragments.
3. **Generator writes into multiple sections.** `render_sensor_config.py` needs updating to write into the correct fragment files (or continue writing into the assembled output and re-running after assembly).
4. **ESPHome YAML integration.** The `includes:` list in board YAML files must reference all fragment files in the correct order.
5. **No browser-based identity gate.** Verification requires firmware compilation and (ideally) binary comparison.

---

## 6. Recommended Phase Y Structure

Based on Phase X patterns, adapted for C++ / ESPHome:

```
dashboard/
  sensor_history_multi.h      ← GENERATED by include-assembly (or retained as monolith with #include fragments)
  firmware_modules/
    data-model.h              — SatelliteCache struct, entity types, shared constants
    nvs-persistence.h         — NVS read/write functions
    ping-adapter.h            — ICMP ping probe
    aggregator-poll.h         — aggregator_poll_task, manifest fetch
    web-handlers-core.h       — shared handler helpers, status, live, history
    web-handlers-management.h — add/delete/test satellite handlers
    web-handlers-proxy.h      — proxy history handler
    satellite-management.h    — satellite array manipulation under mutex
```

**Alternative approach:** Keep `sensor_history_multi.h` as a single file but use `#include` directives to pull in fragments. The assembled file is committed (like `dashboard.js`), and a "bundle" script verifies the includes match the fragments.

---

## 7. Open Questions for Phase Y Planning Session

1. **Identity gate feasibility.** Can we compare compiled `.o` files or firmware binaries before/after the split? ESPHome compilation includes timestamps and other non-deterministic elements that may prevent byte-for-byte comparison. Alternative: functional equivalence via device testing.

2. **Generator strategy.** Should `render_sensor_config.py` write into fragment files (more complex generator changes) or continue writing into the assembled output (requires assembly step before generator, like Phase X's bundle→generator flow)?

3. **Include order.** Does the C++ preprocessor's `#include` mechanism provide sufficient ordering control, or do we need a dedicated assembly script (like `bundle-dashboard.sh`)?

4. **Mutex visibility.** The `s_cache_mutex` and `AGG_LOCK`/`AGG_UNLOCK` macros must be visible across all fragments. Where do they live? In `data-model.h` or in a separate `locks.h`?

5. **Test strategy.** Phase X had Playwright for automated testing. Phase Y's firmware testing is device-based. How do we gate each split step? Options: compile-only gate, device smoke test, or automated serial log parsing.

6. **Local component coordination.** The patched `web_server_idf` in `firmware/local_components/` registers handlers. Does the split require changes to handler registration in `begin()`?

7. **Phase Y before or after Phase 7?** Phase 7 adds per-device persistence, which will grow `sensor_history_multi.h` further. Splitting before Phase 7 reduces the file size being worked with. Splitting after means Phase 7 can proceed without the structural overhead. The Phase X plan recommends Phase Y after Phase X but before Phase 7 — does this still hold?

---

_End of Phase X context for Phase Y._
