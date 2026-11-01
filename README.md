# Netflaz 🎬

แอป streaming สไตล์ Netflix สำหรับ **iOS (SwiftUI)** ที่โฟกัสการสาธิต
**หลักการของฟีเจอร์ "ดูด้วยกัน" (Watch Party)** — เล่น / หยุด / เลื่อน
พร้อมกันแบบเรียลไทม์ พร้อมแชตระหว่างดู ซึ่งเป็น pain point ที่อยากแก้

> โปรเจกต์นี้ทำ **เพื่อการศึกษา** เท่านั้น

## ⚖️ ขอบเขตด้านกฎหมาย (อ่านก่อน)

สิ่งที่โปรเจกต์นี้ **ไม่ทำ** และจะไม่ทำ:

- ❌ **ไม่** ถอดรหัส / บายพาส DRM — การหลบเลี่ยงมาตรการคุ้มครองทางเทคโนโลยี
  ผิดกฎหมาย (DMCA §1201, EU Copyright Directive และ พ.ร.บ.ลิขสิทธิ์ของไทย)
- ❌ **ไม่** ใช้ API ภายในของ Netflix และ **ไม่** รับล็อกอินบัญชี Netflix
  (Netflix ปิด public API ตั้งแต่ปี 2014 และการทำ client เถื่อนผิด ToS)

สิ่งที่โปรเจกต์นี้ **ทำ** อย่างถูกต้อง:

- ✅ เล่นเฉพาะ **สื่อแบบเปิด** (Creative Commons / สาธารณสมบัติ) ได้แก่
  Blender Open Movies และคลิปตัวอย่างสาธารณะ — สตรีมได้ถูกกฎหมาย ไม่ต้องมี DRM
- ✅ ซิงก์การเล่นด้วย **WebSocket ที่เขียนเอง** (หลักการเดียวกับ Teleparty /
  Apple SharePlay / Netflix "Watch Together")
- ✅ (ไม่บังคับ) ดึง **เมตาดาตา** หนังจริงจาก [TMDB](https://developer.themoviedb.org)
  ซึ่งเป็น API สาธารณะที่ถูกต้อง — ใช้โชว์รายการเพื่อ "ดูข้อมูล" เท่านั้น เล่นไม่ได้

ถ้าต้องการเสนอไอเดียนี้ให้ Netflix จริง ช่องทางที่ถูกต้องคือ
[Netflix Partner Program](https://partnerhelp.netflixstudios.com) — ไม่ใช่การทำ
client ที่เข้าถึงระบบเขาโดยไม่ได้รับอนุญาต

## ✨ ฟีเจอร์

- หน้าแรกสไตล์ Netflix: แบนเนอร์เด่น + แถวเลื่อนแนวนอน
- หน้ารายละเอียด + เล่นเดี่ยว (AVKit)
- **Watch Party (ในแอป)**: สร้าง/เข้าร่วมห้องด้วยรหัส, ซิงก์ play/pause/seek, แก้
  drift อัตโนมัติตามโฮสต์, รายชื่อผู้ชม และแชตเรียลไทม์
- **Co-Watch แบบเว็บ (Teleparty-style)**: ฝังหน้าเว็บด้วย `WKWebView` แล้วฉีด JS
  ไปเกาะ `<video>` เพื่อซิงก์ข้ามเครื่อง — หลักการเดียวกับส่วนขยาย Teleparty
  (ดู [docs/TELEPARTY-APPROACH.md](docs/TELEPARTY-APPROACH.md))
- **สะพานเชื่อม Netflix ที่ถูกต้อง**: ปุ่ม "ค้นหาใน Netflix" deep-link เข้าแอป
  Netflix ทางการของผู้ใช้ (ไม่มีล็อกอินผ่านเรา/ไม่มี API/ไม่มี DRM)
- รองรับ TMDB แบบไม่บังคับ (ใส่ API key ในแท็บตั้งค่า)

## 🧱 สถาปัตยกรรม

```
Netflaz/
├── Netflaz.xcodeproj/         # โปรเจกต์ Xcode (synchronized folder, Xcode 16+)
├── Config/Info.plist          # ตั้งค่า ATS ให้เชื่อม WebSocket ในเครื่องได้
├── Netflaz/                   # ซอร์ส SwiftUI ทั้งหมด
│   ├── NetflazApp.swift        # จุดเริ่มแอป
│   ├── Models/                 # Media, PartyMessage, ...
│   ├── Services/
│   │   ├── SampleContent.swift   # แคตตาล็อกสื่อแบบเปิด (เล่นได้จริง)
│   │   ├── TMDBService.swift     # ดึงเมตาดาตาจาก TMDB (ไม่บังคับ)
│   │   └── WatchPartyClient.swift# WebSocket client (URLSessionWebSocketTask)
│   ├── ViewModels/
│   │   ├── HomeViewModel.swift
│   │   ├── WatchPartyViewModel.swift  # ⭐ ซิงก์ AVPlayer (โหมดในแอป)
│   │   └── WebCoWatchViewModel.swift  # ⭐ ซิงก์ <video> ในเว็บ (โหมด Teleparty)
│   ├── Views/                  # Home, Detail, Player, WatchParty, WebCoWatch, Settings
│   └── Theme/
├── docs/
│   └── TELEPARTY-APPROACH.md   # กลไก Teleparty + ข้อจำกัดกับ Netflix
└── server/                    # เซิร์ฟเวอร์ซิงก์ Node.js (WebSocket)
    └── server.js
```

**แนวคิดการซิงก์** (ดู `WatchPartyViewModel.swift`):
- ผู้สร้างห้อง = **โฮสต์** ส่ง heartbeat `sync` (ตำแหน่ง + สถานะเล่น) ทุก 2 วินาที
- ใครกด play/pause/seek ก็ได้ → ทำงานในเครื่องตัวเอง **และ** ส่ง event ให้ทั้งห้อง
- event ที่รับมาจากคนอื่นจะสั่ง player ตรงๆ (ไม่ส่งซ้ำ) จึงไม่เกิด loop
- ผู้ชมเทียบเวลาตัวเองกับ heartbeat ของโฮสต์ ถ้าเพี้ยนเกิน 1.5 วินาที จะ seek ตาม

## 🚀 วิธีรัน

### 1) แอป iOS
1. เปิด `Netflaz.xcodeproj` ด้วย **Xcode 16 ขึ้นไป**
2. เลือก target **Netflaz** + simulator (เช่น iPhone 15)
3. กด **Run** (⌘R) — เล่นหนังแบบเปิดได้ทันที

> ต้องใช้ Xcode 16+ เพราะโปรเจกต์ใช้ *file-system synchronized groups* ถ้าใช้
> Xcode เก่ากว่านั้น ให้สร้างโปรเจกต์ iOS App ใหม่แล้วลากโฟลเดอร์ `Netflaz/` เข้าไป

### 2) เซิร์ฟเวอร์ Watch Party
```bash
cd server
npm install
npm start      # ws://0.0.0.0:8080
```
แล้วตั้งค่า **เซิร์ฟเวอร์ซิงก์** ในแอปให้ชี้มาที่เซิร์ฟเวอร์ (ดู `server/README.md`)

### 3) ทดลอง "ดูด้วยกัน"
- เปิดแอปสองเครื่อง/สอง simulator
- เครื่องแรก: แท็บ **ดูด้วยกัน** → เลือกเรื่อง → **สร้างห้อง (เป็นโฮสต์)** → จำรหัสห้อง
- เครื่องที่สอง: ใส่รหัสเดียวกัน → **เข้าร่วมห้อง**
- กดเล่น/หยุด/เลื่อนฝั่งไหนก็ได้ อีกฝั่งจะซิงก์ตาม พร้อมแชตคุยกันได้

## 🙏 เครดิตเนื้อหา
- **Blender Open Movies** (Big Buck Bunny, Sintel, Tears of Steel, Elephants
  Dream) © Blender Foundation — เผยแพร่ภายใต้ Creative Commons Attribution
- คลิปตัวอย่างจาก Google public sample-video bucket
- เมตาดาตาจาก The Movie Database (TMDB) — ผลิตภัณฑ์นี้ใช้ TMDB API แต่ไม่ได้รับ
  การรับรองหรือการันตีจาก TMDB
