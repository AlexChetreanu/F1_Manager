import Foundation

struct RaceEvent: Identifiable, Decodable, Hashable {
    let id: Int64
    let eventType: EventType
    let timestampMs: Int64
    let lap: Int?
    let driverNumber: Int?
    let driverNumberOvertaken: Int?
    let message: String?
    let subtype: String?
    let extra: [String: String]?

    enum EventType: String, Decodable {
        case overtake
        case race_control
    }
}

struct ToastEvent: Identifiable, Hashable {
    let id: Int64
    let event: RaceEvent
    let expiresAtMs: Int64
}
