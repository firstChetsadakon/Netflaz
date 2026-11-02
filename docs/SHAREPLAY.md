# SharePlay บน Netflaz

Netflaz รองรับ **SharePlay (GroupActivities)** สำหรับคอนเทนต์แบบเปิดของแอปเอง →
ดูด้วยกันผ่าน FaceTime โดย **iOS ซิงก์การเล่นให้อัตโนมัติ** ไม่ต้องมีเซิร์ฟเวอร์เอง

> อ้างอิงฟีเจอร์ของ Apple: https://support.apple.com/th-th/guide/iphone/shareplay-watch-listen-play-iphb657eb791/ios

## ใช้กับ Netflix ได้ไหม? — ไม่ได้

SharePlay จะ sync การเล่นของแอปไหนได้ **ก็ต่อเมื่อแอปนั้น adopt GroupActivities เอง**
(ต้องผูก `AVPlayer` ของแอปเข้ากับ group session) แอปภายนอกเอื้อมเข้าไปสั่งเครื่องเล่น
ของ Netflix ไม่ได้

- บริการที่ **รองรับ** SharePlay: Disney+, Max (HBO), Hulu, Paramount+, Apple TV,
  Twitch ฯลฯ
- **Netflix ไม่รองรับ** SharePlay → มีแต่ Netflix เองที่เปิดได้ (คือสิ่งที่ควรเสนอ Netflix)

ดังนั้นแอปเราทำ SharePlay ได้เฉพาะ **คอนเทนต์ที่เราเล่นเองอย่างถูกต้อง** (สื่อเปิด)

## โครงสร้างในโค้ด

| ไฟล์ | หน้าที่ |
|---|---|
| `Services/WatchTogetherActivity.swift` | นิยาม `GroupActivity` (ชื่อเรื่อง + metadata) |
| `Services/SharePlayCoordinator.swift` | รอรับ session, เริ่ม SharePlay, ผูก `player.playbackCoordinator` เข้ากับ session |
| `Views/SharePlayPlayerView.swift` | หน้าจอเล่นที่ควบคุมผ่าน SharePlay |

หัวใจคือบรรทัดเดียว:
```swift
player.playbackCoordinator.coordinateWithSession(session)
```
หลังจากนี้ play/pause/seek จะถูก iOS ซิงก์ให้ทุกคนในสาย FaceTime เอง

## เปิดใช้งาน (ก่อนรันจริง)

1. ใน Xcode: เลือก target **Netflaz** → แท็บ **Signing & Capabilities**
2. กด **+ Capability** → เพิ่ม **Group Activities**
   (Xcode จะสร้าง/ผูกไฟล์ entitlements และจัดการ provisioning ให้ — ไฟล์ตัวอย่างอยู่ที่
   `Config/Netflaz.entitlements`)
3. ตั้ง **Development Team** ของคุณในแท็บเดียวกัน

## วิธีทดสอบ

- ต้องใช้ **อุปกรณ์จริง 2 เครื่อง** (Simulator เล่น SharePlay จริงไม่ได้) ล็อกอิน Apple ID
- โทร **FaceTime** หากัน
- เปิดแอป → เลือกเรื่อง → **ดูผ่าน SharePlay (FaceTime)** → **เริ่ม SharePlay**
- อีกฝั่งกดเข้าร่วมจากแบนเนอร์ SharePlay แล้วลองกดเล่น/หยุด — จะซิงก์กันเอง

## เทียบกับโหมดอื่นในแอป

| โหมด | กลไก sync | ข้ามแพลตฟอร์ม | ต้องมีเซิร์ฟเวอร์ | เหมาะกับ |
|---|---|---|---|---|
| Watch Party (ในแอป) | WebSocket + ชดเชยดีเลย์เราเขียนเอง | ได้ (Android/เว็บได้ในอนาคต) | ต้องมี | เรียนรู้หลักการ, คุมเองทุกอย่าง |
| Co-Watch (เว็บ, Teleparty) | ฉีด JS เกาะ `<video>` + WebSocket | ได้ | ต้องมี | เนื้อหาบนหน้าเว็บที่ฝังได้ |
| **SharePlay** | iOS/GroupActivities ซิงก์ให้ | เฉพาะ Apple | **ไม่ต้อง** | ประสบการณ์ native ลื่นสุดบน iOS |
