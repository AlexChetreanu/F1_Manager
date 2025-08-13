//
//  Race.swift
//  F1App
//
//  Created by Alexandru Chetreanu on 09.06.2025.
//

struct Race: Identifiable, Decodable {
    let id: Int
    let name: String
    let circuit_id: String?
    let location: String
    let date: String
    let status: String
    let coordinates: String? // JSON string cu coordonate, le vom decoda ulterior
}
