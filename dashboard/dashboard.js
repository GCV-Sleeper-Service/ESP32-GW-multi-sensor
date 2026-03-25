// ╔════════════════════════════════════════════════════════════════╗
// ║  Multi-Sensor Gateway Dashboard                               ║
// ║                                                                ║
// ║  Current dashboard features:                                   ║
// ║    • 24h/7d/30d/45d selectable Min/Max toggle per sensor card     ║
// ║    • BLE RSSI signal strength indicator (needs YAML sensor)    ║
// ║    • Comfort level estimate row (ASHRAE-55-inspired proxy)        ║
// ║    • Dew point calculation (Magnus formula, browser-side)      ║
// ║    • Dark/light mode toggle with CSS custom properties         ║
// ║    • Staleness indicator (yellow >2min, red >5min)             ║
// ║    • CSV history export with gateway metadata and merged Export All                    ║
// ║  Core behavior:                                                ║
// ║    • retained merged history, 0°C freezing line, embedded hosting     ║
// ║    • Transport auto-detection (hosted/SSE/polling)             ║
// ║    • Gateway mini cards under the gateway card, with auth-protected management actions                     ║
// ║                                                                ║
// ║  CONNECTION:                                                    ║
// ║    If opened from ESP (same-origin), ESP_HOST stays ''.        ║
// ║    If opened from disk, set FILE_FALLBACK_HOST below.         ║
// ║    Transport: http → SSE, https → polling, hosted → SSE.      ║
// ╚════════════════════════════════════════════════════════════════╝


// ── v7.3 dashboard structural enforcement: module boundaries + plugin hooks ──
//
// Goal (Step 1 + Step 2 of the re-architecture plan):
//   1) Introduce an App namespace with clear module boundaries.
//   2) Add a tiny plugin interface so new features can be isolated.
//      Each plugin runs in try/catch so one feature cannot blank the UI.
//
// NOTE: This phase intentionally preserves the working v7.2/v7.3 transport/init
// behavior. Phase 1 now adds two practical guardrails without broad rewrites:
//   1) primary shared-state writes go through App.State setters
//   2) inline dashboard handlers are replaced by a centralized bindEvents()
// The bulk of the logic still lives in existing functions so regression risk stays low.
// v7.5.2.0 (Phase 2 Step 1): adds loadManifestV2() + autoPromoteV1ToV2() for
// manifest v2 consumption; result stored in window._manifest. No rendering changes.
// v7.5.2.3 (Phase 2 Step 4): adds fetchDeviceHistory() — manifest-driven history URL
// resolution with fallback to legacy /history/{id}/temp and /history/{id}/hum.

var App = window.App || (window.App = {});
App.version = 'v7.5.5.3';
App.Config = App.Config || {};
App.State = App.State || {};
App.Util = App.Util || {};
App.API = App.API || {};
App.Transport = App.Transport || {};
App.Render = App.Render || {};
App.Charts = App.Charts || {};
App.Boot = App.Boot || {};
App.Features = App.Features || (function() {
  var api = { plugins: [] };

  api.register = function(plugin) {
    if (!plugin) return;
    api.plugins.push(plugin);
  };

  api.emit = function(hook) {
    var args = Array.prototype.slice.call(arguments, 1);
    for (var i = 0; i < api.plugins.length; i++) {
      var p = api.plugins[i];
      var fn = p && p[hook];
      if (typeof fn === 'function') {
        try { fn.apply(p, args); } catch (e) { logNonFatal('plugin hook ' + hook, e); }
      }
    }
  };

  return api;
})();

function logNonFatal(scope, err) {
  var msg = scope + ': ' + (err && err.message ? err.message : err);
  try { if (typeof console !== 'undefined' && console.warn) console.warn(msg, err); } catch (_e) {}
  try { if (typeof dlog === 'function') dlog(msg, 'err'); } catch (_e2) {}
}

// ── Connection ──────────────────────────────────────────────────
// For hosted mode (served directly by the ESP firmware), leave ESP_HOST empty.
// For LAN from disk: var FILE_FALLBACK_HOST = 'http://192.168.120.189';
// For Cloudflare:    var FILE_FALLBACK_HOST = 'https://esp32-2.high-lands.online';
var FILE_FALLBACK_HOST = 'http://192.168.120.189';

// Determine ESP_HOST: if page is served from ESP (same-origin http/https),
// use relative paths. When opened from disk/localhost, use the fallback host.
var IS_FILE_MODE = (window.location.protocol === 'file:' ||
    window.location.hostname === '' || window.location.hostname === 'localhost');
var ESP_HOST = '';
if (IS_FILE_MODE) {
  ESP_HOST = FILE_FALLBACK_HOST;
}

// Transport selection:
// - same-origin http  -> SSE
// - same-origin https -> polling (Cloudflare / reverse-proxy friendly)
// - fallback http     -> SSE
// - fallback https    -> polling
var TRANSPORT;
if (!IS_FILE_MODE && window.location.protocol === 'https:') {
  TRANSPORT = 'polling';
} else if (ESP_HOST === '') {
  TRANSPORT = 'sse';
} else if (/^https:/i.test(ESP_HOST)) {
  TRANSPORT = 'polling';
} else {
  TRANSPORT = 'sse';
}


// ── App.Config wiring (kept in-sync with the legacy globals) ──
try {
  App.Config.FILE_FALLBACK_HOST = FILE_FALLBACK_HOST;
  App.Config.ESP_HOST = ESP_HOST;
  App.Config.TRANSPORT = TRANSPORT;
  App.Config.IS_FILE_MODE = IS_FILE_MODE;
  App.Config.isHosted = function() { return App.Config.ESP_HOST === ''; };
} catch(e) { logNonFatal('App.Config wiring', e); }

// ── Chart data cap ──────────────────────────────────────────────
var MAX_POINTS = 720;
var HISTORY_RANGE_HOURS = 24;
var MAX_HISTORY_RANGE_HOURS = 1080;  // 45 days — must match max range button
var CUSTOM_RANGE_START = 0;  // epoch (seconds), 0 = not in use
var CUSTOM_RANGE_END   = 0;  // epoch (seconds), 0 = not in use
var avgHistoryStore = {};
var chartsReady = false;

// ── Sensor state bootstrap ─────────────────────────────────────
// Must exist before App.State initializes, or early script execution fails
// and the dashboard can appear stuck on the static 'connecting...' shell.
var SENSORS = [];

// ── Aggregator mode flag ────────────────────────────────────────
// Set by detectAggregatorMode() at boot. 'satellite' (default) = normal satellite
// dashboard. 'aggregator' = multi-gateway aggregator UI.
var DASHBOARD_MODE = 'satellite'; // 'satellite' | 'aggregator'

// ── App.State implementation (Phase 1 write chokepoints) ───────
(function(api) {
  var store = {
    sensors: SENSORS,
    historyRangeHours: HISTORY_RANGE_HOURS,
    maxHistoryRangeHours: MAX_HISTORY_RANGE_HOURS,
    avgHistoryStore: avgHistoryStore,
    chartsReady: chartsReady
  };

  api.get = function(key) { return store[key]; };
  api.set = function(key, value) { store[key] = value; return value; };
  api.patch = function(values) {
    if (!values || typeof values !== 'object') return store;
    for (var key in values) if (Object.prototype.hasOwnProperty.call(values, key)) store[key] = values[key];
    return store;
  };

  api.getSensors = function() { return SENSORS; };
  api.setSensors = function(nextSensors) {
    SENSORS = Array.isArray(nextSensors) ? nextSensors : [];
    store.sensors = SENSORS;
    return SENSORS;
  };

  api.getHistoryRangeHours = function() { return HISTORY_RANGE_HOURS; };
  api.setHistoryRangeHours = function(hours) {
    HISTORY_RANGE_HOURS = hours;
    store.historyRangeHours = HISTORY_RANGE_HOURS;
    return HISTORY_RANGE_HOURS;
  };

  api.getMaxHistoryRangeHours = function() { return MAX_HISTORY_RANGE_HOURS; };

  api.getAvgHistoryStore = function() { return avgHistoryStore; };
  api.resetAvgHistoryStore = function() {
    avgHistoryStore = {};
    store.avgHistoryStore = avgHistoryStore;
    return avgHistoryStore;
  };
  api.ensureHistoryStore = function(sensorId) {
    if (!avgHistoryStore[sensorId]) avgHistoryStore[sensorId] = { temp: [], hum: [] };
    store.avgHistoryStore = avgHistoryStore;
    return avgHistoryStore[sensorId];
  };

  api.isChartsReady = function() { return !!chartsReady; };
  api.setChartsReady = function(ready) {
    chartsReady = !!ready;
    store.chartsReady = chartsReady;
    return chartsReady;
  };
})(App.State);

// ── Sensor definitions ──────────────────────────────────────────
var SENSOR_COLORS = ['#fbbf24', '#f87171', '#34d399', '#60a5fa'];

// <<< SENSOR_MANIFEST:DEFAULT_SENSOR_META_BEGIN >>>
var DEFAULT_SENSOR_META = [
];
// <<< SENSOR_MANIFEST:DEFAULT_SENSOR_META_END >>>

var GATEWAY_EXPORT_HOSTNAME_FALLBACK = 'esp32-c3-multi';
var EXPORT_SHARED_COLUMNS = ['gateway_host', 'gateway_ip', 'timestamp', 'datetime_utc'];
var EXPORT_SENSOR_SUFFIXES = ['temp_c', 'temp_f', 'humidity_pct', 'dewpoint_c'];

function sensorSlug(value) {
  return String(value || '')
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '');
}

function isIPv4Host(value) {
  return /^\d{1,3}(?:\.\d{1,3}){3}$/.test(String(value || '').trim());
}

function getResolvedGatewayUrl() {
  if (ESP_HOST) return ESP_HOST;
  return window.location.origin || '';
}

function getResolvedGatewayEndpointHost() {
  var raw = getResolvedGatewayUrl();
  try {
    if (raw) return new URL(raw, window.location.href).hostname || '';
  } catch (e) {}
  return window.location.hostname || '';
}

function getExportGatewayHostname() {
  var endpointHost = getResolvedGatewayEndpointHost();
  if (endpointHost && endpointHost !== 'localhost' && !isIPv4Host(endpointHost)) return endpointHost;
  return GATEWAY_EXPORT_HOSTNAME_FALLBACK || endpointHost || 'gateway';
}

function getKnownGatewayIpFromDom() {
  var el = document.getElementById('di-ip');
  if (!el) return '';
  var text = (el.textContent || '').trim();
  if (!text || text === 'loading...' || text === '\u2014') return '';
  return text;
}

function fetchGatewayIpAddress() {
  var cached = getKnownGatewayIpFromDom();
  if (cached) return Promise.resolve(cached);
  return fetch(ESP_HOST + '/text_sensor/IP%20Address', {cache:'no-store'})
    .then(function(r) { if (!r.ok) throw new Error('HTTP ' + r.status); return r.json(); })
    .then(function(d) {
      var state = d && d.state ? String(d.state).trim() : '';
      return state && state !== 'loading...' ? state : '';
    })
    .catch(function() {
      var endpointHost = getResolvedGatewayEndpointHost();
      return isIPv4Host(endpointHost) ? endpointHost : '';
    });
}

function getGatewayExportMeta() {
  return fetchGatewayIpAddress().then(function(ip) {
    return {
      gatewayHost: getExportGatewayHostname(),
      gatewayIp: ip || ''
    };
  });
}

function getExportSensorPrefix(sensor) {
  return sensorSlug((sensor && sensor.id) || (sensor && sensor.name) || '');
}

function getSingleSensorExportColumns(sensor) {
  var cols = EXPORT_SHARED_COLUMNS.slice();
  var prefix = getExportSensorPrefix(sensor);
  EXPORT_SENSOR_SUFFIXES.forEach(function(suffix) {
    cols.push(prefix + '_' + suffix);
  });
  return cols;
}

function getMergedExportColumns(sensors) {
  var cols = EXPORT_SHARED_COLUMNS.slice();
  sensors.forEach(function(sensor) {
    var prefix = getExportSensorPrefix(sensor);
    EXPORT_SENSOR_SUFFIXES.forEach(function(suffix) {
      cols.push(prefix + '_' + suffix);
    });
  });
  return cols;
}

function csvEscape(value) {
  if (value === null || value === undefined) return '';
  var str = String(value);
  if (/[",\r\n]/.test(str)) return '"' + str.replace(/"/g, '""') + '"';
  return str;
}

function formatMetricNumber(value) {
  return (typeof value === 'number' && isFinite(value)) ? value.toFixed(1) : '';
}

// ── v7.5.2.2 — Metric formatter registry ─────────────────────────
var METRIC_FORMATTERS = {
  temperature: function(value, unit) {
    if (unit === 'celsius' || unit === '\u00b0C') {
      var f = value * 9 / 5 + 32;
      return value.toFixed(1) + ' \u00b0C / ' + f.toFixed(1) + ' \u00b0F';
    }
    return value.toFixed(1) + ' ' + (unit || '');
  },
  humidity: function(value) {
    return Math.round(value) + ' %';
  },
  ping_latency: function(value, unit) {
    if (value === null || value === undefined || isNaN(value)) return '\u2014';
    return value.toFixed(0) + ' ' + (unit || 'ms');
  },
  success_rate: function(value) {
    if (value === null || value === undefined || isNaN(value)) return '\u2014';
    return value.toFixed(0) + '%';
  },
  _default: function(value, unit) {
    return value.toFixed(1) + ' ' + (unit || '');
  }
};

function formatMetricValue(key, value, metric_def) {
  var formatter = METRIC_FORMATTERS[key] || METRIC_FORMATTERS._default;
  var unit = metric_def ? (metric_def.unit_symbol || metric_def.unit || '') : '';
  return formatter(value, unit);
}

function getMetricDef(key) {
  if (window._manifest && window._manifest.metrics) {
    for (var i = 0; i < window._manifest.metrics.length; i++) {
      if (window._manifest.metrics[i].key === key) return window._manifest.metrics[i];
    }
  }
  return null;
}

function triggerCsvDownload(csv, filename) {
  var blob = new Blob([csv], {type: 'text/csv'});
  var url = URL.createObjectURL(blob);
  var a = document.createElement('a');
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
}

function parseHistoryMetricLines(text) {
  var out = {};
  text.split(/\r?\n/).forEach(function(line) {
    if (!line) return;
    var c = line.indexOf(',');
    if (c < 0) return;
    var epoch = parseInt(line.substring(0, c).trim(), 10);
    if (!isFinite(epoch)) return;
    var raw = line.substring(c + 1).trim();
    if (!raw) {
      out[epoch] = '';
      return;
    }
    var num = parseFloat(raw);
    out[epoch] = isFinite(num) ? num : '';
  });
  return out;
}

function buildNormalizedSensorRows(tempText, humText) {
  var tempMap = parseHistoryMetricLines(tempText);
  var humMap = parseHistoryMetricLines(humText);
  var seen = {};
  var timestamps = [];
  Object.keys(tempMap).forEach(function(key) {
    var ts = parseInt(key, 10);
    if (isFinite(ts) && !seen[ts]) { seen[ts] = true; timestamps.push(ts); }
  });
  Object.keys(humMap).forEach(function(key) {
    var ts = parseInt(key, 10);
    if (isFinite(ts) && !seen[ts]) { seen[ts] = true; timestamps.push(ts); }
  });
  timestamps.sort(function(a, b) { return a - b; });

  return timestamps.map(function(ts) {
    var tC = (typeof tempMap[ts] === 'number' && isFinite(tempMap[ts])) ? tempMap[ts] : null;
    var hum = (typeof humMap[ts] === 'number' && isFinite(humMap[ts])) ? humMap[ts] : null;
    var tF = tC !== null ? (tC * 9 / 5 + 32) : null;
    var dp = null;
    if (tC !== null && hum !== null) {
      var dpv = calcDewPoint(tC, hum);
      if (dpv !== null && isFinite(dpv)) dp = dpv;
    }
    return {
      timestamp: ts,
      datetime_utc: formatUtcForExport(ts),
      temp_c: tC,
      temp_f: tF,
      humidity_pct: hum,
      dewpoint_c: dp
    };
  });
}

// fetchDeviceHistory — manifest-driven history URL resolution (v7.5.2.3)
// Derives history URLs from manifest measurements[].history_url when available.
// Falls back to legacy /history/{id}/temp and /history/{id}/hum when manifest data is absent.
// Returns Promise<Array<{key, raw}>> where raw is the raw CSV text.
function fetchDeviceHistory(sensor, manifest) {
  var historyMeasurements = [];

  // Use _deviceId (original manifest ID) when available — sensor.id may be namespaced in aggregator mode.
  var lookupId = sensor._deviceId || sensor.id;

  // Manifest-driven: look up this sensor's measurements and their history URLs
  if (manifest && manifest.sensors) {
    var manifestDevice = null;
    for (var i = 0; i < manifest.sensors.length; i++) {
      if (manifest.sensors[i].id === lookupId) { manifestDevice = manifest.sensors[i]; break; }
    }
    if (manifestDevice && manifestDevice.measurements) {
      manifestDevice.measurements.forEach(function(m) {
        var metricDef = null;
        if (manifest.metrics) {
          for (var j = 0; j < manifest.metrics.length; j++) {
            if (manifest.metrics[j].key === m.key) { metricDef = manifest.metrics[j]; break; }
          }
        }
        // Only include measurements that have history + chart enabled
        if (metricDef && metricDef.history && metricDef.display && metricDef.display.chart) {
          var url;
          if (sensor._gwId) {
            // Aggregator mode: route history through the proxy endpoint
            url = '/api/aggregator/proxy/' + sensor._gwId + '/history/' + lookupId + '/' + m.key;
          } else {
            url = m.history_url || ('/history/' + lookupId + '/' + (metricDef.history_suffix || m.key));
          }
          historyMeasurements.push({ key: m.key, url: url });
        }
      });
    }
  }

  // Fallback: if no manifest data available, use legacy temp/hum paths
  if (historyMeasurements.length === 0) {
    if (sensor._gwId) {
      // Aggregator fallback: proxy the standard history metrics
      historyMeasurements = [
        { key: 'temp', url: '/api/aggregator/proxy/' + sensor._gwId + '/history/' + lookupId + '/temp' },
        { key: 'hum',  url: '/api/aggregator/proxy/' + sensor._gwId + '/history/' + lookupId + '/hum'  }
      ];
    } else {
      historyMeasurements = [
        { key: 'temp', url: '/history/' + lookupId + '/temp' },
        { key: 'hum',  url: '/history/' + lookupId + '/hum'  }
      ];
    }
  }

  // BUG-043-cont Fix 2: fetch metrics sequentially with a 300ms gap between requests.
  // Concurrent fetches via Promise.all trigger simultaneous NVS scan loops in the firmware
  // that each block the HTTP server task for 0.5–2 seconds, starving BLE/WiFi/watchdog.
  var results = [];
  var chain = Promise.resolve();
  historyMeasurements.forEach(function(m) {
    chain = chain.then(function() {
      return fetch(ESP_HOST + m.url, {cache:'no-store'})
        .then(function(r) { if (!r.ok) throw new Error('HTTP ' + r.status); return r.text(); })
        .then(function(raw) { results.push({key: m.key, raw: raw}); })
        .then(function() { return new Promise(function(res) { setTimeout(res, 300); }); });
    });
  });
  return chain.then(function() { return results; });
}

function fetchSensorHistoryRows(sensor) {
  return fetchDeviceHistory(sensor, window._manifest).then(function(series) {
    var temp = '', hum = '';
    series.forEach(function(s) {
      if (s.key === 'temp') temp = s.raw;
      else if (s.key === 'hum') hum = s.raw;
    });
    return buildNormalizedSensorRows(temp, hum);
  });
}

function fetchAllSensorHistoryRowsSequentially(sensors, onProgress) {
  var queue = Array.isArray(sensors) ? sensors.slice() : [];
  var results = new Array(queue.length);
  return queue.reduce(function(chain, sensor, idx) {
    return chain.then(function() {
      if (typeof onProgress === 'function') onProgress(idx, sensor, queue.length);
      return fetchSensorHistoryRows(sensor).then(function(rows) {
        results[idx] = rows;
      }).catch(function() {
        // BUG-046: tolerate per-sensor fetch failures (e.g. empty history after migration)
        results[idx] = [];
      });
    });
  }, Promise.resolve()).then(function() {
    return results;
  });
}

function buildSingleSensorCsv(meta, sensor, rows) {
  var lines = [getSingleSensorExportColumns(sensor).join(',')];
  rows.forEach(function(row) {
    lines.push([
      csvEscape(meta.gatewayHost),
      csvEscape(meta.gatewayIp),
      row.timestamp,
      csvEscape(row.datetime_utc),
      formatMetricNumber(row.temp_c),
      formatMetricNumber(row.temp_f),
      formatMetricNumber(row.humidity_pct),
      formatMetricNumber(row.dewpoint_c)
    ].join(','));
  });
  return lines.join('\n') + '\n';
}

function buildMergedSensorCsv(meta, sensors, sensorRowsList) {
  var header = getMergedExportColumns(sensors);
  var union = {};
  sensorRowsList.forEach(function(rows, idx) {
    if (!rows) return; // BUG-046: guard against undefined/null entries (empty [] iterates safely)
    rows.forEach(function(row) {
      if (!union[row.timestamp]) {
        union[row.timestamp] = { timestamp: row.timestamp, datetime_utc: row.datetime_utc, sensorData: {} };
      }
      union[row.timestamp].datetime_utc = row.datetime_utc;
      union[row.timestamp].sensorData[idx] = row;
    });
  });

  var timestamps = Object.keys(union)
    .map(function(k) { return parseInt(k, 10); })
    .filter(function(v) { return isFinite(v); })
    .sort(function(a, b) { return a - b; });
  var lines = [header.join(',')];

  timestamps.forEach(function(ts) {
    var entry = union[ts];
    var rowOut = [
      csvEscape(meta.gatewayHost),
      csvEscape(meta.gatewayIp),
      ts,
      csvEscape(entry.datetime_utc || formatUtcForExport(ts))
    ];
    sensors.forEach(function(_sensor, idx) {
      var row = entry.sensorData[idx] || null;
      rowOut.push(formatMetricNumber(row ? row.temp_c : null));
      rowOut.push(formatMetricNumber(row ? row.temp_f : null));
      rowOut.push(formatMetricNumber(row ? row.humidity_pct : null));
      rowOut.push(formatMetricNumber(row ? row.dewpoint_c : null));
    });
    lines.push(rowOut.join(','));
  });

  return lines.join('\n') + '\n';
}

function currentExportDateTag() {
  return new Date().toISOString().slice(0, 10);
}


function makeSensorConfig(meta, idx) {
  var id = meta.id, name = meta.name;
  var color = SENSOR_COLORS[idx % SENSOR_COLORS.length];
  try { var saved = localStorage.getItem('sensor_color_' + id); if (saved) color = saved; } catch(e) {}
  return {
    id: id, name: name,
    color: color,
    tempId: 'text_sensor-' + id + '_temperature',
    humId: 'text_sensor-' + id + '_humidity',
    tempAvgId: 'text_sensor-' + id + '_temp__15m_avg_',
    humAvgId: 'text_sensor-' + id + '_humidity__15m_avg_',
    battId: 'text_sensor-' + id + '_battery',
    rssiId: 'sensor-' + id + '_rssi',
    lastSeenId: 'text_sensor-' + id + '_last_seen',
    restPaths: [
      '/text_sensor/' + encodeURIComponent(name + ' Temperature'),
      '/text_sensor/' + encodeURIComponent(name + ' Humidity'),
      '/text_sensor/' + encodeURIComponent(name + ' Temp (15m avg)'),
      '/text_sensor/' + encodeURIComponent(name + ' Humidity (15m avg)'),
      '/text_sensor/' + encodeURIComponent(name + ' Battery'),
      '/text_sensor/' + encodeURIComponent(name + ' Last Seen'),
      '/sensor/' + encodeURIComponent(name + ' RSSI')
    ]
  };
}

function makeNetworkSensorConfig(meta, idx) {
  var id = meta.id, name = meta.name;
  var color = SENSOR_COLORS[idx % SENSOR_COLORS.length];
  try { var saved = localStorage.getItem('sensor_color_' + id); if (saved) color = saved; } catch(e) {}
  return {
    id: id, name: name,
    color: color,
    category: meta.category || 'network',
    // No ThermoPro entity IDs — network devices use /api/v2/live polling
    restPaths: []
  };
}

function applySensorMeta(meta) {
  if (!Array.isArray(meta) || !meta.length) meta = DEFAULT_SENSOR_META;
  App.State.setSensors(meta.map(function(m, idx) {
    var cat = m.category || 'environmental';
    if (cat === 'network') return makeNetworkSensorConfig(m, idx);
    if (cat === 'system') return makeNetworkSensorConfig(m, idx); // reuse for now
    return makeSensorConfig(m, idx); // ThermoPro path
  }));
  // Assign chart dataset indices: environmental sensors get 0,1,2,...; others get -1
  var chartIdx = 0;
  App.State.getSensors().forEach(function(s) {
    var cat = s.category || 'environmental';
    s.chartIdx = (cat === 'environmental') ? chartIdx++ : -1;
  });
  try { App.Features.emit('onManifest', App.State.getSensors()); } catch(e) { logNonFatal('manifest hook emit', e); }
}

function normalizeManifestSensors(payload) {
  var sensors = [];
  if (Array.isArray(payload)) sensors = payload;
  else if (payload && Array.isArray(payload.sensors)) sensors = payload.sensors;
  return sensors.map(function(sensor) {
    return {
      id: String(sensor && sensor.id || '').trim(),
      name: String(sensor && sensor.name || '').trim(),
      category: String(sensor && sensor.category || 'environmental').trim(),
      metrics: Array.isArray(sensor && sensor.metrics) ? sensor.metrics : []
    };
  }).filter(function(sensor) {
    return sensor.id && sensor.name;
    // Removed environmental-only filter — all categories now included (v7.5.4.2+)
  });
}

function loadSensorManifest() {
  return fetch(ESP_HOST + '/api/manifest', {cache:'no-store'})
    .then(function(r) { if (!r.ok) throw new Error('HTTP ' + r.status); return r.json(); })
    .then(function(payload) {
      var meta = normalizeManifestSensors(payload);
      if (!meta.length) throw new Error('empty manifest');
      applySensorMeta(meta);
      var schema = payload && payload.schema_version ? payload.schema_version : 'legacy';
      dlog('Manifest loaded from /api/manifest (schema ' + schema + ', ' + SENSORS.length + ' sensors)', 'ok');
    })
    .catch(function(apiErr) {
      return fetch(ESP_HOST + '/sensors.json', {cache:'no-store'})
        .then(function(r) { if (!r.ok) throw new Error('HTTP ' + r.status); return r.json(); })
        .then(function(payload) {
          var meta = normalizeManifestSensors(payload);
          if (!meta.length) throw new Error('empty legacy manifest');
          applySensorMeta(meta);
          dlog('Manifest fallback loaded from /sensors.json (' + SENSORS.length + ' sensors); /api/manifest unavailable: ' + apiErr.message, 'err');
        })
        .catch(function(legacyErr) {
          applySensorMeta(DEFAULT_SENSOR_META);
          dlog('Manifest unavailable, using built-in (' + DEFAULT_SENSOR_META.length + ' sensors): api=' + apiErr.message + '; legacy=' + legacyErr.message, 'err');
        });
    });
};

// ── v7.5.2.0: manifest v2 loader with three-tier fallback ──────────────────
async function loadManifestV2() {
  try {
    // Tier 1: Try v2 manifest endpoint
    var manifestResp = await fetch(ESP_HOST + '/api/manifest', {cache: 'no-store'});
    if (manifestResp.ok) {
      var manifest = await manifestResp.json();
      if (manifest.schema_version === 2 && manifest.sensors) {
        console.log('[manifest] Loaded v2 manifest from /api/manifest');
        return manifest;
      }
    }
  } catch (e) {
    console.warn('[manifest] /api/manifest failed:', e.message);
  }

  try {
    // Tier 2: Fall back to legacy /sensors.json, auto-promote to v2
    var sensorsResp = await fetch(ESP_HOST + '/sensors.json', {cache: 'no-store'});
    if (sensorsResp.ok) {
      var sensors = await sensorsResp.json();
      console.log('[manifest] Falling back to /sensors.json \u2192 auto-promote to v2');
      return autoPromoteV1ToV2(sensors);
    }
  } catch (e) {
    console.warn('[manifest] /sensors.json failed:', e.message);
  }

  // Tier 3: Use hardcoded DEFAULT_SENSOR_META
  console.warn('[manifest] Using hardcoded DEFAULT_SENSOR_META fallback');
  return autoPromoteV1ToV2(DEFAULT_SENSOR_META);
}

function autoPromoteV1ToV2(sensorsArray) {
  // Convert v1 [{id, name}] to v2 manifest structure with ThermoPro defaults
  return {
    ok: true,
    schema_version: 2,
    source: 'auto-promoted',
    version: App.version,
    gateway: { id: 'gw-main', name: 'Main Gateway', role: 'satellite', hardware: 'ESP32-C3', firmware_version: App.version, api_version: 'v2' },
    history: { backend: 'nvs', retention_hours: 1080, ram_window_hours: 24, sample_interval_seconds: 900 },
    sensor_count: sensorsArray.length,
    metrics: [
      { key: 'temp', name: 'Temperature', unit: 'celsius', unit_symbol: '\u00b0C', class: 'analog_numeric', data_type: 'float', bounds: {min: -50, max: 80}, history: true, history_suffix: 'temp', display: {precision: 1, chart: true} },
      { key: 'hum', name: 'Humidity', unit: 'percent', unit_symbol: '%', class: 'analog_numeric', data_type: 'float', bounds: {min: 0, max: 100}, history: true, history_suffix: 'hum', display: {precision: 1, chart: true} }
    ],
    sensors: sensorsArray.map(function(s) {
      return { id: s.id, name: s.name, category: 'environmental', adapter: 'thermopro_ble', source: { mac: s.mac || '' }, measurements: [{ key: 'temp', history_url: '/history/' + s.id + '/temp' }, { key: 'hum', history_url: '/history/' + s.id + '/hum' }] };
    })
  };
}

var TELEMETRY_IDS = { heap:'sensor-free_heap', uptime:'sensor-uptime', wifi:'sensor-wifi_signal' };

var POLL_SHARED = ['/text_sensor/Current%20Time', '/sensor/WiFi%20Signal'];
var POLL_DEVICE = ['/text_sensor/Chip', '/text_sensor/Features', '/text_sensor/Cores', '/text_sensor/Revision', '/text_sensor/CPU%20Frequency', '/text_sensor/Framework', '/text_sensor/ESPHome%20Version', '/text_sensor/IP%20Address', '/text_sensor/MAC%20Address', '/text_sensor/Reset%20Reason'];


function formatUptimeSeconds(value) {
  var s = Math.floor(Number(value) || 0);
  var hr = Math.floor(s / 3600);
  var mn = Math.floor((s % 3600) / 60);
  return hr + 'h ' + mn + 'm ' + (s % 60) + 's';
}

function applyStatusSnapshot(status) {
  if (!status || typeof status !== 'object') return false;
  var touched = false;

  if (status.free_heap !== undefined && status.free_heap !== null) {
    var heapVal = Number(status.free_heap);
    if (isFinite(heapVal)) {
      lastTelemetry.heap = heapVal;
      var h = document.getElementById('di-heap');
      if (h) { h.textContent = (heapVal / 1024).toFixed(1) + ' KB'; h.classList.remove('loading'); }
      if (chartsReady) pushTelemetry();
      touched = true;
    }
  }

  if (status.uptime_seconds !== undefined && status.uptime_seconds !== null) {
    var uptimeVal = Number(status.uptime_seconds);
    if (isFinite(uptimeVal)) {
      var u = document.getElementById('di-uptime');
      if (u) { u.textContent = formatUptimeSeconds(uptimeVal); u.classList.remove('loading'); }
      touched = true;
    }
  }

  return touched;
}

// BUG-037: in-flight guard prevents concurrent /api/status requests from stacking up
// on the ESP32-C3 HTTP server (LESSON-OPS-050)
var _statusInFlight = false;

function loadStatusSnapshot() {
  if (isImportActive()) return Promise.resolve(false);
  if (_statusInFlight) return Promise.resolve(false);
  _statusInFlight = true;
  return fetch(ESP_HOST + '/api/status', {cache:'no-store'})
    .then(function(r) { if (!r.ok) throw new Error('HTTP ' + r.status); return r.json(); })
    .then(function(status) { return applyStatusSnapshot(status); })
    .catch(function(err) {
      dlog('Status snapshot failed: ' + err.message, 'err');
      return false;
    })
    .then(function(result) { _statusInFlight = false; return result; },
          function(err) { _statusInFlight = false; throw err; });
}

// ╔════════════════════════════════════════════════════════════════╗
// ║  HELPERS                                                       ║
// ╚════════════════════════════════════════════════════════════════╝

var totalPoints = 0, historyPoints = 0, liveAvgPoints = 0;
var lastAvgEpoch = {}, eventCount = 0, pollAvgLast = {};

function esc(s) { return s.replace(/[^a-zA-Z0-9]/g, '_'); }
function escAttr(s) { return String(s || '').replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/</g, '&lt;'); }
function escHtml(s) { return String(s || '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;'); }
function cToF(c) { return c * 9 / 5 + 32; }
function pad2(v) { return String(v).padStart(2, '0'); }
function formatUtcForExport(epoch) {
  var d = new Date(parseInt(epoch, 10) * 1000);
  return d.getUTCFullYear() + '-' + pad2(d.getUTCMonth() + 1) + '-' + pad2(d.getUTCDate()) +
         ' ' + pad2(d.getUTCHours()) + ':' + pad2(d.getUTCMinutes()) + ':' + pad2(d.getUTCSeconds());
}

function formatBytes(bytes) {
  var n = Number(bytes);
  if (!isFinite(n) || n < 0) return 'n/a';
  if (n < 1024) return Math.round(n) + ' B';
  if (n < 1024 * 1024) return (n / 1024).toFixed(n >= 10 * 1024 ? 0 : 1) + ' KiB';
  return (n / (1024 * 1024)).toFixed(2) + ' MiB';
}
function formatEpochLocal(epoch) {
  var n = Number(epoch);
  if (!isFinite(n) || n <= 0) return 'not yet';
  var d = new Date(n * 1000);
  return pad2(d.getHours()) + ':' + pad2(d.getMinutes()) + ' ' +
         d.getFullYear() + '-' + pad2(d.getMonth() + 1) + '-' + pad2(d.getDate());
}
// Returns {start, end} in epoch milliseconds — the active view window.
// Custom range (set by the date picker) takes priority over the preset hours.
function getEffectiveTimeRange() {
  if (CUSTOM_RANGE_START > 0 && CUSTOM_RANGE_END > 0) {
    return { start: CUSTOM_RANGE_START * 1000, end: CUSTOM_RANGE_END * 1000 };
  }
  var end = Date.now();
  return { start: end - (App.State.getHistoryRangeHours() * 3600000), end: end };
}
function filterPointsForRange(points) {
  var range = getEffectiveTimeRange();
  return (points || []).filter(function(pt) {
    return pt.x && pt.x.getTime() >= range.start && pt.x.getTime() <= range.end;
  });
}
function ensureHistoryStore(sensorId) {
  return App.State.ensureHistoryStore(sensorId);
}
function getHistoryTimeFormat(hours) {
  if (hours <= 24) {
    return {
      axisTitle: 'Time',
      tooltipFormat: 'MMM d, yyyy HH:mm:ss',
      displayFormats: { second:'HH:mm:ss', minute:'HH:mm', hour:'HH:mm', day:'MMM d' }
    };
  }
  if (hours <= 168) {
    return {
      axisTitle: 'Date / Time',
      tooltipFormat: 'MMM d, yyyy HH:mm',
      displayFormats: { second:'MMM d HH:mm:ss', minute:'MMM d HH:mm', hour:'MMM d HH:mm', day:'MMM d' }
    };
  }
  return {
    axisTitle: 'Date',
    tooltipFormat: 'MMM d, yyyy HH:mm',
    displayFormats: { second:'MMM d HH:mm:ss', minute:'MMM d HH:mm', hour:'MMM d HH:mm', day:'MMM d' }
  };
}
function applyHistoryAxisFormatting(chart, hours) {
  if (!chart || !chart.options || !chart.options.scales || !chart.options.scales.x) return;
  var fmt = getHistoryTimeFormat(hours);
  chart.options.scales.x.time.displayFormats = fmt.displayFormats;
  chart.options.scales.x.time.tooltipFormat = fmt.tooltipFormat;
  if (chart.options.scales.x.title) chart.options.scales.x.title.text = fmt.axisTitle;
}
function setHistoryRange(hours) {
  // Clear custom range — preset buttons always override it
  CUSTOM_RANGE_START = 0;
  CUSTOM_RANGE_END   = 0;
  App.State.setHistoryRangeHours(hours);
  try { App.Features.emit('onRangeChange', hours); } catch(e) { logNonFatal('range-change hook emit', e); }
  [24, 168, 720, 1080].forEach(function(v) {
    var btn = document.getElementById('histRange-' + v);
    if (btn) btn.classList.toggle('active', v === hours);
  });
  var custBtn = document.getElementById('histRange-custom');
  if (custBtn) custBtn.classList.remove('active');
  applyHistoryRange();
}
function applyHistoryRange() {
  if (!chartsReady) return;
  var tempVisible = 0, humVisible = 0;
  var effRange = getEffectiveTimeRange();
  var effHours = Math.round((effRange.end - effRange.start) / 3600000);
  applyHistoryAxisFormatting(tempAvgChart, effHours);
  applyHistoryAxisFormatting(humAvgChart, effHours);
  SENSORS.forEach(function(s, idx) {
    if (s.chartIdx === undefined || s.chartIdx < 0) return; // skip non-environmental
    var store = ensureHistoryStore(s.id);
    var tempPts = filterPointsForRange(store.temp);
    var humPts = filterPointsForRange(store.hum);
    tempAvgChart.data.datasets[s.chartIdx].data = tempPts;
    humAvgChart.data.datasets[s.chartIdx].data = humPts;
    tempVisible += tempPts.length;
    humVisible += humPts.length;
    updateMinMax(store.temp, s.id, true);
    updateMinMax(store.hum, s.id, false);
  });
  document.getElementById('tempAvgNoData').classList.toggle('hidden', tempVisible > 0);
  document.getElementById('humAvgNoData').classList.toggle('hidden', humVisible > 0);
  tempAvgChart.update('none');
  humAvgChart.update('none');
}

function isNoDataState(str) {
  if (str == null) return true;
  var s = String(str).trim().toUpperCase();
  return s === '' || s === 'NA' || s === 'NO DATA' || s === 'STALE';
}
function parseVal(str) {
  if (isNoDataState(str)) return null;
  if (typeof str === 'number') return str;
  var m = String(str).match(/([-\d.]+)/); return m ? parseFloat(m[1]) : null;
}

function dlog(msg, cls) {
  eventCount++; var el = document.getElementById('debugLog'), cnt = document.getElementById('evtCount');
  if (cnt) cnt.textContent = '(' + eventCount + ')'; if (!el) return;
  var line = document.createElement('div'); if (cls) line.className = cls;
  line.textContent = new Date().toLocaleTimeString([], {hour12:false}) + '  ' + msg;
  el.appendChild(line); while (el.children.length > 200) el.removeChild(el.firstChild);
  el.scrollTop = el.scrollHeight;
}
function toggleDebug() { var el = document.getElementById('debugLog'); el.classList.toggle('open'); }
function showError(msg) { var el = document.getElementById('errorBanner'); el.textContent = msg; el.classList.add('visible'); }
function toggle(id) {
  var icon = document.getElementById('icon-' + id), body = document.getElementById('body-' + id);
  if (!body || !icon) return;
  var closed = body.classList.contains('hidden');
  if (closed) { body.classList.remove('hidden'); icon.textContent = '\u2212'; icon.parentElement.classList.remove('collapsed'); }
  else { body.classList.add('hidden'); icon.textContent = '+'; icon.parentElement.classList.add('collapsed'); }
  if (closed && chartsReady) setTimeout(function() { [tempChart,humChart,tempAvgChart,humAvgChart,telemetryChart].forEach(function(c) { if(c) c.resize(); }); }, 50);
}

// Theme toggle
function toggleTheme() {
  var root = document.documentElement, btn = document.getElementById('themeBtn');
  var isLight = root.classList.toggle('light');
  btn.textContent = isLight ? '\u263E' : '\u2606';
  try { localStorage.setItem('theme', isLight ? 'light' : 'dark'); } catch(e) {}
  try { updateChartsTheme(); } catch(e) {}
  try { refreshChartsAfterVisualChange('theme-toggle'); } catch(e) { logNonFatal('theme redraw', e); }
  try { App.Features.emit('onThemeChange', isLight ? 'light' : 'dark'); } catch(e) {}
}
(function() {
  try { if (localStorage.getItem('theme') === 'light') { document.documentElement.classList.add('light'); var b = document.getElementById('themeBtn'); if(b) b.textContent = '\u263E'; } } catch(e) {}
})();

function bindEvents() {
  if (bindEvents._bound) return;
  bindEvents._bound = true;

  document.addEventListener('click', function(event) {
    var colorInput = event.target.closest('[data-sensor-color]');
    if (colorInput) {
      event.stopPropagation();
      return;
    }

    var actionEl = event.target.closest('[data-action]');
    if (actionEl) {
      var action = actionEl.getAttribute('data-action');
      if (action === 'toggle-theme') {
        toggleTheme();
        return;
      }
      if (action === 'toggle-debug') {
        toggleDebug();
        return;
      }
      if (action === 'reboot-esp') {
        rebootESP();
        return;
      }
      if (action === 'delete-history') {
        deleteHistoryData();
        return;
      }
      if (action === 'import-history') {
        importHistoryData();
        return;
      }
      if (action === 'refresh-history') {
        event.preventDefault();
        event.stopPropagation();
        loadHistory();
        return;
      }
    }

    var historyRangeBtn = event.target.closest('[data-history-range]');
    if (historyRangeBtn) {
      var rangeVal = historyRangeBtn.getAttribute('data-history-range');
      if (rangeVal === 'custom') {
        CustomRange.open();
      } else {
        setHistoryRange(parseInt(rangeVal, 10));
      }
      return;
    }

    var minMaxBtn = event.target.closest('[data-minmax-hours]');
    if (minMaxBtn) {
      var mmVal = minMaxBtn.getAttribute('data-minmax-hours');
      if (mmVal === 'custom') {
        CustomRange.open();
      } else {
        setMinMaxPeriod(minMaxBtn.getAttribute('data-minmax-sensor'), parseInt(mmVal, 10));
      }
      return;
    }

    var exportBtn = event.target.closest('[data-export-sensor]');
    if (exportBtn) {
      exportSensorCSV(exportBtn.getAttribute('data-export-sensor'), exportBtn.getAttribute('data-export-name') || exportBtn.textContent || 'sensor');
      return;
    }

    var exportAllBtn = event.target.closest('[data-export-all]');
    if (exportAllBtn) {
      exportAllCSV();
      return;
    }

    var toggleHdr = event.target.closest('[data-toggle-target]');
    if (toggleHdr) {
      toggle(toggleHdr.getAttribute('data-toggle-target'));
    }
  });

  function onColorEvent(event) {
    var colorInput = event.target.closest('[data-sensor-color]');
    if (!colorInput) return;
    event.stopPropagation();
    onSensorColorPicked(colorInput.getAttribute('data-sensor-color'), colorInput.value);
  }

  document.addEventListener('input', onColorEvent);
  document.addEventListener('change', onColorEvent);
}

// Dew point calculation (Magnus formula)
function calcDewPoint(tempC, rh) {
  if (tempC === null || rh === null || isNaN(tempC) || isNaN(rh) || rh <= 0) return null;
  var a = 17.27, b = 237.3;
  var gamma = (a * tempC) / (b + tempC) + Math.log(rh / 100);
  return (b * gamma) / (a - gamma);
}

// Staleness tracking
var sensorLastSeenEpoch = {};

function checkStaleness() {
  var now = Date.now();
  SENSORS.forEach(function(s) {
    var te = document.getElementById('time-' + s.id);
    if (!te) return;
    var epoch = sensorLastSeenEpoch[s.id];
    if (!epoch) return;
    var age = now - epoch;
    te.classList.remove('stale-warn', 'stale-crit');
    if (age > 300000) te.classList.add('stale-crit');       // >5 min
    else if (age > 120000) te.classList.add('stale-warn');   // >2 min
  });
}
var stalenessIntervalId = setInterval(checkStaleness, 10000);

// RSSI update
function updateRSSI(sensorId, dbm) {
  var barsEl = document.getElementById('rssi-bars-' + sensorId);
  var dbmEl = document.getElementById('rssi-dbm-' + sensorId);
  if (!barsEl || !dbmEl) return;
  dbmEl.textContent = Math.round(dbm) + ' dBm';
  dbmEl.classList.remove('waiting', 'strong', 'med', 'weak');
  var cls, onCls;
  if (dbm >= -70) { cls = 'strong'; onCls = 'on-strong'; }
  else if (dbm >= -85) { cls = 'med'; onCls = 'on-med'; }
  else { cls = 'weak'; onCls = 'on-weak'; }
  dbmEl.classList.add(cls);
  var bars = barsEl.children;
  var level = dbm >= -60 ? 4 : dbm >= -70 ? 3 : dbm >= -85 ? 2 : 1;
  for (var i = 0; i < bars.length; i++) {
    bars[i].className = 'rssi-bar b' + (i+1);
    if (i < level) bars[i].classList.add(onCls);
  }
}

// Dew point update for a sensor
var sensorCurrentTemp = {};
var sensorCurrentHum = {};

function updateDewPoint(sensorId) {
  var el = document.getElementById('dewpoint-' + sensorId);
  if (!el) return;
  var t = sensorCurrentTemp[sensorId], h = sensorCurrentHum[sensorId];
  if (t == null || h == null) return;
  var dp = calcDewPoint(t, h);
  if (dp === null) { el.textContent = '\u2014'; el.classList.add('waiting'); return; }
  el.textContent = dp.toFixed(1) + ' \u00B0C / ' + cToF(dp).toFixed(1) + ' \u00B0F';
  el.classList.remove('waiting');
}


function calcComfortEstimate(tempC, humPct) {
  if (tempC == null || humPct == null || isNaN(tempC) || isNaN(humPct)) return null;
  // Comfort note:
  // This is an ASHRAE-55-style browser-side estimate using only measured
  // dry-bulb temperature and RH with fixed assumptions suitable for a
  // simple dashboard proxy (operative temperature ≈ air temperature,
  // low air speed / sedentary occupancy / light clothing).
  var label = 'Comfortable', cls = 'good';

  if (tempC < 18.0) { label = 'Cold'; cls = 'cold'; }
  else if (tempC < 20.5) { label = 'Cool'; cls = 'warn'; }
  else if (tempC <= 26.0 && humPct >= 30 && humPct <= 60) { label = 'Comfortable'; cls = 'good'; }
  else if (tempC <= 27.5 && humPct >= 25 && humPct <= 65) { label = 'Slightly warm'; cls = 'neutral'; }
  else if (tempC >= 20.0 && tempC <= 24.5 && humPct < 30) { label = 'Dry / cool'; cls = 'warn'; }
  else if (tempC > 27.5 && humPct > 60) { label = 'Warm / humid'; cls = 'bad'; }
  else if (tempC > 27.5) { label = 'Warm'; cls = 'hot'; }
  else if (humPct > 70) { label = 'Humid'; cls = 'warn'; }
  else { label = 'Marginal'; cls = 'neutral'; }

  return {label: label, cls: cls};
}

function updateComfortLevel(sensorId) {
  var el = document.getElementById('comfort-' + sensorId);
  if (!el) return;
  var t = sensorCurrentTemp[sensorId], h = sensorCurrentHum[sensorId];
  var comfort = calcComfortEstimate(t, h);
  if (!comfort) {
    el.textContent = '\u2014';
    el.className = 'comfort-chip waiting';
    return;
  }
  el.textContent = comfort.label;
  el.className = 'comfort-chip ' + comfort.cls;
}

// Min/max period state (per sensor)
var minmaxPeriod = {};

function setMinMaxPeriod(sensorId, hours) {
  // Clear custom range — preset min/max selection overrides it
  CUSTOM_RANGE_START = 0;
  CUSTOM_RANGE_END   = 0;
  minmaxPeriod[sensorId] = hours;
  ['', 'm'].forEach(function(suffix) {
    [24, 168, 720, 1080].forEach(function(v) {
      var btn = document.getElementById('mmtog-' + v + suffix + '-' + sensorId);
      if (btn) btn.classList.toggle('active', v === hours);
    });
    var custBtn = document.getElementById('mmtog-custom' + suffix + '-' + sensorId);
    if (custBtn) custBtn.classList.remove('active');
  });
  var store = ensureHistoryStore(sensorId);
  updateMinMax(store.temp, sensorId, true);
  updateMinMax(store.hum, sensorId, false);
}

// ╔════════════════════════════════════════════════════════════════╗
// ║  Custom Date Range Selector — v7.4.2.0                        ║
// ║  Vanilla JS modal with calendar, presets, time selectors.     ║
// ║  Uses /api/storage-stats for available-range bounds.          ║
// ╚════════════════════════════════════════════════════════════════╝
var CustomRange = (function() {
  'use strict';
  var _availOldest = 0, _availNewest = 0;
  var _selStart = null, _selEnd = null;  // Date objects
  var _viewYear = 0, _viewMonth = 0;    // currently displayed calendar month
  var _pickingStart = true;             // two-click selection state

  function _pad(n) { return String(n).padStart(2, '0'); }
  function _fmtDate(d) {
    if (!d) return '';
    return d.getFullYear() + '-' + _pad(d.getMonth() + 1) + '-' + _pad(d.getDate());
  }
  function _epochToDate(ep) { return new Date(ep * 1000); }
  function _dateToEpoch(d)  { return Math.floor(d.getTime() / 1000); }

  function _getModal()   { return document.getElementById('customRangeModal'); }
  function _getEl(id)    { return document.getElementById(id); }

  // ── Show / hide ─────────────────────────────────────────────────────────────
  function open() {
    var modal = _getModal();
    if (!modal) return;
    // Fetch fresh bounds then show
    fetch(ESP_HOST + '/api/storage-stats')
      .then(safeJsonResponse)
      .then(function(data) {
        _availOldest = data.retention_oldest_epoch || 0;
        _availNewest = data.retention_newest_epoch || 0;
        _initSelection();
        _renderAvailability();
        _renderCalendar();
        _updateTimeFields();
        modal.classList.remove('hidden');
        modal.setAttribute('aria-hidden', 'false');
      })
      .catch(function() {
        // Fall back: no bounds — still open with today
        _availOldest = 0;
        _availNewest = Math.floor(Date.now() / 1000);
        _initSelection();
        _renderAvailability();
        _renderCalendar();
        _updateTimeFields();
        modal.classList.remove('hidden');
        modal.setAttribute('aria-hidden', 'false');
      });
  }

  function close() {
    var modal = _getModal();
    if (modal) { modal.classList.add('hidden'); modal.setAttribute('aria-hidden', 'true'); }
  }

  // ── Initialise selection state ───────────────────────────────────────────────
  function _initSelection() {
    var now = new Date();
    // Default: mirror the current active range
    if (CUSTOM_RANGE_START > 0 && CUSTOM_RANGE_END > 0) {
      _selStart = _epochToDate(CUSTOM_RANGE_START);
      _selEnd   = _epochToDate(CUSTOM_RANGE_END);
    } else {
      var hours = App.State.getHistoryRangeHours();
      _selEnd   = new Date(now);
      _selStart = new Date(now.getTime() - hours * 3600000);
    }
    _viewYear  = _selEnd.getFullYear();
    _viewMonth = _selEnd.getMonth();
    _pickingStart = false;
  }

  // ── Availability footer ──────────────────────────────────────────────────────
  function _renderAvailability() {
    var el = _getEl('customRangeAvail');
    if (!el) return;
    if (_availOldest > 0 && _availNewest > 0) {
      var o = _epochToDate(_availOldest), n = _epochToDate(_availNewest);
      el.textContent = 'Data available: ' + _fmtDate(o) + ' \u2013 ' + _fmtDate(n);
    } else if (_availNewest > 0) {
      el.textContent = 'Data available: up to ' + _fmtDate(_epochToDate(_availNewest));
    } else {
      el.textContent = 'No persisted history yet \u2014 range applies to RAM data only';
    }
  }

  // ── Calendar ─────────────────────────────────────────────────────────────────
  function _prevMonth() {
    _viewMonth--;
    if (_viewMonth < 0) { _viewMonth = 11; _viewYear--; }
    _renderCalendar();
  }
  function _nextMonth() {
    _viewMonth++;
    if (_viewMonth > 11) { _viewMonth = 0; _viewYear++; }
    _renderCalendar();
  }

  var _MONTH_NAMES = ['January','February','March','April','May','June',
                      'July','August','September','October','November','December'];
  var _DAY_NAMES   = ['Su','Mo','Tu','We','Th','Fr','Sa'];

  function _renderCalendar() {
    var hdr = _getEl('crCalHeader');
    if (hdr) hdr.textContent = _MONTH_NAMES[_viewMonth] + ' ' + _viewYear;

    var grid = _getEl('crCalGrid');
    if (!grid) return;

    var todayD = new Date();
    todayD.setHours(0,0,0,0);

    var firstDay = new Date(_viewYear, _viewMonth, 1).getDay();
    var daysInMonth = new Date(_viewYear, _viewMonth + 1, 0).getDate();

    var cells = '';
    // Day-of-week headers
    for (var h = 0; h < 7; h++) {
      cells += '<span class="cr-cal-dow">' + _DAY_NAMES[h] + '</span>';
    }
    // Leading blanks
    for (var b = 0; b < firstDay; b++) {
      cells += '<span class="cr-cal-cell cr-cal-blank"></span>';
    }
    // Days
    for (var d = 1; d <= daysInMonth; d++) {
      var dayD = new Date(_viewYear, _viewMonth, d);
      var dayEp = _dateToEpoch(dayD);
      var cls = 'cr-cal-cell';
      var unavail = (_availOldest > 0 && dayEp + 86399 < _availOldest) ||
                    (_availNewest > 0 && dayEp > _availNewest);
      if (unavail) cls += ' cr-unavail';

      // Selection highlighting
      var selStartD = _selStart ? new Date(_selStart.getFullYear(), _selStart.getMonth(), _selStart.getDate()) : null;
      var selEndD   = _selEnd   ? new Date(_selEnd.getFullYear(),   _selEnd.getMonth(),   _selEnd.getDate())   : null;
      if (selStartD && selEndD) {
        var t = dayD.getTime();
        if (t >= selStartD.getTime() && t <= selEndD.getTime()) cls += ' cr-in-range';
        if (t === selStartD.getTime()) cls += ' cr-range-start';
        if (t === selEndD.getTime())   cls += ' cr-range-end';
      } else if (selStartD && dayD.getTime() === selStartD.getTime()) {
        cls += ' cr-in-range cr-range-start cr-range-end';
      }
      if (dayD.getTime() === todayD.getTime()) cls += ' cr-today';

      var disabled = unavail ? ' data-unavail="1"' : '';
      cells += '<span class="' + cls + '" data-cr-day="' + dayEp + '"' + disabled + '>' + d + '</span>';
    }
    grid.innerHTML = cells;

    // Attach day-click listener
    grid.onclick = function(e) {
      var cell = e.target.closest('[data-cr-day]');
      if (!cell || cell.hasAttribute('data-unavail')) return;
      _onDayClick(parseInt(cell.getAttribute('data-cr-day'), 10));
    };

    // Update picking-hint label
    var hint = _getEl('crPickHint');
    if (hint) hint.textContent = _pickingStart ? 'Click a start date' : 'Click an end date';
  }

  function _onDayClick(dayEpoch) {
    var d = _epochToDate(dayEpoch);
    if (_pickingStart) {
      _selStart = new Date(d.getFullYear(), d.getMonth(), d.getDate(),
                           _selStart ? _selStart.getHours() : 0, 0, 0, 0);
      // Reset end if it's now before start
      if (_selEnd && _selEnd < _selStart) _selEnd = null;
      _pickingStart = false;
    } else {
      if (_selStart && d < new Date(_selStart.getFullYear(), _selStart.getMonth(), _selStart.getDate())) {
        // Clicked before start — swap to start mode
        _selStart = new Date(d.getFullYear(), d.getMonth(), d.getDate(), 0, 0, 0, 0);
        _selEnd   = null;
        _pickingStart = false;
      } else {
        _selEnd = new Date(d.getFullYear(), d.getMonth(), d.getDate(),
                           _selEnd ? _selEnd.getHours() : 23, 59, 59, 0);
        _pickingStart = false;
      }
    }
    _renderCalendar();
    _updateTimeFields();
  }

  // ── Time fields ──────────────────────────────────────────────────────────────
  function _updateTimeFields() {
    var startDate = _getEl('crStartDate');
    var startHour = _getEl('crStartHour');
    var startAmpm = _getEl('crStartAmpm');
    var endDate   = _getEl('crEndDate');
    var endHour   = _getEl('crEndHour');
    var endAmpm   = _getEl('crEndAmpm');
    if (!startDate) return;

    if (_selStart) {
      startDate.value = _fmtDate(_selStart);
      var sh = _selStart.getHours();
      startHour.value = String(sh % 12 || 12);
      startAmpm.value = sh < 12 ? 'AM' : 'PM';
    }
    if (_selEnd) {
      endDate.value = _fmtDate(_selEnd);
      var eh = _selEnd.getHours();
      endHour.value = String(eh % 12 || 12);
      endAmpm.value = eh < 12 ? 'AM' : 'PM';
    }
  }

  function _readTimeFields() {
    var startDate = _getEl('crStartDate');
    var startHour = parseInt(_getEl('crStartHour').value, 10);
    var startAmpm = _getEl('crStartAmpm').value;
    var endDate   = _getEl('crEndDate');
    var endHour   = parseInt(_getEl('crEndHour').value, 10);
    var endAmpm   = _getEl('crEndAmpm').value;
    if (!startDate || !endDate) return;

    var startH24 = (startAmpm === 'PM' ? (startHour === 12 ? 12 : startHour + 12) : (startHour === 12 ? 0 : startHour));
    var endH24   = (endAmpm   === 'PM' ? (endHour   === 12 ? 12 : endHour   + 12) : (endHour   === 12 ? 0 : endHour));
    var sd = new Date(startDate.value + 'T' + _pad(startH24) + ':00:00');
    var ed = new Date(endDate.value   + 'T' + _pad(endH24)   + ':59:59');
    if (!isNaN(sd.getTime())) _selStart = sd;
    if (!isNaN(ed.getTime())) _selEnd   = ed;
  }

  // ── Presets ──────────────────────────────────────────────────────────────────
  function _onPreset(name) {
    var now = new Date();
    var start, end;
    end = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59);
    if (name === 'today') {
      start = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0);
    } else if (name === 'yesterday') {
      var y = new Date(now); y.setDate(y.getDate() - 1);
      start = new Date(y.getFullYear(), y.getMonth(), y.getDate(), 0, 0, 0);
      end   = new Date(y.getFullYear(), y.getMonth(), y.getDate(), 23, 59, 59);
    } else if (name === '24h') {
      start = new Date(now.getTime() - 24 * 3600000);
      end   = new Date(now);
    } else if (name === '7d') {
      start = new Date(now.getTime() - 7 * 86400000);
      end   = new Date(now);
    } else if (name === '30d') {
      start = new Date(now.getTime() - 30 * 86400000);
      end   = new Date(now);
    } else if (name === '45d') {
      start = new Date(now.getTime() - 45 * 86400000);
      end   = new Date(now);
    }
    if (start && end) {
      _selStart = start;
      _selEnd   = end;
      _applyAndClose();
    }
  }

  // ── Apply / commit ────────────────────────────────────────────────────────────
  function apply() {
    _readTimeFields();
    if (!_selStart || !_selEnd) return;
    if (_selEnd <= _selStart) {
      var errEl = _getEl('crError');
      if (errEl) { errEl.textContent = 'End must be after start.'; return; }
      return;
    }
    _applyAndClose();
  }

  function _applyAndClose() {
    CUSTOM_RANGE_START = _dateToEpoch(_selStart);
    CUSTOM_RANGE_END   = _dateToEpoch(_selEnd);
    // Mark the Custom buttons active, deactivate presets
    [24, 168, 720, 1080].forEach(function(v) {
      var btn = document.getElementById('histRange-' + v);
      if (btn) btn.classList.remove('active');
    });
    var custBtn = document.getElementById('histRange-custom');
    if (custBtn) custBtn.classList.add('active');
    // Update minmax custom buttons for all sensors
    if (typeof SENSORS !== 'undefined') {
      SENSORS.forEach(function(s) {
        ['', 'm'].forEach(function(suffix) {
          [24, 168, 720, 1080].forEach(function(v) {
            var b = document.getElementById('mmtog-' + v + suffix + '-' + s.id);
            if (b) b.classList.remove('active');
          });
          var cb = document.getElementById('mmtog-custom' + suffix + '-' + s.id);
          if (cb) cb.classList.add('active');
        });
      });
    }
    close();
    applyHistoryRange();
  }

  // ── Wire up modal internal events (called once on DOMContentLoaded) ──────────
  function bindModalEvents() {
    var modal = _getModal();
    if (!modal) return;

    _getEl('customRangeClose')  && _getEl('customRangeClose').addEventListener('click', close);
    _getEl('customRangeCancel') && _getEl('customRangeCancel').addEventListener('click', close);
    _getEl('customRangeApply')  && _getEl('customRangeApply').addEventListener('click', apply);
    _getEl('crPrev') && _getEl('crPrev').addEventListener('click', _prevMonth);
    _getEl('crNext') && _getEl('crNext').addEventListener('click', _nextMonth);

    // Preset buttons
    modal.addEventListener('click', function(e) {
      var preset = e.target.closest('[data-cr-preset]');
      if (preset) _onPreset(preset.getAttribute('data-cr-preset'));
    });

    // Close on backdrop click
    modal.addEventListener('click', function(e) {
      if (e.target === modal) close();
    });

    // Keyboard Escape
    document.addEventListener('keydown', function(e) {
      if (e.key === 'Escape') {
        var m = _getModal();
        if (m && !m.classList.contains('hidden')) close();
      }
    });
  }

  return { open: open, close: close, apply: apply, bindModalEvents: bindModalEvents };
})();

// CSV export
function exportSensorCSV(sensorId, sensorName) {
  var statusEl = document.getElementById('export-status');
  if (statusEl) statusEl.textContent = 'Fetching ' + sensorName + '...';

  var sensor = { id: sensorId, name: sensorName };
  Promise.all([
    getGatewayExportMeta(),
    fetchSensorHistoryRows(sensor)
  ]).then(function(results) {
    var meta = results[0];
    var rows = results[1];
    var csv = buildSingleSensorCsv(meta, sensor, rows);
    triggerCsvDownload(csv, 'gateway-history-' + getExportSensorPrefix(sensor) + '-' + currentExportDateTag() + '.csv');
    if (statusEl) statusEl.textContent = sensorName + ' exported (' + rows.length + ' rows) \u2714';
  }).catch(function(e) {
    if (statusEl) statusEl.textContent = 'Export failed: ' + e.message;
  });
}

function exportAllCSV() {
  var statusEl = document.getElementById('export-status');
  if (statusEl) statusEl.textContent = 'Fetching merged history...';

  Promise.all([
    getGatewayExportMeta(),
    fetchAllSensorHistoryRowsSequentially(SENSORS, function(idx, sensor, total) {
      if (statusEl) statusEl.textContent = 'Fetching merged history (' + (idx + 1) + '/' + total + '): ' + sensor.name + '...';
    })
  ]).then(function(results) {
    var meta = results[0];
    var sensorRowsList = results[1];
    var csv = buildMergedSensorCsv(meta, SENSORS, sensorRowsList);
    var rowCount = csv.split(/\r?\n/).filter(Boolean).length - 1;
    triggerCsvDownload(csv, 'gateway-history-multi-' + currentExportDateTag() + '.csv');
    if (statusEl) statusEl.textContent = 'Merged export ready (' + rowCount + ' rows) \u2714';
  }).catch(function(e) {
    if (statusEl) statusEl.textContent = 'Export failed: ' + e.message;
  });
}


function resetHistoryVisuals() {
  App.State.resetAvgHistoryStore();
  historyPoints = 0;
  liveAvgPoints = 0;
  SENSORS.forEach(function(s) {
    ensureHistoryStore(s.id);
    updateMinMax([], s.id, true);
    updateMinMax([], s.id, false);
  });
  if (chartsReady) {
    tempAvgChart.data.datasets.forEach(function(ds) { ds.data = []; });
    humAvgChart.data.datasets.forEach(function(ds) { ds.data = []; });
    document.getElementById('tempAvgNoData').classList.remove('hidden');
    document.getElementById('humAvgNoData').classList.remove('hidden');
    tempAvgChart.update('none');
    humAvgChart.update('none');
  }
  totalPoints = 0;
  document.getElementById('pointCount').textContent = '0 data points';
  updateBadge();
}


function applyStorageStats(data) {
  var statusEl = document.getElementById('storage-status');
  if (!data || !data.ok || !data.history || !data.layout) {
    if (statusEl) statusEl.textContent = 'Storage statistics unavailable';
    return;
  }
  var h = data.history, l = data.layout, ns = data.nvs_stats || {};
  var layoutText = 'nvs ' + formatBytes(l.nvs_bytes) +
                   ' | otadata ' + formatBytes(l.otadata_bytes) +
                   ' | phy ' + formatBytes(l.phy_init_bytes) +
                   ' | ota_0 ' + formatBytes(l.ota_0_bytes) +
                   ' | ota_1 ' + formatBytes(l.ota_1_bytes) +
                   ' | history ' + formatBytes(l.history_bytes) +
                   ' | coredump ' + formatBytes(l.coredump_bytes);
  var set = function(id, text) {
    var el = document.getElementById(id);
    if (el) el.textContent = text;
  };
  var nvsUsage = 'unavailable';
  var nvsFree = 'unavailable';
  var nvsNs = 'unavailable';
  if (ns.available && ns.total_entries > 0) {
    var pct = ((ns.used_entries * 100) / ns.total_entries).toFixed(1) + '%';
    nvsUsage = String(ns.used_entries) + ' / ' + String(ns.total_entries) + ' entries (' + pct + ')';
    nvsFree = String(ns.free_entries) + ' entries';
    nvsNs = String(ns.namespace_count);
  }
  set('st-layout', layoutText);
  set('st-history-size', formatBytes(h.partition_size_bytes));
  set('st-nvs-usage', nvsUsage);
  set('st-nvs-free', nvsFree);
  set('st-nvs-ns', nvsNs);
  set('st-segments', String(h.valid_segments) + ' / ' + String(h.capacity_segments));
  set('st-segment-size', formatBytes(h.segment_size_bytes));
  set('st-retained', formatBytes(h.estimated_payload_bytes));
  set('st-free', formatBytes(h.estimated_free_payload_bytes));
  set('st-target', String(h.retention_days) + ' days (' + String(h.segment_hours) + 'h snapshots, from firmware)');
  set('st-cadence', 'Every ' + String(h.segment_hours) + ' hour(s)');
  set('st-last-persist', formatEpochLocal(h.last_persist_epoch));
  if (statusEl) {
    if (!ns.available) {
      statusEl.textContent = 'Live NVS entry statistics are unavailable on this build. Partition size and retained payload values are still shown.';
    } else if (h.namespace_initialized) {
      statusEl.textContent = 'Last persist: ' + formatEpochLocal(h.last_persist_epoch);
    } else {
      statusEl.textContent = 'Awaiting first hourly persist cycle.';
    }
  }
}

// BUG-037: in-flight guard prevents concurrent /api/storage-stats requests;
// internal retries (attempt > 0) bypass the guard since they are sequential (LESSON-OPS-050)
var _storageStatsInFlight = false;

function loadStorageStats(attempt) {
  if (isImportActive()) return Promise.resolve(null);
  var tryNum = Number(attempt || 0);
  if (_storageStatsInFlight && tryNum === 0) return Promise.resolve(null);
  _storageStatsInFlight = true;
  var statusEl = document.getElementById('storage-status');
  if (statusEl) {
    statusEl.textContent = tryNum === 0
      ? 'Refreshing storage statistics...'
      : 'Retrying storage statistics (' + (tryNum + 1) + '/3)...';
  }
  return fetch(ESP_HOST + '/api/storage-stats', {cache:'no-store'})
    .then(function(r) { if (!r.ok) throw new Error('HTTP ' + r.status); return r.json(); })
    .then(function(data) { _storageStatsInFlight = false; applyStorageStats(data); return data; })
    .catch(function(err) {
      if (tryNum < 2) {
        return new Promise(function(resolve) {
          setTimeout(resolve, 600 * (tryNum + 1));
        }).then(function() {
          return loadStorageStats(tryNum + 1);
        });
      }
      _storageStatsInFlight = false;
      if (statusEl) {
        var hint = (window.location.protocol === 'file:')
          ? ' Check fallback host and CORS headers.'
          : '';
        statusEl.textContent = 'Storage stats failed: ' + err.message + hint;
      }
      throw err;
    });
}


var importState = {
  active: false,
  authHeader: '',
  startedAt: 0,
  mode: '',        // 'multi' or 'single'
  targetSensor: '' // sensor ID for single mode
};
var pollingLiveIntervalId = null;
var pollingDeviceIntervalId = null;
var storageStatsIntervalId = null;
var statusSnapshotIntervalId = null;
var historyBootstrapTimerId = null;

function isImportActive() {
  return !!importState.active;
}

function stopPolling() {
  if (pollingLiveIntervalId) {
    clearInterval(pollingLiveIntervalId);
    pollingLiveIntervalId = null;
  }
  if (pollingDeviceIntervalId) {
    clearInterval(pollingDeviceIntervalId);
    pollingDeviceIntervalId = null;
  }
}

function stopStorageRefresh() {
  if (storageStatsIntervalId) {
    clearInterval(storageStatsIntervalId);
    storageStatsIntervalId = null;
  }
}

function stopStatusRefresh() {
  if (statusSnapshotIntervalId) {
    clearInterval(statusSnapshotIntervalId);
    statusSnapshotIntervalId = null;
  }
}

function suspendDashboardNetworkActivity(statusEl) {
  importState.active = true;
  importState.startedAt = Date.now();
  stopPolling();
  stopStorageRefresh();
  stopStatusRefresh();
  if (historyBootstrapTimerId) {
    clearTimeout(historyBootstrapTimerId);
    historyBootstrapTimerId = null;
  }
  if (evtSource) {
    // BUG-049: Null out all callbacks BEFORE calling close(). Firefox's Gecko
    // engine keeps the SSE TCP socket alive if callbacks are still attached,
    // causing browserContext.close() to hang during Playwright teardown.
    evtSource.onopen = null;
    evtSource.onerror = null;
    evtSource.onmessage = null;
    try { evtSource.close(); } catch (_e) {}
    evtSource = null;
  }
  if (statusEl) statusEl.textContent = 'Pausing dashboard refresh during import...';
}

function resumeDashboardNetworkActivity() {
  importState.active = false;
  if (TRANSPORT === 'sse') {
    try { connectSSE(); } catch (e) { logNonFatal('resume SSE after import', e); }
  } else {
    try { startPolling(); } catch (e2) { logNonFatal('resume polling after import', e2); }
  }
  // BUG-037 Fix 8: storage stats interval 120s (matching boot sequence)
  if (!storageStatsIntervalId) {
    storageStatsIntervalId = setInterval(function() {
      if (isImportActive()) return;
      loadStorageStats().catch(function(){});
    }, 120000);
  }
  // BUG-037 Fix 5: status interval only in polling mode (matching boot sequence)
  if (!statusSnapshotIntervalId && TRANSPORT !== 'sse') {
    statusSnapshotIntervalId = setInterval(function() {
      if (isImportActive()) return;
      loadStatusSnapshot().catch(function(){});
    }, 30000);
  }
}

function isTransientImportError(err) {
  var msg = (err && err.message ? err.message : String(err || '')).toLowerCase();
  if (!msg) return false;
  return /http\s+(502|503|504|520|522|524)\b/.test(msg) ||
    msg.indexOf('failed to fetch') >= 0 ||
    msg.indexOf('networkerror') >= 0 ||
    msg.indexOf('load failed') >= 0 ||
    msg.indexOf('bad gateway') >= 0 ||
    msg.indexOf('connection reset') >= 0;
}

function importFetchJsonWithRetry(url, options, label, statusEl, attempt) {
  var tryNum = Number(attempt || 1);
  return fetch(url, options)
    .then(safeJsonResponse)
    .catch(function(err) {
      if (!isTransientImportError(err) || tryNum >= 3) throw err;
      var waitMs = 500 * Math.pow(2, tryNum - 1);
      if (statusEl) {
        statusEl.textContent = 'Transient tunnel/origin error during ' + label +
          '; retrying in ' + waitMs + ' ms (attempt ' + (tryNum + 1) + '/3)...';
      }
      return delay(waitMs).then(function() {
        return importFetchJsonWithRetry(url, options, label, statusEl, tryNum + 1);
      });
    });
}

function requestManagementCredentials(actionLabel) {
  return new Promise(function(resolve, reject) {
    var modal = document.getElementById('authModal');
    var title = document.getElementById('authTitle');
    var subtitle = document.getElementById('authSubtitle');
    var userInput = document.getElementById('authUsername');
    var passInput = document.getElementById('authPassword');
    var toggleBtn = document.getElementById('authToggle');
    var errorEl = document.getElementById('authError');
    var cancelBtn = document.getElementById('authCancel');
    var submitBtn = document.getElementById('authSubmit');
    if (!modal || !title || !subtitle || !userInput || !passInput || !toggleBtn || !errorEl || !cancelBtn || !submitBtn) {
      reject(new Error('Authentication dialog is unavailable'));
      return;
    }

    title.textContent = 'Management authentication required';
    subtitle.textContent = 'Authentication required for ' + actionLabel + '. Enter the case-sensitive management credentials to continue.';
    userInput.value = '';
    passInput.value = '';
    passInput.type = 'password';
    toggleBtn.setAttribute('aria-label', 'Show password');
    toggleBtn.setAttribute('title', 'Show password');
    errorEl.textContent = '';
    modal.classList.remove('hidden');
    modal.setAttribute('aria-hidden', 'false');

    var settled = false;
    function cleanup() {
      toggleBtn.removeEventListener('click', onToggle);
      cancelBtn.removeEventListener('click', onCancel);
      submitBtn.removeEventListener('click', onSubmit);
      userInput.removeEventListener('keydown', onKeyDown);
      passInput.removeEventListener('keydown', onKeyDown);
      modal.removeEventListener('click', onBackdropClick);
      document.removeEventListener('keydown', onEscape, true);
      modal.classList.add('hidden');
      modal.setAttribute('aria-hidden', 'true');
    }
    function finish(value, isError) {
      if (settled) return;
      settled = true;
      cleanup();
      if (isError) reject(value);
      else resolve(value);
    }
    function onToggle() {
      var show = passInput.type === 'password';
      passInput.type = show ? 'text' : 'password';
      toggleBtn.setAttribute('aria-label', show ? 'Hide password' : 'Show password');
      toggleBtn.setAttribute('title', show ? 'Hide password' : 'Show password');
      passInput.focus();
      try { passInput.setSelectionRange(passInput.value.length, passInput.value.length); } catch (e) {}
    }
    function validateAndSubmit() {
      var username = String(userInput.value || '').trim();
      var password = String(passInput.value || '');
      if (!username) {
        errorEl.textContent = 'Management username is required.';
        userInput.focus();
        return;
      }
      if (!password) {
        errorEl.textContent = 'Management password is required.';
        passInput.focus();
        return;
      }
      finish({ username: username, password: password }, false);
    }
    function onCancel() { finish(null, false); }
    function onSubmit() { validateAndSubmit(); }
    function onKeyDown(ev) {
      if (ev.key === 'Enter') {
        ev.preventDefault();
        validateAndSubmit();
      }
    }
    function onEscape(ev) {
      if (ev.key === 'Escape') {
        ev.preventDefault();
        finish(null, false);
      }
    }
    function onBackdropClick(ev) {
      if (ev.target === modal) finish(null, false);
    }

    toggleBtn.addEventListener('click', onToggle);
    cancelBtn.addEventListener('click', onCancel);
    submitBtn.addEventListener('click', onSubmit);
    userInput.addEventListener('keydown', onKeyDown);
    passInput.addEventListener('keydown', onKeyDown);
    modal.addEventListener('click', onBackdropClick);
    document.addEventListener('keydown', onEscape, true);
    window.setTimeout(function() { userInput.focus(); userInput.select(); }, 0);
  });
}

function postManagementAction(path, busyText, actionLabel) {
  var statusEl = document.getElementById('mgmt-status');
  return requestManagementCredentials(actionLabel)
    .then(function(creds) {
      if (!creds) {
        if (statusEl) statusEl.textContent = 'Action cancelled';
        throw new Error('Authentication cancelled');
      }
      if (statusEl) statusEl.textContent = busyText;
      return fetch(ESP_HOST + path, {
          method: 'POST',
          cache: 'no-store',
          headers: {
            'Authorization': 'Basic ' + btoa(creds.username + ':' + creds.password)
          }
        });
    })
    .then(function(r) {
      return r.json().catch(function(){ return {ok:false, message:'Invalid JSON response'}; }).then(function(data) {
        if (!r.ok || !data.ok) {
          var msg = data.message || ('HTTP ' + r.status);
          throw new Error(msg);
        }
        return data;
      });
    })
    .then(function(data) {
      if (statusEl) statusEl.textContent = data.message || 'Done';
      return data;
    })
    .catch(function(err) {
      if (statusEl) statusEl.textContent = err.message === 'Authentication cancelled' ? 'Action cancelled' : 'Action failed: ' + err.message;
      throw err;
    });
}

function rebootESP() {
  if (!confirm('Reboot this ESP32 gateway now? The dashboard connection will drop briefly.')) return;
  postManagementAction('/api/reboot', 'Scheduling reboot...', 'gateway reboot').catch(function(){});
}

function deleteHistoryData() {
  if (!confirm('Delete persisted sensor history from the dedicated history partition and clear RAM history on the ESP?')) return;
  postManagementAction('/api/delete-data', 'Deleting history...', 'history deletion').then(function() {
    resetHistoryVisuals();
    loadStorageStats().catch(function(){});
  }).catch(function(){});
}

// ═══════════════════════════════════════════════════════════════════
// Import v1 — CSV import into NVS history
// ═══════════════════════════════════════════════════════════════════

function importHistoryData() {
  var statusEl = document.getElementById('mgmt-status');
  var fileInput = document.getElementById('importFileInput');
  if (!fileInput) return;
  if (isImportActive()) {
    if (statusEl) statusEl.textContent = 'Import already in progress...';
    return;
  }

  // Reset file input so re-selecting the same file triggers change.
  fileInput.value = '';
  fileInput.onchange = function() {
    var file = fileInput.files && fileInput.files[0];
    if (!file) return;
    if (statusEl) statusEl.textContent = 'Reading file...';
    var reader = new FileReader();
    reader.onload = function(e) {
      processImportFile(e.target.result, file.name);
    };
    reader.onerror = function() {
      if (statusEl) statusEl.textContent = 'Failed to read file';
    };
    reader.readAsText(file);
  };
  fileInput.click();
}

function processImportFile(csvText, fileName) {
  var statusEl = document.getElementById('mgmt-status');
  if (statusEl) statusEl.textContent = 'Parsing CSV...';

  var result = parseImportCsv(csvText, fileName);
  if (result.error) {
    if (statusEl) statusEl.textContent = 'Import error: ' + result.error;
    return;
  }

  if (result.points.length === 0) {
    if (statusEl) statusEl.textContent = 'No valid data points found in file';
    return;
  }

  // Build segments from points.
  var batches = buildImportSegments(result.points);

  // Determine import mode: single-sensor or multi-sensor.
  var sensorNames = {};
  result.points.forEach(function(p) { sensorNames[p.sensor] = true; });
  var sensorIds = Object.keys(sensorNames);
  var isSingle = (sensorIds.length === 1);
  var targetSensorId = isSingle ? sensorIds[0] : '';

  var estimate = estimateImportDuration(batches.length);
  var msg = 'Import ' + result.points.length + ' data points (' + batches.length +
    ' batches) for sensor(s): ' + sensorIds.join(', ') +
    '.\nApproximate time: ~' + estimate.label + ' (' + estimate.mode + ').\n\n';

  if (isSingle) {
    msg += 'This will replace history for ' + targetSensorId + ' only.\n' +
      'Data from other sensors will be preserved.\nContinue?';
  } else {
    msg += 'This will REPLACE ALL existing history. Continue?';
  }

  if (!confirm(msg)) {
    if (statusEl) statusEl.textContent = 'Import cancelled';
    return;
  }

  executeImport(batches, statusEl, isSingle ? 'single' : 'multi', targetSensorId);
}

function parseImportCsv(csvText, fileName) {
  var lines = csvText.split(/\r?\n/).filter(function(l) { return l.trim() !== ''; });
  if (lines.length < 2) return { error: 'File too short (need header + data)', points: [] };

  var header = lines[0].split(',').map(function(h) { return h.trim().toLowerCase(); });
  var tsIdx = header.indexOf('timestamp');
  if (tsIdx < 0) return { error: 'Missing "timestamp" column in header', points: [] };

  // Detect format: single-sensor or merged.
  var detection = detectImportColumns(header, fileName);
  if (detection.error) {
    return { error: detection.error, points: [] };
  }
  var sensorColumns = detection.results;
  if (sensorColumns.length === 0) {
    return { error: 'Could not find temp_c / humidity_pct columns in header', points: [] };
  }

  var points = [];
  var rejected = 0;
  var now = Math.floor(Date.now() / 1000);

  for (var i = 1; i < lines.length; i++) {
    var cols = lines[i].split(',');
    var epochRaw = parseInt(cols[tsIdx], 10);
    if (!isFinite(epochRaw) || epochRaw < 946684800) { rejected++; continue; }  // Before year 2000
    if (epochRaw > now + 86400) { rejected++; continue; }  // More than 1 day in future

    for (var s = 0; s < sensorColumns.length; s++) {
      var sc = sensorColumns[s];
      var tempStr = (sc.tempIdx >= 0 && sc.tempIdx < cols.length) ? cols[sc.tempIdx].trim() : '';
      var humStr = (sc.humIdx >= 0 && sc.humIdx < cols.length) ? cols[sc.humIdx].trim() : '';

      var tempVal = parseFloat(tempStr);
      var humVal = parseFloat(humStr);
      var hasTemp = isFinite(tempVal) && tempVal > -50 && tempVal < 80;
      var hasHum = isFinite(humVal) && humVal >= 0 && humVal <= 100;

      if (hasTemp) {
        points.push({ sensor: sc.sensorId, series: 'temp', epoch: epochRaw, value: tempVal });
      }
      if (hasHum) {
        points.push({ sensor: sc.sensorId, series: 'hum', epoch: epochRaw, value: humVal });
      }
    }
  }

  // Sort by epoch.
  points.sort(function(a, b) { return a.epoch - b.epoch; });

  return { points: points, rejected: rejected, error: null };
}

function estimateImportDuration(batchCount) {
  var isCloudflarePath = (!IS_FILE_MODE && window.location.protocol === 'https:') || /^https:/i.test(ESP_HOST);
  var secondsPerBatch = isCloudflarePath ? 1.9 : 1.25;
  var baseSeconds = isCloudflarePath ? 8 : 6;
  var totalSeconds = Math.max(8, Math.round(baseSeconds + (batchCount * secondsPerBatch)));
  return {
    seconds: totalSeconds,
    label: formatDurationLabel(totalSeconds),
    mode: isCloudflarePath ? 'Cloudflare / remote access estimate' : 'LAN / direct access estimate'
  };
}

function formatDurationLabel(totalSeconds) {
  totalSeconds = Math.max(0, Math.round(totalSeconds || 0));
  var minutes = Math.floor(totalSeconds / 60);
  var seconds = totalSeconds % 60;
  if (minutes <= 0) return seconds + ' sec';
  if (seconds === 0) return minutes + ' min';
  return minutes + ' min ' + seconds + ' sec';
}

function detectSensorIdFromImportFileName(fileName) {
  var knownSensors = (typeof SENSORS !== 'undefined') ? SENSORS : [];
  var normalized = sensorSlug((fileName || '').replace(/\.[^.]+$/, ''));
  if (!normalized) return '';

  var candidates = [];
  for (var si = 0; si < knownSensors.length; si++) {
    var sensor = knownSensors[si];
    var checks = [
      sensorSlug(sensor && sensor.id),
      sensorSlug(sensor && sensor.name),
      sensorSlug(getExportSensorPrefix(sensor))
    ].filter(Boolean);

    for (var ci = 0; ci < checks.length; ci++) {
      var token = checks[ci];
      if (normalized.indexOf(token) >= 0) {
        candidates.push(sensor.id);
        break;
      }
    }
  }

  if (candidates.length === 1) return candidates[0];
  return '';
}

function detectImportColumns(header, fileName) {
  var results = [];

  // Check for single-sensor legacy format: temp_c, humidity_pct directly.
  var tempIdx = header.indexOf('temp_c');
  var humIdx = header.indexOf('humidity_pct');
  if (tempIdx >= 0 || humIdx >= 0) {
    // Check if there are prefixed columns too (merged format or new single-sensor export).
    var hasPrefixed = false;
    for (var h = 0; h < header.length; h++) {
      if (header[h].match(/^.+_temp_c$/)) { hasPrefixed = true; break; }
    }

    if (!hasPrefixed) {
      var detectedSensorId = detectSensorIdFromImportFileName(fileName);
      if (!detectedSensorId) {
        return {
          results: [],
          error: 'Legacy single-sensor CSV detected (temp_c/humidity_pct), but the sensor could not be identified from the file name. Re-export from the updated dashboard or rename the file to include the sensor name (for example: outside, office, first_floor).'
        };
      }
      results.push({ sensorId: detectedSensorId, tempIdx: tempIdx, humIdx: humIdx });
      return { results: results, error: null };
    }
  }

  // Check for prefixed format: {prefix}_temp_c, {prefix}_humidity_pct
  var knownSensors = (typeof SENSORS !== 'undefined') ? SENSORS : [];
  for (var si = 0; si < knownSensors.length; si++) {
    var prefix = getExportSensorPrefix(knownSensors[si]).toLowerCase();
    var ti = header.indexOf(prefix + '_temp_c');
    var hi = header.indexOf(prefix + '_humidity_pct');
    if (ti >= 0 || hi >= 0) {
      results.push({ sensorId: knownSensors[si].id, tempIdx: ti, humIdx: hi });
    }
  }

  return { results: results, error: null };
}

function buildImportSegments(points) {
  // Group points into 1-hour segments aligned to hour boundaries.
  // Each segment contains up to 4 points per sensor per series.
  // Each segment is split into URL-path-safe batches (max ~250 chars of data per batch)
  // to fit within the ESP32 URL buffer limit (512 bytes with /api/import/d/ prefix).
  var segmentMap = {};

  points.forEach(function(p) {
    var hourEpoch = p.epoch - (p.epoch % 3600);
    if (!segmentMap[hourEpoch]) segmentMap[hourEpoch] = [];
    segmentMap[hourEpoch].push(p);
  });

  var hourKeys = Object.keys(segmentMap).map(Number).sort(function(a, b) { return a - b; });
  var batches = [];

  hourKeys.forEach(function(hourEpoch) {
    var segPoints = segmentMap[hourEpoch];
    var counts = {};
    var lines = [];
    segPoints.forEach(function(p) {
      var countKey = p.sensor + ',' + p.series;
      if (!counts[countKey]) counts[countKey] = 0;
      if (counts[countKey] >= 4) return;
      counts[countKey]++;
      lines.push(p.sensor + ',' + p.series + ',' + p.epoch + ',' + p.value.toFixed(2));
    });

    // Split lines into batches that fit in ~440 chars (leaves room for URL path + params).
    var currentBatch = [];
    var currentLen = 0;
    for (var i = 0; i < lines.length; i++) {
      var lineLen = lines[i].length + 1;  // +1 for semicolon separator
      if (currentLen + lineLen > 250 && currentBatch.length > 0) {
        batches.push({ data: currentBatch.join(';'), pointCount: currentBatch.length, isLast: false });
        currentBatch = [];
        currentLen = 0;
      }
      currentBatch.push(lines[i]);
      currentLen += lineLen;
    }
    if (currentBatch.length > 0) {
      // Mark the last batch of this hourly segment with write flag.
      batches.push({ data: currentBatch.join(';'), pointCount: currentBatch.length, isLast: true });
    }
  });

  return batches;
}

function safeJsonResponse(r) {
  var status = r.status;
  return r.text().then(function(body) {
    if (!r.ok) throw new Error('HTTP ' + status + ': ' + body.substring(0, 100));
    try { return JSON.parse(body); }
    catch(e) { throw new Error('HTTP ' + status + ' non-JSON: ' + body.substring(0, 100)); }
  });
}

function executeImport(batches, statusEl, importMode, targetSensorId) {
  if (isImportActive()) {
    if (statusEl) statusEl.textContent = 'Import already in progress...';
    return;
  }

  var isSingle = (importMode === 'single');
  if (statusEl) statusEl.textContent = 'Authenticating...';

  requestManagementCredentials('history import').then(function(creds) {
    if (!creds) {
      if (statusEl) statusEl.textContent = 'Import cancelled';
      return;
    }

    var authHeader = 'Basic ' + btoa(creds.username + ':' + creds.password);
    var pacing = {
      pauseBeforeBeginMs: 250,
      dataBatchGapMs: 120,
      writeBatchGapMs: 320,
      postFinishReloadDelayMs: 500
    };

    importState.authHeader = authHeader;
    importState.mode = importMode || 'multi';
    importState.targetSensor = targetSensorId || '';
    suspendDashboardNetworkActivity(statusEl);

    var beginUrl = ESP_HOST + '/api/import/begin';
    if (isSingle && targetSensorId) {
      beginUrl = ESP_HOST + '/api/import/begin/single/' + encodeURIComponent(targetSensorId);
    }
    var beginStatusText = isSingle
      ? 'Preparing single-sensor import for ' + targetSensorId + '...'
      : 'Clearing history for import...';

    return delay(pacing.pauseBeforeBeginMs)
      .then(function() {
        if (statusEl) statusEl.textContent = beginStatusText;
        return importFetchJsonWithRetry(
          beginUrl,
          {
            method: 'POST',
            cache: 'no-store',
            headers: { 'Authorization': authHeader }
          },
          'begin',
          statusEl
        );
      })
      .then(function(data) {
        if (!data.ok) throw new Error(data.message || 'Begin failed');

        var totalAccepted = 0;
        var totalRejected = 0;

        var estimate = estimateImportDuration(batches.length);
        return batches.reduce(function(chain, batch, idx) {
          return chain.then(function() {
            if (statusEl) {
              var remainingBatches = Math.max(0, batches.length - (idx + 1));
              var remainingSeconds = Math.round((estimate.seconds / Math.max(1, batches.length)) * remainingBatches);
              statusEl.textContent = 'Importing batch ' + (idx + 1) + ' / ' + batches.length +
                ' (' + batch.pointCount + ' points, ~' + formatDurationLabel(remainingSeconds) + ' left)...';
            }

            var pathPrefix = batch.isLast ? '/api/import/w/' : '/api/import/d/';
            return importFetchJsonWithRetry(
              ESP_HOST + pathPrefix + batch.data,
              {
                method: 'POST',
                cache: 'no-store',
                headers: { 'Authorization': authHeader }
              },
              'batch ' + (idx + 1) + ' of ' + batches.length,
              statusEl
            )
            .then(function(result) {
              if (!result.ok) throw new Error(result.message || 'Data write failed at batch ' + (idx + 1));
              totalAccepted += (result.accepted || 0);
              totalRejected += (result.rejected || 0);
              return delay(batch.isLast ? pacing.writeBatchGapMs : pacing.dataBatchGapMs);
            });
          });
        }, Promise.resolve()).then(function() {
          return { accepted: totalAccepted, rejected: totalRejected };
        });
      })
      .then(function(totals) {
        if (statusEl) statusEl.textContent = 'Finalizing import...';
        return importFetchJsonWithRetry(
          ESP_HOST + '/api/import/finish',
          {
            method: 'POST',
            cache: 'no-store',
            headers: { 'Authorization': authHeader }
          },
          'finish',
          statusEl
        )
        .then(function(data) {
          if (!data.ok) throw new Error(data.message || 'Finish failed');
          var msg = 'Import complete: ' + data.segments_written + ' segments, ' +
            totals.accepted + ' accepted';
          if (totals.rejected > 0) msg += ', ' + totals.rejected + ' rejected';
          if (statusEl) statusEl.textContent = msg + ' \u2714';
          resetHistoryVisuals();
          return delay(pacing.postFinishReloadDelayMs).then(function() {
            resumeDashboardNetworkActivity();
            loadHistory();
            loadStorageStats().catch(function(){});
          });
        });
      })
      .catch(function(err) {
        if (statusEl) statusEl.textContent = 'Import failed: ' + err.message;
        throw err;
      })
      .then(function(result) {
        if (isImportActive()) resumeDashboardNetworkActivity();
        importState.authHeader = '';
        importState.mode = '';
        importState.targetSensor = '';
        return result;
      }, function(err) {
        if (isImportActive()) resumeDashboardNetworkActivity();
        importState.authHeader = '';
        importState.mode = '';
        importState.targetSensor = '';
        throw err;
      });
  }).catch(function(err) {
    if (err && err.message === 'Authentication cancelled') {
      if (statusEl) statusEl.textContent = 'Import cancelled';
      return;
    }
    if (statusEl && err && err.message && statusEl.textContent.indexOf('Import failed:') !== 0) {
      statusEl.textContent = 'Import failed: ' + err.message;
    }
  });
}

function updateBadge() {
  var badge = document.getElementById('histBadge'), total = historyPoints + liveAvgPoints;
  if (total > 0) {
    var p = []; if (historyPoints > 0) p.push(historyPoints + ' loaded'); if (liveAvgPoints > 0) p.push(liveAvgPoints + ' live');
    badge.textContent = total + ' pts (' + p.join(' + ') + ')'; badge.classList.remove('empty');
  }
}

// ╔════════════════════════════════════════════════════════════════╗
// ║  Build sensor cards                                            ║
// ╚════════════════════════════════════════════════════════════════╝


function onSensorColorPicked(sensorId, color) {
  if (!color) return;
  // persist
  try { localStorage.setItem('sensor_color_' + sensorId, color); } catch(e) {}
  // update sensor meta
  for (var i=0;i<SENSORS.length;i++) {
    if (SENSORS[i].id === sensorId) { SENSORS[i].color = color; break; }
  }
  // update value colors
  for (var j=0;j<SENSORS.length;j++) {
    var s=SENSORS[j];
    if (s.id !== sensorId) continue;
    var ids=[s.tempId,s.humId,s.tempAvgId,s.humAvgId,s.battId,s.rssiId];
    for (var k=0;k<ids.length;k++) {
      var v=document.getElementById('val-' + esc(ids[k]));
      if (v) v.style.color = color;
    }
  }
  // update chart datasets
  function recolor(chart) {
    if (!chart || !chart.data || !chart.data.datasets) return;
    chart.data.datasets.forEach(function(ds) {
      // match by label
      for (var i=0;i<SENSORS.length;i++) {
        if (SENSORS[i].id===sensorId && ds.label===SENSORS[i].name) {
          ds.borderColor = color;
          ds.backgroundColor = color + '18';
          ds.pointBackgroundColor = color;
          ds.pointBorderColor = color;
          ds.pointHoverBackgroundColor = color;
          ds.pointHoverBorderColor = color;
        }
      }
    });
    try { chart.update('none'); } catch(e) { logNonFatal('sensor color chart update', e); }
  }
  recolor(tempChart); recolor(humChart); recolor(tempAvgChart); recolor(humAvgChart);
}

// ── Card renderer registry (v7.5.2.1) ────────────────────────────
// Dispatches card rendering by device category from the manifest.

var CARD_RENDERERS = {
  environmental: function(device, manifest) {
    return buildEnvironmentalCard(device, manifest);
  },
  network: function(device, manifest) {
    return buildNetworkCard(device, manifest);
  },
  _default: function(device, manifest) {
    // Graceful fallback for unknown categories — simple key/value card
    var html = '<div class="sensor-card">' +
      '<div class="sensor-card-header">' + (device.name || device.id || 'Unknown') + '</div>' +
      '<div class="sensor-readings">';
    var keys = Object.keys(device);
    for (var i = 0; i < keys.length; i++) {
      var k = keys[i];
      if (k === 'name' || k === 'id' || k === 'color') continue;
      html += '<div class="sensor-reading">' +
        '<div class="reading-label">' + k + '</div>' +
        '<div class="reading-value">' + String(device[k]) + '</div>' +
        '</div>';
    }
    html += '</div></div>';
    return html;
  }
};

function buildEnvironmentalCard(s, manifest) {
  var avgLabel = '15m avg';
  minmaxPeriod[s.id] = 24;  // default 24h
  return (
    '<div class="sensor-card">' +
      '<div class="sensor-card-header">' +
        '<input class="sensor-color-picker" id="picker-' + s.id + '" type="color" value="' + s.color + '" title="Click to change sensor color" data-sensor-color="' + s.id + '">' +
        s.name +
        '<img class="sensor-photo-thumb" src="https://buythermopro.com/cdn/shop/files/TP-357-3436-1.jpg?v=1742547257" alt="TP357" loading="lazy">' +
      '</div>' +
      '<div class="sensor-readings">' +
        '<div class="sensor-reading"><div class="reading-label">Temperature</div><div class="reading-value waiting" id="val-' + esc(s.tempId) + '" style="color:' + s.color + '">&mdash;</div><div class="reading-time" id="time-' + s.id + '">last: &mdash;</div></div>' +
        '<div class="sensor-reading"><div class="reading-label">' + avgLabel + ' Temp</div><div class="reading-value waiting" id="val-' + esc(s.tempAvgId) + '" style="color:' + s.color + '">&mdash;</div></div>' +
        '<div class="sensor-reading"><div class="reading-label">Humidity</div><div class="reading-value waiting" id="val-' + esc(s.humId) + '" style="color:' + s.color + '">&mdash;</div></div>' +
        '<div class="sensor-reading"><div class="reading-label">' + avgLabel + ' Hum</div><div class="reading-value waiting" id="val-' + esc(s.humAvgId) + '" style="color:' + s.color + '">&mdash;</div></div>' +
      '</div>' +
      '<div class="sensor-env-grid">' +
        '<div class="sensor-env-item">' +
          '<div class="dewpoint-label">Dew Point</div>' +
          '<div class="dewpoint-value waiting" id="dewpoint-' + s.id + '">&mdash;</div>' +
        '</div>' +
        '<div class="sensor-env-item">' +
          '<div class="comfort-label">Comfort</div>' +
          '<div class="comfort-chip waiting" id="comfort-' + s.id + '">&mdash;</div>' +
        '</div>' +
      '</div>' +
      // Min/max with 24h/7d/30d/45d toggle
      '<div class="sensor-minmax">' +
        '<div class="minmax-col">' +
          '<div class="minmax-col-title">Min' +
            '<span class="minmax-toggle">' +
              '<button class="active" id="mmtog-24-' + s.id + '" data-minmax-sensor="' + s.id + '" data-minmax-hours="24">24h</button>' +
              '<button id="mmtog-168-' + s.id + '" data-minmax-sensor="' + s.id + '" data-minmax-hours="168">7d</button>' +
              '<button id="mmtog-720-' + s.id + '" data-minmax-sensor="' + s.id + '" data-minmax-hours="720">30d</button>' +
              '<button id="mmtog-1080-' + s.id + '" data-minmax-sensor="' + s.id + '" data-minmax-hours="1080">45d</button>' +
              '<button id="mmtog-custom-' + s.id + '" data-minmax-sensor="' + s.id + '" data-minmax-hours="custom">Custom</button>' +
            '</span>' +
          '</div>' +
          '<div class="minmax-line" id="minmax-temp-min-' + s.id + '"><span class="waiting" style="font-size:.78rem">temp: calculating...</span></div>' +
          '<div class="minmax-line" id="minmax-hum-min-' + s.id + '"><span class="waiting" style="font-size:.78rem">hum: calculating...</span></div>' +
        '</div>' +
        '<div class="minmax-col">' +
          '<div class="minmax-col-title">Max' +
            '<span class="minmax-toggle">' +
              '<button class="active" id="mmtog-24m-' + s.id + '" data-minmax-sensor="' + s.id + '" data-minmax-hours="24">24h</button>' +
              '<button id="mmtog-168m-' + s.id + '" data-minmax-sensor="' + s.id + '" data-minmax-hours="168">7d</button>' +
              '<button id="mmtog-720m-' + s.id + '" data-minmax-sensor="' + s.id + '" data-minmax-hours="720">30d</button>' +
              '<button id="mmtog-1080m-' + s.id + '" data-minmax-sensor="' + s.id + '" data-minmax-hours="1080">45d</button>' +
              '<button id="mmtog-customm-' + s.id + '" data-minmax-sensor="' + s.id + '" data-minmax-hours="custom">Custom</button>' +
            '</span>' +
          '</div>' +
          '<div class="minmax-line" id="minmax-temp-max-' + s.id + '"><span class="waiting" style="font-size:.78rem">temp: calculating...</span></div>' +
          '<div class="minmax-line" id="minmax-hum-max-' + s.id + '"><span class="waiting" style="font-size:.78rem">hum: calculating...</span></div>' +
        '</div>' +
      '</div>' +
      // Battery row
      '<div class="sensor-batt-row">' +
        '<div class="batt-label">Battery</div>' +
        '<div class="batt-bar-bg"><div class="batt-bar-fill" id="batt-fill-' + s.id + '" style="width:0%"></div></div>' +
        '<div class="batt-pct waiting" id="val-' + esc(s.battId) + '">&mdash;%</div>' +
      '</div>' +
      // RSSI signal strength row
      '<div class="sensor-rssi-row">' +
        '<div class="rssi-label">Signal</div>' +
        '<div class="rssi-bars" id="rssi-bars-' + s.id + '">' +
          '<div class="rssi-bar b1"></div><div class="rssi-bar b2"></div><div class="rssi-bar b3"></div><div class="rssi-bar b4"></div>' +
        '</div>' +
        '<div class="rssi-dbm waiting" id="rssi-dbm-' + s.id + '">&mdash; dBm</div>' +
      '</div>' +
    '</div>'
  );
}

function buildNetworkCard(s, manifest) {
  // Find source.target from manifest for display.
  // Use _deviceId (original manifest ID) when available — s.id may be namespaced in aggregator mode.
  var lookupId = s._deviceId || s.id;
  var target = '\u2014';
  if (manifest && manifest.sensors) {
    var entry = manifest.sensors.find(function(ms) { return ms.id === lookupId; });
    if (entry && entry.source && entry.source.target) target = entry.source.target;
  }
  return (
    '<div class="sensor-card network-card" data-device-id="' + s.id + '">' +
      '<div class="sensor-card-header">' +
        '<input class="sensor-color-picker" id="picker-' + s.id + '" type="color" value="' + (s.color || '#4FC3F7') + '" data-sensor-color="' + s.id + '">' +
        s.name +
      '</div>' +
      '<div class="sensor-readings">' +
        '<div class="sensor-reading">' +
          '<div class="reading-label">Latency</div>' +
          '<div class="reading-value waiting" id="net-ping-' + s.id + '" style="color:' + (s.color || '#4FC3F7') + '">&mdash;</div>' +
        '</div>' +
        '<div class="sensor-reading">' +
          '<div class="reading-label">Success Rate</div>' +
          '<div class="reading-value waiting" id="net-success-' + s.id + '">&mdash;</div>' +
        '</div>' +
        '<div class="sensor-reading">' +
          '<div class="reading-label">Target</div>' +
          '<div class="reading-value" id="net-target-' + s.id + '">' + target + '</div>' +
        '</div>' +
        '<div class="sensor-reading">' +
          '<div class="reading-label">Last Seen</div>' +
          '<div class="reading-time" id="net-lastseen-' + s.id + '">last: &mdash;</div>' +
        '</div>' +
      '</div>' +
    '</div>'
  );
}

function buildDeviceCards() {
  var grid = document.getElementById('sensorGrid');
  grid.innerHTML = '';
  SENSORS.forEach(function(sensor) {
    var manifestEntry = null;
    if (window._manifest && window._manifest.sensors) {
      manifestEntry = window._manifest.sensors.find(function(s) { return s.id === sensor.id; });
    }
    var category = (manifestEntry && manifestEntry.category) || 'environmental';
    var renderer = CARD_RENDERERS[category] || CARD_RENDERERS._default;
    grid.innerHTML += renderer(sensor, window._manifest);
  });
  // Build export buttons dynamically
  buildExportButtons();
}

function buildSensorCards() {
  // Compatibility alias — delegates to the registry-dispatched buildDeviceCards()
  buildDeviceCards();
}

function buildExportButtons() {
  var bar = document.getElementById('exportBar');
  if (!bar) return;
  bar.innerHTML = '<span class="export-status" id="export-status">Export retained history as CSV. Sensor buttons create single-sensor files; Export All creates one merged file with gateway host/IP metadata.</span>';
  SENSORS.forEach(function(s) {
    bar.innerHTML += '<button class="export-btn" data-export-sensor="' + s.id + '" data-export-name="' + escAttr(s.name) + '">' + s.name + '</button>';
  });
  bar.innerHTML += '<button class="export-btn" data-export-all="1" style="background:rgba(52,211,153,.1);color:#34d399;border-color:rgba(52,211,153,.3)">Export All</button>';
}

// ╔════════════════════════════════════════════════════════════════╗
// ║  Min/max calculation - browser-side, 24h / 7d / 30d / 45d           ║
// ╚════════════════════════════════════════════════════════════════╝

function updateMinMax(pts, sensorId, isTemp) {
  var minEl = document.getElementById('minmax-' + (isTemp ? 'temp' : 'hum') + '-min-' + sensorId);
  var maxEl = document.getElementById('minmax-' + (isTemp ? 'temp' : 'hum') + '-max-' + sensorId);
  if (!minEl || !maxEl) return;
  var hours, startMs, endMs;
  if (CUSTOM_RANGE_START > 0 && CUSTOM_RANGE_END > 0) {
    startMs = CUSTOM_RANGE_START * 1000;
    endMs   = CUSTOM_RANGE_END * 1000;
    hours = Math.round((endMs - startMs) / 3600000);
  } else {
    hours = minmaxPeriod[sensorId] || 24;
    endMs = Date.now();
    startMs = endMs - hours * 3600000;
  }
  var minVal = Infinity, maxVal = -Infinity, minT, maxT, count = 0;
  for (var i = 0; i < pts.length; i++) {
    var pt = pts[i];
    var t = pt.x && pt.x.getTime();
    if (pt.y !== null && !isNaN(pt.y) && t >= startMs && t <= endMs) {
      count++;
      if (pt.y < minVal) { minVal = pt.y; minT = pt.x; }
      if (pt.y > maxVal) { maxVal = pt.y; maxT = pt.x; }
    }
  }
  if (count === 0) {
    var label = isTemp ? 'temp' : 'hum';
    minEl.innerHTML = '<span class="waiting" style="font-size:.78rem">' + label + ': no data</span>';
    maxEl.innerHTML = '<span class="waiting" style="font-size:.78rem">' + label + ': no data</span>';
    return;
  }
  var fmtT = function(d) {
    var mm = d.getMonth()+1, dd = d.getDate();
    var hh = d.getHours().toString().padStart(2,'0'), mi = d.getMinutes().toString().padStart(2,'0');
    return hours > 24 ? (mm + '/' + dd + ' ' + hh + ':' + mi) : (hh + ':' + mi);
  };
  if (isTemp) {
    minEl.innerHTML = '<span class="lo">&darr; ' + minVal.toFixed(1) + ' &deg;C / ' + cToF(minVal).toFixed(1) + ' &deg;F</span> <span class="ts">(' + fmtT(minT) + ')</span>';
    maxEl.innerHTML = '<span class="hi">&uarr; ' + maxVal.toFixed(1) + ' &deg;C / ' + cToF(maxVal).toFixed(1) + ' &deg;F</span> <span class="ts">(' + fmtT(maxT) + ')</span>';
  } else {
    minEl.innerHTML = '<span class="lo">&darr; ' + Math.round(minVal) + ' %</span> <span class="ts">(' + fmtT(minT) + ')</span>';
    maxEl.innerHTML = '<span class="hi">&uarr; ' + Math.round(maxVal) + ' %</span> <span class="ts">(' + fmtT(maxT) + ')</span>';
  }
}

// ╔════════════════════════════════════════════════════════════════╗
// ║  CHART CONFIGURATION                                          ║
// ║  Freezing line helper                                          ║
// ║  line in all Chart.js render paths, so an explicit overlay     ║
// ║  plugin now draws a blue 0°C guide across both temperature     ║
// ║  charts after datasets are rendered.                           ║
// ╚════════════════════════════════════════════════════════════════╝

var FREEZING_LINE_PLUGIN = {
  id:'freezingLine',
  afterDraw:function(chart) {
    if (!chart || !chart.scales || !chart.scales.y || !chart.chartArea) return;
    var y = chart.scales.y.getPixelForValue(0);
    if (!isFinite(y) || y < chart.chartArea.top || y > chart.chartArea.bottom) return;
    var ctx = chart.ctx;
    ctx.save();
    ctx.strokeStyle = '#60a5fa';
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(chart.chartArea.left, y);
    ctx.lineTo(chart.chartArea.right, y);
    ctx.stroke();
    ctx.restore();
  }
};

var AX_TEXT = '#ffffff', AX_GRID = '#3a3a3a', AX_TITLE = '#cccccc';

function isLightTheme() {
  return document.documentElement.classList.contains('light');
}

function setAxisColorsForTheme() {
  if (isLightTheme()) {
    AX_TEXT = '#111827';     // near-black
    AX_GRID = '#d1d5db';     // light gray
    AX_TITLE = '#374151';    // dark gray
  } else {
    AX_TEXT = '#ffffff';
    AX_GRID = '#3a3a3a';
    AX_TITLE = '#cccccc';
  }
}

function recolorChartForTheme(chart, mode) {
  if (!chart || !chart.options) return;
  var opts = chart.options;
  if (opts.plugins && opts.plugins.legend && opts.plugins.legend.labels) {
    opts.plugins.legend.labels.color = AX_TEXT;
  }
  if (!opts.scales) return;

  if (opts.scales.x) {
    if (opts.scales.x.ticks) opts.scales.x.ticks.color = AX_TEXT;
    if (opts.scales.x.title) opts.scales.x.title.color = AX_TITLE;
    if (opts.scales.x.grid && typeof opts.scales.x.grid.color !== 'function') opts.scales.x.grid.color = AX_GRID;
  }

  if (mode === 'telemetry') {
    if (opts.scales.y && opts.scales.y.grid && typeof opts.scales.y.grid.color !== 'function') opts.scales.y.grid.color = AX_GRID;
    chart.update();
    return;
  }

  if (opts.scales.y) {
    if (opts.scales.y.ticks) opts.scales.y.ticks.color = AX_TEXT;
    if (opts.scales.y.title) opts.scales.y.title.color = AX_TITLE;
    if (opts.scales.y.grid && typeof opts.scales.y.grid.color !== 'function') opts.scales.y.grid.color = AX_GRID;
  }
  if (opts.scales.y1) {
    if (opts.scales.y1.ticks) opts.scales.y1.ticks.color = AX_TEXT;
    if (opts.scales.y1.title) opts.scales.y1.title.color = AX_TITLE;
    if (opts.scales.y1.grid && typeof opts.scales.y1.grid.color !== 'function') opts.scales.y1.grid.color = AX_GRID;
  }
  chart.update();
}

function refreshChartsAfterVisualChange(reason) {
  [tempChart, humChart, tempAvgChart, humAvgChart, telemetryChart].forEach(function(chart) {
    if (!chart) return;
    try { chart.resize(); } catch(e) { logNonFatal((reason || 'visual-change') + ' resize', e); }
    try { chart.render(); } catch(e) { logNonFatal((reason || 'visual-change') + ' render', e); }
    try { chart.update('none'); } catch(e) { logNonFatal((reason || 'visual-change') + ' update', e); }
  });
}

function updateChartsTheme() {
  try { setAxisColorsForTheme(); } catch(e) { logNonFatal('set axis colors for theme', e); }
  try {
    recolorChartForTheme(tempChart, 'standard');
    recolorChartForTheme(humChart, 'standard');
    recolorChartForTheme(tempAvgChart, 'standard');
    recolorChartForTheme(humAvgChart, 'standard');
    recolorChartForTheme(telemetryChart, 'telemetry');
  } catch(e) { logNonFatal('update charts theme', e); }
}

setAxisColorsForTheme();
var TEMP_MIN_C = -15, TEMP_MAX_C = 40;
var TEMP_MIN_F = cToF(TEMP_MIN_C), TEMP_MAX_F = cToF(TEMP_MAX_C);

function tempChartOpts() {
  return {
    responsive:true, maintainAspectRatio:false, animation:false,
    interaction:{mode:'index',intersect:false},
    plugins:{
      legend:{display:SENSORS.length>1, labels:{color:AX_TEXT,font:{family:'JetBrains Mono',size:11},boxWidth:14,boxHeight:2,padding:16}},
      tooltip:{backgroundColor:'#333',titleColor:'#fff',bodyColor:'#ccc',borderColor:'#555',borderWidth:1,
        titleFont:{family:'JetBrains Mono',size:11},bodyFont:{family:'JetBrains Mono',size:11},
        callbacks:{label:function(c){var v=c.parsed.y; if(v===null)return ' '+c.dataset.label+': gap'; return ' '+c.dataset.label+': '+v.toFixed(1)+' \u00B0C / '+cToF(v).toFixed(1)+' \u00B0F';}}}
    },
    scales:{
      x:(function(){ var fmt = getHistoryTimeFormat(HISTORY_RANGE_HOURS); return {type:'time',time:{displayFormats:fmt.displayFormats,tooltipFormat:fmt.tooltipFormat},
        title:{display:true,text:fmt.axisTitle,color:AX_TITLE,font:{family:'JetBrains Mono',size:11}},
        ticks:{color:AX_TEXT,font:{family:'JetBrains Mono',size:11},maxRotation:0,autoSkipPadding:30},
        grid:{color:AX_GRID,lineWidth:0.5}}; })(),
      y:{min:TEMP_MIN_C,max:TEMP_MAX_C,position:'left',
        title:{display:true,text:'\u00B0C',color:AX_TITLE,font:{family:'JetBrains Mono',size:11}},
        ticks:{color:AX_TEXT,font:{family:'JetBrains Mono',size:11},stepSize:5},
        // Blue freezing line at 0 C
        grid:{color:function(ctx){return ctx.tick&&ctx.tick.value===0?'#60a5fa':AX_GRID;},
              lineWidth:function(ctx){return ctx.tick&&ctx.tick.value===0?2:0.5;}}},
      y1:{min:TEMP_MIN_F,max:TEMP_MAX_F,position:'right',
        title:{display:true,text:'\u00B0F',color:AX_TITLE,font:{family:'JetBrains Mono',size:11}},
        ticks:{color:AX_TEXT,font:{family:'JetBrains Mono',size:11},stepSize:9,callback:function(v){return Math.round(v);}},
        grid:{drawOnChartArea:false}}
    }
  };
}

function humChartOpts() {
  return {
    responsive:true, maintainAspectRatio:false, animation:false,
    interaction:{mode:'index',intersect:false},
    plugins:{
      legend:{display:SENSORS.length>1, labels:{color:AX_TEXT,font:{family:'JetBrains Mono',size:11},boxWidth:14,boxHeight:2,padding:16}},
      tooltip:{backgroundColor:'#333',titleColor:'#fff',bodyColor:'#ccc',borderColor:'#555',borderWidth:1,
        titleFont:{family:'JetBrains Mono',size:11},bodyFont:{family:'JetBrains Mono',size:11},
        callbacks:{label:function(c){var v=c.parsed.y; if(v===null)return ' '+c.dataset.label+': gap'; return ' '+c.dataset.label+': '+Math.round(v)+' %';}}}
    },
    scales:{
      x:(function(){ var fmt = getHistoryTimeFormat(HISTORY_RANGE_HOURS); return {type:'time',time:{displayFormats:fmt.displayFormats,tooltipFormat:fmt.tooltipFormat},
        title:{display:true,text:fmt.axisTitle,color:AX_TITLE,font:{family:'JetBrains Mono',size:11}},
        ticks:{color:AX_TEXT,font:{family:'JetBrains Mono',size:11},maxRotation:0,autoSkipPadding:30},
        grid:{color:AX_GRID,lineWidth:0.5}}; })(),
      y:{min:0,max:100,title:{display:true,text:'%',color:AX_TITLE,font:{family:'JetBrains Mono',size:11}},
        ticks:{color:AX_TEXT,font:{family:'JetBrains Mono',size:11},stepSize:10},
        grid:{color:AX_GRID,lineWidth:0.5}}
    }
  };
}

function telemetryChartOpts() {
  return {
    responsive:true, maintainAspectRatio:false, animation:false,
    interaction:{mode:'index',intersect:false},
    plugins:{
      legend:{display:true,labels:{color:AX_TEXT,font:{family:'JetBrains Mono',size:10},boxWidth:14,boxHeight:2,padding:14}},
      tooltip:{backgroundColor:'#333',titleColor:'#fff',bodyColor:'#ccc',borderColor:'#555',borderWidth:1, titleFont:{family:'JetBrains Mono',size:10},bodyFont:{family:'JetBrains Mono',size:10},
        callbacks:{label:function(c){if(c.datasetIndex===0)return ' Heap: '+Math.round(c.parsed.y).toLocaleString()+' B'; return ' WiFi: '+c.parsed.y.toFixed(0)+' dBm';}}}
    },
    scales:{
      x:{type:'time',time:{displayFormats:{second:'HH:mm:ss',minute:'HH:mm',hour:'HH:mm'},tooltipFormat:'HH:mm:ss'},
        title:{display:true,text:'Uptime',color:AX_TITLE,font:{family:'JetBrains Mono',size:10}},
        ticks:{color:AX_TEXT,font:{family:'JetBrains Mono',size:10},maxRotation:0,autoSkipPadding:30},
        grid:{color:AX_GRID,lineWidth:0.5}},
      y:{position:'left',title:{display:true,text:'Free Heap (B)',color:'#34d399',font:{family:'JetBrains Mono',size:10}},
        ticks:{color:'#34d399',font:{family:'JetBrains Mono',size:10},callback:function(v){return (v/1024).toFixed(0)+'K';}},
        grid:{color:AX_GRID,lineWidth:0.5}},
      y1:{position:'right',title:{display:true,text:'WiFi (dBm)',color:'#a78bfa',font:{family:'JetBrains Mono',size:10}},
        ticks:{color:'#a78bfa',font:{family:'JetBrains Mono',size:10}},grid:{drawOnChartArea:false}}
    }
  };
}

var tempChart, humChart, tempAvgChart, humAvgChart, telemetryChart;

function initCharts() {
  if (typeof Chart === 'undefined') { showError('Chart.js not loaded'); return; }
  var mkDS = function(type, avg) {
    return SENSORS.filter(function(s) { return (s.chartIdx !== undefined && s.chartIdx >= 0); }).map(function(s) {
      return {label:s.name, data:[], borderColor:s.color, backgroundColor:s.color+'18',
        fill:true, tension:0.3, pointRadius:1.5, pointHoverRadius:4,
        pointBackgroundColor:s.color, pointBorderColor:s.color,
        pointHoverBackgroundColor:s.color, pointHoverBorderColor:s.color,
        borderWidth:avg?2.5:2, yAxisID:'y', spanGaps:false};
    });
  };
  tempChart    = new Chart(document.getElementById('tempChart'),    {type:'line',data:{datasets:mkDS('temp',false)},options:tempChartOpts(),plugins:[FREEZING_LINE_PLUGIN]});
  humChart     = new Chart(document.getElementById('humChart'),     {type:'line',data:{datasets:mkDS('hum',false)},options:humChartOpts()});
  tempAvgChart = new Chart(document.getElementById('tempAvgChart'), {type:'line',data:{datasets:mkDS('temp',true)},options:tempChartOpts(),plugins:[FREEZING_LINE_PLUGIN]});
  humAvgChart  = new Chart(document.getElementById('humAvgChart'),  {type:'line',data:{datasets:mkDS('hum',true)},options:humChartOpts()});

  telemetryChart = new Chart(document.getElementById('telemetryChart'), {
    type:'line', data:{datasets:[
      {label:'Free Heap',data:[],borderColor:'#34d399',backgroundColor:'#34d39918',fill:true,tension:0.3,pointRadius:3,borderWidth:2,yAxisID:'y'},
      {label:'WiFi Signal',data:[],borderColor:'#a78bfa',backgroundColor:'#a78bfa18',fill:true,tension:0.3,pointRadius:3,borderWidth:2,yAxisID:'y1'}
    ]}, options:telemetryChartOpts()
  });
  App.State.setChartsReady(true);
  try { App.Features.emit('onChartsReady'); } catch(e) { logNonFatal('charts-ready hook emit', e); }
  dlog('All charts initialized (' + SENSORS.length + ' sensors)', 'ok');
}

// ╔════════════════════════════════════════════════════════════════╗
// ║  BATTERY + TELEMETRY + DEVICE INFO UPDATES                     ║
// ╚════════════════════════════════════════════════════════════════╝

function updateBattery(s, raw) {
  var pct = parseVal(raw); if (pct === null) return;
  var el = document.getElementById('val-' + esc(s.battId));
  var fill = document.getElementById('batt-fill-' + s.id);
  if (el) { el.textContent = Math.round(pct) + '%'; el.classList.remove('waiting'); el.className = 'batt-pct ' + (pct<=30?'low':pct<=55?'mid':''); }
  if (fill) { fill.style.width = Math.max(0, Math.min(100, pct)) + '%'; fill.style.background = pct<=30?'#f87171':pct<=55?'#fbbf24':'#34d399'; }
}

function updateDeviceInfo(eid, d) {
  var info = DEVICE_INFO_MAP[eid]; if (!info) return false;
  var el = document.getElementById(info.el); if (!el) return false;
  el.textContent = d.state !== undefined ? d.state : (d.value !== undefined ? String(d.value) : '');
  el.classList.remove('loading'); return true;
}

var lastTelemetry = {heap:null, wifi:null};
function updateTelemetry(eid, d) {
  var v = parseVal(d.value !== undefined ? d.value : d.state); if (v === null) return false;
  if (eid === TELEMETRY_IDS.heap) {
    lastTelemetry.heap = v;
    var h = document.getElementById('di-heap');
    if(h){h.textContent=(v/1024).toFixed(1)+' KB';h.classList.remove('loading');}
    pushTelemetry(); return true;
  }
  if (eid === TELEMETRY_IDS.wifi) { lastTelemetry.wifi = v; pushTelemetry(); return true; }
  if (eid === TELEMETRY_IDS.uptime) {
    var u = document.getElementById('di-uptime');
    if(u){u.textContent = formatUptimeSeconds(v); u.classList.remove('loading');}
    return true;
  }
  return false;
}

function pushTelemetry() {
  if (!chartsReady) return; var now = new Date();
  if (lastTelemetry.heap!==null) { telemetryChart.data.datasets[0].data.push({x:now,y:lastTelemetry.heap}); if(telemetryChart.data.datasets[0].data.length>720) telemetryChart.data.datasets[0].data.shift(); }
  if (lastTelemetry.wifi!==null) { telemetryChart.data.datasets[1].data.push({x:now,y:lastTelemetry.wifi}); if(telemetryChart.data.datasets[1].data.length>720) telemetryChart.data.datasets[1].data.shift(); }
  document.getElementById('telemetryNoData').classList.add('hidden');
  telemetryChart.update('none');
}

// ╔════════════════════════════════════════════════════════════════╗
// ║  HISTORY LOADER — sequential per-sensor fetch + min/max        ║
// ╚════════════════════════════════════════════════════════════════╝

function parseCompactHistory(text) {
  var points = [], lines = text.split('\n');
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i].trim(); if (!line) continue;
    var comma = line.indexOf(','); if (comma < 0) continue;
    var epoch = parseInt(line.substring(0, comma)), valStr = line.substring(comma + 1);
    var value = (valStr === '' || valStr === 'NaN') ? null : parseFloat(valStr);
    if (!isNaN(epoch) && epoch > 0) points.push({x: new Date(epoch * 1000), y: value});
  }
  return points;
}

// BUG-043-cont Fix 3: in-flight guard prevents concurrent history loads (F5 refresh / button
// click during boot). Without this, two loadHistory() chains run simultaneously and double
// the NVS blocking time, compounding the crash risk.
var _historyInFlight = false;

function loadHistory() {
  if (isImportActive()) return Promise.resolve(false);
  if (_historyInFlight) { dlog('History load already in flight — skipping', 'warn'); return Promise.resolve(false); } // BUG-043-cont Fix 3
  _historyInFlight = true; // BUG-043-cont Fix 3
  var badge = document.getElementById('histBadge');
  badge.textContent = 'loading...'; badge.classList.add('empty');
  var loaded = 0, sensorIdx = 0;

  App.State.resetAvgHistoryStore();
  historyPoints = 0;
  liveAvgPoints = 0;
  SENSORS.forEach(function(s) { ensureHistoryStore(s.id); });

  function loadNext() {
    if (sensorIdx >= SENSORS.length) {
      historyPoints = loaded;
      totalPoints = historyPoints + liveAvgPoints;
      document.getElementById('pointCount').textContent = totalPoints + ' data points';
      if (loaded > 0) {
        applyHistoryRange();
        updateBadge();
        dlog('History: ' + loaded + ' total points loaded', 'ok');
      } else {
        badge.textContent = 'no history yet';
        badge.classList.add('empty');
        applyHistoryRange();
      }
      _historyInFlight = false; // BUG-043-cont Fix 3: release guard on completion
      return;
    }

    var s = SENSORS[sensorIdx];

    // Skip non-environmental sensors — they don't have temp/hum history
    if (s.category && s.category !== 'environmental') {
      sensorIdx++;
      setTimeout(loadNext, 0);
      return;
    }

    fetchDeviceHistory(s, window._manifest)
    .then(function(series) {
      var tempPts = [], humPts = [];
      series.forEach(function(item) {
        var pts = parseCompactHistory(item.raw);
        if (item.key === 'temp') tempPts = pts;
        else if (item.key === 'hum') humPts = pts;
      });

      ensureHistoryStore(s.id).temp = tempPts;
      loaded += tempPts.length;
      if (tempPts.length > 0) {
        var last = tempPts[tempPts.length - 1];
        if (last.y !== null) {
          var el = document.getElementById('val-' + esc(s.tempAvgId));
          if (el) {
            el.textContent = formatMetricValue('temperature', last.y, getMetricDef('temp'));
            el.classList.remove('waiting');
          }
        }
      }
      updateMinMax(tempPts, s.id, true);

      ensureHistoryStore(s.id).hum = humPts;
      loaded += humPts.length;
      if (humPts.length > 0) {
        var lastH = humPts[humPts.length - 1], elH = document.getElementById('val-' + esc(s.humAvgId));
        if (elH) {
          elH.textContent = (lastH.y !== null) ? formatMetricValue('humidity', lastH.y, getMetricDef('hum')) : 'No data';
          elH.classList.remove('waiting');
        }
      }
      updateMinMax(humPts, s.id, false);

      dlog(s.name + ' history loaded', 'ok');
      sensorIdx++;
      // BUG-043-cont (PR2) Fix C: 500ms inter-sensor pause lets the ESP32-C3 service BLE/WiFi
      // between NVS scan loops instead of chaining the next history request immediately.
      setTimeout(loadNext, 500);
    })
    .catch(function(e) {
      dlog(s.name + ' history failed: ' + e.message, 'err');
      sensorIdx++;
      setTimeout(loadNext, 500); // BUG-043-cont (PR2): maintain inter-sensor gap on failure too
    });
  }

  loadNext();
}

// ╔════════════════════════════════════════════════════════════════╗
// ║  SSE EVENT HANDLER                                             ║
// ╚════════════════════════════════════════════════════════════════╝

function handleState(d) {
  var eid = d.id || '', now = new Date(), nowEpoch = Math.floor(now.getTime() / 1000);
  try { App.Features.emit('onStateUpdate', d); } catch(e) { logNonFatal('state-update hook emit', e); }
  if (updateDeviceInfo(eid, d)) return;
  if (updateTelemetry(eid, d)) return;

  SENSORS.forEach(function(s, idx) {
    if (eid === s.tempId) {
      var v = parseVal(d.state); if (v === null) return;
      sensorCurrentTemp[s.id] = v;
      var el = document.getElementById('val-' + esc(s.tempId));
      if (el) { el.textContent = d.state; el.classList.remove('waiting'); }
      updateDewPoint(s.id);
      updateComfortLevel(s.id);
      if (chartsReady && s.chartIdx >= 0) { tempChart.data.datasets[s.chartIdx].data.push({x:now,y:v}); if(tempChart.data.datasets[s.chartIdx].data.length>MAX_POINTS) tempChart.data.datasets[s.chartIdx].data.shift(); document.getElementById('tempNoData').classList.add('hidden'); tempChart.update('none'); totalPoints++; }
    }
    if (eid === s.humId) {
      var v = parseVal(d.state); if (v === null) return;
      sensorCurrentHum[s.id] = v;
      var el = document.getElementById('val-' + esc(s.humId));
      if (el) { el.textContent = formatMetricValue('humidity', v, getMetricDef('hum')); el.classList.remove('waiting'); }
      updateDewPoint(s.id);
      updateComfortLevel(s.id);
      if (chartsReady && s.chartIdx >= 0) { humChart.data.datasets[s.chartIdx].data.push({x:now,y:v}); if(humChart.data.datasets[s.chartIdx].data.length>MAX_POINTS) humChart.data.datasets[s.chartIdx].data.shift(); document.getElementById('humNoData').classList.add('hidden'); humChart.update('none'); totalPoints++; }
    }
    if (eid === s.lastSeenId) {
      var t = d.state || '', te = document.getElementById('time-' + s.id);
      if (te) { te.textContent = t ? ('last: ' + t) : 'last: \u2014'; te.classList.remove('stale-warn','stale-crit'); }
      sensorLastSeenEpoch[s.id] = Date.now();
    }
    if (eid === s.battId) updateBattery(s, d.state);
    // RSSI handling
    if (eid === s.rssiId) {
      var rv = parseVal(d.value !== undefined ? d.value : d.state);
      if (rv !== null) updateRSSI(s.id, rv);
    }

    if (eid === s.tempAvgId) {
      var v = parseVal(d.value !== undefined ? d.value : d.state), isGap = (v === null);
      var el = document.getElementById('val-' + esc(s.tempAvgId));
      if (el) { el.textContent = isGap ? 'No data' : (d.state || formatMetricValue('temperature', v, getMetricDef('temp'))); el.classList.remove('waiting'); }
      if (TRANSPORT === 'polling') { var prev = pollAvgLast[s.tempAvgId], sig = isGap ? 'NA' : v; if (prev && prev.val === sig && (nowEpoch - prev.epoch) < 600) return; pollAvgLast[s.tempAvgId] = {val:sig, epoch:nowEpoch}; }
      else { if (lastAvgEpoch[s.tempAvgId] && nowEpoch <= lastAvgEpoch[s.tempAvgId] + 30) return; lastAvgEpoch[s.tempAvgId] = nowEpoch; }
      var store = ensureHistoryStore(s.id);
      store.temp.push({x: now, y: isGap ? null : v});
      if (store.temp.length > (MAX_HISTORY_RANGE_HOURS * 4 + 32)) store.temp.shift();
      liveAvgPoints++;
      totalPoints = historyPoints + liveAvgPoints;
      updateBadge();
      updateMinMax(store.temp, s.id, true);
      if (chartsReady) applyHistoryRange();
    }
    if (eid === s.humAvgId) {
      var v = parseVal(d.value !== undefined ? d.value : d.state), isGap = (v === null);
      var el = document.getElementById('val-' + esc(s.humAvgId));
      if (el) { el.textContent = isGap ? 'No data' : formatMetricValue('humidity', v, getMetricDef('hum')); el.classList.remove('waiting'); }
      if (TRANSPORT === 'polling') { var prev = pollAvgLast[s.humAvgId], sig = isGap ? 'NA' : v; if (prev && prev.val === sig && (nowEpoch - prev.epoch) < 600) return; pollAvgLast[s.humAvgId] = {val:sig, epoch:nowEpoch}; }
      else { if (lastAvgEpoch[s.humAvgId] && nowEpoch <= lastAvgEpoch[s.humAvgId] + 30) return; lastAvgEpoch[s.humAvgId] = nowEpoch; }
      var store = ensureHistoryStore(s.id);
      store.hum.push({x: now, y: isGap ? null : v});
      if (store.hum.length > (MAX_HISTORY_RANGE_HOURS * 4 + 32)) store.hum.shift();
      liveAvgPoints++;
      totalPoints = historyPoints + liveAvgPoints;
      updateBadge();
      updateMinMax(store.hum, s.id, false);
      if (chartsReady) applyHistoryRange();
    }
  });
  document.getElementById('pointCount').textContent = totalPoints + ' data points';
  document.getElementById('lastUpdate').textContent = 'last: ' + now.toLocaleTimeString([], {hour12:false});
}

// ── SSE connection ──────────────────────────────────────────────
var evtSource = null;
function connectSSE() {
  if (evtSource) evtSource.close();
  dlog('SSE connecting to ' + (ESP_HOST || '(same-origin)') + '/events');
  evtSource = new EventSource(ESP_HOST + '/events');
  evtSource.addEventListener('state', function(e) { try { handleState(JSON.parse(e.data)); } catch(err) { dlog('SSE parse: ' + err.message, 'err'); } });
  // BUG-037: ping handler must NOT call loadStatusSnapshot() — SSE already delivers state
  // via 'state' events; firing /api/status on every ping caused 10-20+ redundant requests/min
  evtSource.addEventListener('ping', function() { document.getElementById('statusDot').classList.add('connected'); document.getElementById('statusText').textContent = 'connected (SSE)'; });
  // BUG-037: onopen must NOT call loadStatusSnapshot() — boot sequence already calls it once;
  // firing again here created duplicate concurrent /api/status requests at connect time
  evtSource.onopen = function() { document.getElementById('statusDot').classList.add('connected'); document.getElementById('statusText').textContent = 'connected (SSE)'; dlog('SSE connected', 'ok'); };
  evtSource.onerror = function() { document.getElementById('statusDot').classList.remove('connected'); document.getElementById('statusText').textContent = 'reconnecting...'; };
}

// ── REST polling (Cloudflare mode) ──────────────────────────────
var pollFailCount = 0;
function pollEntity(path) {
  if (isImportActive()) return Promise.resolve(false);
  return fetch(ESP_HOST + path, {cache:'no-store'})
    .then(function(r) { if (!r.ok) throw new Error('HTTP '+r.status); return r.json(); })
    .then(function(d) { handleState(d); return true; })
    .catch(function() { return false; });
}
function delay(ms) { return new Promise(function(resolve) { setTimeout(resolve, ms); }); }
function pollAll(paths, batchSize, gapMs) {
  batchSize = batchSize || 4; gapMs = gapMs || 120;
  var results = [], chain = Promise.resolve();
  for (var i = 0; i < paths.length; i += batchSize) {
    (function(batch) { chain = chain.then(function() { return Promise.all(batch.map(pollEntity)).then(function(r) { results = results.concat(r); return delay(gapMs); }); }); })(paths.slice(i, i + batchSize));
  }
  return chain.then(function() {
    var ok = results.filter(Boolean).length;
    if (ok > 0) { pollFailCount = 0; document.getElementById('statusDot').classList.add('connected'); document.getElementById('statusText').textContent = 'connected (polling)'; }
    else { pollFailCount++; if (pollFailCount >= 3) { document.getElementById('statusDot').classList.remove('connected'); document.getElementById('statusText').textContent = 'connection lost'; } }
  });
}
function startPolling() {
  stopPolling();
  dlog('Starting REST polling (batched)...');
  var livePaths = POLL_SHARED.slice();
  SENSORS.forEach(function(s) { livePaths = livePaths.concat(s.restPaths); });
  // BUG-043-cont (PR2) Fix B: Fully sequential startup poll (batch=1, 200ms gap).
  // Promise.all(batch.map()) with batchSize=1 resolves to a single request — no concurrency.
  // The 200ms inter-request gap gives the ESP32-C3 more recovery time than the previous
  // batch-2 + 120ms scheme, and ensures history/storage-stats timers fire into a quiet bus.
  setTimeout(function() {
    pollAll(POLL_DEVICE.concat(livePaths), 1, 200).then(function() {
      dlog('Initial poll done', 'ok');
      loadStatusSnapshot().catch(function(){});
    });
  }, 1000);
  // BUG-037 Fix 6: removed loadStatusSnapshot() from 15s interval — the 30s
  // statusSnapshotIntervalId (created in boot sequence) handles status refresh
  pollingLiveIntervalId = setInterval(function() {
    if (isImportActive()) return;
    pollAll(livePaths).catch(function(){});
  }, 15000);
  pollingDeviceIntervalId = setInterval(function() {
    if (isImportActive()) return;
    pollAll(POLL_DEVICE);
  }, 300000);
}

// ── Network card live data polling (/api/v2/live) ─────────────────
// Network devices are not in the SSE state event stream — they use
// periodic /api/v2/live polling to update card values. (v7.5.4.2)

function updateNetworkCards(liveData) {
  // liveData = response from /api/v2/live → { timestamp, devices: { wan_ping: { ping_ms, success_pct, last_seen } } }
  if (!liveData || !liveData.devices) return;
  SENSORS.forEach(function(s) {
    if (s.category !== 'network') return;
    var devData = liveData.devices[s.id];
    if (!devData) return;

    var pingEl = document.getElementById('net-ping-' + s.id);
    if (pingEl && devData.ping_ms !== undefined && devData.ping_ms !== null) {
      pingEl.textContent = METRIC_FORMATTERS.ping_latency(devData.ping_ms);
      pingEl.classList.remove('waiting');
    }

    var successEl = document.getElementById('net-success-' + s.id);
    if (successEl && devData.success_pct !== undefined && devData.success_pct !== null) {
      successEl.textContent = METRIC_FORMATTERS.success_rate(devData.success_pct);
      successEl.classList.remove('waiting');
    }

    var seenEl = document.getElementById('net-lastseen-' + s.id);
    if (seenEl && devData.last_seen) {
      var d = new Date(devData.last_seen * 1000);
      seenEl.textContent = 'last: ' + d.toLocaleTimeString([], {hour12:false});
    }
  });
}

var _v2LiveInFlight = false;
function pollV2Live() {
  if (_v2LiveInFlight) return;
  _v2LiveInFlight = true;
  fetch(ESP_HOST + '/api/v2/live', {cache:'no-store'})
    .then(function(r) { if (!r.ok) throw new Error('HTTP ' + r.status); return r.json(); })
    .then(function(data) { updateNetworkCards(data); })
    .catch(function(err) { dlog('v2/live poll: ' + err.message, 'err'); })
    .then(function() { _v2LiveInFlight = false; });
}

// ╔════════════════════════════════════════════════════════════════╗
// ║  INITIALIZATION                                                ║
// ╚════════════════════════════════════════════════════════════════╝


// ── App module exports (stable references for future refactors) ──
try {
  // Config/state
  App.State.getSensors = App.State.getSensors || function() { return SENSORS; };

  // Utilities
  App.Util.sensorSlug = sensorSlug;
  App.Util.formatUtcForExport = formatUtcForExport;
  App.Util.formatEpochLocal = formatEpochLocal;

  // Data + manifest
  App.API.loadSensorManifest = loadSensorManifest;
  App.API.loadHistory = loadHistory;
  App.API.loadStorageStats = loadStorageStats;
  App.API.fetchDeviceHistory = fetchDeviceHistory;

  // Transport
  App.Transport.connectSSE = connectSSE;
  App.Transport.startPolling = startPolling;

  // Rendering + charts
  App.Render.buildSensorCards = buildSensorCards;
  App.Render.buildDeviceCards = buildDeviceCards;
  App.Render.buildEnvironmentalCard = buildEnvironmentalCard;
  App.Render.buildNetworkCard = buildNetworkCard;
  App.Render.bindEvents = bindEvents;
  App.Render.handleState = handleState;
  App.Charts.initCharts = initCharts;
  App.Charts.updateChartsTheme = updateChartsTheme;
} catch(e) { logNonFatal('App module export wiring', e); }

/*
Example plugin (v7.3+):
App.Features.register({
  onBoot: function() {},               // called before App.Boot.start()
  onManifest: function(sensors) {},     // called after sensors.json (or fallback)
  onStateUpdate: function(stateEvt) {}, // called for every SSE/poll state event
  onThemeChange: function(theme) {},    // 'light' or 'dark'
  onRangeChange: function(hours) {},    // history range hours
  onChartsReady: function() {}          // charts constructed
});
*/

// ── Aggregator mode detection and UI (v7.5.5.3) ──────────────────
// detectAggregatorMode() probes /api/aggregator/gateways at runtime.
// On satellites the endpoint returns 404 (fast fail). On aggregators it
// returns the gateway list. The same dashboard.html is served by both.

async function detectAggregatorMode() {
  try {
    var r = await fetch(ESP_HOST + '/api/aggregator/gateways', {cache: 'no-store'});
    if (r.ok) {
      var data = await r.json();
      if (data && Array.isArray(data.gateways) && data.gateways.length > 0) {
        DASHBOARD_MODE = 'aggregator';
        window._aggregatorGateways = data.gateways;
        return true;
      }
    }
  } catch(e) { /* not aggregator — satellite mode */ }
  return false;
}

function renderGatewaySelector(gateways) {
  var container = document.getElementById('sensorGrid');
  var selectorHtml = '<div id="gwSelector" class="gw-selector">' +
    '<button class="gw-tab active" data-gw="all">All Gateways</button>';
  gateways.forEach(function(gw) {
    var statusClass = gw.reachable ? 'gw-online' : 'gw-offline';
    // escAttr for attribute value; escHtml for button text content
    selectorHtml += '<button class="gw-tab ' + statusClass + '" data-gw="' + escAttr(gw.id) + '">' +
      escHtml(gw.name) + '</button>';
  });
  // Settings tab — always last
  selectorHtml += '<button class="gw-tab gw-settings-tab" data-gw="settings">&#9881; Settings</button>';
  selectorHtml += '</div>';
  container.insertAdjacentHTML('beforebegin', selectorHtml);
  // Use programmatic event binding (App.State.get/set pattern, not inline onclick)
  document.querySelectorAll('.gw-tab').forEach(function(tab) {
    tab.addEventListener('click', function() {
      document.querySelectorAll('.gw-tab').forEach(function(t) { t.classList.remove('active'); });
      tab.classList.add('active');
      var gwId = tab.getAttribute('data-gw');
      if (gwId === 'all') {
        _currentGwId = null; _currentGwSensors = null;
        renderAllGatewaysSummary(window._aggregatorGateways);
      } else if (gwId === 'settings') {
        _currentGwId = null; _currentGwSensors = null;
        renderSettingsPanel(window._aggregatorGateways);
      } else {
        renderGatewayDevices(gwId);
      }
    });
  });
}

function renderAllGatewaysSummary(gateways) {
  var grid = document.getElementById('sensorGrid');
  grid.innerHTML = '';
  if (!gateways || gateways.length === 0) {
    grid.innerHTML = '<div class="gw-summary-card">No satellites configured.</div>';
    return;
  }
  var html = '';
  gateways.forEach(function(gw) {
    var statusClass = gw.reachable ? 'gw-status-online' : 'gw-status-offline';
    var statusText = gw.reachable ? '&#127002; Online' : '&#128308; Unreachable';
    var lastSeenStr = gw.last_seen ? new Date(gw.last_seen * 1000).toLocaleString() : '\u2014';
    var fwVersion = gw.firmware_version || '\u2014';
    var deviceCount = (gw.sensor_count !== undefined) ? gw.sensor_count :
      (gw.device_count !== undefined ? gw.device_count : '\u2014');
    html += '<div class="gw-summary-card' + (gw.reachable ? '' : ' gw-stale') + '">';
    html += '<div class="gw-summary-header"><span class="' + statusClass + '">' + statusText + '</span>' +
      ' <strong>' + escHtml(gw.name) + '</strong>' +
      ' <span class="gw-summary-id">(' + escHtml(gw.id) + ')</span></div>';
    html += '<div class="gw-summary-details">';
    html += '<div><span class="gw-detail-label">Last seen:</span> ' + escHtml(lastSeenStr) + '</div>';
    html += '<div><span class="gw-detail-label">Firmware:</span> ' + escHtml(fwVersion) + '</div>';
    html += '<div><span class="gw-detail-label">Devices:</span> ' + escHtml(String(deviceCount)) + '</div>';
    if (!gw.reachable) html += '<div class="gw-stale-overlay">Unreachable</div>';
    html += '</div>';
    html += '</div>';
  });
  grid.innerHTML = html;
}

function renderGatewayDevices(gwId) {
  var gw = null;
  if (window._aggregatorGateways) {
    for (var i = 0; i < window._aggregatorGateways.length; i++) {
      if (window._aggregatorGateways[i].id === gwId) { gw = window._aggregatorGateways[i]; break; }
    }
  }
  var grid = document.getElementById('sensorGrid');
  grid.innerHTML = '';
  if (!gw) {
    grid.innerHTML = '<div class="gw-summary-card gw-stale"><div>Gateway not found: ' + escHtml(gwId) + '</div></div>';
    return;
  }
  if (!gw.reachable) {
    var lastSeenStr = gw.last_seen ? new Date(gw.last_seen * 1000).toLocaleString() : 'unknown';
    grid.innerHTML = '<div class="gw-summary-card gw-stale">' +
      '<div class="gw-status-offline">&#128308; Unreachable</div>' +
      '<div>Last seen: ' + escHtml(lastSeenStr) + '</div></div>';
    return;
  }
  // Parse manifest if available from /api/aggregator/gateways response
  var manifest = null;
  if (gw.manifest) {
    try { manifest = (typeof gw.manifest === 'string') ? JSON.parse(gw.manifest) : gw.manifest; } catch(e) {}
  }
  if (!manifest || !manifest.sensors || manifest.sensors.length === 0) {
    grid.innerHTML = '<div class="gw-summary-card"><div>No device data available for <strong>' +
      escHtml(gw.name) + '</strong>. Manifest not yet cached.</div></div>';
    return;
  }
  // Build sensor configs with namespaced IDs and render cards using existing CARD_RENDERERS
  var gwSensors = [];
  manifest.sensors.forEach(function(s, idx) {
    var cat = s.category || 'environmental';
    var nsId = gwId + '.' + s.id; // namespaced: avoids cross-gateway ID collisions
    // cfg.id is namespaced (for DOM element IDs); _deviceId is the original id (for API calls)
    var meta = { id: nsId, name: s.name, category: cat };
    var cfg;
    if (cat === 'environmental') {
      cfg = makeSensorConfig(meta, idx);
    } else {
      cfg = makeNetworkSensorConfig(meta, idx); // network, system, and unknown categories
    }
    // Store originals for proxy history routing and API lookups
    cfg._gwId = gwId;
    cfg._deviceId = s.id;
    cfg._namespacedId = nsId; // kept for clarity
    gwSensors.push({ cfg: cfg, entry: s });
  });
  var html = '';
  gwSensors.forEach(function(item) {
    var s = item.cfg;
    var cat = s.category || 'environmental';
    var renderer = CARD_RENDERERS[cat] || CARD_RENDERERS._default;
    html += renderer(s, manifest);
  });
  grid.innerHTML = html;
  // Track current per-gateway view for pollAggregatorLive refresh (fix 2b)
  _currentGwId = gwId;
  _currentGwSensors = gwSensors;
  // Populate live values from /api/aggregator/live (in-flight guarded separately)
  _populateGatewayDeviceLive(gwId, gwSensors);
}

// Current per-gateway view state (for pollAggregatorLive to refresh)
var _currentGwId = null;
var _currentGwSensors = null;

var _aggDeviceLiveInFlight = false;
function _populateGatewayDeviceLive(gwId, gwSensors) {
  if (_aggDeviceLiveInFlight) return;
  _aggDeviceLiveInFlight = true;
  fetch(ESP_HOST + '/api/aggregator/live', {cache: 'no-store'})
    .then(function(r) { if (!r.ok) throw new Error('HTTP ' + r.status); return r.json(); })
    .then(function(data) {
      if (!data || !data.gateways || !data.gateways[gwId]) return;
      var gwLive = data.gateways[gwId];
      if (!gwLive.reachable || !gwLive.live || !gwLive.live.devices) return;
      var devices = gwLive.live.devices;
      gwSensors.forEach(function(item) {
        var s = item.cfg;
        var deviceId = s._deviceId;
        var devData = devices[deviceId];
        if (!devData) return;
        var cat = s.category || 'environmental';
        if (cat === 'environmental') {
          // Temperature (raw float → format with unit)
          if (devData.temp !== undefined && devData.temp !== null) {
            var tempEl = document.getElementById('val-' + esc(s.tempId));
            if (tempEl) {
              var tC = devData.temp;
              sensorCurrentTemp[s.id] = tC;
              tempEl.textContent = formatMetricValue('temperature', tC, getMetricDef('temp'));
              tempEl.classList.remove('waiting');
            }
          }
          // Humidity
          if (devData.hum !== undefined && devData.hum !== null) {
            var humEl = document.getElementById('val-' + esc(s.humId));
            if (humEl) {
              var hV = devData.hum;
              sensorCurrentHum[s.id] = hV;
              humEl.textContent = formatMetricValue('humidity', hV, getMetricDef('hum'));
              humEl.classList.remove('waiting');
            }
          }
          // Derived values (dew point and comfort) once both temp and hum are available
          if (sensorCurrentTemp[s.id] !== undefined && sensorCurrentHum[s.id] !== undefined) {
            updateDewPoint(s.id);
            updateComfortLevel(s.id);
          }
          // Battery
          if (devData.batt !== undefined && devData.batt !== null) {
            updateBattery(s, String(devData.batt));
          }
          // Last seen
          var seenEl = document.getElementById('time-' + s.id);
          if (seenEl && devData.last_seen) {
            var d = new Date(devData.last_seen * 1000);
            seenEl.textContent = 'last: ' + d.toLocaleTimeString([], {hour12:false});
          }
        } else if (cat === 'network') {
          var pingEl = document.getElementById('net-ping-' + s.id);
          if (pingEl && devData.ping_ms !== undefined && devData.ping_ms !== null) {
            pingEl.textContent = METRIC_FORMATTERS.ping_latency(devData.ping_ms);
            pingEl.classList.remove('waiting');
          }
          var successEl = document.getElementById('net-success-' + s.id);
          if (successEl && devData.success_pct !== undefined && devData.success_pct !== null) {
            successEl.textContent = METRIC_FORMATTERS.success_rate(devData.success_pct);
            successEl.classList.remove('waiting');
          }
          var seenEl = document.getElementById('net-lastseen-' + s.id);
          if (seenEl && devData.last_seen) {
            var d = new Date(devData.last_seen * 1000);
            seenEl.textContent = 'last: ' + d.toLocaleTimeString([], {hour12:false});
          }
        }
      });
    })
    .catch(function() { /* silent */ })
    .finally(function() { _aggDeviceLiveInFlight = false; });
}

function renderSettingsPanel(gateways) {
  var grid = document.getElementById('sensorGrid');
  grid.innerHTML = '';
  var html = '<div class="settings-panel">';
  html += '<h3 class="settings-title">Satellite Configuration</h3>';
  html += '<p class="settings-subtitle">Configured satellites (read-only \u2014 runtime management coming in a future update)</p>';
  gateways.forEach(function(gw) {
    var statusDot = gw.reachable ? '\uD83D\uDFE2' : '\uD83D\uDD34';
    var fwVersion = '\u2014';
    var deviceCount = '\u2014';
    if (gw.firmware_version) fwVersion = gw.firmware_version;
    if (gw.device_count !== undefined) deviceCount = gw.device_count;
    else if (gw.sensor_count !== undefined) deviceCount = gw.sensor_count;
    html += '<div class="settings-satellite-card">';
    html += '<div class="settings-sat-header">' + statusDot + ' ' + escHtml(gw.name) +
      ' <span class="settings-sat-id">(' + escHtml(gw.id) + ')</span></div>';
    html += '<div class="settings-sat-details">';
    html += '<div>URL: <code>' + escHtml(gw.base_url || '\u2014') + '</code></div>';
    html += '<div>Firmware: ' + escHtml(fwVersion) + '</div>';
    html += '<div>Devices: ' + escHtml(String(deviceCount)) + '</div>';
    html += '<div>Status: ' + (gw.reachable ? 'Online' : 'Unreachable') + '</div>';
    html += '</div>';
    html += '</div>';
  });
  html += '</div>';
  grid.innerHTML = html;
}

async function initAggregatorDashboard() {
  renderGatewaySelector(window._aggregatorGateways);
  // Render "All Gateways" as the default active view
  renderAllGatewaysSummary(window._aggregatorGateways);
  // Start periodic aggregator polling — 15s interval, in-flight guarded
  setInterval(pollAggregatorLive, 15000);
  pollAggregatorLive();
  // Signal for Playwright test infrastructure (v7.5.5.4 will use this)
  window._aggregatorReady = true;
}

var _aggLiveInFlight = false;
function pollAggregatorLive() {
  if (_aggLiveInFlight) return;
  _aggLiveInFlight = true;
  fetch(ESP_HOST + '/api/aggregator/gateways', {cache: 'no-store'})
    .then(function(r) { return r.json(); })
    .then(function(data) {
      if (data && data.gateways) {
        window._aggregatorGateways = data.gateways;
        // Update gateway selector tab status indicators
        data.gateways.forEach(function(gw) {
          var tab = document.querySelector('.gw-tab[data-gw="' + gw.id + '"]');
          if (tab) {
            tab.classList.toggle('gw-online', !!gw.reachable);
            tab.classList.toggle('gw-offline', !gw.reachable);
          }
        });
        var activeTab = document.querySelector('.gw-tab.active');
        if (activeTab) {
          var gwId = activeTab.getAttribute('data-gw');
          if (gwId === 'all') renderAllGatewaysSummary(data.gateways);
          else if (gwId === 'settings') renderSettingsPanel(data.gateways);
          else if (gwId && _currentGwId === gwId && _currentGwSensors) {
            // Refresh live values for the currently displayed per-gateway device view
            _populateGatewayDeviceLive(gwId, _currentGwSensors);
          }
        }
      }
    })
    .catch(function() { /* silent */ })
    .finally(function() { _aggLiveInFlight = false; });
}

function updateBoardInfo() {
  var manifest = window._manifest;
  if (!manifest || !manifest.gateway) return;
  var hw = manifest.gateway.hardware || '';
  // Hide C3 pinout on non-C3 boards (SVG is C3-specific)
  var pinout = document.getElementById('pinoutDiagram');
  if (pinout && hw.indexOf('C3') === -1) {
    pinout.style.display = 'none';
  }
}

// ── Boot entrypoint (exported for testing) ─────────────────────
App.Boot.start = function() {
  var modeStr = TRANSPORT === 'sse' ? (ESP_HOST === '' ? 'HOSTED' : 'SSE') : 'POLLING';
  document.getElementById('modeLabel').textContent = '[' + modeStr + ' mode]';
  detectAggregatorMode().then(function(isAggregator) {
    if (isAggregator) {
      // Aggregator boot path: load manifest and init aggregator UI.
      // Local device cards are NOT rendered here — they have no live update mechanism
      // in aggregator mode (no SSE/polling started). Satellite devices are shown via
      // the gateway selector + renderGatewayDevices(). See review finding 2c.
      loadManifestV2().then(function(manifest) {
        window._manifest = manifest;
        dlog('[manifest] v2 manifest stored (source: ' + (manifest.source || 'unknown') + ')', 'ok');
      }).catch(function(e) {
        dlog('[manifest] loadManifestV2 failed: ' + e.message, 'err');
        window._manifest = null;
      }).then(function() {
        updateBoardInfo();
        return initAggregatorDashboard();
      });
    } else {
      // Satellite boot path — UNCHANGED (v7.5.5.3: +updateBoardInfo() per Part D)
      // v7.5.3.0: sequence manifest v2 load before sensor manifest load
      // to ensure window._manifest is available when buildDeviceCards() runs
      loadManifestV2().then(function(manifest) {
        window._manifest = manifest;
        dlog('[manifest] v2 manifest stored (source: ' + (manifest.source || 'unknown') + ')', 'ok');
      }).catch(function(e) {
        dlog('[manifest] loadManifestV2 failed: ' + e.message, 'err');
        window._manifest = null;
      }).then(function() {
        // BUG-043-cont Fix 1: if v2 manifest already has sensor data, skip the second
        // /api/manifest fetch that loadSensorManifest() would issue. Fall back to
        // loadSensorManifest() only when the v2 manifest returned no sensor entries.
        if (window._manifest && window._manifest.sensors && window._manifest.sensors.length) {
          var meta = normalizeManifestSensors(window._manifest);
          applySensorMeta(meta);
          dlog('[manifest] Sensors loaded from v2 manifest cache (' + meta.length + ' sensors, no second fetch)', 'ok');
          return Promise.resolve();
        }
        return loadSensorManifest();
      }).then(function() {
        updateBoardInfo();
        dlog('init - ' + SENSORS.length + ' sensors, transport=' + TRANSPORT + ', host=' + (ESP_HOST || '(same-origin)'));
        buildSensorCards();
        try { initCharts(); setHistoryRange(24); } catch(e) { dlog('initCharts: ' + e.message, 'err'); showError('Chart init failed'); }
        // BUG-037: Startup request staggering — spread non-critical requests across 5s
        // to avoid overwhelming the ESP32-C3 HTTP server (~4-7 concurrent connections).
        // See Docs/dashboard-stability-remediation-plan.md for full rationale.

        // v7.5.4.2: Start /api/v2/live polling for network card live data updates.
        // Network devices do not appear in SSE state events, so a periodic poll is needed.
        setInterval(pollV2Live, 15000);
        pollV2Live(); // initial fetch

        // BUG-043-cont (PR2) Fix A: In SSE mode, start the event stream first, then defer the
        // status snapshot ~2s. SSE 'state' events already carry initial live state so an
        // immediate /api/status call is unnecessary and adds pressure during the fragile
        // connection-open window. Polling mode is unchanged — startPolling() handles its
        // own status fetch after the deferred sequential initial poll completes.
        if (TRANSPORT === 'sse') {
          try { connectSSE(); } catch(e) { dlog('SSE: ' + e.message, 'err'); showError('SSE failed'); }
          setTimeout(function() { loadStatusSnapshot().catch(function(){}); }, 2000);
        } else {
          try { startPolling(); } catch(e) { dlog('Polling: ' + e.message, 'err'); showError('Polling failed'); }
        }

        // BUG-043-cont (PR2) Fix D: Defer storage stats from 3s to 5s — reduces overlap with
        // the sequential initial poll (which now takes ~7-8s at batch=1, 200ms gap).
        setTimeout(function() {
          if (isImportActive()) return;
          loadStorageStats().catch(function(){});
          // BUG-037 Fix 8: storage stats interval increased from 60s to 120s
          // (storage stats change only on NVS persist cycles, roughly every 60 minutes)
          storageStatsIntervalId = setInterval(function() {
            if (isImportActive()) return;
            loadStorageStats().catch(function(){});
          }, 120000);
        }, 5000);

        // BUG-037 Fix 5: 30s status interval only in polling mode — in SSE mode,
        // state is delivered via SSE events, so periodic /api/status polling is unnecessary
        if (TRANSPORT !== 'sse') {
          statusSnapshotIntervalId = setInterval(function() {
            if (isImportActive()) return;
            loadStatusSnapshot().catch(function(){});
          }, 30000);
        }

        // BUG-043-cont (PR2) Fix E: History deferred from 8s to 10s — the sequential initial
        // poll (batch=1, 200ms gap, ~30 paths) takes roughly 7-8s on a loaded device. Adding
        // 2s headroom prevents NVS-heavy history scans from overlapping with poll tail or
        // storage stats (t+5s), keeping the startup window clean.
        historyBootstrapTimerId = setTimeout(function() {
          if (isImportActive()) return;
          loadHistory();
        }, 10000);
      });
    }
  });
};

document.addEventListener('DOMContentLoaded', function() {
  bindEvents();
  CustomRange.bindModalEvents();
  try { App.Features.emit('onBoot'); } catch(e) { logNonFatal('boot hook emit', e); }
  App.Boot.start();
});
