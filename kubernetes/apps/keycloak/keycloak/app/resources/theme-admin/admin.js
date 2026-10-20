// The header names the realm being managed, so changes to master are hard to make by accident.
// The admin console keeps the realm as the first part of the address: #/<realm>/...
function markRealm() {
  var m = location.hash.match(/^#\/([^/?]+)/);
  var realm = m ? decodeURIComponent(m[1]) : "master";
  document.documentElement.dataset.ccRealm = realm === "master" ? "master" : "other";
}
markRealm();
window.addEventListener("hashchange", markRealm);
