// Netflaz Party — popup: create / join / leave a room for the current tab.

const $ = (id) => document.getElementById(id);
const DEFAULT_SERVER = "ws://localhost:8080";

function randomCode() {
  const letters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  let s = "";
  for (let i = 0; i < 5; i++) s += letters[Math.floor(Math.random() * letters.length)];
  return s;
}

function showError(text) {
  $("error").textContent = text || "";
  $("error").hidden = !text;
}

function render(st) {
  const active = !!(st && st.active);
  $("idle").hidden = active;
  $("active").hidden = !active;
  if (!active) return;

  const s = $("status");
  if (st.status === "connected") {
    s.textContent = `เชื่อมต่อแล้ว · ${st.isHost ? "คุณเป็นโฮสต์" : "ผู้ชม"}` + (st.rtt > 0 ? ` · ~${st.rtt}ms` : "");
    s.classList.remove("bad");
  } else if (st.status === "connecting") {
    s.textContent = "กำลังเชื่อมต่อ…";
    s.classList.remove("bad");
  } else {
    s.textContent = st.error || "ไม่ได้เชื่อมต่อ";
    s.classList.add("bad");
  }
  $("roomCode").textContent = st.roomId;

  const ul = $("people");
  ul.textContent = "";
  (st.participants || []).forEach((p) => {
    const li = document.createElement("li");
    li.textContent = (p.isHost ? "👑 " : "") + p.userName + (p.userId === st.me ? " (คุณ)" : "");
    ul.appendChild(li);
  });
}

async function refresh() {
  try {
    render(await chrome.runtime.sendMessage({ cmd: "status" }));
  } catch {
    render({ active: false });
  }
}

async function start(isHost) {
  showError("");
  const userName = $("name").value.trim();
  const roomId = $("room").value.trim().toUpperCase();
  const serverURL = $("server").value.trim() || DEFAULT_SERVER;
  if (!roomId) return showError("ใส่รหัสห้องก่อน");
  if (!/^wss?:\/\//.test(serverURL)) return showError("ที่อยู่เซิร์ฟเวอร์ต้องขึ้นต้นด้วย ws:// หรือ wss://");

  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  if (!tab || !/^https?:/.test(tab.url || "")) {
    return showError("ใช้ได้กับหน้าเว็บ http/https ที่มีวิดีโอเท่านั้น");
  }

  await chrome.storage.local.set({ name: userName, server: serverURL });

  $("create").disabled = $("join").disabled = true;
  try {
    const st = await chrome.runtime.sendMessage({
      cmd: "join",
      tabId: tab.id,
      roomId,
      userName,
      serverURL,
      isHost,
    });
    if (st && st.error && !st.active) showError(st.error);
    render(st);
  } catch (e) {
    showError(String((e && e.message) || e));
  } finally {
    $("create").disabled = $("join").disabled = false;
  }
}

$("dice").addEventListener("click", () => ($("room").value = randomCode()));
$("create").addEventListener("click", () => start(true));
$("join").addEventListener("click", () => start(false));
$("leave").addEventListener("click", async () => {
  render(await chrome.runtime.sendMessage({ cmd: "leave" }));
});
$("copy").addEventListener("click", async () => {
  try {
    await navigator.clipboard.writeText($("roomCode").textContent);
    $("copy").textContent = "คัดลอกแล้ว";
  } catch {
    $("copy").textContent = "คัดลอกไม่ได้";
  }
});

(async () => {
  const saved = await chrome.storage.local.get(["name", "server"]);
  $("name").value = saved.name || "";
  $("server").value = saved.server || DEFAULT_SERVER;
  $("room").value = randomCode();
  await refresh();
  setInterval(refresh, 1000);
})();
