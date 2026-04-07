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
  system: function(device, manifest) {
    return buildSystemCard(device, manifest);
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
          '<div class="reading-value" id="net-target-' + s.id + '">' + escHtml(target) + '</div>' +
        '</div>' +
        '<div class="sensor-reading">' +
          '<div class="reading-label">Last Seen</div>' +
          '<div class="reading-time" id="net-lastseen-' + s.id + '">last: &mdash;</div>' +
        '</div>' +
      '</div>' +
    '</div>'
  );
}

function buildSystemCard(s, manifest) {
  var lookupId = s._deviceId || s.id;
  var description = '';
  if (manifest && manifest.sensors) {
    var entry = manifest.sensors.find(function(ms) { return ms.id === lookupId; });
    if (entry && entry.source && entry.source.description) description = entry.source.description;
  }
  return (
    '<div class="sensor-card system-card" data-device-id="' + s.id + '">' +
      '<div class="sensor-card-header">' +
        '<input class="sensor-color-picker" id="picker-' + s.id + '" type="color" value="' + (s.color || '#66BB6A') + '" data-sensor-color="' + s.id + '">' +
        s.name +
      '</div>' +
      '<div class="sensor-readings">' +
        buildUsageBarRow('CPU', 'sys-cpu-' + s.id) +
        buildUsageBarRow('RAM', 'sys-ram-' + s.id) +
        buildUsageBarRow('Disk', 'sys-disk-' + s.id) +
        '<div class="sensor-reading">' +
          '<div class="reading-label">Uptime</div>' +
          '<div class="reading-value waiting" id="sys-uptime-' + s.id + '">&mdash;</div>' +
        '</div>' +
        '<div class="sensor-reading">' +
          '<div class="reading-label">Last Seen</div>' +
          '<div class="reading-time" id="sys-lastseen-' + s.id + '">last: &mdash;</div>' +
        '</div>' +
        (description ? '<div class="sensor-reading"><div class="reading-label" style="font-size:.52rem;color:var(--text-muted)">' + escHtml(description) + '</div></div>' : '') +
      '</div>' +
    '</div>'
  );
}

function buildUsageBarRow(label, id) {
  return (
    '<div class="sensor-reading system-usage-row">' +
      '<div class="reading-label">' + label + '</div>' +
      '<div class="system-bar-bg"><div class="system-bar-fill" id="bar-' + id + '"></div></div>' +
      '<div class="reading-value waiting" id="val-' + id + '">&mdash;</div>' +
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

