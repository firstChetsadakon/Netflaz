# Netflaz — sync server

A minimal WebSocket relay for the **Netflaz Party** browser extension
(`extension/`). It keeps everyone in a room playing in sync and carries the
chat. It stores **no media** and streams **no video**; it only passes small
JSON control messages between clients.

## Requirements

- Node.js 18+

## Run

```bash
cd server
npm install
npm start
```

You should see:

```
Netflaz Watch Party server listening on ws://0.0.0.0:8080
```

Change the port with `PORT=9000 npm start`.

## Point the extension at it

In the extension popup, open **เซิร์ฟเวอร์ซิงก์** and enter:

- Same computer: `ws://localhost:8080`
- Same Wi‑Fi/LAN: `ws://<this-computer-LAN-IP>:8080`
- Friends elsewhere: deploy the server somewhere reachable from the internet and
  put it behind TLS (e.g. a reverse proxy such as Caddy or nginx terminating
  `wss://`), then use `wss://your-host`.

## Protocol

Every frame is one JSON object:

```jsonc
{
  "type": "join|leave|play|pause|seek|sync|chat|roster|hello|ping|pong",
  "roomId": "ABCDE",
  "userId": "uuid",
  "userName": "First",
  "time": 42.5,                 // playback position (seconds), for transport events
  "isPlaying": true,
  "text": "hello",              // chat body, or "host"/"viewer" on join
  "url": "https://…",           // join: page being watched (for same-title checks)
  "title": "…",                 // join: page title
  "roster": [ ... ],            // server -> clients: { userId, userName, isHost, url, title }
  "clientTime": 1730000000000,  // ping: client send time (local clock, ms)
  "serverTime": 1730000000005,  // pong: server clock; transport/sync: sample time on the shared clock
  "sentAt": 1730000000000
}
```

- `join` registers a client in a room. The first client that joins as `host`
  becomes the host; everyone else is a viewer. If the host leaves, the oldest
  remaining member is promoted (clients follow the roster).
- `play` / `pause` / `seek` / `sync` / `chat` are relayed to everyone else in
  the same room (never echoed back to the sender).
- `ping` / `pong` implement clock sync: the server replies to the sender with a
  `pong` echoing `clientTime` and adding `serverTime`, so each client can
  estimate its offset and round-trip time to the shared server clock.
- On relayed `play` / `pause` / `seek` / `sync` the server makes sure a
  `serverTime` (the sample moment on the shared clock) is present, stamping one
  as a fallback if the sender hadn't finished clock sync. Receivers use it to
  compensate for in-flight latency.
- `hello` (room state) goes to a newcomer; `roster` is broadcast whenever
  membership changes. A client that sends `leave` and then closes is processed
  once.
