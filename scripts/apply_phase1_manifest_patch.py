#!/usr/bin/env python3
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VERSION = "7.5.0.0"


def replace_version_markers(text: str) -> str:
    text = text.replace("sensor_history_multi-v7.4.5.1.h", f"sensor_history_multi-v{VERSION}.h")
    text = text.replace("// ── SENSOR COUNT CONFIGURATION GUIDE (v7.4.5.1) ──", f"// ── SENSOR COUNT CONFIGURATION GUIDE (v{VERSION}) ──")
    text = text.replace("v7.4.5.1", f"v{VERSION}")
    return text


def find_block_end(text: str, start_idx: int) -> int:
    brace = text.find("{", start_idx)
    if brace < 0:
        raise RuntimeError("Could not find opening brace for block")
    depth = 0
    for i in range(brace, len(text)):
        ch = text[i]
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return i + 1
    raise RuntimeError("Could not find closing brace for block")


def patch_dashboard_js(text: str) -> str:
    # tolerate already-patched dashboard.js
    text = re.sub(r"App\.version\s*=\s*'v[0-9.]+'", f"App.version = 'v{VERSION}'", text, count=1)

    if "/api/manifest" in text and "normalizeManifestSensors" in text:
        return text

    normalize_fn = (
        "function normalizeManifestSensors(payload) { "
        "var sensors = []; "
        "if (Array.isArray(payload)) sensors = payload; "
        "else if (payload && Array.isArray(payload.sensors)) sensors = payload.sensors; "
        "return sensors.map(function(sensor) { "
        "return { "
        "id: String(sensor && sensor.id || '').trim(), "
        "name: String(sensor && sensor.name || '').trim(), "
        "metrics: Array.isArray(sensor && sensor.metrics) ? sensor.metrics : [] "
        "}; "
        "}).filter(function(sensor) { return sensor.id && sensor.name; }); "
        "} "
    )

    new_load_fn = (
        "function loadSensorManifest() { "
        "return fetch(ESP_HOST + '/api/manifest', {cache:'no-store'}) "
        ".then(function(r) { if (!r.ok) throw new Error('HTTP ' + r.status); return r.json(); }) "
        ".then(function(payload) { "
        "var meta = normalizeManifestSensors(payload); "
        "if (!meta.length) throw new Error('empty manifest'); "
        "applySensorMeta(meta); "
        "var schema = payload && payload.schema_version ? payload.schema_version : 'legacy'; "
        "dlog('Manifest loaded from /api/manifest (schema ' + schema + ', ' + SENSORS.length + ' sensors)', 'ok'); "
        "}) "
        ".catch(function(apiErr) { "
        "return fetch(ESP_HOST + '/sensors.json', {cache:'no-store'}) "
        ".then(function(r) { if (!r.ok) throw new Error('HTTP ' + r.status); return r.json(); }) "
        ".then(function(payload) { "
        "var meta = normalizeManifestSensors(payload); "
        "if (!meta.length) throw new Error('empty legacy manifest'); "
        "applySensorMeta(meta); "
        "dlog('Manifest fallback loaded from /sensors.json (' + SENSORS.length + ' sensors); /api/manifest unavailable: ' + apiErr.message, 'err'); "
        "}) "
        ".catch(function(legacyErr) { "
        "applySensorMeta(DEFAULT_SENSOR_META); "
        "dlog('Manifest unavailable, using built-in (' + DEFAULT_SENSOR_META.length + ' sensors): api=' + apiErr.message + '; legacy=' + legacyErr.message, 'err'); "
        "}); "
        "}); "
        "}"
    )

    if "function normalizeManifestSensors(payload)" not in text:
        if "function applySensorMeta(" in text:
            text = text.replace("function applySensorMeta(", normalize_fn + "function applySensorMeta(", 1)
        elif "function loadSensorManifest(" in text:
            text = text.replace("function loadSensorManifest(", normalize_fn + "function loadSensorManifest(", 1)
        else:
            raise RuntimeError("Could not find insertion point for normalizeManifestSensors()")

    anchor = "function loadSensorManifest()"
    start = text.find(anchor)
    if start < 0:
        anchor = "function loadSensorManifest("
        start = text.find(anchor)
    if start < 0:
        raise RuntimeError("Could not find loadSensorManifest() in dashboard.js")
    end = find_block_end(text, start)
    text = text[:start] + new_load_fn + text[end:]
    return text


def patch_history_header(text: str) -> str:
    text = replace_version_markers(text)

    # 1) Add /api/manifest to GET allowlist after /sensors.json
    allowlist_pat = re.compile(
        r'(if\s*\(\s*len\s*==\s*13\s*&&\s*memcmp\s*\(\s*p\s*,\s*"/sensors\.json"\s*,\s*13\s*\)\s*==\s*0\s*\)\s*return\s+true\s*;)'
    )
    if '"/api/manifest"' not in text:
        text, n = allowlist_pat.subn(r'\1 if (strcmp(p, "/api/manifest") == 0) return true;', text, count=1)
        if n != 1:
            raise RuntimeError("Could not patch canHandle() allowlist for /api/manifest")

    # 2) Add /api/manifest dispatch right after /api/status
    if 'handle_api_manifest_(request)' not in text:
        dispatch_pat = re.compile(
            r'(if\s*\(\s*strcmp\s*\(\s*p\s*,\s*"/api/status"\s*\)\s*==\s*0\s*\)\s*\{\s*handle_status_\(\s*request\s*\)\s*;\s*return\s*;\s*\})'
        )
        text, n = dispatch_pat.subn(
            r'\1 if (strcmp(p, "/api/manifest") == 0) { handle_api_manifest_(request); return; }',
            text,
            count=1,
        )
        if n != 1:
            raise RuntimeError("Could not patch handleRequest() dispatch for /api/manifest")

    # 3) Insert new handler immediately after legacy handle_manifest_
    if "void handle_api_manifest_(AsyncWebServerRequest *request) const" not in text:
        manifest_anchor = "void handle_manifest_(AsyncWebServerRequest *request) const"
        start = text.find(manifest_anchor)
        if start < 0:
            raise RuntimeError("Could not find legacy handle_manifest_()")
        end = find_block_end(text, start)

        insertion = (
            ' void handle_api_manifest_(AsyncWebServerRequest *request) const { '
            'auto *resp = request->beginResponseStream("application/json"); '
            'add_common_headers_(resp); '
            'char num[224]; '
            'resp->print("{\\"ok\\":true,\\"schema_version\\":2,\\"source\\":\\"firmware\\",\\"version\\":\\""); '
            'resp->print(firmware_version_.c_str()); '
            'resp->print("\\","); '
            'snprintf(num, sizeof(num), "\\"sensor_count\\":%d,", NUM_SENSORS); '
            'resp->print(num); '
            'resp->print("\\"metrics\\":[{\\"key\\":\\"temp\\",\\"name\\":\\"Temperature\\",\\"unit\\":\\"celsius\\",\\"unit_symbol\\":\\"\\\\u00B0C\\",\\"bounds\\":{\\"min\\":-50,\\"max\\":80},\\"history_suffix\\":\\"temp\\"},{\\"key\\":\\"hum\\",\\"name\\":\\"Humidity\\",\\"unit\\":\\"percent\\",\\"unit_symbol\\":\\"%\\",\\"bounds\\":{\\"min\\":0,\\"max\\":100},\\"history_suffix\\":\\"hum\\"}],\\"sensors\\":["); '
            'for (int i = 0; i < NUM_SENSORS; i++) { '
            'if (i > 0) resp->print(","); '
            'resp->print("{\\"id\\":\\""); '
            'resp->print(sensors[i].id); '
            'resp->print("\\",\\"name\\":\\""); '
            'resp->print(sensors[i].name); '
            'snprintf(num, sizeof(num), "\\",\\"metrics\\":[{\\"key\\":\\"temp\\",\\"history\\":\\"/history/%s/temp\\"},{\\"key\\":\\"hum\\",\\"history\\":\\"/history/%s/hum\\"}]}", sensors[i].id, sensors[i].id); '
            'resp->print(num); '
            '} '
            'resp->print("]}"); '
            'request->send(resp); '
            '}'
        )
        text = text[:end] + insertion + text[end:]

    # 4) Optional startup log enrichment
    if 'manifest -> GET /api/manifest' not in text:
        text = re.sub(
            r'ESP_LOGI\(TAG,\s*" status -> GET /api/status"\);\s*ESP_LOGI\(TAG,\s*" storage -> dedicated NVS partition: %s / namespace: %s",\s*HISTORY_PARTITION_LABEL,\s*HISTORY_NAMESPACE\);\s*\}',
            'ESP_LOGI(TAG, " status -> GET /api/status"); ESP_LOGI(TAG, " manifest -> GET /api/manifest (legacy /sensors.json retained)"); ESP_LOGI(TAG, " storage -> dedicated NVS partition: %s / namespace: %s", HISTORY_PARTITION_LABEL, HISTORY_NAMESPACE); }',
            text,
            count=1,
        )

    return text


def patch_firmware_yaml(text: str) -> str:
    text = replace_version_markers(text)
    text = text.replace(
        "# Registers custom /history/*, /sensors.json, /dashboard.html, # /dashboard-download, /api/storage-stats, and /api/status via AsyncWebHandler.",
        "# Registers custom /history/*, /sensors.json, /api/manifest, /dashboard.html, # /dashboard-download, /api/storage-stats, and /api/status via AsyncWebHandler.",
    )
    return text


def main() -> int:
    targets = [
        (ROOT / "dashboard" / "dashboard.js", patch_dashboard_js),
        (ROOT / "dashboard" / "sensor_history_multi.h", patch_history_header),
        (ROOT / "firmware" / "esp32-c3-multi-sensor.yaml", patch_firmware_yaml),
    ]

    for path, fn in targets:
        if not path.exists():
            raise SystemExit(f"Missing expected file: {path}")
        original = path.read_text(encoding="utf-8")
        updated = fn(original)
        if updated != original:
            path.write_text(updated, encoding="utf-8")
            print(f"patched {path.relative_to(ROOT)}")
        else:
            print(f"no change needed for {path.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
