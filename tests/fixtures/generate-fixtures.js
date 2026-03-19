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
const VERSION = 'v7.5.4.2';

const SENSOR_LIBRARY = [
  { id: 'office', name: 'Office', tempBase: 21.4, humBase: 44 },
  { id: 'first_floor', name: 'First Floor', tempBase: 19.2, humBase: 51 },
  { id: 'outside', name: 'Outside', tempBase: 8.1, humBase: 68 },
  { id: 'garage', name: 'Garage', tempBase: 12.8, humBase: 57 },
];

// Network device always appended to every variant — reflects the real firmware
// configuration where wan_ping is present alongside BLE environmental sensors.
const WAN_PING_DEVICE = {
  id: 'wan_ping',
  name: 'WAN Latency',
  category: 'network',
  adapter: 'icmp_ping',
  source: { target: '8.8.8.8' },
};

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
    category: sensor.category || 'environmental',
    adapter: sensor.adapter || 'thermopro_ble',
    source: sensor.source || null,
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
  // Legacy v1 format: only environmental (BLE) sensors, id/name only
  return sensors
    .filter(s => !s.adapter || s.adapter === 'thermopro_ble')
    .map(({ id, name }) => ({ id, name }));
}

const PING_METRICS = [
  {
    key: 'ping_ms',
    name: 'Latency',
    unit: 'ms',
    unit_symbol: 'ms',
    class: 'analog_numeric',
    data_type: 'float',
    bounds: { min: 0, max: 10000 },
    history: true,
    history_suffix: 'ping_ms',
    display: { precision: 0, chart: true },
  },
  {
    key: 'success_pct',
    name: 'Success Rate',
    unit: 'percent',
    unit_symbol: '%',
    class: 'analog_numeric',
    data_type: 'float',
    bounds: { min: 0, max: 100 },
    history: true,
    history_suffix: 'success_pct',
    display: { precision: 0, chart: true },
  },
];

function fixtureManifestV2(sensors, tag) {
  const envMetrics = [
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

  const sensorEntries = sensors.map(s => {
    if (!s.adapter || s.adapter === 'thermopro_ble') {
      return {
        id: s.id,
        name: s.name,
        category: s.category || 'environmental',
        adapter: 'thermopro_ble',
        source: { mac: s.mac || null },
        measurements: envMetrics.map(m => ({
          key: m.key,
          history_url: `/history/${s.id}/${m.history_suffix}`,
        })),
      };
    }
    if (s.adapter === 'icmp_ping') {
      return {
        id: s.id,
        name: s.name,
        category: s.category || 'network',
        adapter: 'icmp_ping',
        source: s.source || {},
        measurements: PING_METRICS.map(m => ({
          key: m.key,
          history_url: `/api/v2/history/${s.id}/${m.history_suffix}`,
        })),
      };
    }
    return {
      id: s.id,
      name: s.name,
      category: s.category || 'unknown',
      adapter: s.adapter,
      measurements: [],
    };
  });

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
    metrics: envMetrics,
    sensors: sensorEntries,
  };
}

function writeFixtureSet(targetDir, sensors, tag) {
  fs.mkdirSync(targetDir, { recursive: true });
  const legacyManifest = fixtureManifestV1(sensors);
  const v2Manifest = fixtureManifestV2(sensors, tag || 'mock');
  // env-only sensor count for storage-stats (BLE sensors with NVS persistence)
  const envCount = sensors.filter(s => !s.adapter || s.adapter === 'thermopro_ble').length;

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
    used_bytes: Math.round(184320 * Math.max(1, envCount) / 3),
    free_bytes: Math.max(0, 524288 - Math.round(184320 * Math.max(1, envCount) / 3)),
    retention_days: 45,
    retention_oldest_epoch: ANCHOR_EPOCH_SEC - POINTS * INTERVAL_SEC,
    retention_newest_epoch: ANCHOR_EPOCH_SEC,
    segment_count: POINTS,
    mode: tag || 'mock',
  }, null, 2) + '\n');

  sensors.forEach((sensor, idx) => {
    if (!sensor.adapter || sensor.adapter === 'thermopro_ble') {
      fs.writeFileSync(path.join(targetDir, `history-${sensor.id}-temp.csv`), buildCsvLines(idx, 'temp', sensor.tempBase));
      fs.writeFileSync(path.join(targetDir, `history-${sensor.id}-hum.csv`), buildCsvLines(idx, 'hum', sensor.humBase));
    } else if (sensor.adapter === 'icmp_ping') {
      // Stub history files for ping device (RAM-only, no data at this phase)
      fs.writeFileSync(path.join(targetDir, `history-${sensor.id}-ping_ms.csv`), '');
      fs.writeFileSync(path.join(targetDir, `history-${sensor.id}-success_pct.csv`), '');
    }
  });
}

function writeVariant(count) {
  const bleSensors = materializeSensors(SENSOR_LIBRARY.slice(0, count));
  const sensors = [...bleSensors, materializeSensors([WAN_PING_DEVICE])[0]];
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
