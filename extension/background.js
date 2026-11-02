// Netflaz Party — background service worker
// ------------------------------------------
// Owns the WebSocket to the sync server, the NTP-style clock sync, and the
// relay between the room and the content script injected into the tab being
// watched. One party at a time.
//
// What this extension does NOT do: it never reads passwords, never touches
// DRM, never fetches or re-streams video. Each viewer watches in their own
// browser with their own account; we only mirror play / pause / seek.

const DEFAULT_SERVER = "ws://localhost:8080";
const HEARTBEAT_MS = 2000; // host -> room authoritative position
const PING_MS = 4000;      // clock sync + keeps the service worker alive

let party = null;

// ---------- clock sync (same math as NTP, symmetric-delay assumption) ----------

function newClock() {
  return { offset: 0, rtt: 0, synced: false, best: Infinity };
}

function serverNow(clock) {
  return Date.now() + clock.offset;
}

function handlePong(clock, clientSend, serverTime) {
  const recv = Date.now();
  const rtt = Math.max(0, recv - clientSend);
  const offset = serverTime - (clientSend + rtt / 2);
  if (!clock.synced || rtt <= clock.best) {
    clock.best = rtt;
    clock.offset = offset;
  } else {
    clock.offset = clock.offset * 0.8 + offset * 0.2;
  }
  clock.best *= 1.05;
  clock.rtt = rtt;
  clock.synced = true;
}

// Advance a remote sample by the time it spent in flight, so we land on the
// sender's *current* position instead of where it was when the packet left.
function compensate(clock, msg) {
  if (msg.time == null) return null;
  if (!clock.synced || msg.serverTime == null) return msg.time;
  const elapsed = Math.max(0, (serverNow(clock) - msg.serverTime) / 1000);
  return msg.time + (msg.isPlaying ? elapsed : 0);
}

// Convert a local Date.now() sample into the shared (server) clock.
function toServerTime(p, sampledAt) {
  return p.clock.synced && sampledAt != null ? sampledAt + p.clock.offset : undefined;
}

// ---------- party lifecycle ----------

async function injectInto(tabId) {
  await chrome.scripting.executeScript({ target: { tabId }, files: ["content.js"] });
  // Optional site adapter that runs in the page's own JS world (no-op on
  // sites that don't need it).
  await chrome.scripting
    .executeScript({ target: { tabId }, files: ["netflix-main.js"], world: "MAIN" })
    .catch(() => {});
}

async function joinParty({ tabId, roomId, userName, serverURL, isHost }) {
  if (party) leaveParty("switch");

  await injectInto(tabId);
  const tab = await chrome.tabs.get(tabId);

  const p = {
    tabId,
    roomId: String(roomId || "").trim().toUpperCase(),
    userName: (userName || "").trim() || "ผู้ชม",
    isHost: !!isHost,
    userId: crypto.randomUUID(),
    serverURL: (serverURL || "").trim() || DEFAULT_SERVER,
    clock: newClock(),
    participants: [],
    status: "connecting",
    error: null,
    pageUrl: tab.url || "",
    pageTitle: tab.title || "",
    timers: [],
    heartbeat: null,
    ws: null,
  };
  party = p;
  connect(p);
  updateBadge();
  return statusOf(p);
}

function connect(p) {
  let ws;
  try {
    ws = new WebSocket(p.serverURL);
  } catch (e) {
    p.status = "closed";
    p.error = "ที่อยู่เซิร์ฟเวอร์ไม่ถูกต้อง: " + p.serverURL;
    pushStatus(p);
    return;
  }
  p.ws = ws;

  ws.onopen = () => {
    if (party !== p) return ws.close();
    p.status = "connected";
    p.error = null;
    send(p, {
      type: "join",
      text: p.isHost ? "host" : "viewer",
      url: p.pageUrl,
      title: p.pageTitle,
    });
    for (let i = 0; i < 4; i++) p.timers.push(setTimeout(() => ping(p), i * 250));
    p.timers.push(setInterval(() => ping(p), PING_MS));
    if (p.isHost) startHeartbeat(p);
    pushStatus(p);
    toTab(p, {
      cmd: "system",
      text: `เข้าห้อง ${p.roomId} แล้ว` + (p.isHost ? " · คุณเป็นโฮสต์" : ""),
    });
    updateBadge();
  };

  ws.onmessage = (ev) => {
    if (party !== p) return;
    let msg;
    try {
      msg = JSON.parse(ev.data);
    } catch {
      return;
    }
    onServerMessage(p, msg);
  };

  ws.onerror = () => {
    if (party !== p) return;
    p.error = "เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ (" + p.serverURL + ")";
  };

  ws.onclose = () => {
    if (party !== p) return;
    p.status = "closed";
    clearTimers(p);
    pushStatus(p);
    toTab(p, { cmd: "system", text: p.error || "หลุดการเชื่อมต่อกับเซิร์ฟเวอร์" });
    updateBadge();
  };
}

function leaveParty(reason) {
  const p = party;
  if (!p) return;
  send(p, { type: "leave" });
  party = null;
  clearTimers(p);
  try {
    p.ws && p.ws.close();
  } catch {}
  if (reason !== "tab") toTab(p, { cmd: "ended" });
  updateBadge();
}

function clearTimers(p) {
  p.timers.forEach((t) => {
    clearTimeout(t);
    clearInterval(t);
  });
  p.timers = [];
  if (p.heartbeat) clearInterval(p.heartbeat);
  p.heartbeat = null;
}

function startHeartbeat(p) {
  if (p.heartbeat) return;
  p.heartbeat = setInterval(() => hostHeartbeat(p), HEARTBEAT_MS);
}

function stopHeartbeat(p) {
  if (p.heartbeat) clearInterval(p.heartbeat);
  p.heartbeat = null;
}

// The server decides who is host (first to claim it; promotes someone if the
// host leaves). Follow its decision.
function applyRole(p, isHost) {
  if (p.isHost === isHost) return;
  p.isHost = isHost;
  if (isHost) {
    startHeartbeat(p);
    toTab(p, { cmd: "system", text: "คุณเป็นโฮสต์ของห้องแล้ว" });
  } else {
    stopHeartbeat(p);
  }
}

// ---------- messaging ----------

function send(p, fields) {
  if (!p.ws || p.ws.readyState !== WebSocket.OPEN) return;
  p.ws.send(
    JSON.stringify({
      roomId: p.roomId,
      userId: p.userId,
      userName: p.userName,
      sentAt: Date.now(),
      ...fields,
    })
  );
}

function ping(p) {
  send(p, { type: "ping", clientTime: Date.now() });
}

async function hostHeartbeat(p) {
  const st = await askTab(p, { cmd: "getState" });
  if (party !== p || !st || !st.hasVideo || st.time == null) return;
  send(p, {
    type: "sync",
    time: st.time,
    isPlaying: st.playing,
    serverTime: toServerTime(p, st.sampledAt),
  });
}

function onServerMessage(p, msg) {
  switch (msg.type) {
    case "pong":
      if (msg.clientTime != null && msg.serverTime != null) {
        handlePong(p.clock, msg.clientTime, msg.serverTime);
      }
      return;
    case "hello":
    case "roster": {
      p.participants = Array.isArray(msg.roster) ? msg.roster : [];
      const me = p.participants.find((r) => r.userId === p.userId);
      if (me) applyRole(p, !!me.isHost);
      toTab(p, { cmd: "roster", roster: p.participants, me: p.userId });
      pushStatus(p);
      updateBadge();
      return;
    }
    case "join":
      toTab(p, { cmd: "system", text: `${msg.userName} เข้าร่วมห้อง` });
      return;
    case "leave":
      toTab(p, { cmd: "system", text: `${msg.userName} ออกจากห้อง` });
      return;
    case "chat":
      if (typeof msg.text === "string") {
        toTab(p, { cmd: "chat", userName: msg.userName, text: msg.text });
      }
      return;
    case "play":
      toTab(p, { cmd: "apply", type: "play", time: compensate(p.clock, msg), playing: true, by: msg.userName });
      return;
    case "pause":
      toTab(p, { cmd: "apply", type: "pause", time: msg.time, playing: false, by: msg.userName });
      return;
    case "seek":
      toTab(p, { cmd: "apply", type: "seek", time: compensate(p.clock, msg), playing: !!msg.isPlaying, by: msg.userName });
      return;
    case "sync":
      if (!p.isHost) {
        toTab(p, { cmd: "apply", type: "sync", time: compensate(p.clock, msg), playing: !!msg.isPlaying });
      }
      return;
  }
}

function toTab(p, msg) {
  chrome.tabs.sendMessage(p.tabId, msg).catch(() => {});
}

function askTab(p, msg) {
  return chrome.tabs.sendMessage(p.tabId, msg).catch(() => null);
}

function statusOf(p) {
  return {
    active: true,
    roomId: p.roomId,
    isHost: p.isHost,
    userName: p.userName,
    status: p.status,
    error: p.error,
    rtt: Math.round(p.clock.rtt),
    participants: p.participants,
    me: p.userId,
    serverURL: p.serverURL,
    tabId: p.tabId,
  };
}

function status() {
  return party ? statusOf(party) : { active: false };
}

function pushStatus(p) {
  toTab(p, { cmd: "status", ...statusOf(p) });
}

function updateBadge() {
  const connected = party && party.status === "connected";
  const text = party ? (connected ? String(Math.max(party.participants.length, 1)) : "…") : "";
  chrome.action.setBadgeText({ text });
  chrome.action.setBadgeBackgroundColor({ color: connected ? "#E50914" : "#666666" });
}

// ---------- events ----------

chrome.runtime.onMessage.addListener((msg, sender, sendResponse) => {
  // From the popup.
  if (msg.cmd === "join") {
    joinParty(msg)
      .then(sendResponse)
      .catch((e) => sendResponse({ active: false, error: String((e && e.message) || e) }));
    return true; // async response
  }
  if (msg.cmd === "leave") {
    leaveParty("user");
    sendResponse(status());
    return;
  }
  if (msg.cmd === "status") {
    sendResponse(status());
    return;
  }

  // From the content script — only the tab we are watching may talk to us.
  if (!party || !sender.tab || sender.tab.id !== party.tabId) return;

  if (msg.cmd === "hello") {
    sendResponse(status());
    return;
  }
  if (msg.cmd === "local") {
    const isPlaying = msg.type === "play" ? true : msg.type === "pause" ? false : !!msg.playing;
    send(party, {
      type: msg.type,
      time: msg.time,
      isPlaying,
      serverTime: toServerTime(party, msg.sampledAt),
    });
    return;
  }
  if (msg.cmd === "chat" && typeof msg.text === "string") {
    const text = msg.text.trim().slice(0, 500);
    if (text) send(party, { type: "chat", text });
  }
});

chrome.tabs.onRemoved.addListener((tabId) => {
  if (party && party.tabId === tabId) leaveParty("tab");
});

chrome.tabs.onUpdated.addListener((tabId, info) => {
  if (!party || party.tabId !== tabId || info.status !== "complete") return;
  // The page may have reloaded. Re-inject (the content script ignores a second
  // install). If we lost access because the tab navigated elsewhere, end the
  // party cleanly.
  const p = party;
  injectInto(tabId)
    .then(() => pushStatus(p))
    .catch(() => {
      if (party === p) leaveParty("tab");
    });
});
