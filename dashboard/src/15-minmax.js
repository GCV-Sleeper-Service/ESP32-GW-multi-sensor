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

