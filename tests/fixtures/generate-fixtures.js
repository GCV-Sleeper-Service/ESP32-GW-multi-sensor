#!/usr/bin/env node
/**
 * generate-fixtures.js
 * Generates deterministic JSON and CSV fixture files for the mock server.
 *
 * Usage:
 *   node tests/fixtures/generate-fixtures.js
 *     → generates all four variants (1sensor/2sensor/3sensor/4sensor) under tests/fixtures/variants/
 *
 *   node tests/fixtures/generate-fixtures.js --count 2
 *     → generates only the 2sensor variant
 *
 *   node tests/fixtures/generate-fixtures.js --count 2 --overwrite-baseline
 *     → generates the 2sensor variant AND overwrites tests/fixtures/sensors.json with 2 sensors
 *       (only use this when intentionally changing the active repository default count)
 *
 * IMPORTANT: History CSVs use epoch seconds (not milliseconds).
 * The dashboard parser multiplies timestamps by 1000 when creating Date objects:
 *   new Date(epoch * 1000)   — expects seconds input
 * Generating millisecond timestamps would produce year ~58000 dates, silently empty charts.
 */

'use strict';

const fs   = require('fs');
const path = require('path');

const FIXTURES_ROOT  = path.join(__dirname);
const VARIANTS_ROOT  = path.join(FIXTURES_ROOT, 'variants');

// Sensor library — first N entries are used for count N.
// IDs and names here must align with sensor_history_multi.h when testing live firmware.
const SENSOR_LIBRARY = [
  { id: 'office',      name: 'Office',      tempBase: 21.4, humBase: 44 },
  { id: 'first_floor', name: 'First Floor', tempBase: 19.2, humBase: 51 },
  { id: 'outside',     name: 'Outside',     tempBase:  8.1, humBase: 68 },
  { id: 'garage',      name: 'Garage',      tempBase: 12.8, humBase: 57 },
];

// Anchor epoch (seconds) — 2026-03-11 12:00:00 UTC
// Fixed so fixtures are deterministic; does not drift over time.
const ANCHOR_EPOCH_SEC = 1741694400;

// 24h of 15-minute points = 96 points per series
const POINTS = 96;
const INTERVAL_SEC = 15 * 60;

// ── Deterministic noise (no external deps) ──────────────────────────────────
function pseudoRand(seed) {
  const x = Math.sin(seed + 1) * 10000;
  return x - Math.floor(x);
}

// ── CSV generation: epoch seconds, two-column format ───────────────────────
// Format: <epoch_seconds>,<value>
// No header row (matches existing root fixture format; parser skips non-numeric first column anyway).
function buildCsvLines(sensorIdx, series, base) {
  const lines = [];
  for (let i = 0; i < POINTS; i++) {
    const ts    = ANCHOR_EPOCH_SEC - (POINTS - 1 - i) * INTERVAL_SEC;  // epoch seconds
    const noise = (pseudoRand(sensorIdx * 1000 + i + (series === 'hum' ? 5000 : 0)) - 0.5) * 2.0;
    const val   = (base + noise).toFixed(2);
    lines.push(`${ts},${val}`);
  }
  return lines.join('\n') + '\n';
}

// ── Write a single count variant ────────────────────────────────────────────
function writeVariant(count) {
  const sensors = SENSOR_LIBRARY.slice(0, count);
  const dir     = path.join(VARIANTS_ROOT, `${count}sensor`);
  fs.mkdirSync(dir, { recursive: true });

  // sensors.json — manifest matching C++ sensor IDs
  const manifest = sensors.map(({ id, name }) => ({ id, name }));
  fs.writeFileSync(path.join(dir, 'sensors.json'), JSON.stringify(manifest, null, 2) + '\n');

  // api-status.json
  const apiStatus = {
    ok:         true,
    version:    'v7.4.4.0',
    sensor_count: count,
    sensors:    manifest,
    mode:       'mock',
    connected:  true,
  };
  fs.writeFileSync(path.join(dir, 'api-status.json'), JSON.stringify(apiStatus, null, 2) + '\n');

  // storage-stats.json
  const storageStats = {
    ok:           true,
    partition:    'history',
    total_bytes:  524288,
    used_bytes:   Math.round(184320 * (count / 3)),
    free_bytes:   Math.round(339968 + 184320 * (1 - count / 3)),
    retention_days: 45,
    retention_oldest_epoch: ANCHOR_EPOCH_SEC - POINTS * INTERVAL_SEC,
    retention_newest_epoch: ANCHOR_EPOCH_SEC,
    segment_count: POINTS,
    mode: 'mock',
  };
  fs.writeFileSync(path.join(dir, 'storage-stats.json'), JSON.stringify(storageStats, null, 2) + '\n');

  // History CSVs — epoch seconds
  sensors.forEach(function(s, idx) {
    fs.writeFileSync(
      path.join(dir, `history-${s.id}-temp.csv`),
      buildCsvLines(idx, 'temp', s.tempBase)
    );
    fs.writeFileSync(
      path.join(dir, `history-${s.id}-hum.csv`),
      buildCsvLines(idx, 'hum', s.humBase)
    );
  });

  console.log(`  ${count}sensor: ${dir}`);
}

// ── Overwrite root baseline sensors.json ────────────────────────────────────
function overwriteBaselineManifest(count) {
  const sensors  = SENSOR_LIBRARY.slice(0, count);
  const manifest = sensors.map(({ id, name }) => ({ id, name }));
  fs.writeFileSync(path.join(FIXTURES_ROOT, 'sensors.json'), JSON.stringify(manifest, null, 2) + '\n');
  console.log(`  baseline tests/fixtures/sensors.json overwritten with ${count} sensors`);
}

// ── CLI args ─────────────────────────────────────────────────────────────────
(function main() {
  const args = process.argv.slice(2);
  let targetCount       = null;
  let doOverwriteBaseline = false;

  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--count' && args[i + 1]) {
      targetCount = parseInt(args[i + 1], 10);
      i++;
    } else if (args[i] === '--overwrite-baseline') {
      doOverwriteBaseline = true;
    }
  }

  if (targetCount !== null) {
    if (targetCount < 1 || targetCount > 4) {
      console.error('Error: --count must be 1, 2, 3, or 4');
      process.exit(1);
    }
    console.log(`Generating ${targetCount}sensor variant:`);
    writeVariant(targetCount);
    if (doOverwriteBaseline) overwriteBaselineManifest(targetCount);
  } else {
    console.log('Generating all sensor-count variants:');
    [1, 2, 3, 4].forEach(writeVariant);
    if (doOverwriteBaseline) {
      console.error('Warning: --overwrite-baseline requires --count N when generating all variants. Skipped.');
    }
  }

  console.log('Done.');
})();
