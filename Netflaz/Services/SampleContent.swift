import Foundation

/// The built-in catalog.
///
/// Every title here is Creative Commons / open content with a stable, public
/// MP4 URL (the Blender Open Movies and Google's public sample-video bucket),
/// so playback is fully legal and needs no DRM. This is what makes the whole
/// demo honest: we learn the streaming + SharePlay co-watch principles on content we
/// are actually allowed to stream.
enum SampleContent {

    private static let bucket = "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/"

    private static func video(_ file: String) -> URL? { URL(string: bucket + file) }

    static let all: [Media] = animation + demos

    static let animation: [Media] = [
        Media(
            id: "big-buck-bunny",
            title: "Big Buck Bunny",
            overview: "กระต่ายยักษ์ใจดีถูกสัตว์ป่าจอมกวนแกล้ง จนต้องวางแผนเอาคืนแบบน่ารักๆ หนังสั้นแอนิเมชันระดับตำนานจากมูลนิธิ Blender เผยแพร่ภายใต้สัญญาอนุญาต Creative Commons.",
            posterURL: nil,
            backdropURL: nil,
            videoURL: video("BigBuckBunny.mp4"),
            year: "2008",
            genres: ["แอนิเมชัน", "ครอบครัว", "ตลก"],
            rating: 8.1,
            durationMinutes: 10,
            maturity: "ALL",
            source: .openContent
        ),
        Media(
            id: "sintel",
            title: "Sintel",
            overview: "หญิงสาวออกตามหามังกรน้อยที่พลัดพรากจากกัน การเดินทางอันโดดเดี่ยวข้ามดินแดนหนาวเหน็บ โปรเจกต์หนังเปิดลำดับที่สามของ Blender.",
            posterURL: nil,
            backdropURL: nil,
            videoURL: video("Sintel.mp4"),
            year: "2010",
            genres: ["แอนิเมชัน", "แฟนตาซี", "ดราม่า"],
            rating: 8.0,
            durationMinutes: 15,
            maturity: "13+",
            source: .openContent
        ),
        Media(
            id: "tears-of-steel",
            title: "Tears of Steel",
            overview: "ในอนาคตที่หุ่นยนต์ครองเมือง กลุ่มนักรบและนักวิทยาศาสตร์พยายามย้อนอดีตเพื่อกอบกู้มนุษยชาติ ผลงานไลฟ์แอ็กชัน+VFX โอเพนซอร์สของ Blender.",
            posterURL: nil,
            backdropURL: nil,
            videoURL: video("TearsOfSteel.mp4"),
            year: "2012",
            genres: ["ไซไฟ", "แอ็กชัน"],
            rating: 7.4,
            durationMinutes: 12,
            maturity: "13+",
            source: .openContent
        ),
        Media(
            id: "elephants-dream",
            title: "Elephants Dream",
            overview: "ชายสองคนสำรวจโลกกลไกเหนือจริงที่เปลี่ยนรูปไม่หยุดนิ่ง หนังเปิดเรื่องแรกของโลกจากโครงการ Orange ของ Blender.",
            posterURL: nil,
            backdropURL: nil,
            videoURL: video("ElephantsDream.mp4"),
            year: "2006",
            genres: ["แอนิเมชัน", "ทดลอง"],
            rating: 7.0,
            durationMinutes: 11,
            maturity: "13+",
            source: .openContent
        ),
    ]

    static let demos: [Media] = [
        demo("for-bigger-blazes", "For Bigger Blazes", "ForBiggerBlazes.mp4",
             "คลิปสาธิตสั้นสำหรับทดสอบการสตรีมวิดีโอความละเอียดสูงบนทุกหน้าจอ."),
        demo("for-bigger-escapes", "For Bigger Escapes", "ForBiggerEscapes.mp4",
             "คลิปสาธิตการเล่นวิดีโอแบบลื่นไหล เหมาะกับการทดสอบการดูด้วยกัน."),
        demo("for-bigger-fun", "For Bigger Fun", "ForBiggerFun.mp4",
             "วิดีโอตัวอย่างสำหรับทดสอบการ sync ตำแหน่งการเล่นระหว่างผู้ชมหลายคน."),
        demo("for-bigger-joyrides", "For Bigger Joyrides", "ForBiggerJoyrides.mp4",
             "คลิปตัวอย่างสำหรับทดลองปุ่มเล่น/หยุด/เลื่อนแบบเรียลไทม์ร่วมกัน."),
        demo("for-bigger-meltdowns", "For Bigger Meltdowns", "ForBiggerMeltdowns.mp4",
             "วิดีโอสาธิตปิดท้าย เหมาะกับการทดสอบความเสถียรของการเชื่อมต่อ."),
    ]

    private static func demo(_ id: String, _ title: String, _ file: String, _ overview: String) -> Media {
        Media(
            id: id,
            title: title,
            overview: overview,
            posterURL: nil,
            backdropURL: nil,
            videoURL: video(file),
            year: "2015",
            genres: ["สาธิต"],
            rating: 6.5,
            durationMinutes: 1,
            maturity: "ALL",
            source: .openContent
        )
    }

    static func media(withId id: String) -> Media? {
        all.first { $0.id == id }
    }
}
