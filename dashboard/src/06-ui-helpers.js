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
