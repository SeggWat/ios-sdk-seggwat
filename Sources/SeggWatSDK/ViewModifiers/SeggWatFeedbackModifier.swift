import SwiftUI

/// View modifier that adds a floating feedback button and sheet to any view.
struct SeggWatFeedbackModifier: ViewModifier {
    @ObservedObject private var seggwat = SeggWat.shared
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .overlay(alignment: seggwat.options.buttonPosition.alignment) {
                if seggwat.isConfigured && !seggwat.isButtonHidden {
                    SeggWatButton()
                        .padding(16)
                        .environmentObject(seggwat)
                }
            }
            .sheet(isPresented: $seggwat.isPresented) {
                SeggWatFeedbackView()
                    .environmentObject(seggwat)
            }
            .sheet(isPresented: $seggwat.isChatPresented) {
                NavigationStack {
                    SeggWatChatView()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button(seggwat.localizedString("button_close")) {
                                    seggwat.isChatPresented = false
                                }
                            }
                        }
                }
                .environmentObject(seggwat)
            }
            .task { await seggwat.refreshUnreadCount() }
            .onChange(of: scenePhase) { phase in
                if phase == .active {
                    Task { await seggwat.refreshUnreadCount() }
                }
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
