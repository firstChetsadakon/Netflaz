// End-to-end test: two Chromium browsers with the Netflaz Party extension
// loaded, each on a page with a real <video>. "User" actions in one browser
// must be mirrored in the other.
//
//   cd server && npm install          (the test starts server.js itself)
//   cd tests  && npm install && npx playwright install chromium && npm run e2e
//
// In the cloud container Playwright + Chromium are preinstalled: run
// `node tests/extension/e2e.cjs` without `npm install` (a second Playwright
// would not find the preinstalled browser).
const { chromium } = require("playwright");
const { spawn } = require("node:child_process");
const fs = require("node:fs");
const http = require("node:http");
const os = require("node:os");
const path = require("node:path");

const REPO = path.join(__dirname, "..", "..");
const SYNC_PORT = Number(process.env.E2E_SYNC_PORT || 18081);
const WEB_PORT = Number(process.env.E2E_WEB_PORT || 18173);
const PAGE = `http://localhost:${WEB_PORT}/test.html`;
const ROOM = "E2E01";

const results = [];
let failures = 0;
const cleanups = [];
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function check(cond, label) {
  results.push(`${cond ? "PASS" : "FAIL"}  ${label}`);
  if (!cond) failures++;
}

async function waitFor(fn, timeout = 6000, every = 100) {
  const end = Date.now() + timeout;
  while (Date.now() < end) {
    const v = await fn();
    if (v) return v;
    await sleep(every);
  }
  return null;
}

// ---------- fixtures ----------

function makeWorkDir() {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "netflaz-e2e-"));
  cleanups.push(() => fs.rmSync(dir, { recursive: true, force: true }));

  // A 10-minute silent WAV: real, seekable media without codec licensing issues.
  const sr = 8000, secs = 600, n = sr * secs;
  const header = Buffer.alloc(44);
  header.write("RIFF", 0);
  header.writeUInt32LE(36 + n, 4);
  header.write("WAVEfmt ", 8);
  header.writeUInt32LE(16, 16);
  header.writeUInt16LE(1, 20); // PCM
  header.writeUInt16LE(1, 22); // mono
  header.writeUInt32LE(sr, 24);
  header.writeUInt32LE(sr, 28);
  header.writeUInt16LE(1, 32);
  header.writeUInt16LE(8, 34);
  header.write("data", 36);
  header.writeUInt32LE(n, 40);
  const site = path.join(dir, "site");
  fs.mkdirSync(site);
  fs.writeFileSync(path.join(site, "silence.wav"), Buffer.concat([header, Buffer.alloc(n, 0x80)]));
  fs.copyFileSync(path.join(__dirname, "fixtures", "test.html"), path.join(site, "test.html"));

  // Test copy of the extension: same code, plus localhost host access so the
  // harness can inject without a person clicking the toolbar icon.
  const ext = path.join(dir, "ext");
  fs.cpSync(path.join(REPO, "extension"), ext, { recursive: true });
  const manifestPath = path.join(ext, "manifest.json");
  const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
  manifest.host_permissions = ["http://localhost/*"];
  fs.writeFileSync(manifestPath, JSON.stringify(manifest, null, 2));

  return { dir, site, ext };
}

function startStatic(root) {
  const server = http.createServer((req, res) => {
    const file = path.join(root, decodeURIComponent(req.url.split("?")[0]));
    if (!file.startsWith(root) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) {
      res.writeHead(404);
      return res.end();
    }
    const size = fs.statSync(file).size;
    const type = file.endsWith(".html") ? "text/html; charset=utf-8" : "audio/wav";
    const m = /bytes=(\d*)-(\d*)/.exec(req.headers.range || "");
    if (m) {
      const s = m[1] ? +m[1] : 0;
      const e = Math.min(m[2] ? +m[2] : size - 1, size - 1);
      res.writeHead(206, {
        "Content-Type": type,
        "Content-Range": `bytes ${s}-${e}/${size}`,
        "Accept-Ranges": "bytes",
        "Content-Length": e - s + 1,
      });
      fs.createReadStream(file, { start: s, end: e }).pipe(res);
    } else {
      res.writeHead(200, { "Content-Type": type, "Content-Length": size, "Accept-Ranges": "bytes" });
      fs.createReadStream(file).pipe(res);
    }
  });
  cleanups.push(() => server.close());
  return new Promise((resolve) => server.listen(WEB_PORT, resolve));
}

function startSync() {
  if (!fs.existsSync(path.join(REPO, "server", "node_modules", "ws"))) {
    throw new Error("run `npm install` in server/ first");
  }
  const child = spawn(process.execPath, [path.join(REPO, "server", "server.js")], {
    env: { ...process.env, PORT: String(SYNC_PORT) },
    stdio: ["ignore", "pipe", "pipe"],
  });
  cleanups.push(() => child.kill());
  const log = [];
  child.stdout.on("data", (d) => log.push(String(d)));
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error("sync server did not start")), 5000);
    child.stdout.on("data", (d) => {
      if (String(d).includes("listening")) {
        clearTimeout(timer);
        resolve(log);
      }
    });
    child.on("exit", (code) => reject(new Error(`sync server exited (${code})`)));
  });
}

// ---------- browsers ----------

async function launch(name, ext) {
  const profile = fs.mkdtempSync(path.join(os.tmpdir(), `netflaz-${name}-`));
  cleanups.push(() => fs.rmSync(profile, { recursive: true, force: true }));
  const ctx = await chromium.launchPersistentContext(profile, {
    channel: "chromium",
    headless: true,
    args: [
      `--disable-extensions-except=${ext}`,
      `--load-extension=${ext}`,
      "--autoplay-policy=no-user-gesture-required",
      "--mute-audio",
    ],
  });
  cleanups.push(() => ctx.close().catch(() => {}));
  let [sw] = ctx.serviceWorkers();
  if (!sw) sw = await ctx.waitForEvent("serviceworker", { timeout: 10000 });
  const page = await ctx.newPage();
  page.on("pageerror", (e) => console.log(`[${name} pageerror]`, e.message));
  await page.goto(PAGE);
  await page.waitForFunction(() => document.getElementById("v").readyState >= 1);
  return { name, ctx, sw, page };
}

const join = (c, isHost, userName) =>
  c.sw.evaluate(
    async ({ isHost, userName, room, sync, web }) => {
      const [tab] = await chrome.tabs.query({ url: `http://localhost:${web}/*` });
      return joinParty({ tabId: tab.id, roomId: room, userName, serverURL: `ws://localhost:${sync}`, isHost });
    },
    { isHost, userName, room: ROOM, sync: SYNC_PORT, web: WEB_PORT }
  );
const status = (c) => c.sw.evaluate(() => status());
const vid = (c) =>
  c.page.evaluate(() => {
    const v = document.getElementById("v");
    return { t: v.currentTime, paused: v.paused, ev: { ...window.__ev } };
  });
const act = (c, fn) => c.page.evaluate(fn);

// ---------- scenario ----------

async function run() {
  const { site, ext } = makeWorkDir();
  await startStatic(site);
  const syncLog = await startSync();
  const A = await launch("A", ext); // host
  const B = await launch("B", ext); // viewer

  await join(A, true, "Alice");
  await sleep(300);
  await join(B, false, "Bob");
  const both = await waitFor(async () => {
    const [a, b] = await Promise.all([status(A), status(B)]);
    return a.status === "connected" && b.status === "connected" &&
      a.participants.length === 2 && b.participants.length === 2 ? [a, b] : null;
  });
  check(!!both, "both browsers connected, roster shows 2 people");
  check(both && both[0].isHost && !both[1].isHost, "Alice is host, Bob is viewer");
  check((await A.page.locator("#netflaz-party-root .panel").count()) === 1, "chat sidebar injected into the page");

  await act(A, () => document.getElementById("v").play());
  check(!!(await waitFor(async () => !(await vid(B)).paused)), "host play -> viewer starts playing");

  await act(A, () => { document.getElementById("v").currentTime = 120; });
  await sleep(1500);
  let [a, b] = await Promise.all([vid(A), vid(B)]);
  check(Math.abs(a.t - b.t) < 0.5, `host seek to 120s -> viewer follows (A=${a.t.toFixed(2)} B=${b.t.toFixed(2)})`);
  check(a.t > 120 && b.t > 120, "both still playing past the seek point");

  const before = [(await vid(A)).ev.seeked, (await vid(B)).ev.seeked];
  await sleep(3000);
  const after = [(await vid(A)).ev.seeked, (await vid(B)).ev.seeked];
  check(after[0] - before[0] <= 1 && after[1] - before[1] <= 1,
    `no seek ping-pong after settling (A +${after[0] - before[0]}, B +${after[1] - before[1]} in 3s)`);

  await act(B, () => document.getElementById("v").pause());
  const aPaused = await waitFor(async () => (await vid(A)).paused);
  [a, b] = await Promise.all([vid(A), vid(B)]);
  check(!!aPaused, "viewer pause -> host pauses");
  check(Math.abs(a.t - b.t) < 0.5, `paused at the same spot (A=${a.t.toFixed(2)} B=${b.t.toFixed(2)})`);

  await act(B, () => document.getElementById("v").play());
  check(!!(await waitFor(async () => !(await vid(A)).paused)), "viewer play -> host plays");

  // Drift without any seek event; the 2 s host heartbeat must correct it and
  // the correction must not be echoed back to the host.
  await sleep(500);
  const seeksBefore = [(await vid(A)).ev.seeked, (await vid(B)).ev.seeked];
  await act(B, () => { document.getElementById("v").playbackRate = 3; });
  await sleep(2600);
  await act(B, () => { document.getElementById("v").playbackRate = 1; });
  const healed = await waitFor(async () => {
    const [x, y] = await Promise.all([vid(A), vid(B)]);
    return Math.abs(x.t - y.t) < 0.5;
  }, 5000);
  const seeksAfter = [(await vid(A)).ev.seeked, (await vid(B)).ev.seeked];
  check(seeksAfter[1] > seeksBefore[1], `heartbeat corrected the drifting viewer with a seek (B +${seeksAfter[1] - seeksBefore[1]})`);
  check(seeksAfter[0] === seeksBefore[0], "the correction was not echoed back to the host (A +0)");
  check(!!healed, "viewer back within 0.5s of the host");

  const input = B.page.locator("#netflaz-party-root input");
  const hostLog = () => A.page.locator("#netflaz-party-root .log").textContent();
  await input.fill("สวัสดี ดูพร้อมกันนะ");
  await input.press("Enter");
  check(!!(await waitFor(async () => (await hostLog()).includes("สวัสดี ดูพร้อมกันนะ"))),
    "chat typed in viewer sidebar appears in host sidebar");

  const evil = '<img src=x onerror="window.__xss=1">';
  await input.fill(evil);
  await input.press("Enter");
  const shown = await waitFor(async () => (await hostLog()).includes(evil));
  const xss = await A.page.evaluate(() => window.__xss);
  const imgs = await A.page.locator("#netflaz-party-root .log img").count();
  check(!!shown && xss === undefined && imgs === 0, "chat HTML is shown as text, never executed");

  await B.page.evaluate(() => {
    window.__keys = 0;
    document.addEventListener("keydown", () => window.__keys++);
  });
  await input.press("Space");
  await input.press("f");
  check((await B.page.evaluate(() => window.__keys)) === 0, "keystrokes in chat do not reach page shortcuts");

  await A.sw.evaluate(() => leaveParty("user"));
  check(!!(await waitFor(async () => {
    const s = await status(B);
    return s.isHost && s.participants.length === 1;
  })), "host leaves -> remaining viewer becomes host");
  check(!!(await waitFor(async () => (await A.page.locator("#netflaz-party-root").count()) === 0)),
    "leaving removes the sidebar from the page");

  await sleep(300);
  const aliceLeaves = syncLog.join("").split("\n").filter((l) => l.includes("[leave] Alice")).length;
  check(aliceLeaves === 1, `server processed the host's leave once (${aliceLeaves})`);
}

async function cleanup() {
  for (const fn of cleanups.reverse()) {
    try {
      await fn();
    } catch {}
  }
}

run()
  .then(async () => {
    await cleanup();
    console.log(results.join("\n"));
    console.log(`\n${failures === 0 ? "ALL PASS" : failures + " FAILED"} (${results.length} checks)`);
    process.exit(failures === 0 ? 0 : 1);
  })
  .catch(async (e) => {
    await cleanup();
    console.log(results.join("\n"));
    console.error("E2E crashed:", e);
    process.exit(2);
  });
