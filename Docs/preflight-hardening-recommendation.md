# Preflight Hardening Recommendation

## Current answer
**No, the currently verified preflight success does not prove the YAML indentation problem is permanently covered by the main `scripts/preflight.sh` yet.**

What was proven in this session:
- final preflight passed
- final compile passed
- runtime passed

What was *not* yet proven as permanently folded into the main preflight:
- an explicit ESPHome/YAML parse gate that fails before compile when generator indentation is broken

## Recommended hardening
Add a supplemental parse step to preflight:

```bash
if esphome config firmware/esp32-c3-multi-sensor.yaml >/dev/null 2>&1; then
  echo "esphome_config_parse: PASS"
else
  echo "esphome_config_parse: FAIL"
  exit 1
fi
```

## Why
Phase 1 showed that:
- generated files can be in sync
- version checks can pass
- fixture checks can pass
- but YAML can still be structurally invalid

## Recommendation for Phase 2
Fold this parse gate into the main `scripts/preflight.sh` at the start of Phase 2, and keep the supplemental script below available immediately.
