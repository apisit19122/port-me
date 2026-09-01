import Foundation

public enum AppVersion {
    /// เลขเวอร์ชันอยู่ที่ `scripts/Info.plist` ที่เดียว ไม่ทำสำเนาไว้ใน Swift
    /// เพื่อไม่ให้ค่าสองที่หลุดจากกันเวลาลืมแก้ที่ใดที่หนึ่ง
    public static var display: String {
        display(shortVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
    }

    /// ตอนรันจาก `swift run` ยังไม่มี bundle จึงไม่มีเลขเวอร์ชันให้อ่าน — บอกว่า dev ตรง ๆ
    /// ดีกว่าโชว์เลขที่ไม่ตรงกับสิ่งที่กำลังรันอยู่
    static func display(shortVersion: String?) -> String {
        guard let shortVersion, !shortVersion.isEmpty else { return "dev" }
        return "v\(shortVersion)"
    }
}
