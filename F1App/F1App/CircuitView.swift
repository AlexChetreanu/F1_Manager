//
//  CircuitView.swift
//  F1App
//
//  Created by Alexandru Chetreanu
//

import SwiftUI

struct CircuitView: View {
    let coordinatesJSON: String?
    
    // Structură simplificată pentru un punct
    struct Point: Identifiable {
        let id = UUID()
        let x: Double
        let y: Double
    }
    
    // Convertim coordonatele geo în puncte relative pentru desen
    func parseCoordinates() -> [CGPoint] {
        guard
            let jsonString = coordinatesJSON,
            let data = jsonString.data(using: .utf8),
            let arr = try? JSONSerialization.jsonObject(with: data) as? [[Double]]
        else {
            return []
        }
        
        // Coordonatele originale pot fi mari sau mici, vrem să le mapăm la un spațiu de desen
        let lons = arr.map { $0[0] }
        let lats = arr.map { $0[1] }
        
        guard let minLon = lons.min(), let maxLon = lons.max(),
              let minLat = lats.min(), let maxLat = lats.max() else {
            return []
        }
        
        // Mapăm la un dreptunghi 0..1 (normalizare)
        return arr.map { point in
            let x = (point[0] - minLon) / (maxLon - minLon)
            let y = 1 - (point[1] - minLat) / (maxLat - minLat) // inversăm y să fie corect sus-jos
            return CGPoint(x: x, y: y)
        }
    }
    
    var body: some View {
        GeometryReader { geo in
            let points = parseCoordinates()
            
            if points.isEmpty {
                Text("No coordinates available").foregroundColor(.red)
            } else {
                Path { path in
                    let first = points[0]
                    path.move(to: CGPoint(x: first.x * geo.size.width, y: first.y * geo.size.height))
                    for point in points.dropFirst() {
                        path.addLine(to: CGPoint(x: point.x * geo.size.width, y: point.y * geo.size.height))
                    }
                    path.closeSubpath()
                }
                .stroke(Color.blue, lineWidth: 2)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
}
