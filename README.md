# Netflaz 🎬

โปรเจกต์ "ดูด้วยกัน" ตอบโจทย์ pain point เรื่องการดูไปพร้อมเพื่อน/แฟน มี 2 ส่วน:

| ส่วน | ใช้บน | ดู Netflix ได้ไหม | วิธีซิงก์ |
|---|---|---|---|
| **แอป iOS (SwiftUI) + SharePlay** | iPhone / iPad | ❌ (เล่นสื่อแบบเปิดของแอปเอง) | iOS ซิงก์ให้ผ่าน FaceTime |
| **ส่วนขยาย Chrome แบบ Teleparty** (`extension/`) | คอมพิวเตอร์ (Chrome/Edge) | ✅ แต่ละคนใช้บัญชีตัวเอง | WebSocket ผ่าน `server/` ที่รันเอง |

> โปรเจกต์นี้ทำ **เพื่อการศึกษา** เท่านั้น

## ⚖️ ขอบเขตด้านกฎหมาย (อ่านก่อน)

สิ่งที่โปรเจกต์นี้ **ไม่ทำ**:

- ❌ **ไม่** ถอดรหัส / บายพาส DRM (ผิด DMCA §1201, EU Copyright Directive และ
  พ.ร.บ.ลิขสิทธิ์ของไทย)
- ❌ **ไม่** รับ เก็บ หรืออ่านรหัสผ่าน Netflix และ **ไม่** เรียก API ฝั่งเซิร์ฟเวอร์ของ Netflix
- ❌ **ไม่** ดึง คัดลอก หรือส่งต่อตัววิดีโอ — ทุกคนต้องดูด้วยบัญชีของตัวเอง

สิ่งที่โปรเจกต์นี้ **ทำ**:

- ✅ แอป iOS เล่นเฉพาะ **สื่อแบบเปิด** (Creative Commons / สาธารณสมบัติ): Blender Open
  Movies และคลิปตัวอย่างสาธารณะ และดูด้วยกันด้วย **SharePlay (GroupActivities)**
- ✅ ส่วนขยาย Chrome **สั่ง เล่น/หยุด/เลื่อน บนเครื่องเล่นในหน้าเว็บที่ผู้ใช้เปิดเอง** (เท่ากับกดปุ่มเอง)
  บน Netflix การเลื่อนเวลาใช้ออบเจกต์เครื่องเล่นภายในหน้าเว็บ (ไม่ใช่ API ทางการ) เหมือนที่ Teleparty ทำ
  — เป็น **พื้นที่สีเทาตามข้อตกลงการใช้งาน (ToS)** ของบริการ ใช้เพื่อการศึกษา (ดู [extension/README.md](extension/README.md))
- ✅ ปุ่ม **"ค้นหาใน Netflix"** ในแอป iOS deep-link เข้าแอป Netflix ทางการของผู้ใช้
- ✅ (ไม่บังคับ) ดึงเมตาดาตาหนังจริงจาก [TMDB](https://developer.themoviedb.org)
  เพื่อโชว์รายการ (ดูข้อมูลอย่างเดียว เล่นไม่ได้)

## 📺 SharePlay กับ Netflix

SharePlay จะซิงก์การเล่นของแอปไหนได้ **ก็ต่อเมื่อแอปนั้น adopt GroupActivities เอง**
→ แอปภายนอกทำ SharePlay ให้ Netflix **ไม่ได้** มีแต่ Netflix เองที่เปิดได้ (บริการที่
รองรับแล้ว เช่น Disney+, Max, Hulu, Paramount+, Apple TV; Netflix ยังไม่รองรับ)

Netflaz จึงทำ SharePlay กับ **คอนเทนต์เปิดของแอปเอง** เป็นตัวสาธิตหลักการ และถ้าจะ
เสนอ Netflix จริง สิ่งที่ขอได้คือ "ขอให้ Netflix รองรับ SharePlay/เปิด co-watch API"
รายละเอียดใน [docs/SHAREPLAY.md](docs/SHAREPLAY.md)

## 🧩 ส่วนขยาย Chrome แบบ Teleparty (ดู Netflix ด้วยกันบนคอมพิวเตอร์)

ทุกคนเปิดเรื่องเดียวกันใน Netflix ด้วยบัญชีตัวเอง → โฮสต์กดไอคอน **สร้างห้อง** ส่งรหัสให้เพื่อน →
เพื่อนกด **เข้าร่วมห้อง** → ใครกดเล่น/หยุด/เลื่อน ทุกคนตามกัน พร้อมแถบแชตข้างจอ

```bash
cd server && npm install && npm start          # เซิร์ฟเวอร์ซิงก์
# Chrome → chrome://extensions → Developer mode → Load unpacked → เลือกโฟลเดอร์ extension/
```

- ซิงก์แบบชดเชยดีเลย์ (ซิงก์นาฬิกาแบบ NTP) + โฮสต์ส่งตำแหน่งทุก 2 วิ ดึงคนที่เพี้ยนเกิน 0.4 วิกลับ
- กันลูปสะท้อน: คำสั่งที่มาจากเพื่อนจะไม่ถูกส่งกลับเข้าห้องซ้ำ
- ใช้สิทธิ์แค่ `activeTab` (เข้าถึงเฉพาะแท็บที่กดไอคอน)
- ดูกับเพื่อนคนละที่ต้องเอา `server/` ขึ้นโฮสต์ที่เข้าจากอินเทอร์เน็ตได้ (`wss://`)
- ⚠️ ส่วนเฉพาะ Netflix (การเลื่อนเวลา) **ยังไม่ได้ทดสอบกับ Netflix จริง** — รายละเอียดและข้อจำกัดใน
  [extension/README.md](extension/README.md)

## ✨ ฟีเจอร์ของแอป iOS

- หน้าแรกสไตล์ Netflix: แบนเนอร์เด่น + แถวเลื่อนแนวนอน
- หน้ารายละเอียด + เล่นเดี่ยว (AVKit)
- **ดูด้วยกันด้วย SharePlay**: iOS ซิงก์ play/pause/seek ให้ทุกคนในสาย FaceTime
- ปุ่ม "ค้นหาใน Netflix" (deep link) และรองรับ TMDB แบบไม่บังคับ

## 🧱 สถาปัตยกรรม

```
Netflaz/
├── Netflaz.xcodeproj/         # โปรเจกต์ Xcode (synchronized folder, Xcode 16+)
├── Config/
│   ├── Info.plist
│   └── Netflaz.entitlements    # ตัวอย่าง entitlement สำหรับ Group Activities
├── Netflaz/                   # ซอร์ส SwiftUI ทั้งหมด
│   ├── NetflazApp.swift        # จุดเริ่มแอป
│   ├── Models/Media.swift
│   ├── Services/
│   │   ├── SampleContent.swift         # แคตตาล็อกสื่อแบบเปิด (เล่นได้จริง)
│   │   ├── TMDBService.swift           # ดึงเมตาดาตาจาก TMDB (ไม่บังคับ)
│   │   ├── WatchTogetherActivity.swift # นิยาม SharePlay GroupActivity
│   │   └── SharePlayCoordinator.swift  # ⭐ จัดการ session + ผูก playbackCoordinator
│   ├── ViewModels/HomeViewModel.swift
│   ├── Views/                  # Home, Detail, SoloPlayer, SharePlayPlayer, Settings
│   └── Theme/
├── extension/                 # ส่วนขยาย Chrome แบบ Teleparty (MV3)
│   ├── manifest.json
│   ├── background.js           # WebSocket + ซิงก์นาฬิกา + relay
│   ├── content.js              # เกาะ <video>, กันลูปสะท้อน, แถบแชต
│   ├── netflix-main.js         # adapter การเลื่อนเวลาบน netflix.com
│   └── popup.html / .js / .css # สร้าง/เข้าร่วม/ออกจากห้อง
├── server/                    # เซิร์ฟเวอร์ซิงก์ WebSocket (Node.js)
└── docs/
    └── SHAREPLAY.md            # SharePlay: setup, การทดสอบ, ทำไม Netflix ใช้ไม่ได้
```

**หัวใจการซิงก์** (ดู `SharePlayCoordinator.swift`) คือบรรทัดเดียว:
```swift
player.playbackCoordinator.coordinateWithSession(session)
```
หลังจากนี้ iOS จะซิงก์ play / pause / seek ให้ทุกคนในสาย FaceTime เอง

## 🚀 วิธีรัน

1. เปิด `Netflaz.xcodeproj` ด้วย **Xcode 16 ขึ้นไป**
2. เลือก target **Netflaz** + simulator → **Run** (⌘R) เพื่อดูหน้าแรก/เล่นเดี่ยว
3. **เปิด SharePlay ก่อนใช้งานจริง**: target → Signing & Capabilities → + Capability →
   **Group Activities** และตั้ง Development Team (ดู [docs/SHAREPLAY.md](docs/SHAREPLAY.md))

### ทดลองดูด้วยกัน (SharePlay)
- ใช้ **อุปกรณ์จริง 2 เครื่อง** (Simulator เล่น SharePlay จริงไม่ได้) ล็อกอิน Apple ID
- โทร **FaceTime** หากัน → เปิดแอป → เลือกเรื่อง → **ดูด้วยกันผ่าน SharePlay** → **เริ่ม SharePlay**
- กดเล่น/หยุด/เลื่อนฝั่งไหนก็ได้ iOS จะซิงก์ให้เอง

## 🙏 เครดิตเนื้อหา
- **Blender Open Movies** (Big Buck Bunny, Sintel, Tears of Steel, Elephants
  Dream) © Blender Foundation — Creative Commons Attribution
- คลิปตัวอย่างจาก Google public sample-video bucket
- เมตาดาตาจาก The Movie Database (TMDB) — ใช้ TMDB API แต่ไม่ได้รับการรับรองจาก TMDB
