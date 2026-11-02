import SwiftUI

/// The end-user's conversation with the project's team. Team replies arrive
/// live over SSE while it is on screen. Shown in its own sheet
/// (`SeggWat.presentChat()`) or pushed from the feedback form.
struct SeggWatChatView: View {
    @EnvironmentObject private var seggwat: SeggWat
    @Environment(\.scenePhase) private var scenePhase

    @State private var thread = ChatThread()
    @State private var draft = ""
    @State private var replyingTo: ChatReplyTo?
    @State private var isLoading = true
    @FocusState private var isComposerFocused: Bool
    @State private var errorMessage: String?
    /// The chat identity `messages` belong to.
    @State private var shownIdentity: Int?

    var body: some View {
        VStack(spacing: 0) {
            messageList
            composer
        }
        .navigationTitle(seggwat.localizedString("chat_title"))
        .navigationBarTitleDisplayMode(.inline)
        // Restarts for a new identity, and stops in the background so the
        // server doesn't mark replies read (and skip the push) while the user
        // is elsewhere.
        .task(id: ChatSession(identity: seggwat.chatIdentity, isActive: scenePhase == .active)) {
            if shownIdentity != seggwat.chatIdentity {
                shownIdentity = seggwat.chatIdentity
                thread = ChatThread()
                draft = ""
                replyingTo = nil
                errorMessage = nil
                isLoading = true
            }
            guard scenePhase == .active else { return }
            await listenForReplies()
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    if isLoading {
                        ProgressView().padding(.top, 32)
                    } else if thread.rows.isEmpty {
                        Text(seggwat.localizedString("chat_empty"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.top, 32)
                            .padding(.horizontal, 24)
                    }
                    ForEach(thread.rows) { row in
                        bubble(for: row, proxy: proxy).id(row.id)
                    }
                }
                .padding(16)
            }
            // A new last row: history loaded, a message arrived or was sent.
            .onChange(of: thread.rows.last?.id) { id in
                guard let id else { return }
                withAnimation { proxy.scrollTo(id, anchor: .bottom) }
            }
            // Scroll again once the keyboard has resized the list.
            .onChange(of: isComposerFocused) { focused in
                guard focused, let id = thread.rows.last?.id else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation { proxy.scrollTo(id, anchor: .bottom) }
                }
            }
        }
    }

    private func bubble(for row: ChatRow, proxy: ScrollViewProxy) -> some View {
        let message = row.message
        let isMine = message.sender == .you
        let senderName = name(of: message.sender)
        let time = message.createdDate?.formatted(date: .omitted, time: .shortened)
        return HStack {
            if isMine { Spacer(minLength: 48) }
            VStack(alignment: isMine ? .trailing : .leading, spacing: 4) {
                VStack(alignment: .leading, spacing: 6) {
                    if let quote = message.replyTo {
                        Button {
                            withAnimation { proxy.scrollTo(quote.messageId, anchor: .center) }
                        } label: {
                            quoteView(quote, isMine: isMine)
                        }
                        .buttonStyle(.plain)
                    }
                    Text(message.body)
                        .font(.body)
                        .foregroundColor(isMine ? .white : .primary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isMine ? seggwat.options.buttonColor : Color(.secondarySystemBackground))
                )
                .opacity(row.state == .sent ? 1 : 0.6)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Text(verbatim: "\(senderName): \(message.body)"))
                .accessibilityValue(row.state == .failed ? "" : time ?? "")
                .contextMenu {
                    if row.state == .sent {
                        Button {
                            replyingTo = ChatReplyTo(quoting: message)
                            isComposerFocused = true
                        } label: {
                            Label(seggwat.localizedString("chat_reply"), systemImage: "arrowshape.turn.up.left")
                        }
                    }
                }
                if row.state == .failed {
                    Button {
                        thread.remove(row.id)
                        send(message.body, replyTo: message.replyTo)
                    } label: {
                        VStack(alignment: .trailing, spacing: 2) {
                            if let reason = row.failureReason {
                                Text(reason)
                            }
                            Text(seggwat.localizedString("chat_send_failed"))
                        }
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.trailing)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(time.map { "\(senderName) · \($0)" } ?? senderName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .accessibilityHidden(true)
                }
            }
            if !isMine { Spacer(minLength: 48) }
        }
    }

    private func quoteView(_ quote: ChatReplyTo, isMine: Bool) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 1)
                .frame(width: 2)
            VStack(alignment: .leading, spacing: 1) {
                Text(name(of: quote.sender)).font(.caption.weight(.semibold))
                Text(quote.snippet).font(.caption).lineLimit(2)
            }
        }
        .foregroundColor(isMine ? .white.opacity(0.85) : .secondary)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func name(of sender: ChatMessage.Sender) -> String {
        seggwat.localizedString(sender == .team ? "chat_sender_team" : "chat_sender_you")
    }

    private var composer: some View {
        let length = ChatBody.length(draft)
        return VStack(spacing: 4) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let replyingTo {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(seggwat.localizedString("chat_replying_to", name(of: replyingTo.sender)))
                            .font(.caption.weight(.semibold))
                        Text(replyingTo.snippet)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Button {
                        self.replyingTo = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                    }
                    .accessibilityLabel(seggwat.localizedString("chat_reply_cancel"))
                }
            }
            if length > ChatBody.maxLength {
                Text(seggwat.localizedString("chat_too_long", length, ChatBody.maxLength))
                    .font(.caption)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(alignment: .bottom, spacing: 8) {
                TextField(seggwat.localizedString("chat_placeholder"), text: $draft, axis: .vertical)
                    .lineLimit(1...5)
                    .focused($isComposerFocused)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(18)
                Button {
                    let body = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                    draft = ""
                    let reply = replyingTo
                    replyingTo = nil
                    send(body, replyTo: reply)
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(seggwat.options.buttonColor)
                }
                .disabled(length == 0 || length > ChatBody.maxLength)
                .accessibilityLabel(seggwat.localizedString("chat_send"))
            }
        }
        .padding(12)
        .background(.bar)
    }

    /// Load the history and merge it with what's on screen, keeping messages
    /// the stream delivered meanwhile.
    private func loadHistory() async throws {
        let history = try await seggwat.chatHistory()
        thread.merge(history: history)
        errorMessage = nil
        isLoading = false
    }

    /// Show the message at once and send it in the background; a failed
    /// send stays on screen with a retry.
    private func send(_ body: String, replyTo: ChatReplyTo?) {
        let localId = thread.addPending(body: body, replyTo: replyTo)
        Task { @MainActor in
            do {
                let message = try await seggwat.sendChatMessage(body, replyTo: replyTo)
                thread.markSent(localId, as: message)
            } catch is CancellationError {
            } catch SeggWatError.chatMessageRejected(let reason) {
                thread.markFailed(localId, reason: reason)
            } catch {
                thread.markFailed(localId, reason: nil)
            }
        }
    }

    /// Hold the SSE stream open while the view is visible, reconnecting after
    /// a drop with exponential backoff (3s doubling to 60s), so a rate-limited
    /// or offline client doesn't hammer the server. The history loads while
    /// the stream connects (which can take until the first keep-alive), and
    /// once more after, so no reply falls between the two. The `.task`
    /// modifier cancels this when it disappears.
    private func listenForReplies() async {
        var failures = 0
        while !Task.isCancelled {
            do {
                async let connecting = seggwat.chatStream()
                try await loadHistory()
                let stream = try await connecting
                try await loadHistory()
                failures = 0
                var parser = ChatStreamParser()
                for try await line in stream.lines {
                    switch parser.consume(line) {
                    case .message(let message):
                        thread.receive(message)
                    case .resync:
                        try await loadHistory()
                    case nil:
                        break
                    }
                }
            } catch is CancellationError {
                return
            } catch SeggWatError.chatTokenInvalid, SeggWatError.chatTokenMissing,
                    SeggWatError.attestationUnsupported, SeggWatError.attestationFailed {
                showLoadErrorIfLoading()
                return
            } catch {
                // Show the history even while the stream can't connect.
                if isLoading { try? await loadHistory() }
                showLoadErrorIfLoading()
            }
            let delay = min(3 << min(failures, 5), 60)
            failures += 1
            try? await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000_000)
        }
    }

    private func showLoadErrorIfLoading() {
        guard isLoading, !Task.isCancelled else { return }
        errorMessage = seggwat.localizedString("chat_error_load")
        isLoading = false
    }
}

private struct ChatSession: Equatable {
    let identity: Int
    let isActive: Bool
}

/// A message on screen, with the delivery state of the user's own sends.
struct ChatRow: Identifiable, Equatable {
    enum DeliveryState {
        case sent, pending, failed
    }

    var message: ChatMessage
    var state: DeliveryState = .sent
    /// The server's reason a send failed, when it gave one.
    var failureReason: String?

    var id: String { message.id }
}

/// The rows of the chat: delivered messages plus sends in flight or failed.
struct ChatThread {
    private(set) var rows: [ChatRow] = []

    /// Replace delivered messages with the history, keeping what the stream
    /// delivered meanwhile and the user's unconfirmed sends.
    mutating func merge(history: [ChatMessage]) {
        let ids = Set(history.map(\.id))
        rows = history.map { ChatRow(message: $0) } + rows.filter { !ids.contains($0.id) }
    }

    mutating func receive(_ message: ChatMessage) {
        guard !rows.contains(where: { $0.id == message.id }) else { return }
        rows.append(ChatRow(message: message))
    }

    /// Append a send in flight under a temporary id, which it returns.
    mutating func addPending(body: String, replyTo: ChatReplyTo?) -> String {
        let message = ChatMessage(
            id: "local-\(UUID().uuidString)",
            sender: .you,
            body: body,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            replyTo: replyTo
        )
        rows.append(ChatRow(message: message, state: .pending))
        return message.id
    }

    /// Swap the temporary row for the delivered message, or drop it if a
    /// history load already brought the message in.
    mutating func markSent(_ localId: String, as message: ChatMessage) {
        guard let index = rows.firstIndex(where: { $0.id == localId }) else { return }
        if rows.contains(where: { $0.id == message.id }) {
            rows.remove(at: index)
        } else {
            rows[index] = ChatRow(message: message)
        }
    }

    mutating func markFailed(_ localId: String, reason: String?) {
        guard let index = rows.firstIndex(where: { $0.id == localId }) else { return }
        rows[index].state = .failed
        rows[index].failureReason = reason
    }

    mutating func remove(_ id: String) {
        rows.removeAll { $0.id == id }
    }
}
