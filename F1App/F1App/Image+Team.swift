import SwiftUI
import UIKit

extension Image {
    /// Loads a team logo from the asset catalog using the team name.
    /// - Parameter teamName: The official team name (e.g., "Ferrari").
    /// - Returns: Image of the team logo or a default placeholder if not found.
    static func teamLogo(for teamName: String) -> Image {
        let base = teamName
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
        let assetName = "2025\(base)logo"
        if let uiImage = UIImage(named: assetName) {
            return Image(uiImage: uiImage)
        }
        return Image(systemName: "questionmark")
    }
}

