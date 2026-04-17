var SENSOR_COLORS = ['#fbbf24', '#f87171', '#34d399', '#60a5fa'];

// <<< SENSOR_MANIFEST:DEFAULT_SENSOR_META_BEGIN >>>
var DEFAULT_SENSOR_META = [
  { id: 'office', name: 'Office' },
  { id: 'first_floor', name: 'First Floor' },
  { id: 'outside', name: 'Outside' },
];
// <<< SENSOR_MANIFEST:DEFAULT_SENSOR_META_END >>>

var GATEWAY_EXPORT_HOSTNAME_FALLBACK = 'esp32-c3-multi';
var EXPORT_SHARED_COLUMNS = ['gateway_host', 'gateway_ip', 'role', 'timestamp', 'datetime_utc'];
var EXPORT_SENSOR_SUFFIXES = ['temp_c', 'temp_f', 'humidity_pct', 'dewpoint_c'];

function getExportRole(sensor, manifest) {
  if (!manifest || !manifest.gateway) return 'unknown';
  return manifest.gateway.role || 'satellite';
}

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
    var satellitePrefix = sensorSlug((sensor && sensor._gwDisplayName) || (sensor && sensor._gwName) || (sensor && sensor._gwId) || 'gateway');
    var prefix = satellitePrefix + '_' + getExportSensorPrefix(sensor);
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
  cpu_usage: function(value) {
    if (value === null || value === undefined || isNaN(value)) return '\u2014';
    return value.toFixed(1) + '%';
  },
  ram_usage: function(value) {
    if (value === null || value === undefined || isNaN(value)) return '\u2014';
    return value.toFixed(1) + '%';
  },
  disk_usage: function(value) {
    if (value === null || value === undefined || isNaN(value)) return '\u2014';
    return value.toFixed(1) + '%';
  },
  uptime_hours: function(value) {
    if (value === null || value === undefined || isNaN(value)) return '\u2014';
    if (value >= 24) return (value / 24).toFixed(1) + ' days';
    return value.toFixed(1) + ' hrs';
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

