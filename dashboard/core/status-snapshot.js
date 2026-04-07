// Device info + telemetry mapping
var DEVICE_INFO_MAP = {
  'text_sensor-chip': {el:'di-chip'}, 'text_sensor-features': {el:'di-features'},
  'text_sensor-cores': {el:'di-cores'}, 'text_sensor-revision': {el:'di-revision'},
  'text_sensor-cpu_frequency': {el:'di-cpu'}, 'text_sensor-framework': {el:'di-framework'},
  'text_sensor-esphome_version': {el:'di-esphome'}, 'text_sensor-ip_address': {el:'di-ip'},
  'text_sensor-mac_address': {el:'di-mac'}, 'text_sensor-reset_reason': {el:'di-reset'}
};
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

