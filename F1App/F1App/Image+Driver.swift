import SwiftUI
import UIKit

extension Image {
    /// Loads a driver image from the bundled Images directory.
    /// - Parameter name: Driver image base name (e.g., "Albon").
    /// - Returns: SwiftUI Image loaded from disk or a default system image if not found.
    static func driver(named name: String) -> Image {
        let candidates: [(String, String)] = [
            ("Images/\(name)", "png"),
            ("Images/\(name)", "jpg"),
            ("Images/\(name).webp", "avif")
        ]

        for (resource, ext) in candidates {
            if let path = Bundle.main.path(forResource: resource, ofType: ext),
               let uiImage = UIImage(contentsOfFile: path) {
                return Image(uiImage: uiImage)
            }
        }

        return Image(systemName: "person.circle")
    }
}

