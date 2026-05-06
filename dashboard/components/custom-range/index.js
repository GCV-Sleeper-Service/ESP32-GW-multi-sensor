var CustomRange = (function() {
  'use strict';
  var _availOldest = 0, _availNewest = 0;
  var _selStart = null, _selEnd = null;  // Date objects
  var _viewYear = 0, _viewMonth = 0;    // currently displayed calendar month
  var _pickingStart = true;             // two-click selection state

  function _pad(n) { return String(n).padStart(2, '0'); }
  function _fmtDate(d) {
    if (!d) return '';
    return d.getFullYear() + '-' + _pad(d.getMonth() + 1) + '-' + _pad(d.getDate());
  }
  function _epochToDate(ep) { return new Date(ep * 1000); }
  function _dateToEpoch(d)  { return Math.floor(d.getTime() / 1000); }

  function _getModal()   { return document.getElementById('customRangeModal'); }
  function _getEl(id)    { return document.getElementById(id); }

  // ── Show / hide ─────────────────────────────────────────────────────────────
  function open() {
    var modal = _getModal();
    if (!modal) return;
    // Fetch fresh bounds then show
    authFetch(ESP_HOST + '/api/storage-stats')
      .then(safeJsonResponse)
      .then(function(data) {
        _availOldest = data.retention_oldest_epoch || 0;
        _availNewest = data.retention_newest_epoch || 0;
        _initSelection();
        _renderAvailability();
        _renderCalendar();
        _updateTimeFields();
        modal.classList.remove('hidden');
        modal.setAttribute('aria-hidden', 'false');
      })
      .catch(function() {
        // Fall back: no bounds — still open with today
        _availOldest = 0;
        _availNewest = Math.floor(Date.now() / 1000);
        _initSelection();
        _renderAvailability();
        _renderCalendar();
        _updateTimeFields();
        modal.classList.remove('hidden');
        modal.setAttribute('aria-hidden', 'false');
      });
  }

  function close() {
    var modal = _getModal();
    if (modal) { modal.classList.add('hidden'); modal.setAttribute('aria-hidden', 'true'); }
  }

  // ── Initialise selection state ───────────────────────────────────────────────
  function _initSelection() {
    var now = new Date();
    // Default: mirror the current active range
    if (CUSTOM_RANGE_START > 0 && CUSTOM_RANGE_END > 0) {
      _selStart = _epochToDate(CUSTOM_RANGE_START);
      _selEnd   = _epochToDate(CUSTOM_RANGE_END);
    } else {
      var hours = App.State.getHistoryRangeHours();
      _selEnd   = new Date(now);
      _selStart = new Date(now.getTime() - hours * 3600000);
    }
    _viewYear  = _selEnd.getFullYear();
    _viewMonth = _selEnd.getMonth();
    _pickingStart = false;
  }

  // ── Availability footer ──────────────────────────────────────────────────────
  function _renderAvailability() {
    var el = _getEl('customRangeAvail');
    if (!el) return;
    if (_availOldest > 0 && _availNewest > 0) {
      var o = _epochToDate(_availOldest), n = _epochToDate(_availNewest);
      el.textContent = 'Data available: ' + _fmtDate(o) + ' \u2013 ' + _fmtDate(n);
    } else if (_availNewest > 0) {
      el.textContent = 'Data available: up to ' + _fmtDate(_epochToDate(_availNewest));
    } else {
      el.textContent = 'No persisted history yet \u2014 range applies to RAM data only';
    }
  }

  // ── Calendar ─────────────────────────────────────────────────────────────────
  function _prevMonth() {
    _viewMonth--;
    if (_viewMonth < 0) { _viewMonth = 11; _viewYear--; }
    _renderCalendar();
  }
  function _nextMonth() {
    _viewMonth++;
    if (_viewMonth > 11) { _viewMonth = 0; _viewYear++; }
    _renderCalendar();
  }

  var _MONTH_NAMES = ['January','February','March','April','May','June',
                      'July','August','September','October','November','December'];
  var _DAY_NAMES   = ['Su','Mo','Tu','We','Th','Fr','Sa'];

  function _renderCalendar() {
    var hdr = _getEl('crCalHeader');
    if (hdr) hdr.textContent = _MONTH_NAMES[_viewMonth] + ' ' + _viewYear;

    var grid = _getEl('crCalGrid');
    if (!grid) return;

    var todayD = new Date();
    todayD.setHours(0,0,0,0);

    var firstDay = new Date(_viewYear, _viewMonth, 1).getDay();
    var daysInMonth = new Date(_viewYear, _viewMonth + 1, 0).getDate();

    var cells = '';
    // Day-of-week headers
    for (var h = 0; h < 7; h++) {
      cells += '<span class="cr-cal-dow">' + _DAY_NAMES[h] + '</span>';
    }
    // Leading blanks
    for (var b = 0; b < firstDay; b++) {
      cells += '<span class="cr-cal-cell cr-cal-blank"></span>';
    }
    // Days
    for (var d = 1; d <= daysInMonth; d++) {
      var dayD = new Date(_viewYear, _viewMonth, d);
      var dayEp = _dateToEpoch(dayD);
      var cls = 'cr-cal-cell';
      var unavail = (_availOldest > 0 && dayEp + 86399 < _availOldest) ||
                    (_availNewest > 0 && dayEp > _availNewest);
      if (unavail) cls += ' cr-unavail';

      // Selection highlighting
      var selStartD = _selStart ? new Date(_selStart.getFullYear(), _selStart.getMonth(), _selStart.getDate()) : null;
      var selEndD   = _selEnd   ? new Date(_selEnd.getFullYear(),   _selEnd.getMonth(),   _selEnd.getDate())   : null;
      if (selStartD && selEndD) {
        var t = dayD.getTime();
        if (t >= selStartD.getTime() && t <= selEndD.getTime()) cls += ' cr-in-range';
        if (t === selStartD.getTime()) cls += ' cr-range-start';
        if (t === selEndD.getTime())   cls += ' cr-range-end';
      } else if (selStartD && dayD.getTime() === selStartD.getTime()) {
        cls += ' cr-in-range cr-range-start cr-range-end';
      }
      if (dayD.getTime() === todayD.getTime()) cls += ' cr-today';

      var disabled = unavail ? ' data-unavail="1"' : '';
      cells += '<span class="' + cls + '" data-cr-day="' + dayEp + '"' + disabled + '>' + d + '</span>';
    }
    grid.innerHTML = cells;

    // Attach day-click listener
    grid.onclick = function(e) {
      var cell = e.target.closest('[data-cr-day]');
      if (!cell || cell.hasAttribute('data-unavail')) return;
      _onDayClick(parseInt(cell.getAttribute('data-cr-day'), 10));
    };

    // Update picking-hint label
    var hint = _getEl('crPickHint');
    if (hint) hint.textContent = _pickingStart ? 'Click a start date' : 'Click an end date';
  }

  function _onDayClick(dayEpoch) {
    var d = _epochToDate(dayEpoch);
    if (_pickingStart) {
      _selStart = new Date(d.getFullYear(), d.getMonth(), d.getDate(),
                           _selStart ? _selStart.getHours() : 0, 0, 0, 0);
      // Reset end if it's now before start
      if (_selEnd && _selEnd < _selStart) _selEnd = null;
      _pickingStart = false;
    } else {
      if (_selStart && d < new Date(_selStart.getFullYear(), _selStart.getMonth(), _selStart.getDate())) {
        // Clicked before start — swap to start mode
        _selStart = new Date(d.getFullYear(), d.getMonth(), d.getDate(), 0, 0, 0, 0);
        _selEnd   = null;
        _pickingStart = false;
      } else {
        _selEnd = new Date(d.getFullYear(), d.getMonth(), d.getDate(),
                           _selEnd ? _selEnd.getHours() : 23, 59, 59, 0);
        _pickingStart = false;
      }
    }
    _renderCalendar();
    _updateTimeFields();
  }

  // ── Time fields ──────────────────────────────────────────────────────────────
  function _updateTimeFields() {
    var startDate = _getEl('crStartDate');
    var startHour = _getEl('crStartHour');
    var startAmpm = _getEl('crStartAmpm');
    var endDate   = _getEl('crEndDate');
    var endHour   = _getEl('crEndHour');
    var endAmpm   = _getEl('crEndAmpm');
    if (!startDate) return;

    if (_selStart) {
      startDate.value = _fmtDate(_selStart);
      var sh = _selStart.getHours();
      startHour.value = String(sh % 12 || 12);
      startAmpm.value = sh < 12 ? 'AM' : 'PM';
    }
    if (_selEnd) {
      endDate.value = _fmtDate(_selEnd);
      var eh = _selEnd.getHours();
      endHour.value = String(eh % 12 || 12);
      endAmpm.value = eh < 12 ? 'AM' : 'PM';
    }
  }

  function _readTimeFields() {
    var startDate = _getEl('crStartDate');
    var startHour = parseInt(_getEl('crStartHour').value, 10);
    var startAmpm = _getEl('crStartAmpm').value;
    var endDate   = _getEl('crEndDate');
    var endHour   = parseInt(_getEl('crEndHour').value, 10);
    var endAmpm   = _getEl('crEndAmpm').value;
    if (!startDate || !endDate) return;

    var startH24 = (startAmpm === 'PM' ? (startHour === 12 ? 12 : startHour + 12) : (startHour === 12 ? 0 : startHour));
    var endH24   = (endAmpm   === 'PM' ? (endHour   === 12 ? 12 : endHour   + 12) : (endHour   === 12 ? 0 : endHour));
    var sd = new Date(startDate.value + 'T' + _pad(startH24) + ':00:00');
    var ed = new Date(endDate.value   + 'T' + _pad(endH24)   + ':59:59');
    if (!isNaN(sd.getTime())) _selStart = sd;
    if (!isNaN(ed.getTime())) _selEnd   = ed;
  }

  // ── Presets ──────────────────────────────────────────────────────────────────
  function _onPreset(name) {
    var now = new Date();
    var start, end;
    end = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59);
    if (name === 'today') {
      start = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0);
    } else if (name === 'yesterday') {
      var y = new Date(now); y.setDate(y.getDate() - 1);
      start = new Date(y.getFullYear(), y.getMonth(), y.getDate(), 0, 0, 0);
      end   = new Date(y.getFullYear(), y.getMonth(), y.getDate(), 23, 59, 59);
    } else if (name === '24h') {
      start = new Date(now.getTime() - 24 * 3600000);
      end   = new Date(now);
    } else if (name === '7d') {
      start = new Date(now.getTime() - 7 * 86400000);
      end   = new Date(now);
    } else if (name === '30d') {
      start = new Date(now.getTime() - 30 * 86400000);
      end   = new Date(now);
    } else if (name === '45d') {
      start = new Date(now.getTime() - 45 * 86400000);
      end   = new Date(now);
    }
    if (start && end) {
      _selStart = start;
      _selEnd   = end;
      _applyAndClose();
    }
  }

  // ── Apply / commit ────────────────────────────────────────────────────────────
  function apply() {
    _readTimeFields();
    if (!_selStart || !_selEnd) return;
    if (_selEnd <= _selStart) {
      var errEl = _getEl('crError');
      if (errEl) { errEl.textContent = 'End must be after start.'; return; }
      return;
    }
    _applyAndClose();
  }

  function _applyAndClose() {
    CUSTOM_RANGE_START = _dateToEpoch(_selStart);
    CUSTOM_RANGE_END   = _dateToEpoch(_selEnd);
    // Mark the Custom buttons active, deactivate presets
    [24, 168, 720, 1080].forEach(function(v) {
      var btn = document.getElementById('histRange-' + v);
      if (btn) btn.classList.remove('active');
    });
    var custBtn = document.getElementById('histRange-custom');
    if (custBtn) custBtn.classList.add('active');
    // Update minmax custom buttons for all sensors
    if (typeof SENSORS !== 'undefined') {
      SENSORS.forEach(function(s) {
        ['', 'm'].forEach(function(suffix) {
          [24, 168, 720, 1080].forEach(function(v) {
            var b = document.getElementById('mmtog-' + v + suffix + '-' + s.id);
            if (b) b.classList.remove('active');
          });
          var cb = document.getElementById('mmtog-custom' + suffix + '-' + s.id);
          if (cb) cb.classList.add('active');
        });
      });
    }
    close();
    applyHistoryRange();
  }

  // ── Wire up modal internal events (called once on DOMContentLoaded) ──────────
  function bindModalEvents() {
    var modal = _getModal();
    if (!modal) return;

    _getEl('customRangeClose')  && _getEl('customRangeClose').addEventListener('click', close);
    _getEl('customRangeCancel') && _getEl('customRangeCancel').addEventListener('click', close);
    _getEl('customRangeApply')  && _getEl('customRangeApply').addEventListener('click', apply);
    _getEl('crPrev') && _getEl('crPrev').addEventListener('click', _prevMonth);
    _getEl('crNext') && _getEl('crNext').addEventListener('click', _nextMonth);

    // Preset buttons
    modal.addEventListener('click', function(e) {
      var preset = e.target.closest('[data-cr-preset]');
      if (preset) _onPreset(preset.getAttribute('data-cr-preset'));
    });

    // Close on backdrop click
    modal.addEventListener('click', function(e) {
      if (e.target === modal) close();
    });

    // Keyboard Escape
    document.addEventListener('keydown', function(e) {
      if (e.key === 'Escape') {
        var m = _getModal();
        if (m && !m.classList.contains('hidden')) close();
      }
    });
  }

  return { open: open, close: close, apply: apply, bindModalEvents: bindModalEvents };
})();

// CSV export
