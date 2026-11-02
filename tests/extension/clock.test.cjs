// Unit tests for the clock-sync and latency-compensation code in
// extension/background.js. The real file is loaded into a Node VM with a
// stubbed `chrome` API and a controllable Date.now().
//   cd tests && npm test
const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const BG = path.join(__dirname, "..", "..", "extension", "background.js");

function loadBackground() {
  let now = 0;
  const listener = { addListener() {} };
  const chrome = {
    runtime: { onMessage: listener },
    tabs: {
      onRemoved: listener,
      onUpdated: listener,
      sendMessage: async () => null,
      get: async () => ({}),
    },
    scripting: { executeScript: async () => [] },
    action: { setBadgeText() {}, setBadgeBackgroundColor() {} },
  };
  const ctx = vm.createContext({
    chrome,
    console,
    crypto: globalThis.crypto,
    setTimeout,
    clearTimeout,
    setInterval,
    clearInterval,
    WebSocket: class {},
    Date: { now: () => now },
  });
  vm.runInContext(fs.readFileSync(BG, "utf8"), ctx, { filename: BG });
  return { bg: ctx, setNow: (t) => (now = t) };
}

const near = (a, b, eps = 1e-6) => Math.abs(a - b) < eps;

test("a pong yields the server offset and round-trip time", () => {
  const { bg, setNow } = loadBackground();
  const clock = bg.newClock();
  // Sent at 1_000_000, back at 1_000_100 (rtt 100). The server clock is 5 s
  // ahead, so at the midpoint (1_000_050 local) it read 1_005_050.
  setNow(1_000_100);
  bg.handlePong(clock, 1_000_000, 1_005_050);
  assert.equal(clock.synced, true);
  assert.equal(clock.rtt, 100);
  assert.ok(near(clock.offset, 5000));
});

test("a slower sample only nudges the offset; a faster one replaces it", () => {
  const { bg, setNow } = loadBackground();
  const clock = bg.newClock();
  setNow(1_000_100);
  bg.handlePong(clock, 1_000_000, 1_005_050); // rtt 100, offset 5000

  setNow(2_000_400);
  bg.handlePong(clock, 2_000_000, 2_005_600); // rtt 400, sample offset 5400
  assert.ok(near(clock.offset, 5000 * 0.8 + 5400 * 0.2), `offset ${clock.offset}`);

  setNow(3_000_050);
  bg.handlePong(clock, 3_000_000, 3_006_025); // rtt 50, sample offset 6000
  assert.ok(near(clock.offset, 6000), `offset ${clock.offset}`);
});

test("a playing sample is advanced by its time in flight", () => {
  const { bg, setNow } = loadBackground();
  const clock = bg.newClock();
  setNow(1_000_100);
  bg.handlePong(clock, 1_000_000, 1_005_050); // offset 5000

  setNow(2_000_000); // shared clock now reads 2_005_000
  const sampledAt = 2_005_000 - 500; // sent 0.5 s ago on the shared clock
  const playing = { time: 42, isPlaying: true, serverTime: sampledAt };
  assert.ok(near(bg.compensate(clock, playing), 42.5));

  const paused = { time: 42, isPlaying: false, serverTime: sampledAt };
  assert.equal(bg.compensate(clock, paused), 42);
});

test("without clock sync or a sample time, the raw time is used", () => {
  const { bg } = loadBackground();
  const unsynced = bg.newClock();
  assert.equal(bg.compensate(unsynced, { time: 42, isPlaying: true, serverTime: 1 }), 42);

  const synced = bg.newClock();
  synced.synced = true;
  assert.equal(bg.compensate(synced, { time: 42, isPlaying: true }), 42);
  assert.equal(bg.compensate(synced, { isPlaying: true, serverTime: 1 }), null);
});

test("a local sample converts to the shared clock only once synced", () => {
  const { bg } = loadBackground();
  const p = { clock: { synced: true, offset: 5000 } };
  assert.equal(bg.toServerTime(p, 123), 5123);
  assert.equal(bg.toServerTime({ clock: { synced: false, offset: 5000 } }, 123), undefined);
  assert.equal(bg.toServerTime(p, undefined), undefined);
});
