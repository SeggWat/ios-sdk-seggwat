import UIKit

/// Captures a screenshot of the current key window and compresses it as JPEG.
enum ScreenshotCapture {

    /// Capture the current screen as JPEG data.
    /// - Parameter compressionQuality: JPEG compression quality (0.0 - 1.0).
    /// - Returns: JPEG image data.
    @MainActor
    static func capture(compressionQuality: CGFloat = 0.8) -> Data? {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) else {
            return nil
        }

        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
        let image = renderer.image { context in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }

        return image.jpegData(compressionQuality: compressionQuality)
    }

    /// Convert a UIImage to JPEG data with size validation.
    static func compress(_ image: UIImage, quality: CGFloat, maxSizeMB: Int) -> Data? {
        guard let data = image.jpegData(compressionQuality: quality) else { return nil }
        let maxBytes = maxSizeMB * 1024 * 1024
        if data.count > maxBytes {
            // Try lower quality
            let reducedQuality = max(0.1, quality - 0.2)
            return image.jpegData(compressionQuality: reducedQuality)
        }
        return data
    }
}
