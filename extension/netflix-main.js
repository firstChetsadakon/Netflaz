// Netflaz Party — Netflix seek adapter (runs in the page's own JS world)
// ---------------------------------------------------------------------
// Netflix's web player throws a playback error if a script sets
// <video>.currentTime directly. To seek, we ask Netflix's own in-page player
// to do it — exactly what dragging the scrubber does. This is the same
// approach Teleparty-style extensions use.
//
// Scope, on purpose:
//   • seek only (play/pause go through the standard <video> element);
//   • nothing is read from the page, no network calls, no account access,
//     no DRM involvement;
//   • a no-op on every site that isn't netflix.com.

(() => {
  if (window.__netflazNetflixAdapter) return;
  if (!/(^|\.)netflix\.com$/.test(location.hostname)) return;
  window.__netflazNetflixAdapter = true;

  // Tell the content script (isolated world) to route seeks through us.
  document.documentElement.dataset.netflazNetflix = "1";

  function currentPlayer() {
    try {
      const vp = window.netflix.appContext.state.playerApp.getAPI().videoPlayer;
      const ids = vp.getAllPlayerSessionIds();
      if (!ids || !ids.length) return null;
      const id = ids.find((s) => String(s).startsWith("watch")) || ids[ids.length - 1];
      return vp.getVideoPlayerBySessionId(id);
    } catch (e) {
      return null;
    }
  }

  window.addEventListener("message", (e) => {
    if (e.source !== window || !e.data || e.data.source !== "netflaz-content") return;
    if (e.data.type !== "seek" || typeof e.data.ms !== "number" || !isFinite(e.data.ms)) return;

    const player = currentPlayer();
    try {
      if (!player) throw new Error("player not found");
      player.seek(Math.max(0, Math.round(e.data.ms)));
    } catch (err) {
      window.postMessage({ source: "netflaz-main", type: "seekFailed" }, "*");
    }
  });
})();
