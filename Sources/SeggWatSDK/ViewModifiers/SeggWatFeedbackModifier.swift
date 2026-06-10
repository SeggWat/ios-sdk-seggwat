import SwiftUI

/// View modifier that adds a floating feedback button and sheet to any view.
struct SeggWatFeedbackModifier: ViewModifier {
    @ObservedObject private var seggwat = SeggWat.shared

    func body(content: Content) -> some View {
        content
            .overlay(alignment: seggwat.options.buttonPosition.alignment) {
                if seggwat.isConfigured {
                    SeggWatButton()
                        .padding(16)
                        .environmentObject(seggwat)
                }
            }
            .sheet(isPresented: $seggwat.isPresented) {
                SeggWatFeedbackView()
                    .environmentObject(seggwat)
            }
    }
}

public extension View {
    /// Add a floating SeggWat feedback button and modal to this view.
    ///
    /// Requires `SeggWat.configure(projectKey:options:)` to have been called.
    ///
    /// ```swift
    /// ContentView()
    ///     .seggwatFeedbackButton()
    /// ```
    func seggwatFeedbackButton() -> some View {
        modifier(SeggWatFeedbackModifier())
    }
}
