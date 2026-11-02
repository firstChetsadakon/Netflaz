// Netflaz Party — content script
// --------------------------------
// Injected (only when the user clicks the extension) into the tab being
// watched. It:
//   • finds the page's <video> and reports play / pause / seek to the room;
//   • applies the room's play / pause / seek without echoing them back;
//   • shows a chat sidebar.
// It never reads forms or credentials and never touches the media stream.

(() => {
  if (window.__netflazParty) {
    window.__netflazParty.refresh();
    return;
  }

  const DRIFT = 0.4;        // seconds of drift tolerated before a sync seek
  const MIN_SEEK = 0.3;     // ignore seeks smaller than this (avoids ping-pong)
  const SUPPRESS_MS = 2500; // how long we wait for the echo of a remote action

  let video = null;
  let active = true;
  let host = null;   // sidebar host element
  let ui = null;     // references into the shadow DOM

  // ---------------- echo suppression ----------------
  // When we apply a remote action, the <video> fires the same event a user
  // action would. We "arm" an expectation and swallow the matching event so
  // it isn't re-broadcast. Expectations expire so a real user action is never
  // swallowed by a stale one.
  const suppress = { play: 0, pause: 0, seek: null, expires: 0 };

  function arm(kind, value) {
    if (kind === "seek") suppress.seek = value;
    else suppress[kind] += 1;
    suppress.expires = Date.now() + SUPPRESS_MS;
  }

  function expired() {
    if (Date.now() <= suppress.expires) return false;
    suppress.play = 0;
    suppress.pause = 0;
    suppress.seek = null;
    return true;
  }

  function consume(kind) {
    if (expired()) return false;
    if (suppress[kind] > 0) {
      suppress[kind] -= 1;
      return true;
    }
    return false;
  }

  // ---------------- video binding ----------------

  function findVideo() {
    const vids = Array.from(document.querySelectorAll("video"));
    if (vids.length <= 1) return vids[0] || null;
    // Prefer the biggest one (the main player rather than a preview).
    return vids.sort(
      (a, b) => b.clientWidth * b.clientHeight - a.clientWidth * a.clientHeight
    )[0];
  }

  function ensureVideo() {
    const v = findVideo();
    if (v && v !== video) bind(v);
    return video;
  }

  function bind(v) {
    if (video) {
      video.removeEventListener("play", onPlay);
      video.removeEventListener("pause", onPause);
      video.removeEventListener("seeked", onSeeked);
    }
    video = v;
    v.addEventListener("play", onPlay);
    v.addEventListener("pause", onPause);
    v.addEventListener("seeked", onSeeked);
  }

  // Players often swap the <video> element (next episode, ads, quality change).
  setInterval(ensureVideo, 1000);

  function onPlay() {
    if (!active || consume("play")) return;
    report("play");
  }

  function onPause() {
    if (!active || consume("pause")) return;
    report("pause");
  }

  function onSeeked() {
    if (!active) return;
    if (
      !expired() &&
      suppress.seek != null &&
      Math.abs(video.currentTime - suppress.seek) < 1.0
    ) {
      suppress.seek = null;
      return;
    }
    report("seek");
  }

  function report(type) {
    if (!video) return;
    chrome.runtime
      .sendMessage({
        cmd: "local",
        type,
        time: video.currentTime,
        playing: !video.paused,
        sampledAt: Date.now(),
      })
      .catch(() => {});
  }

  // ---------------- applying remote actions ----------------

  function usesNetflixAdapter() {
    return document.documentElement.dataset.netflazNetflix === "1";
  }

  function seekTo(t) {
    if (!video || t == null || !isFinite(t)) return;
    if (Math.abs(video.currentTime - t) < MIN_SEEK) return;
    arm("seek", t);
    if (usesNetflixAdapter()) {
      // Netflix's player errors if currentTime is set directly; ask its own
      // player to seek instead (see netflix-main.js).
      window.postMessage(
        { source: "netflaz-content", type: "seek", ms: Math.round(t * 1000) },
        "*"
      );
    } else {
      video.currentTime = t;
    }
  }

  function playIt() {
    arm("play");
    const r = video.play();
    if (r && typeof r.catch === "function") {
      r.catch(() => {
        suppress.play = Math.max(0, suppress.play - 1);
        toast("เบราว์เซอร์ไม่ให้เล่นอัตโนมัติ — กดเล่นเองหนึ่งครั้งเพื่อตามเพื่อน");
      });
    }
  }

  function pauseIt() {
    arm("pause");
    video.pause();
  }

  function apply(m) {
    const v = ensureVideo();
    if (!v) {
      toast("ยังไม่เจอวิดีโอบนหน้านี้");
      return;
    }
    switch (m.type) {
      case "play":
        seekTo(m.time);
        if (v.paused) playIt();
        if (m.by) addSystem(`${m.by} กดเล่น`);
        break;
      case "pause":
        if (!v.paused) pauseIt();
        seekTo(m.time);
        if (m.by) addSystem(`${m.by} กดหยุด`);
        break;
      case "seek":
        seekTo(m.time);
        if (m.by) addSystem(`${m.by} เลื่อนไปที่ ${fmt(m.time)}`);
        break;
      case "sync":
        if (m.time != null && Math.abs(v.currentTime - m.time) > DRIFT) seekTo(m.time);
        if (m.playing && v.paused) playIt();
        else if (!m.playing && !v.paused) pauseIt();
        break;
    }
  }

  // Failure report from the page-world adapter.
  window.addEventListener("message", (e) => {
    if (e.source !== window || !e.data || e.data.source !== "netflaz-main") return;
    if (e.data.type === "seekFailed") {
      suppress.seek = null;
      toast("เลื่อนเวลาอัตโนมัติไม่สำเร็จ — เลื่อนเองตามเวลาที่แจ้งในแชต");
    }
  });

  // ---------------- messages from the background ----------------

  chrome.runtime.onMessage.addListener((msg, sender, sendResponse) => {
    switch (msg.cmd) {
      case "getState": {
        const v = ensureVideo();
        sendResponse(
          v
            ? { hasVideo: true, time: v.currentTime, playing: !v.paused, sampledAt: Date.now() }
            : { hasVideo: false }
        );
        return;
      }
      case "apply":
        if (active) apply(msg);
        return;
      case "chat":
        addChat(msg.userName, msg.text, false);
        return;
      case "system":
        addSystem(msg.text);
        return;
      case "roster":
        renderRoster(msg.roster, msg.me);
        return;
      case "status":
        renderStatus(msg);
        return;
      case "ended":
        teardown();
        return;
    }
  });

  // ---------------- sidebar UI (shadow DOM) ----------------

  const STYLE = `
    :host { all: initial; }
    * { box-sizing: border-box; font-family: -apple-system, "Segoe UI", "Noto Sans Thai", sans-serif; }
    .wrap { position: fixed; top: 0; right: 0; height: 100vh; display: flex; align-items: flex-start; pointer-events: none; }
    .toggle { pointer-events: auto; margin-top: 72px; width: 40px; height: 40px; border: 0; border-radius: 10px 0 0 10px;
      background: #E50914; color: #fff; font-size: 18px; cursor: pointer; }
    .panel { pointer-events: auto; width: 300px; height: 100vh; background: rgba(15,15,15,.94); color: #eee;
      display: flex; flex-direction: column; border-left: 1px solid #2a2a2a; }
    .collapsed .panel { display: none; }
    header { padding: 12px 14px 8px; border-bottom: 1px solid #2a2a2a; }
    .title { font-weight: 700; font-size: 15px; color: #fff; }
    .meta { font-size: 12px; color: #aaa; margin-top: 2px; }
    .meta.err { color: #ff6b6b; }
    .people { padding: 8px 14px; font-size: 12px; color: #ccc; border-bottom: 1px solid #2a2a2a; line-height: 1.6; }
    .warn { margin: 8px 14px 0; padding: 8px 10px; font-size: 12px; background: #3a2a00; color: #ffd27a; border-radius: 8px; }
    .warn[hidden] { display: none; }
    .log { list-style: none; margin: 0; padding: 10px 14px; flex: 1; overflow-y: auto; font-size: 13px; }
    .log li { margin: 0 0 8px; line-height: 1.4; word-wrap: break-word; }
    .log .who { font-weight: 700; color: #E50914; margin-right: 6px; }
    .log .mine .who { color: #4da3ff; }
    .log .sys { color: #888; font-size: 12px; text-align: center; }
    form { display: flex; gap: 6px; padding: 10px; border-top: 1px solid #2a2a2a; }
    input { flex: 1; min-width: 0; padding: 9px 10px; border-radius: 8px; border: 1px solid #333; background: #1f1f1f; color: #fff; font-size: 13px; }
    button.send { padding: 0 12px; border: 0; border-radius: 8px; background: #E50914; color: #fff; font-weight: 600; cursor: pointer; }
    .toast { position: fixed; left: 50%; bottom: 80px; transform: translateX(-50%); background: rgba(0,0,0,.85);
      color: #fff; padding: 10px 14px; border-radius: 10px; font-size: 13px; pointer-events: none; max-width: 80vw; }
  `;

  function el(tag, cls, text) {
    const n = document.createElement(tag);
    if (cls) n.className = cls;
    if (text != null) n.textContent = text; // always text, never HTML
    return n;
  }

  function mount() {
    if (host && host.isConnected) return;
    host = document.createElement("div");
    host.id = "netflaz-party-root";
    const shadow = host.attachShadow({ mode: "open" });

    const style = document.createElement("style");
    style.textContent = STYLE;

    const wrap = el("div", "wrap");
    const toggle = el("button", "toggle", "💬");
    toggle.title = "Netflaz Party";
    const panel = el("aside", "panel");
    const header = el("header");
    const title = el("div", "title", "Netflaz Party");
    const meta = el("div", "meta", "กำลังเชื่อมต่อ…");
    header.append(title, meta);
    const people = el("div", "people");
    const warn = el("div", "warn");
    warn.hidden = true;
    const log = el("ol", "log");
    const form = el("form");
    const input = el("input");
    input.placeholder = "พิมพ์ข้อความ…";
    input.maxLength = 500;
    const sendBtn = el("button", "send", "ส่ง");
    sendBtn.type = "submit";
    form.append(input, sendBtn);
    panel.append(header, people, warn, log, form);
    wrap.append(toggle, panel);
    shadow.append(style, wrap);

    toggle.addEventListener("click", () => wrap.classList.toggle("collapsed"));

    // Keep typing inside the chat from triggering the player's keyboard
    // shortcuts (space = pause, f = fullscreen, arrows = seek…).
    ["keydown", "keyup", "keypress"].forEach((t) =>
      input.addEventListener(t, (e) => e.stopPropagation())
    );

    form.addEventListener("submit", (e) => {
      e.preventDefault();
      const text = input.value.trim();
      if (!text) return;
      chrome.runtime.sendMessage({ cmd: "chat", text }).catch(() => {});
      addChat("คุณ", text, true);
      input.value = "";
    });

    ui = { shadow, wrap, meta, people, warn, log };
    placeHost();
  }

  // In fullscreen only descendants of the fullscreen element are visible, so
  // move the sidebar inside it.
  function placeHost() {
    if (!host) return;
    const fs = document.fullscreenElement;
    const parent = fs && fs.tagName !== "VIDEO" ? fs : document.body || document.documentElement;
    if (host.parentNode !== parent) parent.appendChild(host);
  }
  document.addEventListener("fullscreenchange", placeHost);

  function teardown() {
    active = false;
    if (host) host.remove();
    host = null;
    ui = null;
  }

  function addLine(li) {
    if (!ui) return;
    ui.log.appendChild(li);
    while (ui.log.children.length > 200) ui.log.firstChild.remove();
    ui.log.scrollTop = ui.log.scrollHeight;
  }

  function addChat(name, text, mine) {
    const li = el("li", mine ? "mine" : "");
    li.append(el("span", "who", name || "?"), el("span", "", text || ""));
    addLine(li);
  }

  function addSystem(text) {
    if (text) addLine(el("li", "sys", text));
  }

  function renderStatus(st) {
    if (!ui || !st) return;
    let text = `ห้อง ${st.roomId} · ${st.isHost ? "โฮสต์" : "ผู้ชม"}`;
    if (st.status === "connected") {
      if (st.rtt > 0) text += ` · ~${st.rtt}ms`;
    } else if (st.status === "connecting") {
      text += " · กำลังเชื่อมต่อ…";
    } else {
      text += " · ไม่ได้เชื่อมต่อ";
    }
    ui.meta.textContent = st.error && st.status !== "connected" ? st.error : text;
    ui.meta.classList.toggle("err", !!st.error && st.status !== "connected");
  }

  function pageKey(u) {
    try {
      const x = new URL(u);
      return x.origin + x.pathname;
    } catch {
      return "";
    }
  }

  function renderRoster(roster, me) {
    if (!ui || !Array.isArray(roster)) return;
    ui.people.textContent = "";
    ui.people.append(el("div", "", `ในห้อง ${roster.length} คน`));
    roster.forEach((r) => {
      const label = (r.isHost ? "👑 " : "• ") + r.userName + (r.userId === me ? " (คุณ)" : "");
      ui.people.append(el("div", "", label));
    });

    // Everyone needs to be on the same title. Warn if we aren't.
    const hostEntry = roster.find((r) => r.isHost);
    const mismatch =
      hostEntry &&
      hostEntry.userId !== me &&
      hostEntry.url &&
      pageKey(hostEntry.url) !== pageKey(location.href);
    ui.warn.hidden = !mismatch;
    if (mismatch) {
      ui.warn.textContent = `โฮสต์ดูอยู่ที่: ${hostEntry.title || hostEntry.url} — เปิดเรื่องเดียวกันก่อนนะ`;
    }
  }

  let toastTimer = null;
  function toast(text) {
    if (!ui) return;
    let t = ui.shadow.querySelector(".toast");
    if (!t) {
      t = el("div", "toast");
      ui.shadow.appendChild(t);
    }
    t.textContent = text;
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => t.remove(), 3500);
  }

  function fmt(s) {
    if (s == null || !isFinite(s)) return "?";
    s = Math.max(0, Math.floor(s));
    const h = Math.floor(s / 3600);
    const m = Math.floor((s % 3600) / 60);
    const sec = String(s % 60).padStart(2, "0");
    return h ? `${h}:${String(m).padStart(2, "0")}:${sec}` : `${m}:${sec}`;
  }

  // ---------------- start ----------------

  function refresh() {
    active = true;
    mount();
    ensureVideo();
    chrome.runtime
      .sendMessage({ cmd: "hello" })
      .then((st) => {
        if (st && st.active) {
          renderStatus(st);
          renderRoster(st.participants, st.me);
        }
      })
      .catch(() => {});
  }

  window.__netflazParty = { refresh };
  refresh();
})();
