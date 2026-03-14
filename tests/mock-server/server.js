/**
 * mock-server/server.js
 * Lightweight HTTP mock of the ESP32 gateway API.
 * Supports either the root baseline fixtures or tests/fixtures/variants/<set>/.
 */
'use strict';

const http = require('http');
const fs = require('fs');
const path = require('path');
const url = require('url');

const ROOT = path.join(__dirname, '..', '..');
const FIXTURES_ROOT = path.join(__dirname, '..', 'fixtures');
const FIXTURE_SET = process.env.FIXTURE_SET || '';
const FIXTURES = FIXTURE_SET ? path.join(FIXTURES_ROOT, 'variants', FIXTURE_SET) : FIXTURES_ROOT;
const DASHBOARD_HTML = path.join(ROOT, 'dashboard', 'dashboard.html');
const DISABLE_API_MANIFEST = process.env.DISABLE_API_MANIFEST === '1';

const args = process.argv.slice(2);
const portIdx = args.indexOf('--port');
const PORT = portIdx !== -1 ? parseInt(args[portIdx + 1], 10) : 3737;

function loadFixture(filename) {
  const primary = path.join(FIXTURES, filename);
  if (fs.existsSync(primary)) return fs.readFileSync(primary, 'utf8');
  const fallback = path.join(FIXTURES_ROOT, filename);
  if (fs.existsSync(fallback)) return fs.readFileSync(fallback, 'utf8');
  return null;
}

function loadFixtureJson(filename, fallback) {
  const raw = loadFixture(filename);
  return raw ? JSON.parse(raw) : fallback;
}

function buildSensorMeta() {
  const manifest = loadFixtureJson('sensors.json', []);
  return (manifest || []).map(function(sensor, idx) {
    return {
      id: sensor.id,
      name: sensor.name,
      temp: `${(20.0 + idx * 1.7).toFixed(1)} °C / ${(68 + idx * 3.1).toFixed(1)} °F`,
      hum: `${45 + idx * 6} %`,
      avg_temp: `${(19.8 + idx * 1.6).toFixed(1)} °C / ${(67.6 + idx * 2.9).toFixed(1)} °F`,
      avg_hum: `${44 + idx * 6} %`,
      battery: `${Math.max(55, 100 - idx * 9)} %`,
      last_seen: `${30 + idx * 15}s ago`,
      rssi: -60 - (idx * 6),
    };
  });
}

const SENSOR_META = buildSensorMeta();
const POLL_RESPONSES = {};
SENSOR_META.forEach(function(s) {
  function reg(name, value) {
    POLL_RESPONSES[name.toLowerCase()] = { id: name.toLowerCase().replace(/\s+/g, '_'), value: String(value) };
  }
  reg(s.name + ' Temperature', s.temp);
  reg(s.name + ' Humidity', s.hum);
  reg(s.name + ' Temp (15m avg)', s.avg_temp);
  reg(s.name + ' Humidity (15m avg)', s.avg_hum);
  reg(s.name + ' Battery', s.battery);
  reg(s.name + ' Last Seen', s.last_seen);
});

const SHARED_TEXT = {
  'current time': '2026-03-13 12:00:00',
  'chip': 'ESP32-C3',
  'features': 'WiFi/BT',
  'cores': '1',
  'revision': '3',
  'cpu frequency': '160 MHz',
  'framework': 'ESP-IDF v5.1',
  'esphome version': '2026.2.1',
  'ip address': '192.168.120.189',
  'mac address': 'AA:BB:CC:DD:EE:FF',
  'reset reason': 'Power on',
};

const SHARED_SENSOR = {
  'free heap': 81920,
  'uptime': 86400,
  'wifi signal': -58,
  'loop time': 12,
};

function json(res, data, status) {
  const body = typeof data === 'string' ? data : JSON.stringify(data);
  res.writeHead(status || 200, {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
    'Cache-Control': 'no-store',
  });
  res.end(body);
}

function text(res, data, contentType, status) {
  res.writeHead(status || 200, {
    'Content-Type': contentType || 'text/plain',
    'Access-Control-Allow-Origin': '*',
    'Cache-Control': 'no-store',
  });
  res.end(data || '');
}

function notFound(res, msg) {
  res.writeHead(404, { 'Content-Type': 'text/plain', 'Access-Control-Allow-Origin': '*' });
  res.end(msg || 'Not found');
}

const server = http.createServer(function(req, res) {
  const parsed = url.parse(req.url, true);
  const pathname = decodeURIComponent(parsed.pathname);

  if (pathname === '/' || pathname === '/index.html' || pathname === '/dashboard' || pathname === '/dashboard.html') {
    const html = fs.readFileSync(DASHBOARD_HTML, 'utf8');
    const patched = html.replace(/var FILE_FALLBACK_HOST\s*=\s*'[^']*';/, `var FILE_FALLBACK_HOST = 'http://127.0.0.1:${PORT}';`);
    res.writeHead(200, { 'Content-Type': 'text/html' });
    res.end(patched);
    return;
  }

  if (pathname === '/sensors.json') {
    return json(res, loadFixtureJson('sensors.json', []));
  }

  if (pathname === '/api/manifest') {
    if (DISABLE_API_MANIFEST) return json(res, { ok: false, message: 'disabled for fallback test' }, 404);
    return json(res, loadFixtureJson('manifest.json', { ok: false }));
  }

  const histMatch = pathname.match(/^\/history\/([^/]+)\/(temp|hum)$/);
  if (histMatch) {
    const sensorId = histMatch[1];
    const series = histMatch[2];
    const data = loadFixture(`history-${sensorId}-${series}.csv`);
    if (data === null) return notFound(res, `No fixture for ${sensorId}/${series}`);
    return text(res, data, 'text/plain');
  }

  if (pathname === '/api/storage-stats') {
    return json(res, loadFixtureJson('storage-stats.json', { ok: false }));
  }

  if (pathname === '/api/status') {
    return json(res, loadFixtureJson('api-status.json', { ok: false }));
  }

  if (pathname === '/api/reboot' || pathname === '/api/delete-data') {
    return json(res, { ok: true, stub: true });
  }

  if (pathname === '/events') {
    res.writeHead(200, {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      'Access-Control-Allow-Origin': '*',
      'Connection': 'keep-alive',
    });
    res.write('event: ping\ndata: {}\n\n');
    const interval = setInterval(function() {
      if (res.writableEnded) {
        clearInterval(interval);
        return;
      }
      res.write('event: ping\ndata: {}\n\n');
    }, 2000);
    req.on('close', function() { clearInterval(interval); });
    return;
  }

  if (pathname.startsWith('/text_sensor/')) {
    const key = pathname.replace('/text_sensor/', '').toLowerCase().replace(/_/g, ' ');
    if (POLL_RESPONSES[key]) return json(res, POLL_RESPONSES[key]);
    if (SHARED_TEXT[key] !== undefined) return json(res, { id: key.replace(/\s+/g, '_'), value: String(SHARED_TEXT[key]) });
    return json(res, { id: key.replace(/\s+/g, '_'), value: 'mock' });
  }

  if (pathname.startsWith('/sensor/')) {
    const key = pathname.replace('/sensor/', '').toLowerCase().replace(/_/g, ' ');
    const rssiMatch = key.match(/^(.+) rssi$/);
    if (rssiMatch) {
      const meta = SENSOR_META.find(s => s.name.toLowerCase() === rssiMatch[1]);
      return json(res, { id: key.replace(/\s+/g, '_'), value: meta ? meta.rssi : -70 });
    }
    if (SHARED_SENSOR[key] !== undefined) return json(res, { id: key.replace(/\s+/g, '_'), value: SHARED_SENSOR[key] });
    return json(res, { id: key.replace(/\s+/g, '_'), value: 0 });
  }

  if (pathname.startsWith('/api/import/')) {
    return json(res, { ok: true, stub: true, accepted: 0, rejected: 0, segments_written: 0 });
  }

  notFound(res, pathname);
});

server.listen(PORT, '127.0.0.1', function() {
  console.log(`Mock ESP32 gateway server listening on http://127.0.0.1:${PORT}`);
  console.log(`Fixture set: ${FIXTURE_SET || 'root-baseline'}`);
  console.log(`Manifest mode: ${DISABLE_API_MANIFEST ? 'legacy-fallback-only' : 'v2 + legacy'}`);
});

module.exports = server;
