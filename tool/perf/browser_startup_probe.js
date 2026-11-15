// Local profile-build instrumentation; no network or production changes.
(() => {
  const p = window.__songbriefProbe = {frames: [], longTasks: [], inputs: [], visibility: [{t: performance.now(), state: document.visibilityState}], firstFlutterFrame: null};
  for (const type of ['pointerdown', 'pointerup', 'wheel']) {
    addEventListener(type, e => p.inputs.push({type, t: performance.now(), x: e.clientX, y: e.clientY}), {capture: true, passive: true});
  }
  addEventListener('flutter-first-frame', () => p.firstFlutterFrame = performance.now());
  document.addEventListener('visibilitychange', () => p.visibility.push({t: performance.now(), state: document.visibilityState}));
  new PerformanceObserver(list => list.getEntries().forEach(e => p.longTasks.push({start: e.startTime, duration: e.duration}))).observe({type: 'longtask', buffered: true});
  p.marks = [];
  p.spans = [];
  const starts = new Map();
  new PerformanceObserver(list => {
    for (const e of list.getEntries()) {
      if (e.name.startsWith('songbrief-')) p.marks.push({name: e.name, start: e.startTime});
      if (!location.search.includes('widget_profile')) continue;
      if (e.name.endsWith('-begin-1')) starts.set(e.name.slice(0, -8), e.startTime);
      else if (e.name.endsWith('-end')) {
        const name = e.name.slice(0, -4), start = starts.get(name);
        if (start !== undefined && e.startTime - start >= 0.5) p.spans.push({name, start, duration: e.startTime - start});
        starts.delete(name);
      }
    }
  }).observe({type: 'mark', buffered: true});
  let last;
  function frame(t) {
    if (last !== undefined) p.frames.push({t, dt: t - last});
    last = t;
    if (t < 600000) requestAnimationFrame(frame);
  }
  requestAnimationFrame(frame);
})();
