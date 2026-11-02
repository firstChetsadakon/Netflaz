// Protocol tests for the sync server. Starts its own server on TEST_PORT.
//   cd server && npm install && npm test
import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { fileURLToPath } from "node:url";
import path from "node:path";
import { WebSocket } from "ws";

const PORT = Number(process.env.TEST_PORT || 18080);
const URL = `ws://localhost:${PORT}`;
const SERVER = path.join(path.dirname(fileURLToPath(import.meta.url)), "..", "server.js");

let server;
let roomSeq = 0;

before(async () => {
  server = spawn(process.execPath, [SERVER], {
    env: { ...process.env, PORT: String(PORT) },
    stdio: ["ignore", "pipe", "pipe"],
  });
  await new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error("server did not start")), 5000);
    server.stdout.on("data", (d) => {
      if (String(d).includes("listening")) {
        clearTimeout(timer);
        resolve();
      }
    });
    server.on("exit", (code) => reject(new Error(`server exited (${code})`)));
  });
});

after(() => server && server.kill());

function room() {
  roomSeq += 1;
  return `T${process.pid}-${roomSeq}`;
}

async function client(roomId, userId, userName) {
  const ws = new WebSocket(URL);
  const inbox = [];
  ws.on("message", (raw) => inbox.push(JSON.parse(raw.toString())));
  await new Promise((resolve, reject) => {
    ws.once("open", resolve);
    ws.once("error", reject);
  });
  const send = (m) =>
    ws.send(JSON.stringify({ roomId, userId, userName, sentAt: Date.now(), ...m }));
  const waitFor = async (pred, timeout = 2000) => {
    const end = Date.now() + timeout;
    while (Date.now() < end) {
      const hit = inbox.find(pred);
      if (hit) return hit;
      await new Promise((r) => setTimeout(r, 20));
    }
    throw new Error("timed out waiting for message");
  };
  const lastRoster = () => [...inbox].reverse().find((m) => m.type === "roster");
  return { ws, inbox, send, waitFor, lastRoster, close: () => ws.close() };
}

async function pair() {
  const roomId = room();
  const host = await client(roomId, "host-1", "Host");
  host.send({ type: "join", text: "host", url: "https://example.com/watch/1", title: "Movie" });
  await host.waitFor((m) => m.type === "hello");
  const viewer = await client(roomId, "viewer-1", "Viewer");
  viewer.send({ type: "join", text: "viewer", url: "https://example.com/watch/1", title: "Movie" });
  await host.waitFor((m) => m.type === "roster" && m.roster.length === 2);
  await viewer.waitFor((m) => m.type === "roster" && m.roster.length === 2);
  return { host, viewer, roomId };
}

const settle = (ms = 150) => new Promise((r) => setTimeout(r, ms));

test("first host claim wins; roster carries page url and title", async () => {
  const { host, viewer } = await pair();
  const roster = host.lastRoster().roster;
  assert.equal(roster.find((r) => r.userId === "host-1").isHost, true);
  assert.equal(roster.find((r) => r.userId === "viewer-1").isHost, false);
  assert.equal(roster[0].url, "https://example.com/watch/1");
  assert.equal(roster[0].title, "Movie");
  host.close();
  viewer.close();
});

test("a second host claim in the same room becomes a viewer", async () => {
  const { host, viewer, roomId } = await pair();
  const late = await client(roomId, "late-1", "Late");
  late.send({ type: "join", text: "host" });
  const roster = await late.waitFor((m) => m.type === "roster" && m.roster.length === 3);
  assert.equal(roster.roster.find((r) => r.userId === "late-1").isHost, false);
  [host, viewer, late].forEach((c) => c.close());
});

test("transport events are relayed with their time and not echoed to the sender", async () => {
  const { host, viewer } = await pair();
  host.send({ type: "play", time: 12.5, isPlaying: true });
  host.send({ type: "seek", time: 90, isPlaying: true });
  host.send({ type: "sync", time: 95.2, isPlaying: true });
  assert.equal((await viewer.waitFor((m) => m.type === "play")).time, 12.5);
  assert.equal((await viewer.waitFor((m) => m.type === "seek")).time, 90);
  const sync = await viewer.waitFor((m) => m.type === "sync");
  assert.equal(sync.time, 95.2);
  assert.equal(sync.isPlaying, true);
  await settle();
  assert.equal(host.inbox.filter((m) => ["play", "seek", "sync"].includes(m.type)).length, 0);
  host.close();
  viewer.close();
});

test("chat is relayed (unicode intact) and not echoed", async () => {
  const { host, viewer } = await pair();
  viewer.send({ type: "chat", text: "สวัสดีครับ" });
  assert.equal((await host.waitFor((m) => m.type === "chat")).text, "สวัสดีครับ");
  await settle();
  assert.equal(viewer.inbox.filter((m) => m.type === "chat").length, 0);
  host.close();
  viewer.close();
});

test("leave followed by socket close is processed once", async () => {
  const { host, viewer } = await pair();
  viewer.send({ type: "leave" });
  viewer.close();
  await host.waitFor((m) => m.type === "leave" && m.userId === "viewer-1");
  await settle(300);
  assert.equal(host.inbox.filter((m) => m.type === "leave").length, 1);
  assert.equal(host.lastRoster().roster.length, 1);
  host.close();
});

test("when the host leaves, the remaining member is promoted", async () => {
  const { host, viewer } = await pair();
  host.send({ type: "leave" });
  host.close();
  const roster = await viewer.waitFor(
    (m) => m.type === "roster" && m.roster.length === 1 && m.roster[0].isHost
  );
  assert.equal(roster.roster[0].userId, "viewer-1");
  viewer.close();
});

test("ping gets a pong that echoes clientTime and adds serverTime", async () => {
  const c = await client(room(), "solo", "Solo");
  const t0 = Date.now();
  c.send({ type: "ping", clientTime: t0 });
  const pong = await c.waitFor((m) => m.type === "pong");
  assert.equal(pong.clientTime, t0);
  assert.equal(typeof pong.serverTime, "number");
  assert.ok(Math.abs(pong.serverTime - Date.now()) < 1000);
  c.close();
});

test("server stamps serverTime when missing and keeps the sender's own", async () => {
  const { host, viewer } = await pair();
  host.send({ type: "play", time: 30, isPlaying: true });
  const stamped = await viewer.waitFor((m) => m.type === "play");
  assert.equal(typeof stamped.serverTime, "number");

  const sampleAt = Date.now() - 500;
  host.send({ type: "sync", time: 42, isPlaying: true, serverTime: sampleAt });
  const kept = await viewer.waitFor((m) => m.type === "sync");
  assert.equal(kept.serverTime, sampleAt);
  host.close();
  viewer.close();
});

test("malformed frames are ignored and the connection stays usable", async () => {
  const c = await client(room(), "solo", "Solo");
  c.ws.send("not json");
  c.ws.send(JSON.stringify({ no: "type" }));
  c.send({ type: "ping", clientTime: 1 });
  assert.equal((await c.waitFor((m) => m.type === "pong")).clientTime, 1);
  c.close();
});
