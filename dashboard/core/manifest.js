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

function normalizeManifestGateway(payload) {
  var gw = payload && payload.gateway;
  if (!gw || typeof gw !== 'object') return null;
  return {
    id: String(gw.id || '').trim(),
    name: String(gw.name || '').trim(),
    hardware: String(gw.hardware || '').trim(),
    version: String(gw.firmware_version || gw.version || '').trim(),
    role: String(gw.role || '').trim()
  };
}

function populateGatewayCardInfo(gw) {
  var nameEl = document.getElementById('di-device-name');
  if (nameEl) {
    nameEl.textContent = (gw && gw.name) ? gw.name : '-';
    nameEl.classList.remove('loading');
  }

  var versionEl = document.getElementById('di-firmware-version');
  if (versionEl) {
    var versionText = '-';
    if (gw && gw.version) {
      versionText = gw.version;
      if (versionText.charAt(0) !== 'v') versionText = 'v' + versionText;
    }
    versionEl.textContent = versionText;
    versionEl.classList.remove('loading');
  }

  var aboutTitle = document.getElementById('aboutCardTitle');
  if (aboutTitle && gw && gw.name) {
    var titleText = gw.name;
    if (!/gateway\s*$/i.test(titleText)) titleText += ' Gateway';
    aboutTitle.textContent = titleText;
  }
}

function applyGatewayMeta(payload) {
  var gw = normalizeManifestGateway(payload) || normalizeManifestGateway(window._manifest);
  if (App.State && typeof App.State.set === 'function') App.State.set('gateway', gw || null);
  populateGatewayCardInfo(gw);
}

function applySensorMeta(meta, payload) {
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
  applyGatewayMeta(payload);
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
      applySensorMeta(meta, payload);
      var schema = payload && payload.schema_version ? payload.schema_version : 'legacy';
      dlog('Manifest loaded from /api/manifest (schema ' + schema + ', ' + SENSORS.length + ' sensors)', 'ok');
    })
    .catch(function(apiErr) {
      return fetch(ESP_HOST + '/sensors.json', {cache:'no-store'})
        .then(function(r) { if (!r.ok) throw new Error('HTTP ' + r.status); return r.json(); })
        .then(function(payload) {
          var meta = normalizeManifestSensors(payload);
          if (!meta.length) throw new Error('empty legacy manifest');
          applySensorMeta(meta, payload);
          dlog('Manifest fallback loaded from /sensors.json (' + SENSORS.length + ' sensors); /api/manifest unavailable: ' + apiErr.message, 'err');
        })
        .catch(function(legacyErr) {
          applySensorMeta(DEFAULT_SENSOR_META, autoPromoteV1ToV2(DEFAULT_SENSOR_META));
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
      console.log('[manifest] Falling back to /sensors.json -> auto-promote to v2');
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
