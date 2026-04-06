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
