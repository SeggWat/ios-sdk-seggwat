import SwiftUI

/// Floating circular feedback button.
struct SeggWatButton: View {
    @EnvironmentObject private var seggwat: SeggWat

    var body: some View {
        Button {
            SeggWat.presentFeedback()
        } label: {
            label
        }
        .buttonStyle(.plain)
        .accessibilityLabel(seggwat.localizedString("button_text"))
    }

    @ViewBuilder
    private var label: some View {
        switch seggwat.options.buttonStyle {
        case .icon:
            Image(systemName: "bubble.left.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 52, height: 52)
                .background(
                    Circle()
                        .fill(seggwat.options.buttonColor)
                        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                )
        case .labeled:
            HStack(spacing: 6) {
                Image(systemName: "bubble.left.fill")
                    .font(.system(size: 16, weight: .semibold))
                Text(seggwat.localizedString("button_text"))
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(seggwat.options.buttonColor)
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
            )
        }
    }
}
