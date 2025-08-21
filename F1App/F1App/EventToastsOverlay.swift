import SwiftUI

struct EventToastsOverlay: View {
    let toasts: [ToastEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(toasts.prefix(3)) { toast in
                EventToastView(event: toast.event)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .allowsHitTesting(false)
    }
}
