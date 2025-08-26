import SwiftUI
import UIKit

extension Image {
    /// Loads a driver image from the asset catalog.
    /// - Parameter name: Driver image base name (e.g., "Albon").
    /// - Returns: SwiftUI Image loaded from the asset catalog or a default system image if not found.
    static func driver(named name: String) -> Image {
        if let uiImage = UIImage(named: name) {
            return Image(uiImage: uiImage)
        }

        return Image(systemName: "person.circle")
    }
}

