import SwiftUI

/// The end-user's conversation with the project's team. Team replies arrive
/// live over SSE while it is on screen. Shown in its own sheet
/// (`SeggWat.presentChat()`) or pushed from the feedback form.
struct SeggWatChatView: View {
    @EnvironmentObject private var seggwat: SeggWat

    @State private var messages: [ChatMessage] = []
    @State private var draft = ""
    @State private var isLoading = true
    @State private var isSending = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            messageList
            composer
        }
        .navigationTitle(seggwat.localizedString("chat_title"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadHistory() }
        .task { await listenForReplies() }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    if isLoading {
                        ProgressView().padding(.top, 32)
                    } else if messages.isEmpty {
                        Text(seggwat.localizedString("chat_empty"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.top, 32)
                            .padding(.horizontal, 24)
                    }
                    ForEach(messages) { message in
                        bubble(for: message).id(message.id)
                    }
                }
                .padding(16)
            }
            .onChange(of: messages) { messages in
                guard let last = messages.last else { return }
                withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
            }
        }
    }

    private func bubble(for message: ChatMessage) -> some View {
        let isMine = message.sender == .you
        return HStack {
            if isMine { Spacer(minLength: 48) }
            Text(message.body)
                .font(.body)
                .foregroundColor(isMine ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isMine ? seggwat.options.buttonColor : Color(.secondarySystemBackground))
                )
            if !isMine { Spacer(minLength: 48) }
        }
    }

    private var composer: some View {
        VStack(spacing: 4) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(alignment: .bottom, spacing: 8) {
                TextField(seggwat.localizedString("chat_placeholder"), text: $draft, axis: .vertical)
                    .lineLimit(1...5)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(18)
                Button {
                    Task { await send() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(seggwat.options.buttonColor)
                }
                .disabled(isSending || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel(seggwat.localizedString("chat_send"))
            }
        }
        .padding(12)
        .background(.bar)
    }

    private func loadHistory() async {
        do {
            messages = try await seggwat.chatHistory()
            errorMessage = nil
        } catch {
            errorMessage = seggwat.localizedString("chat_error_load")
        }
        isLoading = false
    }

    private func send() async {
        isSending = true
        defer { isSending = false }
        do {
            let message = try await seggwat.sendChatMessage(draft)
            messages.append(message)
            draft = ""
            errorMessage = nil
        } catch {
            errorMessage = seggwat.localizedString("chat_error_send")
        }
    }

    /// Hold the SSE stream open while the view is visible, reconnecting after
    /// a drop with exponential backoff (3s doubling to 60s), so a rate-limited
    /// or offline client doesn't hammer the server. The `.task` modifier
    /// cancels this when it disappears.
    private func listenForReplies() async {
        var failures = 0
        while !Task.isCancelled {
            do {
                var parser = ChatStreamParser()
                for try await line in try await seggwat.chatStream().lines {
                    failures = 0
                    switch parser.consume(line) {
                    case .message(let message):
                        if !messages.contains(where: { $0.id == message.id }) {
                            messages.append(message)
                        }
                    case .resync:
                        await loadHistory()
                    case nil:
                        break
                    }
                }
            } catch SeggWatError.chatTokenInvalid, SeggWatError.chatTokenMissing {
                return
            } catch {}
            // Catch up on anything sent while disconnected, then reconnect.
            let delay = min(3 << min(failures, 5), 60)
            failures += 1
            try? await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000_000)
            if !Task.isCancelled { await loadHistory() }
        }
    }
}
