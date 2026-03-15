#!/usr/bin/env node
/**
 * generate-fixtures.js
 *
 * Generates deterministic JSON and CSV fixtures for the mock server.
 */
'use strict';

const fs = require('fs');
const path = require('path');

const FIXTURES_ROOT = path.join(__dirname);
const VARIANTS_ROOT = path.join(FIXTURES_ROOT, 'variants');
const ROOT = path.join(__dirname, '..', '..');
const VERSION_RAW = '7.5.1';   // no v-prefix — matches Python's VERSION constant
const VERSION_TAG = 'v7.5.1'; // v-prefix — used in api-status.json

const SENSOR_LIBRARY = [
  { id: 'office', name: 'Office', tempBase: 21.4, humBase: 44 },
  { id: 'first_floor', name: 'First Floor', tempBase: 19.2, humBase: 51 },
  { id: 'outside', name: 'Outside', tempBase: 8.1, humBase: 68 },
  { id: 'garage', name: 'Garage', tempBase: 12.8, humBase: 57 },
];

// Default v2 metadata — must mirror DEFAULT_GATEWAY / DEFAULT_HISTORY in sensor_manifest_lib.py
const DEFAULT_GATEWAY = {
  id: 'gw-main',
  name: 'Main Gateway',
  role: 'satellite',
  hardware: 'ESP32-C3',
};

const DEFAULT_HISTORY = {
  backend: 'nvs',
  retention_hours: 1080,
  ram_window_hours: 24,
  sample_interval_seconds: 900,
};

const THERMOPRO_MEASUREMENTS = [
  {
    key: 'temp',
    name: 'Temperature',
    class: 'analog_numeric',
    data_type: 'float',
    unit: 'celsius',
    unit_symbol: '\u00b0C',
    bounds: { min: -50, max: 80 },
    history: true,
    history_suffix: 'temp',
    display: { precision: 1, chart: true },
  },
  {
    key: 'hum',
    name: 'Humidity',
    class: 'analog_numeric',
    data_type: 'float',
    unit: 'percent',
    unit_symbol: '%',
    bounds: { min: 0, max: 100 },
    history: true,
    history_suffix: 'hum',
    display: { precision: 1, chart: true },
  },
];

const ANCHOR_EPOCH_SEC = 1741694400; // 2025-03-11 12:00:00 UTC
const POINTS = 96;
const INTERVAL_SEC = 15 * 60;

function pseudoRand(seed) {
  const x = Math.sin(seed + 1) * 10000;
  return x - Math.floor(x);
}

function buildCsvLines(sensorIdx, series, base) {
  const lines = [];
  for (let i = 0; i < POINTS; i++) {
    const ts = ANCHOR_EPOCH_SEC - (POINTS - 1 - i) * INTERVAL_SEC;
    const noise = (pseudoRand(sensorIdx * 1000 + i + (series === 'hum' ? 5000 : 0)) - 0.5) * 2.0;
    const val = (base + noise).toFixed(2);
    lines.push(`${ts},${val}`);
  }
  return lines.join('\n') + '\n';
}

function materializeSensors(sensors) {
  return sensors.map((sensor, idx) => ({
    id: sensor.id,
    name: sensor.name,
    tempBase: typeof sensor.tempBase === 'number' ? sensor.tempBase : (18.0 + idx * 2.1),
    humBase: typeof sensor.humBase === 'number' ? sensor.humBase : (42 + idx * 7),
    category: sensor.category || 'environmental',
    adapter: sensor.adapter || 'thermopro_ble',
    measurements: sensor.measurements || THERMOPRO_MEASUREMENTS,
  }));
}

function readManifestData(manifestPath) {
  const absolute = path.isAbsolute(manifestPath) ? manifestPath : path.join(ROOT, manifestPath);
  const payload = JSON.parse(fs.readFileSync(absolute, 'utf8'));
  const rawSensors = Array.isArray(payload) ? payload : (payload.sensors || []);
  if (!Array.isArray(rawSensors) || rawSensors.length === 0) {
    throw new Error(`Manifest has no sensors: ${manifestPath}`);
  }
  return {
    sensors: materializeSensors(rawSensors),
    gateway: (!Array.isArray(payload) && payload.gateway) || DEFAULT_GATEWAY,
    history: (!Array.isArray(payload) && payload.history) || DEFAULT_HISTORY,
  };
}

function fixtureManifestV1(sensors) {
  return sensors.map(({ id, name }) => ({ id, name }));
}

/**
 * Build a v2 manifest that is byte-identical to Python's manifest_v2() output
 * when serialised with JSON.stringify(..., null, 2).
 *
 * Rules that must match sensor_manifest_lib.py exactly:
 *   - source field: 'repo-fixture' for baseline fixtures
 *   - version field: VERSION_RAW (no v-prefix)
 *   - unit_symbol for °C: literal UTF-8 character (Python uses ensure_ascii=False)
 *   - field insertion order must match the Python dict literal
 */
function fixtureManifestV2(sensors, gateway, history, source) {
  return {
    ok: true,
    schema_version: 2,
    source: source || 'repo-fixture',
    version: VERSION_RAW,
    gateway: gateway,
    history: history,
    sensor_count: sensors.length,
    sensors: sensors.map(({ id, name, category, adapter, measurements }) => ({
      id,
      name,
      category: category || 'environmental',
      adapter: adapter || 'thermopro_ble',
      measurements: measurements || THERMOPRO_MEASUREMENTS,
    })),
  };
}

function writeFixtureSet(targetDir, sensors, gateway, history, tag) {
  fs.mkdirSync(targetDir, { recursive: true });
  const legacyManifest = fixtureManifestV1(sensors);
  // Baseline fixtures always use 'repo-fixture' as source — Python is authoritative.
  const source = 'repo-fixture';
  const v2Manifest = fixtureManifestV2(sensors, gateway, history, source);

  fs.writeFileSync(path.join(targetDir, 'sensors.json'), JSON.stringify(legacyManifest, null, 2) + '\n');
  fs.writeFileSync(path.join(targetDir, 'manifest.json'), JSON.stringify(v2Manifest, null, 2) + '\n');
  fs.writeFileSync(path.join(targetDir, 'api-status.json'), JSON.stringify({
    ok: true,
    version: VERSION_TAG,
    sensor_count: sensors.length,
    sensors: legacyManifest,
    mode: 'active-manifest',
    connected: true,
  }, null, 2) + '\n');
  fs.writeFileSync(path.join(targetDir, 'storage-stats.json'), JSON.stringify({
    ok: true,
    partition: 'history',
    total_bytes: 524288,
    used_bytes: Math.round(184320 * Math.max(1, sensors.length) / 3),
    free_bytes: Math.max(0, 524288 - Math.round(184320 * Math.max(1, sensors.length) / 3)),
    retention_days: 45,
    retention_oldest_epoch: ANCHOR_EPOCH_SEC - POINTS * INTERVAL_SEC,
    retention_newest_epoch: ANCHOR_EPOCH_SEC,
    segment_count: POINTS,
    mode: tag || 'mock',
  }, null, 2) + '\n');

  sensors.forEach((sensor, idx) => {
    fs.writeFileSync(path.join(targetDir, `history-${sensor.id}-temp.csv`), buildCsvLines(idx, 'temp', sensor.tempBase));
    fs.writeFileSync(path.join(targetDir, `history-${sensor.id}-hum.csv`), buildCsvLines(idx, 'hum', sensor.humBase));
  });
}

function writeVariant(count) {
  const sensors = materializeSensors(SENSOR_LIBRARY.slice(0, count));
  const dir = path.join(VARIANTS_ROOT, `${count}sensor`);
  writeFixtureSet(dir, sensors, DEFAULT_GATEWAY, DEFAULT_HISTORY, `${count}sensor`);
  console.log(`generated variant: ${count}sensor -> ${dir}`);
}

(function main() {
  const args = process.argv.slice(2);
  let targetCount = null;
  let overwriteBaseline = false;
  let manifestPath = '';

  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--count' && args[i + 1]) {
      targetCount = parseInt(args[i + 1], 10);
      i++;
    } else if (args[i] === '--overwrite-baseline') {
      overwriteBaseline = true;
    } else if (args[i] === '--manifest' && args[i + 1]) {
      manifestPath = args[i + 1];
      i++;
    }
  }

  if (manifestPath) {
    const { sensors, gateway, history } = readManifestData(manifestPath);
    if (!overwriteBaseline) {
      console.error('--manifest requires --overwrite-baseline so the root mock fixtures stay aligned with the active repo configuration.');
      process.exit(1);
    }
    writeFixtureSet(FIXTURES_ROOT, sensors, gateway, history, 'active-manifest');
    console.log(`baseline fixtures overwritten from manifest: ${manifestPath}`);
    process.exit(0);
  }

  if (targetCount !== null) {
    if (targetCount < 1 || targetCount > 4) {
      console.error('Error: --count must be 1, 2, 3, or 4');
      process.exit(1);
    }
    writeVariant(targetCount);
    if (overwriteBaseline) {
      const sensors = materializeSensors(SENSOR_LIBRARY.slice(0, targetCount));
      writeFixtureSet(FIXTURES_ROOT, sensors, DEFAULT_GATEWAY, DEFAULT_HISTORY, `${targetCount}sensor`);
      console.log(`baseline fixtures overwritten with ${targetCount} sensor(s)`);
    }
    process.exit(0);
  }

  [1, 2, 3, 4].forEach(writeVariant);
  if (overwriteBaseline) {
    console.error('Warning: --overwrite-baseline requires either --count N or --manifest <path>. Skipped baseline overwrite.');
  }
})();
