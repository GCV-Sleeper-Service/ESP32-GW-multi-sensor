# Fresh Start Prompt Template

Use this as the starting message in a new chat/session.

---

This is a continuation of the ESP32 BLE gateway project for repo:

https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Please start from the current known-good baseline: **v7.5.0.1**.

Before doing anything else, review these files first:
1. `Docs/phase2-handoff-fresh-start.md`
2. `Docs/session-log-2026-03-14-phase1-complete.md`
3. `Docs/bugs-and-lessons-learned.md`
4. `Docs/changelog.md`
5. `Docs/v7.5-v7.6-architecture-plan.md`

Important current status:
- Phase 1 is complete and runtime-validated.
- `/api/manifest`, `/api/status`, and `/sensors.json` are all working.
- Dashboard and built-in ESP web page both show Free Heap and Uptime again.
- Current baseline version is `v7.5.0.1`.
- The generator is currently idempotent and compile-clean.

For this session and future sessions:
1. Keep the session output documented as a session log / handoff file.
2. Update changelog and bugs/lessons-learned alongside development.
3. Keep bugs and lessons learned in reverse chronological order.
4. If code changes are nontrivial, provide a full overwrite bundle in ZIP form.
5. Keep source-of-truth discipline:
   - fix source first
   - regenerate derived artifacts
6. Do not assume generated files are correct; verify source/generated alignment.
7. If anything is unclear, ask first rather than guessing.
8. If the current local files differ from the repo baseline, ask me to upload the local files and patch those directly.

Before coding, please:
- summarize the current project state from the listed docs
- summarize the exact next-step scope from the architecture plan
- confirm risks / regression points based on the Phase 1 lessons learned
- then propose the implementation sequence for the next phase

Recommended baseline commands to confirm before new changes:
```bash
python3 scripts/render_sensor_config.py --write
bash ./scripts/preflight.sh
esphome compile firmware/esp32-c3-multi-sensor.yaml
```

Recommended runtime smoke check:
```bash
curl -s http://<esp-ip>/sensors.json | jq
curl -s http://<esp-ip>/api/status | jq
curl -s http://<esp-ip>/api/manifest | jq
```

---

Optional addition if local repo drift is suspected:
“I am also uploading the current local copies of `firmware/esp32-c3-multi-sensor.yaml`, `scripts/render_sensor_config.py`, and any changed dashboard files. Prefer those over reconstructing from memory.”
