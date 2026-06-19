import SwiftUI

/// Brand mark — uses the actual app icon asset.
struct SipliMark: View {
    var size: CGFloat = 24
    var animated: Bool = false

    var body: some View {
        Image("sipliIcon")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview("SipliMark sizes") {
    HStack(spacing: 18) {
        SipliMark(size: 22)
        SipliMark(size: 36)
        SipliMark(size: 64)
    }
    .padding()
    .background(OnboardingPalette.paper)
}
#endif
