/**
 * mock-server/server.js
 * Lightweight Express mock of the ESP32 gateway HTTP API.
 * Serves static fixture data so Playwright tests run without a live device.
 *
 * Endpoints served:
 *   GET /sensors.json
 *   GET /history/:id/temp
 *   GET /history/:id/hum
 *   GET /api/storage-stats
 *   GET /api/status
 *   GET /text_sensor/:name     → { id, value } JSON (polling shim)
 *   GET /sensor/:name          → { id, value } JSON (polling shim)
 *   GET /events                → minimal SSE stream (ping every 2s)
 *   GET /                      → serves dashboard.html
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
const ROOT     = path.join(__dirname, '..', '..');
const FIXTURES = path.join(__dirname, '..', 'fixtures');
const DASHBOARD_HTML = path.join(ROOT, 'dashboard', 'dashboard.html');

// ── CLI args ──────────────────────────────────────────────────────
const args = process.argv.slice(2);
const portIdx = args.indexOf('--port');
const PORT = portIdx !== -1 ? parseInt(args[portIdx + 1], 10) : 3737;

// ── Fixture loader ────────────────────────────────────────────────
function loadFixture(filename) {
  const filepath = path.join(FIXTURES, filename);
  if (!fs.existsSync(filepath)) return null;
  return fs.readFileSync(filepath, 'utf8');
}

function loadFixtureJson(filename) {
  const raw = loadFixture(filename);
  return raw ? JSON.parse(raw) : null;
}

// ── Polling shim responses ────────────────────────────────────────
// The dashboard polls ESPHome REST endpoints like /text_sensor/Office%20Temperature
// which return { id: "...", value: "..." }.  We return plausible static values.
const SENSOR_META = [
  { id: 'office',      name: 'Office',      temp: '21.5 °C / 70.7 °F', hum: '45 %', avg_temp: '21.4 °C / 70.5 °F', avg_hum: '45 %', battery: '100 %', last_seen: '30s ago', rssi: -62 },
  { id: 'first_floor', name: 'First Floor', temp: '19.2 °C / 66.6 °F', hum: '52 %', avg_temp: '19.1 °C / 66.4 °F', avg_hum: '52 %', battery: '87 %',  last_seen: '45s ago', rssi: -71 },
  { id: 'outside',     name: 'Outside',     temp: '8.3 °C / 46.9 °F',  hum: '68 %', avg_temp: '8.1 °C / 46.6 °F',  avg_hum: '68 %', battery: '92 %',  last_seen: '1m ago',  rssi: -78 },
];

// Build a lookup: decoded path segment → { id, value }
const POLL_RESPONSES = {};
SENSOR_META.forEach(function(s) {
  function reg(name, value) {
    POLL_RESPONSES[name.toLowerCase()] = { id: name.toLowerCase().replace(/\s+/g, '_'), value: String(value) };
  }
  reg(s.name + ' Temperature',      s.temp);
  reg(s.name + ' Humidity',         s.hum);
  reg(s.name + ' Temp (15m avg)',   s.avg_temp);
  reg(s.name + ' Humidity (15m avg)', s.avg_hum);
  reg(s.name + ' Battery',          s.battery);
  reg(s.name + ' Last Seen',        s.last_seen);
});

// Shared text sensors
const SHARED_TEXT = {
  'current time':       '2026-03-11 12:00:00',
  'chip':               'ESP32-C3',
  'features':           'WiFi/BT',
  'cores':              '1',
  'revision':           '3',
  'cpu frequency':      '160 MHz',
  'framework':          'ESP-IDF v5.1',
  'esphome version':    '2024.12.0',
  'ip address':         '192.168.120.189',
  'mac address':        'AA:BB:CC:DD:EE:FF',
  'reset reason':       'Power on',
};

const SHARED_SENSOR = {
  'free heap':          81920,
  'uptime':             86400,
  'wifi signal':        -58,
  'loop time':          12,
};

function makePollResponse(name, value) {
  return JSON.stringify({ id: name.toLowerCase().replace(/[\s()]+/g, '_'), value: String(value) });
}

// ── Response helpers ──────────────────────────────────────────────
function json(res, data, status) {
  const body = typeof data === 'string' ? data : JSON.stringify(data);
  res.writeHead(status || 200, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' });
  res.end(body);
}

function text(res, data, contentType, status) {
  res.writeHead(status || 200, { 'Content-Type': contentType || 'text/plain', 'Access-Control-Allow-Origin': '*' });
  res.end(data || '');
}

function notFound(res, msg) {
  res.writeHead(404, { 'Content-Type': 'text/plain', 'Access-Control-Allow-Origin': '*' });
  res.end(msg || 'Not found');
}

// ── Request router ────────────────────────────────────────────────
const server = http.createServer(function(req, res) {
  const parsed   = url.parse(req.url, true);
  const pathname = decodeURIComponent(parsed.pathname);

  // ── Dashboard HTML ──
  if (pathname === '/' || pathname === '/index.html') {
    const html = fs.readFileSync(DASHBOARD_HTML, 'utf8');
    // Inject ESP_HOST so the dashboard targets our mock server
    const patched = html.replace(
      /var ESP_HOST\s*=\s*'[^']*';/,
      `var ESP_HOST = 'http://localhost:${PORT}';`
    );
    res.writeHead(200, { 'Content-Type': 'text/html' });
    res.end(patched);
    return;
  }

  // ── Sensor manifest ──
  if (pathname === '/sensors.json') {
    const data = loadFixtureJson('sensors.json');
    return json(res, data || []);
  }

  // ── History CSV ──
  const histMatch = pathname.match(/^\/history\/([^/]+)\/(temp|hum)$/);
  if (histMatch) {
    const sensorId = histMatch[1];
    const series   = histMatch[2];
    const data = loadFixture(`history-${sensorId}-${series}.csv`);
    if (data === null) return notFound(res, `No fixture for ${sensorId}/${series}`);
    return text(res, data, 'text/plain');
  }

  // ── API: storage-stats ──
  if (pathname === '/api/storage-stats') {
    return json(res, loadFixtureJson('storage-stats.json') || { ok: false });
  }

  // ── API: status ──
  if (pathname === '/api/status') {
    return json(res, loadFixtureJson('api-status.json') || { ok: false });
  }

  // ── API: management stubs (reboot / delete-data) ──
  if (pathname === '/api/reboot' || pathname === '/api/delete-data') {
    return json(res, { ok: true, stub: true });
  }

  // ── SSE /events — sends a ping then keeps connection open ──
  if (pathname === '/events') {
    res.writeHead(200, {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      'Access-Control-Allow-Origin': '*',
      'Connection': 'keep-alive',
    });
    res.write('event: ping\ndata: {}\n\n');
    const interval = setInterval(function() {
      if (res.writableEnded) { clearInterval(interval); return; }
      res.write('event: ping\ndata: {}\n\n');
    }, 2000);
    req.on('close', function() { clearInterval(interval); });
    return;
  }

  // ── ESPHome text_sensor polling ──
  if (pathname.startsWith('/text_sensor/')) {
    const key = pathname.replace('/text_sensor/', '').toLowerCase().replace(/_/g, ' ');
    // Sensor-specific text sensors
    if (POLL_RESPONSES[key]) return json(res, POLL_RESPONSES[key]);
    // Shared text sensors
    if (SHARED_TEXT[key] !== undefined) return json(res, makePollResponse(key, SHARED_TEXT[key]));
    // Default fallback
    return json(res, { id: key.replace(/\s+/g, '_'), value: 'mock' });
  }

  // ── ESPHome sensor polling (numeric) ──
  if (pathname.startsWith('/sensor/')) {
    const key = pathname.replace('/sensor/', '').toLowerCase().replace(/_/g, ' ');
    // Per-sensor RSSI
    const rssiMatch = key.match(/^(.+) rssi$/);
    if (rssiMatch) {
      const sensorName = rssiMatch[1];
      const meta = SENSOR_META.find(s => s.name.toLowerCase() === sensorName);
      return json(res, { id: key.replace(/\s+/g, '_'), value: meta ? meta.rssi : -70 });
    }
    if (SHARED_SENSOR[key] !== undefined) return json(res, { id: key.replace(/\s+/g, '_'), value: SHARED_SENSOR[key] });
    return json(res, { id: key.replace(/\s+/g, '_'), value: 0 });
  }

  // ── Import stubs (basic shape so UI flow can be exercised) ──
  if (pathname.startsWith('/api/import/')) {
    return json(res, { ok: true, stub: true });
  }

  notFound(res, pathname);
});

server.listen(PORT, '127.0.0.1', function() {
  console.log(`Mock ESP32 gateway server listening on http://127.0.0.1:${PORT}`);
  console.log('  Dashboard: http://127.0.0.1:' + PORT + '/');
  console.log('  Press Ctrl-C to stop.');
});

module.exports = server;
