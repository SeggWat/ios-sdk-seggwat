import StoreKit
import UIKit

/// Routes users after a rating: happy users get the App Store review prompt,
/// unhappy users get the feedback form.
///
/// ```swift
/// SeggWat.configure(projectKey: "your-uuid", options: SeggWatOptions(
///     reviewPrompt: ReviewPromptOptions()
/// ))
///
/// // A 5-star rating now asks for an App Store review,
/// // a 2-star rating opens the feedback form.
/// try await SeggWat.shared.submitRating(.star(value: 5))
/// ```
///
/// Helpful ratings never trigger a prompt. Apple decides whether the review
/// dialog is actually shown (at most three times per year per user).
public struct ReviewPromptOptions: Sendable {
    /// Star ratings at or above this value request an App Store review;
    /// lower ones open the feedback form. Default: `4`.
    public var minimumStars: Int

    /// NPS scores at or above this value request an App Store review;
    /// lower ones open the feedback form. Default: `9` (promoters).
    public var minimumNps: Int

    public init(minimumStars: Int = 4, minimumNps: Int = 9) {
        self.minimumStars = minimumStars
        self.minimumNps = minimumNps
    }

    func action(for rating: RatingValue) -> ReviewPromptAction {
        switch rating {
        case .helpful:
            return .noPrompt
        case .star(let value, _):
            return Int(value) >= minimumStars ? .requestReview : .collectFeedback
        case .nps(let value):
            return Int(value) >= minimumNps ? .requestReview : .collectFeedback
        }
    }
}

enum ReviewPromptAction: Equatable {
    case requestReview
    case collectFeedback
    case noPrompt
}

@MainActor
func requestAppStoreReview() {
    let scene = UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .first { $0.activationState == .foregroundActive }
    guard let scene else { return }
    AppStore.requestReview(in: scene)
}
