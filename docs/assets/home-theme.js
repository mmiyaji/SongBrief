// Runs before the page draws: applies the saved light/dark choice and hides the page until English text is in place.
(function () {
  var root = document.documentElement;
  try {
    var saved = localStorage.getItem('songbrief-site-theme');
    if (saved === 'light' || saved === 'dark') root.dataset.theme = saved;
  } catch (e) { /* storage may be unavailable */ }
})();
