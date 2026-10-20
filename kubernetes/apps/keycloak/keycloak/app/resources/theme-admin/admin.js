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
