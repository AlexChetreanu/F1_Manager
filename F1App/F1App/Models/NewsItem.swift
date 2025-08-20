//
//  NewsItem.swift
//  F1App
//
//  Created for F1 news section.
//

import Foundation

struct NewsItem: Identifiable, Decodable {
    let id: String
    let title: String
    let link: String
    let publishedAt: Date
    let imageUrl: URL?
    let source: String
    let excerpt: String

    private enum CodingKeys: String, CodingKey {
        case id, title, link, source, excerpt
        case publishedAt = "published_at"
        case imageUrl = "image_url"
    }
}
