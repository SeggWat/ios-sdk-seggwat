import SwiftUI

/// Thumbnail preview of a captured screenshot in the feedback form.
struct ScreenshotPreviewView: View {
    let image: UIImage
    let onRemove: () -> Void
    @EnvironmentObject private var seggwat: SeggWat

    var body: some View {
        HStack(spacing: 12) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.separator), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(seggwat.localizedString("screenshot_button_label"))
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(seggwat.localizedString("screenshot_button_tooltip"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(role: .destructive, action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(seggwat.localizedString("remove_screenshot"))
        }
        .padding(8)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }
}
