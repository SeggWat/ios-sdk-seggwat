import Foundation

/// Client-side rate limiter matching the web widget's 10-second cooldown.
final class RateLimiter: @unchecked Sendable {
    private let cooldownSeconds: Int
    private var lastSubmission: Date?
    private let lock = NSLock()

    init(cooldownSeconds: Int = 10) {
        self.cooldownSeconds = cooldownSeconds
    }

    /// Check if a submission is allowed. Returns nil if allowed, or the number of seconds remaining.
    func check() -> Int? {
        lock.lock()
        defer { lock.unlock() }

        guard let last = lastSubmission else { return nil }
        let elapsed = Date().timeIntervalSince(last)
        let remaining = Double(cooldownSeconds) - elapsed
        if remaining > 0 {
            return Int(ceil(remaining))
        }
        return nil
    }

    /// Record that a submission was made.
    func recordSubmission() {
        lock.lock()
        defer { lock.unlock() }
        lastSubmission = Date()
    }

    /// Reset the rate limiter (for testing).
    func reset() {
        lock.lock()
        defer { lock.unlock() }
        lastSubmission = nil
    }
}
