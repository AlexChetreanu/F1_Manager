import Foundation

struct RaceEventDTO: Decodable, Identifiable {
    let id: Int64
    let date: String?
    let dateIso: String?
    let timestampMs: Int64?
    let category: String?
    let flag: String?
    let message: String?
    let scope: String?
    let sector: String?
    let lapNumber: Int?
    let driverNumber: Int?
    let driverNumberOvertaken: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case date
        case dateIso = "date_iso"
        case timestampMs = "timestamp_ms"
        case category
        case flag
        case message
        case scope
        case sector
        case lapNumber = "lap_number"
        case driverNumber = "driver_number"
        case driverNumberOvertaken = "driver_number_overtaken"
    }
}

func eventTimeMs(_ dto: RaceEventDTO, sessionStart: Date) -> Int64? {
    if let t = dto.timestampMs {
        return t
    }
    if let iso = dto.dateIso {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        f.timeZone = TimeZone(secondsFromGMT: 0)
        if let d = f.date(from: iso) {
            return Int64(d.timeIntervalSince(sessionStart) * 1000)
        }
    }
    if let raw = dto.date {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        let formats = ["yyyy-MM-dd HH:mm:ss.SSSSSS", "yyyy-MM-dd HH:mm:ss"]
        for format in formats {
            f.dateFormat = format
            if let d = f.date(from: raw) {
                return Int64(d.timeIntervalSince(sessionStart) * 1000)
            }
        }
    }
    return nil
}
