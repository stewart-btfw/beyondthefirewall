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

  var SAMPLE_COUNT = 5;

  function timedFetch() {
    var start = performance.now();
    return fetch('/cdn-cgi/trace', { cache: 'no-store' })
      .then(function (r) { return r.text(); })
      .then(function (text) {
        return { ms: performance.now() - start, text: text };
      });
  }

  function summarizeLatency(samples) {
    var min = Math.min.apply(null, samples);
    var max = Math.max.apply(null, samples);
    var avg = samples.reduce(function (a, b) { return a + b; }, 0) / samples.length;

    var jitterTotal = 0;
    for (var i = 1; i < samples.length; i++) {
      jitterTotal += Math.abs(samples[i] - samples[i - 1]);
    }
    var jitter = samples.length > 1 ? jitterTotal / (samples.length - 1) : 0;

    return Math.round(avg) + ' ms avg (' + Math.round(min) + '–' + Math.round(max) +
      ' ms, jitter ±' + Math.round(jitter) + ' ms, ' + samples.length + ' samples)';
  }

  timedFetch()
    .then(function (first) {
      var data = {};
      first.text.trim().split('\n').forEach(function (line) {
        var i = line.indexOf('=');
        if (i > -1) data[line.slice(0, i)] = line.slice(i + 1);
      });

      set('diag-ip', data.ip);
      set('diag-colo', data.colo);
      set('diag-colo-label', data.colo);
      set('diag-proto', [data.http, data.tls].filter(Boolean).join(' / '));

      var country = data.loc;
      var label = country;
      try {
        label = new Intl.DisplayNames(['en'], { type: 'region' }).of(country) + ' (' + country + ')';
      } catch (e) {}
      set('diag-loc', label);

      var samples = [first.ms];
      var remaining = SAMPLE_COUNT - 1;

      function nextSample() {
        if (remaining <= 0) {
          set('diag-rtt', summarizeLatency(samples));
          return;
        }
        remaining--;
        timedFetch().then(function (r) {
          samples.push(r.ms);
          nextSample();
        }).catch(function () {
          set('diag-rtt', samples.length > 1 ? summarizeLatency(samples) : 'unavailable');
        });
      }
      nextSample();
    })
    .catch(function () {
      set('diag-ip');
      set('diag-loc');
      set('diag-colo');
      set('diag-colo-label');
      set('diag-proto');
      set('diag-rtt');
    });
})();
