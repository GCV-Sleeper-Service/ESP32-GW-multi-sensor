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

