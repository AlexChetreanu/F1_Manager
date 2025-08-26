import UIKit

enum Haptics {
    static func soft() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }
}
