// The header names the realm being managed, so changes to master are hard to make by accident.
// The admin console keeps the realm as the first part of the address: #/<realm>/...
function markRealm() {
  var m = location.hash.match(/^#\/([^/?]+)/);
  var realm = m ? decodeURIComponent(m[1]) : "master";
  document.documentElement.dataset.ccRealm = realm === "master" ? "master" : "other";
}

// The console's router changes the address with history.pushState/replaceState, which fire no
// event, so wrap them; popstate and hashchange cover back/forward and typed addresses.
["pushState", "replaceState"].forEach(function (name) {
  var original = history[name];
  history[name] = function () {
    var result = original.apply(this, arguments);
    markRealm();
    return result;
  };
});
window.addEventListener("popstate", markRealm);
window.addEventListener("hashchange", markRealm);
markRealm();

// Keycloak's Save/Revert bar is fixed to the bottom of the window across its full width. Line it up
// with the main glass panel instead: same left edge, width and bottom (follows resizes and the side
// menu collapsing).
function fitSaveBar() {
  var bar = document.querySelector('[class*="_buttonGroup_"]');
  var panel = document.querySelector(".pf-v5-c-page__main");
  if (!bar || !panel) return;
  var r = panel.getBoundingClientRect();
  bar.style.left = r.left + "px";
  bar.style.width = r.width + "px";
  bar.style.bottom = Math.max(0, window.innerHeight - r.bottom) + "px";
  bar.style.marginLeft = "0";
}
setInterval(fitSaveBar, 250);
window.addEventListener("resize", fitSaveBar);
