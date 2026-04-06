function exportSensorCSV(sensorId, sensorName) {
  var statusEl = document.getElementById('export-status');
  if (statusEl) statusEl.textContent = 'Fetching ' + sensorName + '...';

  var sensor = { id: sensorId, name: sensorName };
  Promise.all([
    getGatewayExportMeta(),
    fetchSensorHistoryRows(sensor)
  ]).then(function(results) {
    var meta = results[0];
    var rows = results[1];
    var csv = buildSingleSensorCsv(meta, sensor, rows);
    triggerCsvDownload(csv, 'gateway-history-' + getExportSensorPrefix(sensor) + '-' + currentExportDateTag() + '.csv');
    if (statusEl) statusEl.textContent = sensorName + ' exported (' + rows.length + ' rows) \u2714';
  }).catch(function(e) {
    if (statusEl) statusEl.textContent = 'Export failed: ' + e.message;
  });
}

function exportAllCSV() {
  var statusEl = document.getElementById('export-status');
  if (statusEl) statusEl.textContent = 'Fetching merged history...';

  Promise.all([
    getGatewayExportMeta(),
    fetchAllSensorHistoryRowsSequentially(SENSORS, function(idx, sensor, total) {
      if (statusEl) statusEl.textContent = 'Fetching merged history (' + (idx + 1) + '/' + total + '): ' + sensor.name + '...';
    })
  ]).then(function(results) {
    var meta = results[0];
    var sensorRowsList = results[1];
    var csv = buildMergedSensorCsv(meta, SENSORS, sensorRowsList);
    var rowCount = csv.split(/\r?\n/).filter(Boolean).length - 1;
    triggerCsvDownload(csv, 'gateway-history-multi-' + currentExportDateTag() + '.csv');
    if (statusEl) statusEl.textContent = 'Merged export ready (' + rowCount + ' rows) \u2714';
  }).catch(function(e) {
    if (statusEl) statusEl.textContent = 'Export failed: ' + e.message;
  });
}


function resetHistoryVisuals() {
  App.State.resetAvgHistoryStore();
  historyPoints = 0;
  liveAvgPoints = 0;
  SENSORS.forEach(function(s) {
    ensureHistoryStore(s.id);
    updateMinMax([], s.id, true);
    updateMinMax([], s.id, false);
  });
  if (chartsReady) {
    tempAvgChart.data.datasets.forEach(function(ds) { ds.data = []; });
    humAvgChart.data.datasets.forEach(function(ds) { ds.data = []; });
    document.getElementById('tempAvgNoData').classList.remove('hidden');
    document.getElementById('humAvgNoData').classList.remove('hidden');
    tempAvgChart.update('none');
    humAvgChart.update('none');
  }
  totalPoints = 0;
  document.getElementById('pointCount').textContent = '0 data points';
  updateBadge();
}


