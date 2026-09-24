(function () {
  function set(id, value) {
    var el = document.getElementById(id);
    if (el) el.textContent = value || 'unavailable';
  }

  set('diag-browser', navigator.userAgent);
  set('diag-platform', navigator.platform);
  set('diag-screen', screen.width + '×' + screen.height);
  set('diag-lang', navigator.language);
  try {
    set('diag-tz', Intl.DateTimeFormat().resolvedOptions().timeZone);
  } catch (e) {}

  function updateClock() {
    var now = new Date();
    set('diag-date', now.toLocaleDateString(undefined, { weekday: 'short', year: 'numeric', month: 'short', day: 'numeric' }));
    set('diag-time', now.toLocaleTimeString());
  }
  updateClock();
  setInterval(updateClock, 1000);

  fetch('/cdn-cgi/trace')
    .then(function (r) { return r.text(); })
    .then(function (text) {
      var data = {};
      text.trim().split('\n').forEach(function (line) {
        var i = line.indexOf('=');
        if (i > -1) data[line.slice(0, i)] = line.slice(i + 1);
      });

      set('diag-ip', data.ip);
      set('diag-colo', data.colo);
      set('diag-proto', [data.http, data.tls].filter(Boolean).join(' / '));

      var country = data.loc;
      var label = country;
      try {
        label = new Intl.DisplayNames(['en'], { type: 'region' }).of(country) + ' (' + country + ')';
      } catch (e) {}
      set('diag-loc', label);
    })
    .catch(function () {
      set('diag-ip');
      set('diag-loc');
      set('diag-colo');
      set('diag-proto');
    });
})();
