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

// ────────────────────────────────────────────────────────────────────────────────
// Stateful satellite management (Phase D mock — v7.6.0.5)
// Initialized from the aggregator fixture on server start.
// ────────────────────────────────────────────────────────────────────────────────
let managedSatellites = [];
let nextSatelliteId = 1;  // Monotonic ID counter for unique satellite IDs
const MOCK_MAX_SATELLITES = 8;

function initManagedSatellites() {
  const gateways = loadFixtureJson('aggregator-gateways.json', { gateways: [] });
  managedSatellites = (gateways.gateways || []).map(function(gw) {
    return {
      id: gw.id,
      name: gw.name,
      base_url: gw.base_url || 'http://mock-satellite',
      poll: gw.poll || 30,  // Use poll field (default 30s if not present)
      reachable: gw.reachable !== undefined ? gw.reachable : true,
      last_seen: gw.last_seen || Math.floor(Date.now() / 1000),
      consecutive_failures: gw.consecutive_failures || 0,
      firmware_version: gw.firmware_version || '7.6.0.5',
      sensor_count: gw.sensor_count || 0,
      device_count: gw.device_count !== undefined ? gw.device_count : 0,  // Preserve fixture device_count
      manifest: gw.manifest || null
    };
  });
  // Reset monotonic ID counter
  nextSatelliteId = managedSatellites.length + 1;
}

// Initialize on server load
initManagedSatellites();

// ────────────────────────────────────────────────────────────────────────────────
// Mock auth and validation helpers (mirrors firmware contract)
// ────────────────────────────────────────────────────────────────────────────────

// Check if request has non-empty body (mirrors firmware lines 2381-2384)
function hasNonEmptyBody(req) {
  const contentLength = parseInt(req.headers['content-length'] || '0', 10);
  return contentLength > 0;
}

// Mock auth check (mirrors firmware authenticate_management_)
// Mock accepts any request without auth query param as unauthenticated
// Real firmware checks session cookie or ?auth=<digest> query param
function checkAuth(req) {
  const parsedUrl = url.parse(req.url, true);
  // In mock: require ?auth=mock for destructive operations
  // Real firmware validates session or HMAC digest
  return parsedUrl.query.auth === 'mock';
}

// List of management POST routes requiring non-empty body
function isManagementPostRoute(pathname) {
  if (pathname === '/api/reboot') return true;
  if (pathname === '/api/delete-data') return true;
  if (pathname === '/api/system/reset-satellites') return true;
  if (pathname.startsWith('/api/aggregator/add-satellite')) return true;
  if (pathname.startsWith('/api/aggregator/test-satellite')) return true;
  return false;
}

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
    // BUG-043: 50ms delay makes concurrency observable in Playwright tests
    return setTimeout(function() { text(res, data, 'text/plain'); }, 50);
  }

  if (pathname === '/api/v2/live') {
    const manifest = loadFixtureJson('manifest.json', { sensors: [] });
    const devices = {};
    (manifest.sensors || []).forEach(function(s, idx) {
      if (!s.adapter || s.adapter === 'thermopro_ble') {
        devices[s.id] = {
          temp: parseFloat((20.0 + idx * 1.7).toFixed(1)),
          hum: parseFloat((45 + idx * 6).toFixed(0)),
          batt: null,
          rssi: null,
          last_seen: 1741694400 + idx * 10
        };
      } else if (s.adapter === 'icmp_ping') {
        devices[s.id] = {
          ping_ms: 12.5,
          success_pct: 100.0,
          last_seen: 1741694400 + idx * 10
        };
      } else if (s.adapter === 'external_push') {
        const isSystem = FIXTURE_SET === 'system';
        devices[s.id] = isSystem
          ? { cpu_pct: 45.2, ram_pct: 72.8, disk_pct: 55.0, uptime_hrs: 168.5, last_seen: 1710264000 }
          : { cpu_pct: null, ram_pct: null, disk_pct: null, uptime_hrs: null, last_seen: 1741694400 + idx * 10 };
      }
    });
    return json(res, { timestamp: 1741694400, devices: devices });
  }

  const v2HistMatch = pathname.match(/^\/api\/v2\/history\/([^/]+)\/([^/]+)$/);
  if (v2HistMatch) {
    const deviceId = v2HistMatch[1];
    const metricKey = v2HistMatch[2];
    const data = loadFixture(`history-${deviceId}-${metricKey}.csv`);
    if (data === null) return notFound(res, `No fixture for ${deviceId}/${metricKey}`);
    // BUG-043: 50ms delay makes concurrency observable in Playwright tests
    return setTimeout(function() { text(res, data, 'text/plain'); }, 50);
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

  const ingestMatch = pathname.match(/^\/api\/ingest\/([^/]+)\/([^/]+)$/);
  if (ingestMatch && req.method === 'POST') {
    const deviceId = ingestMatch[1];
    const metricKey = ingestMatch[2];
    const manifest = loadFixtureJson('manifest.json', { sensors: [] });
    const device = (manifest.sensors || []).find(s => s.id === deviceId);
    if (!device) return json(res, { ok: false, message: `Unknown device: ${deviceId}`, status: 404 }, 404);
    const validMetric = (device.measurements || []).some(m => m.key === metricKey);
    if (!validMetric) return json(res, { ok: false, message: `Unknown metric: ${metricKey} for device ${deviceId}`, status: 404 }, 404);
    const url = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
    const val = url.searchParams.get('val');
    if (val === null || val === '' || !isFinite(Number(val))) {
      return json(res, { ok: false, message: 'Missing or invalid val parameter', status: 400 }, 400);
    }
    return json(res, { ok: true });
  }

  // Aggregator endpoints — return empty gateways in satellite fixture sets (no 404
  // to avoid browser console errors in tests). detectAggregatorMode() handles empty
  // gateways list as satellite mode. In aggregator mode (FIXTURE_SET=aggregator),
  // use managed satellite state (Phase D v7.6.0.5).
  if (pathname === '/api/aggregator/gateways') {
    if (FIXTURE_SET === 'aggregator') {
      return json(res, { gateways: managedSatellites });
    }
    return json(res, loadFixtureJson('aggregator-gateways.json', { gateways: [] }));
  }
  if (pathname === '/api/aggregator/live') {
    return json(res, loadFixtureJson('aggregator-live.json',
      { timestamp: Math.floor(Date.now() / 1000), gateways: {} }));
  }
  if (pathname.startsWith('/api/aggregator/proxy/')) {
    // pathname: /api/aggregator/proxy/{gwId}/history/{device}/{metric}
    const parts = pathname.split('/');
    // parts: ['', 'api', 'aggregator', 'proxy', gwId, 'history', device, metric]
    if (parts.length >= 8 && parts[5] === 'history') {
      const gwId = parts[4];
      const device = parts[6];
      const metric = parts[7];
      const csvFile = `history-${gwId}-${device}-${metric}.csv`;
      const csv = loadFixture(csvFile);
      if (csv !== null) {
        return text(res, csv, 'text/plain');
      }
    }
    return notFound(res, pathname);
  }

  // ────────────────────────────────────────────────────────────────────────────────
  // Satellite Management Endpoints (Phase D v7.6.0.5)
  // Contract mirrors firmware handlers in dashboard/sensor_history_multi.h
  // ────────────────────────────────────────────────────────────────────────────────

  // POST /api/aggregator/add-satellite
  if (pathname === '/api/aggregator/add-satellite') {
    // Method validation (firmware line 3936-3939)
    if (req.method !== 'POST') {
      return json(res, { ok: false, message: 'Method not allowed', status: 405 }, 405);
    }
    // Non-empty body guard (firmware lines 2381-2384)
    if (!hasNonEmptyBody(req)) {
      return json(res, { ok: false, message: 'Non-empty body required for management POST', status: 400 }, 400);
    }

    // NOTE: add-satellite intentionally does NOT require auth (firmware lines 3941-3946)

    const params = new URL(req.url, `http://${req.headers.host || 'localhost'}`).searchParams;
    const satUrl = params.get('url');
    const satName = params.get('name');
    const satPollParam = params.get('poll');

    if (!satUrl) return json(res, { ok: false, message: 'Missing url parameter', status: 400 }, 400);
    if (!satUrl.startsWith('http://')) return json(res, { ok: false, message: 'URL must start with http://', status: 400 }, 400);
    if (satUrl.length >= 128) return json(res, { ok: false, message: 'URL too long (max 127 characters)', status: 400 }, 400);
    if (managedSatellites.length >= MOCK_MAX_SATELLITES) return json(res, { ok: false, message: 'Satellite list full', status: 409 }, 409);
    if (managedSatellites.some(s => s.base_url === satUrl)) return json(res, { ok: false, message: 'URL already configured', status: 409 }, 409);

    // Simulate probe — URLs containing 'unreachable' fail
    if (satUrl.includes('unreachable')) return json(res, { ok: false, message: 'Satellite unreachable or invalid manifest', status: 400 }, 400);

    // Parse poll interval with firmware-matching validation (firmware lines 4007-4012)
    let satPoll = 30;
    if (satPollParam) {
      const p = parseInt(satPollParam, 10);
      if (p >= 10 && p <= 3600) satPoll = p;
    }

    // Probe succeeds — add satellite with monotonic ID
    const newId = 'mock-sat-' + nextSatelliteId++;
    const newName = satName || 'Mock Satellite ' + managedSatellites.length;
    const newSat = {
      id: newId,
      name: newName,
      base_url: satUrl,
      poll: satPoll,
      reachable: true,
      last_seen: Math.floor(Date.now() / 1000),
      consecutive_failures: 0,
      firmware_version: '7.6.0.5',
      sensor_count: 0,
      device_count: 0
    };
    managedSatellites.push(newSat);

    return json(res, { ok: true, satellite: { id: newId, name: newName, url: satUrl, poll: satPoll } });
  }

  // DELETE /api/aggregator/satellite/{id}
  const deleteSatMatch = pathname.match(/^\/api\/aggregator\/satellite\/(.*)$/);
  if (deleteSatMatch) {
    // Method validation (firmware lines 4075-4078)
    if (req.method !== 'DELETE') {
      return json(res, { ok: false, message: 'Method not allowed', status: 405 }, 405);
    }
    // Auth enforcement (firmware line 4080)
    if (!checkAuth(req)) {
      return json(res, { ok: false, message: 'Unauthorized', status: 401 }, 401);
    }

    const satId = decodeURIComponent(deleteSatMatch[1]);
    // Empty ID validation (firmware lines 4086-4089)
    if (satId === '') {
      return json(res, { ok: false, message: 'Missing satellite ID', status: 400 }, 400);
    }

    const idx = managedSatellites.findIndex(s => s.id === satId);
    if (idx < 0) return json(res, { ok: false, message: 'Unknown satellite ID', status: 404 }, 404);
    managedSatellites.splice(idx, 1);
    return json(res, { ok: true });
  }

  // POST /api/aggregator/test-satellite
  if (pathname === '/api/aggregator/test-satellite') {
    // Method validation (firmware lines 4159-4162)
    if (req.method !== 'POST') {
      return json(res, { ok: false, message: 'Method not allowed', status: 405 }, 405);
    }
    // Non-empty body guard (firmware lines 2381-2384)
    if (!hasNonEmptyBody(req)) {
      return json(res, { ok: false, message: 'Non-empty body required for management POST', status: 400 }, 400);
    }
    // Auth enforcement (firmware line 4163)
    if (!checkAuth(req)) {
      return json(res, { ok: false, message: 'Unauthorized', status: 401 }, 401);
    }

    const params = new URL(req.url, `http://${req.headers.host || 'localhost'}`).searchParams;
    const testUrl = params.get('url');

    if (!testUrl) return json(res, { ok: false, message: 'Missing url parameter', status: 400 }, 400);
    if (!testUrl.startsWith('http://')) return json(res, { ok: false, message: 'URL must start with http://', status: 400 }, 400);
    if (testUrl.length > 200) return json(res, { ok: false, message: 'URL too long', status: 400 }, 400);
    if (testUrl.includes('unreachable')) return json(res, { ok: false, message: 'Satellite unreachable or invalid manifest', status: 400 }, 400);

    // Probe succeeds — return mock gateway info
    return json(res, {
      ok: true,
      gateway: {
        id: 'mock-probe-id',
        name: 'Mock Probed Gateway',
        hardware: 'ESP32-C3',
        sensor_count: 3
      }
    });
  }

  // POST /api/system/reset-satellites
  if (pathname === '/api/system/reset-satellites') {
    // Method validation (firmware lines 4256-4259)
    if (req.method !== 'POST') {
      return json(res, { ok: false, message: 'Method not allowed', status: 405 }, 405);
    }
    // Non-empty body guard (firmware lines 2381-2384)
    if (!hasNonEmptyBody(req)) {
      return json(res, { ok: false, message: 'Non-empty body required for management POST', status: 400 }, 400);
    }
    // Auth enforcement (firmware line 4260)
    if (!checkAuth(req)) {
      return json(res, { ok: false, message: 'Unauthorized', status: 401 }, 401);
    }

    initManagedSatellites(); // Reset to fixture defaults
    return json(res, {
      ok: true,
      message: 'Reset to compile-time defaults',
      satellite_count: managedSatellites.length
    });
  }

  notFound(res, pathname);
});

server.listen(PORT, '127.0.0.1', function() {
  console.log(`Mock ESP32 gateway server listening on http://127.0.0.1:${PORT}`);
  console.log(`Fixture set: ${FIXTURE_SET || 'root-baseline'}`);
  console.log(`Manifest mode: ${DISABLE_API_MANIFEST ? 'legacy-fallback-only' : 'v2 + legacy'}`);
});

module.exports = server;
