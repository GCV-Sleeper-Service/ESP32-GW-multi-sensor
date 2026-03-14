# 2026-03-13 addendum — YAML indentation hotfix

- Root cause: `render_yaml_file()` was still routing YAML marker regions through `replace_marker_block()` even after `apply_yaml_marker_block()` had been added.
- Impact: `python3 scripts/render_sensor_config.py --write` reintroduced broken indentation under YAML parents/block scalars, causing `esphome compile` to fail near the averaging block.
- Why preflight missed it: current preflight validates version/sync expectations but does not parse the YAML.
- Fix: switch YAML marker replacements to `apply_yaml_marker_block()`, restore compile-clean YAML, and keep version at `v7.5.0.1`.
- Follow-up recommendation: add an `esphome config` or equivalent YAML parse check to preflight.
