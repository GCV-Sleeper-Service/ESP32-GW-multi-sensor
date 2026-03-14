# Bugs and Lessons Learned Addendum — 2026-03-13

## Latest first

### YAML generator inserted valid content with invalid indentation
- **Symptom:** ESPHome compile failed with YAML parsing errors.
- **Cause:** `render_sensor_config.py` generated correct YAML bodies but inserted them with `replace_marker_block()`, which does not preserve indentation from the marker line.
- **Fix:** Route all YAML marker replacements through `apply_yaml_marker_block()`.

### Regex replacement with generated backslash content
- **Symptom:** `render_sensor_config.py --write` failed with `re.PatternError: bad escape \x`.
- **Cause:** Generated replacement text contained sequences like `\xC2\xB0`, which are unsafe in raw string replacement mode for `re.sub`.
- **Fix:** Use lambda/function replacements so generated content is treated literally.

### Compact one-line source blocks made migration patchers brittle
- **Symptom:** repeated failures applying the Phase 1 patch script to `dashboard/sensor_history_multi.h`.
- **Cause:** inline/compacted source layout made comment-based or exact long-string matching fragile.
- **Fix:** future patchers should use function anchors, regex, and brace-aware insertion rather than exact long snippets.
