# Netflaz 🎬

แอป streaming สไตล์ Netflix สำหรับ **iOS (SwiftUI)** ที่ใช้ **SharePlay** เป็นวิธี
"ดูด้วยกัน" — ดูพร้อมกันผ่าน FaceTime โดย iOS ซิงก์การเล่นให้อัตโนมัติ ตอบโจทย์
pain point เรื่องการดูไปด้วยกันกับเพื่อน/แฟน

> โปรเจกต์นี้ทำ **เพื่อการศึกษา** เท่านั้น

## ⚖️ ขอบเขตด้านกฎหมาย (อ่านก่อน)

สิ่งที่โปรเจกต์นี้ **ไม่ทำ**:

- ❌ **ไม่** ถอดรหัส / บายพาส DRM (ผิด DMCA §1201, EU Copyright Directive และ
  พ.ร.บ.ลิขสิทธิ์ของไทย)
- ❌ **ไม่** ใช้ API ภายในของ Netflix และ **ไม่** รับล็อกอินบัญชี Netflix

สิ่งที่โปรเจกต์นี้ **ทำ** อย่างถูกต้อง:

- ✅ เล่นเฉพาะ **สื่อแบบเปิด** (Creative Commons / สาธารณสมบัติ): Blender Open
  Movies และคลิปตัวอย่างสาธารณะ — สตรีมได้ถูกกฎหมาย ไม่ต้องมี DRM
- ✅ ดูด้วยกันด้วย **SharePlay (GroupActivities)** — Apple ซิงก์ให้ ไม่ต้องมีเซิร์ฟเวอร์
- ✅ ปุ่ม **"ค้นหาใน Netflix"** deep-link เข้าแอป Netflix ทางการของผู้ใช้
- ✅ (ไม่บังคับ) ดึงเมตาดาตาหนังจริงจาก [TMDB](https://developer.themoviedb.org)
  เพื่อโชว์รายการ (ดูข้อมูลอย่างเดียว เล่นไม่ได้)

## 📺 SharePlay กับ Netflix

SharePlay จะซิงก์การเล่นของแอปไหนได้ **ก็ต่อเมื่อแอปนั้น adopt GroupActivities เอง**
→ แอปภายนอกทำ SharePlay ให้ Netflix **ไม่ได้** มีแต่ Netflix เองที่เปิดได้ (บริการที่
รองรับแล้ว เช่น Disney+, Max, Hulu, Paramount+, Apple TV; Netflix ยังไม่รองรับ)

Netflaz จึงทำ SharePlay กับ **คอนเทนต์เปิดของแอปเอง** เป็นตัวสาธิตหลักการ และถ้าจะ
เสนอ Netflix จริง สิ่งที่ขอได้คือ "ขอให้ Netflix รองรับ SharePlay/เปิด co-watch API"
รายละเอียดใน [docs/SHAREPLAY.md](docs/SHAREPLAY.md)

## ✨ ฟีเจอร์

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
