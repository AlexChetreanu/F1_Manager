import SwiftUI
import UIKit

extension Image {
    /// Loads a driver image from the bundled Images directory.
    /// - Parameter name: Driver image base name (e.g., "Albon").
    /// - Returns: SwiftUI Image loaded from disk or a default system image if not found.
    static func driver(named name: String) -> Image {
        if let path = Bundle.main.path(forResource: "Images/\(name).webp", ofType: "avif"),
           let uiImage = UIImage(contentsOfFile: path) {
            return Image(uiImage: uiImage)
        }
        return Image(systemName: "person.circle")
    }
}

