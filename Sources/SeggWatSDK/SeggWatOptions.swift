import SwiftUI

/// Appearance of the floating feedback button.
public enum SeggWatButtonStyle: Sendable {
    /// Compact circular button showing only the icon. Default.
    case icon
    /// Pill-shaped button showing the icon and label text.
    case labeled
}

/// Position of the floating feedback button.
public enum ButtonPosition: Sendable {
    case bottomTrailing
    case bottomLeading
    case topTrailing
    case topLeading

    var alignment: Alignment {
        switch self {
        case .bottomTrailing: return .bottomTrailing
        case .bottomLeading: return .bottomLeading
        case .topTrailing: return .topTrailing
        case .topLeading: return .topLeading
        }
    }
}

/// Configuration options for the SeggWat SDK.
public struct SeggWatOptions: Sendable {
    /// Color of the floating feedback button. Default: `.blue`.
    public var buttonColor: Color

    /// Position of the floating button. Default: `.bottomTrailing`.
    public var buttonPosition: ButtonPosition

    /// Appearance of the floating button. Default: `.icon`.
    public var buttonStyle: SeggWatButtonStyle

    /// App version string sent with feedback. Default: auto-detected from bundle.
    public var appVersion: String?

    /// Language override (en, de, sv). Default: auto-detected from device locale.
    public var language: String?

    /// Base URL of the SeggWat API. Default: `https://seggwat.com`.
    public var apiURL: URL

    /// Whether to show "Powered by SeggWat" in the feedback form. Default: `true`.
    public var showPoweredBy: Bool

    /// Whether screenshot capture is enabled. Default: `true`.
    public var screenshotsEnabled: Bool

    /// JPEG compression quality for screenshots (0.0 - 1.0). Default: `0.8`.
    public var compressionQuality: CGFloat

    /// Maximum screenshot size in MB. Default: `5`.
    public var maxScreenshotSizeMB: Int

    /// Callback invoked after feedback submission completes.
    public var onSubmit: (@Sendable (Result<Void, SeggWatError>) -> Void)?

    public init(
        buttonColor: Color = .blue,
        buttonPosition: ButtonPosition = .bottomTrailing,
        buttonStyle: SeggWatButtonStyle = .icon,
        appVersion: String? = nil,
        language: String? = nil,
        apiURL: URL = URL(string: "https://seggwat.com")!,
        showPoweredBy: Bool = true,
        screenshotsEnabled: Bool = true,
        compressionQuality: CGFloat = 0.8,
        maxScreenshotSizeMB: Int = 5,
        onSubmit: (@Sendable (Result<Void, SeggWatError>) -> Void)? = nil
    ) {
        self.buttonColor = buttonColor
        self.buttonPosition = buttonPosition
        self.buttonStyle = buttonStyle
        self.appVersion = appVersion ?? Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        self.language = language
        self.apiURL = apiURL
        self.showPoweredBy = showPoweredBy
        self.screenshotsEnabled = screenshotsEnabled
        self.compressionQuality = compressionQuality
        self.maxScreenshotSizeMB = maxScreenshotSizeMB
        self.onSubmit = onSubmit
    }
}
