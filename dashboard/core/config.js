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
