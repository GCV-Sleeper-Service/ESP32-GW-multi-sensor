---
applyTo: "scripts/**"
---
Pipeline ordering matters: provision → assemble → render → bundle → build → minify → generate-header → compile.
Never use `esphome run` — use `esphome upload --device=IP` for OTA or `esphome compile` for build-only.
Scripts must work from the repo root directory.