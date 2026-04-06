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
    if (seenEl && devData.last_seen != null) {
      var d = new Date(devData.last_seen * 1000);
      seenEl.textContent = 'last: ' + d.toLocaleTimeString([], {hour12:false});
    }
  });
}

// ── System card DOM updater (shared by satellite + aggregator paths) ──
function _updateSystemCardDOM(s, devData) {
  updateUsageBar('sys-cpu-' + s.id, devData.cpu_pct, METRIC_FORMATTERS.cpu_usage);
  updateUsageBar('sys-ram-' + s.id, devData.ram_pct, METRIC_FORMATTERS.ram_usage);
  updateUsageBar('sys-disk-' + s.id, devData.disk_pct, METRIC_FORMATTERS.disk_usage);

  var uptimeEl = document.getElementById('sys-uptime-' + s.id);
  if (uptimeEl && devData.uptime_hrs !== undefined && devData.uptime_hrs !== null) {
    uptimeEl.textContent = METRIC_FORMATTERS.uptime_hours(devData.uptime_hrs);
    uptimeEl.classList.remove('waiting');
  }

  var seenEl = document.getElementById('sys-lastseen-' + s.id);
  if (seenEl && devData.last_seen !== undefined && devData.last_seen !== null) {
    seenEl.textContent = 'last: ' + new Date(devData.last_seen * 1000).toLocaleTimeString([], {hour12:false});
  }
}

function updateSystemCards(liveData) {
  if (!liveData || !liveData.devices) return;
  SENSORS.forEach(function(s) {
    if (s.category !== 'system') return;
    var devData = liveData.devices[s.id];
    if (!devData) return;
    _updateSystemCardDOM(s, devData);
  });
}

function updateUsageBar(id, value, formatter) {
  var barEl = document.getElementById('bar-' + id);
  var valEl = document.getElementById('val-' + id);
  if (value === null || value === undefined || !isFinite(value)) return;
  var pct = Math.min(100, Math.max(0, value));
  if (barEl) {
    barEl.style.width = pct + '%';
    barEl.className = 'system-bar-fill' +
      (pct >= 80 ? ' bar-danger' : pct >= 60 ? ' bar-warning' : ' bar-ok');
  }
  if (valEl) {
    valEl.textContent = formatter(value);
    valEl.classList.remove('waiting');
  }
}

var _v2LiveInFlight = false;
function pollV2Live() {
  if (_v2LiveInFlight) return;
  _v2LiveInFlight = true;
  fetch(ESP_HOST + '/api/v2/live', {cache:'no-store'})
    .then(function(r) { if (!r.ok) throw new Error('HTTP ' + r.status); return r.json(); })
    .then(function(data) { updateNetworkCards(data); updateSystemCards(data); })
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

