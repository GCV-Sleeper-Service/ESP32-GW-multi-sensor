# Phase 10 — Dashboard UI Enhancements Plan

_Date: 2026-05-07 (multi-phase planning session)_
_Version range: v10.0.x_
_Depends on: None (can run after any phase; lowest priority)_

---

## Goal

Responsive dashboard sizing and multi-language interface support.

## Standalone Role Assessment

A dedicated "standalone" board role was evaluated and found **not worth a full phase**. A satellite with `AGGREGATOR_ENABLED=0` and no aggregator on the network IS standalone. Savings from a formal role: ~3-4 KB flash, 0 heap. Instead, add a `standalone: true` board profile option that disables management auth and excludes gateway-panel from the dashboard bundle. This is a 1-2 step effort within Phase 7 or Phase E.

## Step Breakdown

| Step | Version | Scope |
|---|---|---|
| 10.0 | v10.0.0.0 | Research: responsive CSS framework, i18n approach, translation format |
| 10.1 | v10.0.0.1 | Responsive CSS: breakpoints, grid layout, chart resize listeners |
| 10.2 | v10.0.1.1 | i18n framework: translation object, language selector in settings |
| 10.3 | v10.0.1.2 | Spanish and German translations |
| 10.4 | v10.0.2.1 | Accessibility: ARIA labels, keyboard navigation |

## Flash Impact

| Component | Flash Cost |
|---|---|
| Responsive CSS | ~5-8 KB |
| i18n framework + 3 languages | ~10-15 KB |
| **Total** | **~15-23 KB** |

C6 4 MB flash constraint: monitor binary size. May need to make i18n a compile-time option.

---

_End of Phase 10 plan._
