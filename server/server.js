// Netflaz — Watch Party sync server
// ----------------------------------
// A tiny WebSocket relay that keeps everyone in a room playing in lock-step
// and carries chat. It stores no media and streams no video; it only passes
// small JSON control messages between the iOS clients.
//
// Protocol (mirror of PartyMessage in the Swift app):
//   { type, roomId, userId, userName, time?, isPlaying?, text?, roster?, sentAt }
//   type ∈ join | leave | play | pause | seek | sync | chat | roster | hello
//
// Run:  cd server && npm install && npm start
// Then point the app's "เซิร์ฟเวอร์ซิงก์" setting at ws://<this-machine-ip>:8080

import { WebSocketServer } from "ws";

const PORT = process.env.PORT || 8080;
const wss = new WebSocketServer({ host: "0.0.0.0", port: PORT });

/** roomId -> Set<ws> */
const rooms = new Map();

function now() {
  return Date.now();
}

function send(ws, message) {
  if (ws.readyState === ws.OPEN) {
    ws.send(JSON.stringify(message));
  }
}

function roomMembers(roomId) {
  return rooms.get(roomId) ?? new Set();
}

function rosterFor(roomId) {
  return [...roomMembers(roomId)].map((client) => ({
    userId: client.userId,
    userName: client.userName,
    isHost: !!client.isHost,
    url: client.pageUrl || "",     // page each member is watching (extension clients)
    title: client.pageTitle || "",
  }));
}

function broadcast(roomId, message, { except } = {}) {
  for (const client of roomMembers(roomId)) {
    if (except && client === except) continue;
    send(client, message);
  }
}

function broadcastRoster(roomId) {
  const message = {
    type: "roster",
    roomId,
    userId: "server",
    userName: "server",
    roster: rosterFor(roomId),
    sentAt: now(),
  };
  broadcast(roomId, message);
}

function join(ws, msg) {
  const roomId = msg.roomId;
  ws.roomId = roomId;
  ws.userId = msg.userId;
  ws.userName = msg.userName || "ผู้ชม";
  ws.pageUrl = typeof msg.url === "string" ? msg.url.slice(0, 2048) : "";
  ws.pageTitle = typeof msg.title === "string" ? msg.title.slice(0, 300) : "";

  if (!rooms.has(roomId)) rooms.set(roomId, new Set());
  const members = rooms.get(roomId);

  // First viewer that asks to host becomes the host; everyone else is a viewer.
  const roomHasHost = [...members].some((c) => c.isHost);
  ws.isHost = msg.text === "host" && !roomHasHost;

  members.add(ws);
  console.log(`[join] ${ws.userName} -> room ${roomId} (host=${ws.isHost}), size=${members.size}`);

  // Tell the newcomer the current room state.
  send(ws, {
    type: "hello",
    roomId,
    userId: "server",
    userName: "server",
    roster: rosterFor(roomId),
    sentAt: now(),
  });

  // Let the others know someone joined, then refresh everyone's roster.
  broadcast(roomId, { ...msg, sentAt: now() }, { except: ws });
  broadcastRoster(roomId);
}

function leave(ws) {
  const roomId = ws.roomId;
  if (!roomId) return;
  // A client that sends "leave" and then closes its socket must only be
  // processed once (otherwise the room sees a duplicate leave + roster).
  ws.roomId = null;
  const members = rooms.get(roomId);
  if (!members || !members.has(ws)) return;

  members.delete(ws);
  console.log(`[leave] ${ws.userName} <- room ${roomId}, size=${members.size}`);

  broadcast(roomId, {
    type: "leave",
    roomId,
    userId: ws.userId,
    userName: ws.userName,
    sentAt: now(),
  });

  if (members.size === 0) {
    rooms.delete(roomId);
  } else {
    // If the host left, promote the oldest remaining member.
    if (ws.isHost) {
      const next = members.values().next().value;
      if (next) next.isHost = true;
    }
    broadcastRoster(roomId);
  }
}

wss.on("connection", (ws) => {
  ws.isAlive = true;
  ws.on("pong", () => (ws.isAlive = true));

  ws.on("message", (raw) => {
    let msg;
    try {
      msg = JSON.parse(raw.toString());
    } catch {
      return; // ignore malformed frames
    }
    if (!msg || typeof msg.type !== "string") return;

    switch (msg.type) {
      case "join":
        join(ws, msg);
        break;
      case "leave":
        leave(ws);
        break;
      // Clock sync: reply directly to the sender with a server timestamp.
      case "ping":
        send(ws, {
          type: "pong",
          roomId: msg.roomId,
          userId: "server",
          userName: "server",
          clientTime: msg.clientTime,
          serverTime: now(),
          sentAt: now(),
        });
        break;
      // Transport + sync carry a sample time on the shared (server) clock so
      // receivers can compensate for in-flight latency. If the sender hasn't
      // finished clock-syncing yet, stamp it here as a best-effort fallback.
      case "play":
      case "pause":
      case "seek":
      case "sync":
        if (ws.roomId) {
          if (msg.serverTime == null) msg.serverTime = now();
          broadcast(ws.roomId, msg, { except: ws });
        }
        break;
      case "chat":
        if (ws.roomId) broadcast(ws.roomId, msg, { except: ws });
        break;
      default:
        break;
    }
  });

  ws.on("close", () => leave(ws));
  ws.on("error", () => leave(ws));
});

// Heartbeat: drop dead connections so rooms stay clean.
const heartbeat = setInterval(() => {
  for (const client of wss.clients) {
    if (client.isAlive === false) {
      leave(client);
      client.terminate();
      continue;
    }
    client.isAlive = false;
    try { client.ping(); } catch { /* ignore */ }
  }
}, 30000);

wss.on("close", () => clearInterval(heartbeat));

console.log(`Netflaz Watch Party server listening on ws://0.0.0.0:${PORT}`);
