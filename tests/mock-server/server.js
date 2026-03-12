/**
 * tests/mock-server/server.js
 * Fixture-aware mock of the ESP32 gateway HTTP API.
 *
 * Default fixture set: 3sensor
 * Override via environment variable before starting:
 *   FIXTURE_SET=1sensor node tests/mock-server/server.js
 *   FIXTURE_SET=2sensor node tests/mock-server/server.js
 *   FIXTURE_SET=4sensor node tests/mock-server/server.js
 *
 * Fixture resolution order:
 *   1. tests/fixtures/variants/<FIXTURE_SET>/<filename>
 *   2. tests/fixtures/<filename>  (root fallback for shared files)
 *
 * Endpoints served:
 *   GET /sensors.json
 *   GET /history/:id/temp
 *   GET /history/:id/hum
 *   GET /api/storage-stats
 *   GET /api/status
 *   GET /text_sensor/:name    → { id, value } JSON (polling shim)
 *   GET /sensor/:name         → { id, value } JSON (polling shim)
 *   GET /events               → minimal SSE stream (ping every 2s)
 *   GET /                     → serves dashboard.html
 *
 * Usage:
 *   node tests/mock-server/server.js [--port 3737]
 */

'use strict';

const http = require('http');
const fs   = require('fs');
const path = require('path');
const url  = require('url');

// ── Paths ─────────────────────────────────────────────────────────
const ROOT          = path.join(__dirname, '..', '..');
const FIXTURES_ROOT = path.join(__dirname, '..', 'fixtures');
const VARIANTS_ROOT = path.join(FIXTURES_ROOT, 'variants');
const DASHBOARD_HTML = path.join(ROOT, 'dashboard', 'dashboard.html');

// ── CLI args ──────────────────────────────────────────────────────
const args    = process.argv.slice(2);
const portIdx = args.indexOf('--port');
const PORT    = portIdx !== -1 ? parseInt(args[portIdx + 1], 10) : 3737;

// ── Active fixture set (from env, default 3sensor) ────────────────
const FIXTURE_SET  = (process.env.FIXTURE_SET || '3sensor').trim();
const VARIANT_DIR  = path.join(VARIANTS_ROOT, FIXTURE_SET);

// ── Fixture loader: variant-first, root fallback ──────────────────
function fixturePath(filename) {
  const variantPath = path.join(VARIANT_DIR, filename);
  if (fs.existsSync(variantPath)) return variantPath;
  const rootPath = path.join(FIXTURES_ROOT, filename);
  if (fs.existsSync(rootPath)) return rootPath;
  return null;
}
function loadFixture(filename) {
  const p = fixturePath(filename);
  return p ? fs.readFileSync(p, 'utf8') : null;
}
function loadFixtureJson(filename) {
  const raw = loadFixture(filename);
  return raw ? JSON.parse(raw) : null;
}

// ── Sensor manifest from active fixture set ───────────────────────
const SENSOR_META = loadFixtureJson('sensors.json') || [];

// Build polling response map (case-insensitive sensor name matching)
const POLL_RESPONSES = {};
SENSOR_META.forEach(function(s, idx) {
  function reg(displayName, value) {
    POLL_RESPONSES[displayName.toLowerCase()] = {
      id:    displayName.toLowerCase().replace(/[^\w]+/g, '_'),
      value: String(value)
    };
  }
  // Plausible mock values derived from sensor position
  const tempC   = (21.5 - idx * 1.5).toFixed(1);
  const tempF   = ((21.5 - idx * 1.5) * 9 / 5 + 32).toFixed(1);
  const hum     = String(45 + idx * 6);
  const avgTmpC = (21.3 - idx * 1.5).toFixed(1);
  const avgTmpF = ((21.3 - idx * 1.5) * 9 / 5 + 32).toFixed(1);
  const avgHum  = String(45 + idx * 6);
  const batt    = String(100 - idx * 7);
  const seen    = `${30 + idx * 15}s ago`;
  const rssi    = String(-62 - idx * 8);

  reg(`${s.name} Temperature`,      `${tempC} °C / ${tempF} °F`);
  reg(`${s.name} Humidity`,         `${hum} %`);
  reg(`${s.name} Temp (15m avg)`,   `${avgTmpC} °C / ${avgTmpF} °F`);
  reg(`${s.name} Humidity (15m avg)`, `${avgHum} %`);
  reg(`${s.name} Battery`,          `${batt} %`);
  reg(`${s.name} Last Seen`,        seen);
  reg(`${s.name} RSSI`,             rssi);
});

// Shared device / chip sensors (not per-sensor)
const SHARED_TEXT = {
  'current time':   '2026-03-12 12:00:00',
  'chip':           'ESP32-C3',
  'features':       'WiFi/BT',
  'cores':          '1',
  'revision':       '3',
  'cpu frequency':  '160 MHz',
  'framework':      'ESP-IDF v5.1',
  'esphome version': '2026.2.1',
  'ip address':     '192.168.120.189',
  'mac address':    'AA:BB:CC:DD:EE:FF',
};

// ── Response helpers ──────────────────────────────────────────────
function json(res, data, status) {
  const body = JSON.stringify(data);
  res.writeHead(status || 200, {
    'Content-Type':  'application/json',
    'Content-Length': Buffer.byteLength(body),
    'Access-Control-Allow-Origin': '*',
  });
  res.end(body);
}
function text(res, data, contentType) {
  const ct = contentType || 'text/plain';
  res.writeHead(200, {
    'Content-Type':  ct,
    'Content-Length': Buffer.byteLength(data),
    'Access-Control-Allow-Origin': '*',
  });
  res.end(data);
}
function notFound(res, msg) {
  res.writeHead(404, { 'Content-Type': 'text/plain' });
  res.end(msg || 'Not found');
}

// ── Request router ────────────────────────────────────────────────
function onRequest(req, res) {
  const parsed   = url.parse(req.url);
  const pathname = decodeURIComponent(parsed.pathname);

  // Root: serve dashboard HTML
  if (pathname === '/' || pathname === '/dashboard' || pathname === '/dashboard.html') {
    const html = fs.readFileSync(DASHBOARD_HTML, 'utf8');
    return text(res, html, 'text/html; charset=utf-8');
  }

  // sensors.json manifest
  if (pathname === '/sensors.json') {
    const data = loadFixture('sensors.json');
    if (!data) return notFound(res, 'sensors.json not found');
    return text(res, data, 'application/json');
  }

  // History CSVs
  const histMatch = pathname.match(/^\/history\/([^/]+)\/(temp|hum)$/);
  if (histMatch) {
    const sensorId = histMatch[1];
    const series   = histMatch[2];
    const data = loadFixture(`history-${sensorId}-${series}.csv`);
    if (!data) return notFound(res, `No fixture for ${sensorId}/${series}`);
    return text(res, data, 'text/plain');
  }

  // /api/storage-stats
  if (pathname === '/api/storage-stats') {
    const data = loadFixtureJson('storage-stats.json');
    return json(res, data || { ok: false, error: 'fixture not found' });
  }

  // /api/status
  if (pathname === '/api/status') {
    const data = loadFixtureJson('api-status.json');
    return json(res, data || { ok: false, error: 'fixture not found' });
  }

  // SSE events stream (ping every 2s)
  if (pathname === '/events') {
    res.writeHead(200, {
      'Content-Type':  'text/event-stream',
      'Cache-Control': 'no-cache',
      'Connection':    'keep-alive',
      'Access-Control-Allow-Origin': '*',
    });
    res.write('retry: 2000\n\n');
    const iv = setInterval(function() {
      res.write(':ping\n\n');
    }, 2000);
    req.on('close', function() { clearInterval(iv); });
    return;
  }

  // Management endpoints (mock — always OK)
  if (pathname === '/api/delete-data' || pathname === '/api/reboot') {
    return json(res, { ok: true, mock: true });
  }

  // Polling shim: /text_sensor/<name> and /sensor/<name>
  if (pathname.startsWith('/text_sensor/') || pathname.startsWith('/sensor/')) {
    const raw  = pathname.replace(/^\/(text_sensor|sensor)\//, '');
    const name = raw.toLowerCase();
    if (POLL_RESPONSES[name]) return json(res, POLL_RESPONSES[name]);
    if (SHARED_TEXT[name])    return json(res, { id: name.replace(/\s+/g, '_'), value: SHARED_TEXT[name] });
    return json(res, { id: name.replace(/\s+/g, '_'), value: '—' });
  }

  notFound(res, `${pathname} not found`);
}

// ── Start server ──────────────────────────────────────────────────
const server = http.createServer(onRequest);
server.listen(PORT, '127.0.0.1', function() {
  process.stderr.write(`mock-server: FIXTURE_SET=${FIXTURE_SET} listening on http://127.0.0.1:${PORT}\n`);
});
