import SwiftUI

/// Floating circular feedback button.
struct SeggWatButton: View {
    @EnvironmentObject private var seggwat: SeggWat

    var body: some View {
        Button {
            // An unread reply takes the user straight to the conversation.
            if seggwat.unreadCount > 0 {
                SeggWat.presentChat()
            } else {
                SeggWat.presentFeedback()
            }
        } label: {
            label
        }
        .buttonStyle(.plain)
        .accessibilityLabel(seggwat.localizedString("button_text"))
        .accessibilityValue(seggwat.unreadCount > 0 ? seggwat.localizedString("chat_unread", seggwat.unreadCount) : "")
        .overlay(alignment: .topTrailing) {
            if seggwat.unreadCount > 0 {
                Text("\(seggwat.unreadCount)")
                    .font(.caption2.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.red))
                    .offset(x: 4, y: -4)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
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
