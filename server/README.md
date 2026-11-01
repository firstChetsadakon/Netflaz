# Netflaz — Watch Party sync server

A minimal WebSocket relay that keeps everyone in a room playing in sync and
carries the chat. It stores **no media** and streams **no video** — it only
passes small JSON control messages between the iOS clients.

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

## Connect the app to it

In the app's **ตั้งค่า (Settings)** tab, set **เซิร์ฟเวอร์ซิงก์** to:

- **iOS Simulator:** `ws://localhost:8080`
- **Real device:** `ws://<your-computer-LAN-IP>:8080`
  (e.g. `ws://192.168.1.20:8080` — make sure the phone and computer are on the
  same Wi‑Fi). Find your IP with `ipconfig getifaddr en0` on macOS.

Change the port with an env var: `PORT=9000 npm start`.

## Protocol

Every frame is one JSON object mirroring `PartyMessage` in the Swift app:

```jsonc
{
  "type": "join|leave|play|pause|seek|sync|chat|roster|hello",
  "roomId": "ABCDE",
  "userId": "uuid",
  "userName": "First",
  "time": 42.5,        // playback position (seconds), for transport events
  "isPlaying": true,
  "text": "hello",     // chat body, or "host"/"viewer" on join
  "roster": [ ... ],   // server -> clients, current participants
  "sentAt": 1730000000000
}
```

- `join` registers a client in a room. The first client that joins as `host`
  becomes the host; everyone else is a viewer.
- `play` / `pause` / `seek` / `sync` / `chat` are relayed to everyone else in
  the same room (never echoed back to the sender).
- The server sends `hello` (room state) to a newcomer and broadcasts `roster`
  whenever membership changes. If the host leaves, the oldest remaining member
  is promoted.

## Deploying for real (optional)

For use outside your LAN, put this behind TLS (a reverse proxy such as Caddy or
nginx terminating `wss://`) and point the app at `wss://your-host`. iOS requires
secure WebSockets for non-local connections.
