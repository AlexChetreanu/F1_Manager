import Foundation

struct HistoricRace: Identifiable, Decodable {
    let meeting_key: Int
    let meeting_name: String
    let circuit_short_name: String
    let location: String
    let date_start: String

    var id: Int { meeting_key }
    var date: String { String(date_start.prefix(10)) }
}
