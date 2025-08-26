import SwiftUI

enum Motion {
    static let spring = Animation.interpolatingSpring(stiffness: 220, damping: 28)
    static let appear = Animation.easeInOut(duration: 0.24)
    static let stateChange = Animation.easeInOut(duration: 0.2)
}
