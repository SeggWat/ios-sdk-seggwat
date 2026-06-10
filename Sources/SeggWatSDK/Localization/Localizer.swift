import Foundation

/// Looks up localized strings from the SDK's resource bundle.
enum Localizer {
    static let supportedLanguages = ["en", "de", "sv"]

    /// Get a localized string for the given key, with optional language override.
    static func string(_ key: String, language: String? = nil) -> String {
        let bundle = resolveBundle(for: language)
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }

    /// Get a localized string with format arguments.
    static func string(_ key: String, language: String? = nil, _ args: CVarArg...) -> String {
        let format = string(key, language: language)
        return String(format: format, arguments: args)
    }

    private static func resolveBundle(for language: String?) -> Bundle {
        let lang = resolveLanguage(language)

        if let path = Bundle.module.path(forResource: lang, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }

        // Fallback to English
        if let path = Bundle.module.path(forResource: "en", ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }

        return Bundle.module
    }

    private static func resolveLanguage(_ override: String?) -> String {
        if let override, supportedLanguages.contains(override) {
            return override
        }

        // Auto-detect from device locale
        let preferred = Locale.preferredLanguages.first ?? "en"
        let code = String(preferred.prefix(2))
        return supportedLanguages.contains(code) ? code : "en"
    }
}
