var FREEZING_LINE_PLUGIN = {
  id:'freezingLine',
  afterDraw:function(chart) {
    if (!chart || !chart.scales || !chart.scales.y || !chart.chartArea) return;
    var y = chart.scales.y.getPixelForValue(0);
    if (!isFinite(y) || y < chart.chartArea.top || y > chart.chartArea.bottom) return;
    var ctx = chart.ctx;
    ctx.save();
    ctx.strokeStyle = '#60a5fa';
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(chart.chartArea.left, y);
    ctx.lineTo(chart.chartArea.right, y);
    ctx.stroke();
    ctx.restore();
  }
};

var AX_TEXT = '#ffffff', AX_GRID = '#3a3a3a', AX_TITLE = '#cccccc';

function isLightTheme() {
  return document.documentElement.classList.contains('light');
}

function setAxisColorsForTheme() {
  if (isLightTheme()) {
    AX_TEXT = '#111827';     // near-black
    AX_GRID = '#d1d5db';     // light gray
    AX_TITLE = '#374151';    // dark gray
  } else {
    AX_TEXT = '#ffffff';
    AX_GRID = '#3a3a3a';
    AX_TITLE = '#cccccc';
  }
}

function recolorChartForTheme(chart, mode) {
  if (!chart || !chart.options) return;
  var opts = chart.options;
  if (opts.plugins && opts.plugins.legend && opts.plugins.legend.labels) {
    opts.plugins.legend.labels.color = AX_TEXT;
  }
  if (!opts.scales) return;

  if (opts.scales.x) {
    if (opts.scales.x.ticks) opts.scales.x.ticks.color = AX_TEXT;
    if (opts.scales.x.title) opts.scales.x.title.color = AX_TITLE;
    if (opts.scales.x.grid && typeof opts.scales.x.grid.color !== 'function') opts.scales.x.grid.color = AX_GRID;
  }

  if (mode === 'telemetry') {
    if (opts.scales.y && opts.scales.y.grid && typeof opts.scales.y.grid.color !== 'function') opts.scales.y.grid.color = AX_GRID;
    chart.update();
    return;
  }

  if (opts.scales.y) {
    if (opts.scales.y.ticks) opts.scales.y.ticks.color = AX_TEXT;
    if (opts.scales.y.title) opts.scales.y.title.color = AX_TITLE;
    if (opts.scales.y.grid && typeof opts.scales.y.grid.color !== 'function') opts.scales.y.grid.color = AX_GRID;
  }
  if (opts.scales.y1) {
    if (opts.scales.y1.ticks) opts.scales.y1.ticks.color = AX_TEXT;
    if (opts.scales.y1.title) opts.scales.y1.title.color = AX_TITLE;
    if (opts.scales.y1.grid && typeof opts.scales.y1.grid.color !== 'function') opts.scales.y1.grid.color = AX_GRID;
  }
  chart.update();
}

function refreshChartsAfterVisualChange(reason) {
  [tempChart, humChart, tempAvgChart, humAvgChart, telemetryChart].forEach(function(chart) {
    if (!chart) return;
    try { chart.resize(); } catch(e) { logNonFatal((reason || 'visual-change') + ' resize', e); }
    try { chart.render(); } catch(e) { logNonFatal((reason || 'visual-change') + ' render', e); }
    try { chart.update('none'); } catch(e) { logNonFatal((reason || 'visual-change') + ' update', e); }
  });
}

function updateChartsTheme() {
  try { setAxisColorsForTheme(); } catch(e) { logNonFatal('set axis colors for theme', e); }
  try {
    recolorChartForTheme(tempChart, 'standard');
    recolorChartForTheme(humChart, 'standard');
    recolorChartForTheme(tempAvgChart, 'standard');
    recolorChartForTheme(humAvgChart, 'standard');
    recolorChartForTheme(telemetryChart, 'telemetry');
  } catch(e) { logNonFatal('update charts theme', e); }
}

setAxisColorsForTheme();
var TEMP_MIN_C = -15, TEMP_MAX_C = 40;
var TEMP_MIN_F = cToF(TEMP_MIN_C), TEMP_MAX_F = cToF(TEMP_MAX_C);

function tempChartOpts() {
  return {
    responsive:true, maintainAspectRatio:false, animation:false,
    interaction:{mode:'index',intersect:false},
    plugins:{
      legend:{display:SENSORS.length>1, labels:{color:AX_TEXT,font:{family:'JetBrains Mono',size:11},boxWidth:14,boxHeight:2,padding:16}},
      tooltip:{backgroundColor:'#333',titleColor:'#fff',bodyColor:'#ccc',borderColor:'#555',borderWidth:1,
        titleFont:{family:'JetBrains Mono',size:11},bodyFont:{family:'JetBrains Mono',size:11},
        callbacks:{label:function(c){var v=c.parsed.y; if(v===null)return ' '+c.dataset.label+': gap'; return ' '+c.dataset.label+': '+v.toFixed(1)+' \u00B0C / '+cToF(v).toFixed(1)+' \u00B0F';}}}
    },
    scales:{
      x:(function(){ var fmt = getHistoryTimeFormat(HISTORY_RANGE_HOURS); return {type:'time',time:{displayFormats:fmt.displayFormats,tooltipFormat:fmt.tooltipFormat},
        title:{display:true,text:fmt.axisTitle,color:AX_TITLE,font:{family:'JetBrains Mono',size:11}},
        ticks:{color:AX_TEXT,font:{family:'JetBrains Mono',size:11},maxRotation:0,autoSkipPadding:30},
        grid:{color:AX_GRID,lineWidth:0.5}}; })(),
      y:{min:TEMP_MIN_C,max:TEMP_MAX_C,position:'left',
        title:{display:true,text:'\u00B0C',color:AX_TITLE,font:{family:'JetBrains Mono',size:11}},
        ticks:{color:AX_TEXT,font:{family:'JetBrains Mono',size:11},stepSize:5},
        // Blue freezing line at 0 C
        grid:{color:function(ctx){return ctx.tick&&ctx.tick.value===0?'#60a5fa':AX_GRID;},
              lineWidth:function(ctx){return ctx.tick&&ctx.tick.value===0?2:0.5;}}},
      y1:{min:TEMP_MIN_F,max:TEMP_MAX_F,position:'right',
        title:{display:true,text:'\u00B0F',color:AX_TITLE,font:{family:'JetBrains Mono',size:11}},
        ticks:{color:AX_TEXT,font:{family:'JetBrains Mono',size:11},stepSize:9,callback:function(v){return Math.round(v);}},
        grid:{drawOnChartArea:false}}
    }
  };
}

function humChartOpts() {
  return {
    responsive:true, maintainAspectRatio:false, animation:false,
    interaction:{mode:'index',intersect:false},
    plugins:{
      legend:{display:SENSORS.length>1, labels:{color:AX_TEXT,font:{family:'JetBrains Mono',size:11},boxWidth:14,boxHeight:2,padding:16}},
      tooltip:{backgroundColor:'#333',titleColor:'#fff',bodyColor:'#ccc',borderColor:'#555',borderWidth:1,
        titleFont:{family:'JetBrains Mono',size:11},bodyFont:{family:'JetBrains Mono',size:11},
        callbacks:{label:function(c){var v=c.parsed.y; if(v===null)return ' '+c.dataset.label+': gap'; return ' '+c.dataset.label+': '+Math.round(v)+' %';}}}
    },
    scales:{
      x:(function(){ var fmt = getHistoryTimeFormat(HISTORY_RANGE_HOURS); return {type:'time',time:{displayFormats:fmt.displayFormats,tooltipFormat:fmt.tooltipFormat},
        title:{display:true,text:fmt.axisTitle,color:AX_TITLE,font:{family:'JetBrains Mono',size:11}},
        ticks:{color:AX_TEXT,font:{family:'JetBrains Mono',size:11},maxRotation:0,autoSkipPadding:30},
        grid:{color:AX_GRID,lineWidth:0.5}}; })(),
      y:{min:0,max:100,title:{display:true,text:'%',color:AX_TITLE,font:{family:'JetBrains Mono',size:11}},
        ticks:{color:AX_TEXT,font:{family:'JetBrains Mono',size:11},stepSize:10},
        grid:{color:AX_GRID,lineWidth:0.5}}
    }
  };
}

function telemetryChartOpts() {
  return {
    responsive:true, maintainAspectRatio:false, animation:false,
    interaction:{mode:'index',intersect:false},
    plugins:{
      legend:{display:true,labels:{color:AX_TEXT,font:{family:'JetBrains Mono',size:10},boxWidth:14,boxHeight:2,padding:14}},
      tooltip:{backgroundColor:'#333',titleColor:'#fff',bodyColor:'#ccc',borderColor:'#555',borderWidth:1, titleFont:{family:'JetBrains Mono',size:10},bodyFont:{family:'JetBrains Mono',size:10},
        callbacks:{label:function(c){if(c.datasetIndex===0)return ' Heap: '+Math.round(c.parsed.y).toLocaleString()+' B'; return ' WiFi: '+c.parsed.y.toFixed(0)+' dBm';}}}
    },
    scales:{
      x:{type:'time',time:{displayFormats:{second:'HH:mm:ss',minute:'HH:mm',hour:'HH:mm'},tooltipFormat:'HH:mm:ss'},
        title:{display:true,text:'Uptime',color:AX_TITLE,font:{family:'JetBrains Mono',size:10}},
        ticks:{color:AX_TEXT,font:{family:'JetBrains Mono',size:10},maxRotation:0,autoSkipPadding:30},
        grid:{color:AX_GRID,lineWidth:0.5}},
      y:{position:'left',title:{display:true,text:'Free Heap (B)',color:'#34d399',font:{family:'JetBrains Mono',size:10}},
        ticks:{color:'#34d399',font:{family:'JetBrains Mono',size:10},callback:function(v){return (v/1024).toFixed(0)+'K';}},
        grid:{color:AX_GRID,lineWidth:0.5}},
      y1:{position:'right',title:{display:true,text:'WiFi (dBm)',color:'#a78bfa',font:{family:'JetBrains Mono',size:10}},
        ticks:{color:'#a78bfa',font:{family:'JetBrains Mono',size:10}},grid:{drawOnChartArea:false}}
    }
  };
}

var tempChart, humChart, tempAvgChart, humAvgChart, telemetryChart;

function initCharts() {
  if (typeof Chart === 'undefined') { showError('Chart.js not loaded'); return; }
  var mkDS = function(type, avg) {
    return SENSORS.filter(function(s) { return (s.chartIdx !== undefined && s.chartIdx >= 0); }).map(function(s) {
      return {label:s.name, data:[], borderColor:s.color, backgroundColor:s.color+'18',
        fill:true, tension:0.3, pointRadius:1.5, pointHoverRadius:4,
        pointBackgroundColor:s.color, pointBorderColor:s.color,
        pointHoverBackgroundColor:s.color, pointHoverBorderColor:s.color,
        borderWidth:avg?2.5:2, yAxisID:'y', spanGaps:false};
    });
  };
  tempChart    = new Chart(document.getElementById('tempChart'),    {type:'line',data:{datasets:mkDS('temp',false)},options:tempChartOpts(),plugins:[FREEZING_LINE_PLUGIN]});
  humChart     = new Chart(document.getElementById('humChart'),     {type:'line',data:{datasets:mkDS('hum',false)},options:humChartOpts()});
  tempAvgChart = new Chart(document.getElementById('tempAvgChart'), {type:'line',data:{datasets:mkDS('temp',true)},options:tempChartOpts(),plugins:[FREEZING_LINE_PLUGIN]});
  humAvgChart  = new Chart(document.getElementById('humAvgChart'),  {type:'line',data:{datasets:mkDS('hum',true)},options:humChartOpts()});

  telemetryChart = new Chart(document.getElementById('telemetryChart'), {
    type:'line', data:{datasets:[
      {label:'Free Heap',data:[],borderColor:'#34d399',backgroundColor:'#34d39918',fill:true,tension:0.3,pointRadius:3,borderWidth:2,yAxisID:'y'},
      {label:'WiFi Signal',data:[],borderColor:'#a78bfa',backgroundColor:'#a78bfa18',fill:true,tension:0.3,pointRadius:3,borderWidth:2,yAxisID:'y1'}
    ]}, options:telemetryChartOpts()
  });
  App.State.setChartsReady(true);
  try { App.Features.emit('onChartsReady'); } catch(e) { logNonFatal('charts-ready hook emit', e); }
  dlog('All charts initialized (' + SENSORS.length + ' sensors)', 'ok');
}

// ╔════════════════════════════════════════════════════════════════╗
// ║  BATTERY + TELEMETRY + DEVICE INFO UPDATES                     ║
// ╚════════════════════════════════════════════════════════════════╝

