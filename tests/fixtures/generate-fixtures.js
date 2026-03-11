#!/usr/bin/env node
/**
 * generate-fixtures.js
 * Generates static JSON and CSV fixture files used by the mock server.
 * Run once: node tests/fixtures/generate-fixtures.js
 * Output files are committed so tests are deterministic.
 */

'use strict';

const fs   = require('fs');
const path = require('path');

const OUT = path.join(__dirname);

// ── Sensor definitions ────────────────────────────────────────────
const SENSORS = [
  { id: 'office',      name: 'Office',      baseTemp: 21.5, baseHum: 45 },
  { id: 'first_floor', name: 'First Floor', baseTemp: 19.2, baseHum: 52 },
  { id: 'outside',     name: 'Outside',     baseTemp:  8.3, baseHum: 68 },
];

// ── Anchored "now" so fixtures are deterministic relative to each other ──
// We anchor to a known recent epoch (2026-03-11 12:00:00 UTC) so tests
// that reference fixture data don't drift over time.
const ANCHOR_EPOCH = 1741694400; // 2026-03-11 12:00:00 UTC
const HOURS = 72;

// ── sensors.json ──────────────────────────────────────────────────
const manifest = SENSORS.map(s => ({ id: s.id, name: s.name }));
fs.writeFileSync(path.join(OUT, 'sensors.json'), JSON.stringify(manifest, null, 2));

// ── History CSVs ──────────────────────────────────────────────────
function pseudoRand(seed) {
  // Simple deterministic noise: no external deps
  var x = Math.sin(seed) * 10000;
  return x - Math.floor(x);
}

SENSORS.forEach(function(s, si) {
  let tempLines = [];
  let humLines  = [];
  for (let h = 0; h < HOURS; h++) {
    const epoch   = ANCHOR_EPOCH - (HOURS - h) * 3600;
    const noise   = (pseudoRand(si * 1000 + h) - 0.5) * 2.0;
    const temp    = (s.baseTemp + noise).toFixed(2);
    const hum     = Math.max(10, Math.min(99, s.baseHum + (pseudoRand(si * 2000 + h) - 0.5) * 8)).toFixed(1);
    tempLines.push(`${epoch},${temp}`);
    humLines.push(`${epoch},${hum}`);
  }
  fs.writeFileSync(path.join(OUT, `history-${s.id}-temp.csv`), tempLines.join('\n') + '\n');
  fs.writeFileSync(path.join(OUT, `history-${s.id}-hum.csv`),  humLines.join('\n')  + '\n');
});

// ── storage-stats.json ────────────────────────────────────────────
const storageStats = {
  ok: true,
  partition: 'sensor_history',
  total_bytes: 524288,
  used_bytes: 184320,
  free_bytes: 339968,
  retention_days: 45,
  retention_oldest_epoch: ANCHOR_EPOCH - HOURS * 3600,
  retention_newest_epoch: ANCHOR_EPOCH,
  segment_count: HOURS,
};
fs.writeFileSync(path.join(OUT, 'storage-stats.json'), JSON.stringify(storageStats, null, 2));

// ── api-status.json ───────────────────────────────────────────────
const apiStatus = {
  ok: true,
  version: 'v7.4.3.0',
  uptime_seconds: 86400,
  sensor_count: 3,
  sensors: SENSORS.map(s => ({
    id: s.id,
    name: s.name,
    last_seen: ANCHOR_EPOCH - 30,
    temp_valid: true,
    hum_valid: true,
  })),
  ram_history_points_per_series: 96,
  persist_days: 45,
  free_heap: 81920,
};
fs.writeFileSync(path.join(OUT, 'api-status.json'), JSON.stringify(apiStatus, null, 2));

console.log('Fixtures generated in', OUT);
SENSORS.forEach(s => console.log(`  history-${s.id}-temp.csv  history-${s.id}-hum.csv`));
console.log('  sensors.json  storage-stats.json  api-status.json');
