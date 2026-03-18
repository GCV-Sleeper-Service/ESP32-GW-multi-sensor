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
const VERSION = 'v7.5.3.9';

const SENSOR_LIBRARY = [
  { id: 'office', name: 'Office', tempBase: 21.4, humBase: 44 },
  { id: 'first_floor', name: 'First Floor', tempBase: 19.2, humBase: 51 },
  { id: 'outside', name: 'Outside', tempBase: 8.1, humBase: 68 },
  { id: 'garage', name: 'Garage', tempBase: 12.8, humBase: 57 },
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
    mac: sensor.mac || null,
    tempBase: typeof sensor.tempBase === 'number' ? sensor.tempBase : (18.0 + idx * 2.1),
    humBase: typeof sensor.humBase === 'number' ? sensor.humBase : (42 + idx * 7),
  }));
}

function readManifestSensors(manifestPath) {
  const absolute = path.isAbsolute(manifestPath) ? manifestPath : path.join(ROOT, manifestPath);
  const payload = JSON.parse(fs.readFileSync(absolute, 'utf8'));
  const sensors = Array.isArray(payload) ? payload : payload.sensors;
  if (!Array.isArray(sensors) || sensors.length === 0) {
    throw new Error(`Manifest has no sensors: ${manifestPath}`);
  }
  return materializeSensors(sensors);
}

function fixtureManifestV1(sensors) {
  return sensors.map(({ id, name }) => ({ id, name }));
}

function fixtureManifestV2(sensors, tag) {
  const metrics = [
    {
      key: 'temp',
      name: 'Temperature',
      unit: 'celsius',
      unit_symbol: '°C',
      class: 'analog_numeric',
      data_type: 'float',
      bounds: { min: -50, max: 80 },
      history: true,
      history_suffix: 'temp',
      display: { precision: 1, chart: true },
    },
    {
      key: 'hum',
      name: 'Humidity',
      unit: 'percent',
      unit_symbol: '%',
      class: 'analog_numeric',
      data_type: 'float',
      bounds: { min: 0, max: 100 },
      history: true,
      history_suffix: 'hum',
      display: { precision: 1, chart: true },
    },
  ];
  const source = tag || 'mock';
  return {
    ok: true,
    schema_version: 2,
    source: source,
    version: VERSION,
    gateway: {
      id: 'gw-main',
      name: 'Main Gateway',
      role: 'satellite',
      hardware: 'ESP32-C3',
      firmware_version: VERSION,
      api_version: 'v2',
    },
    history: {
      backend: 'nvs',
      retention_hours: 1080,
      ram_window_hours: 24,
      sample_interval_seconds: 900,
    },
    sensor_count: sensors.length,
    metrics: metrics,
    sensors: sensors.map(({ id, name, mac }) => ({
      id,
      name,
      category: 'environmental',
      adapter: 'thermopro_ble',
      source: { mac: mac || null },
      measurements: metrics.map(m => ({
        key: m.key,
        history_url: `/history/${id}/${m.history_suffix}`,
      })),
    })),
  };
}

function writeFixtureSet(targetDir, sensors, tag) {
  fs.mkdirSync(targetDir, { recursive: true });
  const legacyManifest = fixtureManifestV1(sensors);
  const v2Manifest = fixtureManifestV2(sensors, tag || 'mock');

  fs.writeFileSync(path.join(targetDir, 'sensors.json'), JSON.stringify(legacyManifest, null, 2) + '\n');
  fs.writeFileSync(path.join(targetDir, 'manifest.json'), JSON.stringify(v2Manifest, null, 2) + '\n');
  fs.writeFileSync(path.join(targetDir, 'api-status.json'), JSON.stringify({
    ok: true,
    version: VERSION,
    sensor_count: sensors.length,
    sensors: legacyManifest,
    mode: tag || 'mock',
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
  writeFixtureSet(dir, sensors, `${count}sensor`);
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
    } else if (args[i] === '--manifest') {
      const next = args[i + 1];
      if (next && !next.startsWith('--')) {
        manifestPath = next;
        i++;
      } else {
        manifestPath = 'config/sensors.json';
      }
    }
  }

  if (manifestPath) {
    const sensors = readManifestSensors(manifestPath);
    if (!overwriteBaseline) {
      console.error('--manifest requires --overwrite-baseline so the root mock fixtures stay aligned with the active repo configuration.');
      process.exit(1);
    }
    writeFixtureSet(FIXTURES_ROOT, sensors, 'active-manifest');
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
      writeFixtureSet(FIXTURES_ROOT, materializeSensors(SENSOR_LIBRARY.slice(0, targetCount)), `${targetCount}sensor`);
      console.log(`baseline fixtures overwritten with ${targetCount} sensor(s)`);
    }
    process.exit(0);
  }

  [1, 2, 3, 4].forEach(writeVariant);
  if (overwriteBaseline) {
    console.error('Warning: --overwrite-baseline requires either --count N or --manifest <path>. Skipped baseline overwrite.');
  }
})();
