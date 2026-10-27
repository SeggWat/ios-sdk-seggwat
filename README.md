# SeggWat iOS SDK — In-App Feedback, Ratings & NPS for SwiftUI

[![Swift Package Manager](https://img.shields.io/badge/Swift_Package_Manager-compatible-2563eb.svg)](https://swift.org/package-manager/)
[![Platform](https://img.shields.io/badge/platform-iOS_16%2B-2563eb.svg)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.9%2B-f05138.svg)](https://swift.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-10b981.svg)](LICENSE)
[![Zero dependencies](https://img.shields.io/badge/dependencies-0-10b981.svg)](Package.swift)

**Collect user feedback, bug reports, screenshots, and NPS/star ratings directly inside your iOS app.** The SeggWat iOS SDK drops a native SwiftUI feedback button into any app in two lines of code — no web view, no third-party tracking, no dependencies. Built by [SeggWat](https://seggwat.com), the feedback platform built with Rust, engineered in Germany, and hosted in Europe.

> Feedback is the fuel to growth! Collect. Understand. Improve.

```swift
SeggWat.configure(projectKey: "your-project-uuid")

ContentView()
    .seggwatFeedbackButton()   // floating feedback button, done.
```

---

## Table of Contents

- [Why SeggWat](#why-seggwat)
- [Features](#features)
- [Requirements](#requirements)
- [Installation (Swift Package Manager)](#installation)
- [Quick Start](#quick-start)
- [Collecting Feedback](#collecting-feedback)
- [Star, Helpful & NPS Ratings](#ratings)
- [In-App Support Chat](#chat)
- [Screenshot Capture & Annotation](#screenshots)
- [Configuration](#configuration)
- [Localization](#localization)
- [Privacy & Data Ownership](#privacy)
- [Error Handling](#error-handling)
- [API Compatibility](#api-compatibility)
- [FAQ](#faq)
- [License](#license)

---

## Why SeggWat

Most in-app feedback tools ship a heavy SDK, a web view, and an analytics tracker you didn't ask for. SeggWat is the opposite:

- **Native SwiftUI** — real Swift, real `View`s, no `WKWebView`.
- **Zero external dependencies** — nothing to audit, nothing to break.
- **You own your data** — feedback flows to your own SeggWat project, not a black box. Self-host or use our EU-hosted cloud.
- **One submission API for everything** — feedback, screenshots, helpful/star/NPS ratings all go through the same SDK.

If you collect feedback on the web with the [SeggWat widget](https://seggwat.com), this SDK submits to the same project and shows up in the same dashboard, MCP server, and triage app.

<a name="features"></a>
## Features

- 📝 **In-app feedback button** — a floating, themeable SwiftUI button and modal form.
- 🐞 **Bug reports with screenshots** — capture the current screen and annotate it before sending.
- ✏️ **Full screenshot annotation** — pen, arrow, rectangle, text, and blackout/redaction tools with undo/redo.
- ⭐ **Ratings** — helpful (thumbs up/down), star (1–5 or custom), and **NPS** (0–10).
- 💬 **Support chat** — users message your team in-app and see your replies live, with an unread badge and push notifications.
- 🌟 **Review prompt** — happy raters get the App Store review dialog, unhappy ones the feedback form.
- 🌍 **Localization** — English, German, and Swedish out of the box; auto-detected from the device.
- 🙋 **User attribution** — attach a user ID and email to correlate feedback with accounts and reply directly.
- 🛡️ **Built-in rate limiting** — a client-side cooldown prevents accidental double submissions.
- 📦 **Swift Package Manager** — one line in Xcode, zero dependencies, iOS 16+.

<a name="requirements"></a>
## Requirements

- iOS 16 or later
- SwiftUI
- Swift 5.9+ (Xcode 15+)
- Zero external dependencies

<a name="installation"></a>
## Installation

### Swift Package Manager

In Xcode: **File → Add Package Dependencies…** and enter:

```
https://github.com/SeggWat/ios-sdk-seggwat.git
```

Or add it to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/SeggWat/ios-sdk-seggwat.git", from: "1.3.0")
]
```

You can also reference it as a local package during development.

<a name="quick-start"></a>
## Quick Start

### 1. Configure the SDK

Call `configure` once, typically in your `App` initializer:

```swift
import SeggWatSDK

@main
struct MyApp: App {
    init() {
        SeggWat.configure(
            projectKey: "your-project-uuid",
            options: SeggWatOptions(
                buttonColor: .blue,
                screenshotsEnabled: true
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .seggwatFeedbackButton()
        }
    }
}
```

### 2. Identify the user (optional)

```swift
SeggWat.setUser("user-123")

// Pass an email too so the submitter is contactable in the dashboard
// (your team can reply directly) instead of showing as anonymous:
SeggWat.setUser("user-123", email: "jane@example.com")
```

### 3. Control the form programmatically

```swift
SeggWat.presentFeedback()   // open the feedback form
SeggWat.dismiss()           // close it
```

<a name="collecting-feedback"></a>
## Collecting Feedback

Submit feedback in code — with or without a screenshot:

```swift
try await SeggWat.shared.submitFeedback(
    message: "Loving the new dashboard!",
    screenName: "/settings"
)
```

<a name="ratings"></a>
## Star, Helpful & NPS Ratings

One method covers every rating type:

```swift
// Helpful (thumbs up / down)
try await SeggWat.shared.submitRating(.helpful(true), screenName: "/settings")

// Star rating (1–5, default max 5)
try await SeggWat.shared.submitRating(.star(value: 4), screenName: "/product")

// Star rating with a custom maximum
try await SeggWat.shared.submitRating(.star(value: 8, maxStars: 10))

// NPS (0–10)
try await SeggWat.shared.submitRating(.nps(9), screenName: "/checkout")
```

NPS, helpful, and star ratings aggregate into the same dashboard stats as your web widgets.

### Turn happy ratings into App Store reviews

Set `reviewPrompt` and `submitRating(_:)` routes the user after a star or NPS rating: happy users get Apple's App Store review dialog, unhappy users get the feedback form (attach `.seggwatFeedbackButton()` somewhere in the view hierarchy so the sheet can present).

```swift
SeggWat.configure(projectKey: "your-project-uuid", options: SeggWatOptions(
    reviewPrompt: ReviewPromptOptions(minimumStars: 4, minimumNps: 9) // defaults
))

try await SeggWat.shared.submitRating(.star(value: 5)) // → App Store review dialog
try await SeggWat.shared.submitRating(.nps(4))         // → feedback form
```

Helpful ratings never prompt. Apple decides whether the dialog actually appears (at most three times per user per year).

<a name="chat"></a>
## In-App Support Chat

Let users message your team and read your replies without leaving the app. Replies you send from the SeggWat dashboard arrive live while the chat is open; the floating button shows an unread badge otherwise, and users who are away get the reply by email when the token carries their `email`.

Chat is a Pro feature and needs an end-user token: an HS256 JWT your **backend** mints with the project's end-user signing secret (claims `sub`, `project_key`, `iat`, `exp`, optional `email`/`name`). See [Portal authentication](https://seggwat.com/docs/features/portal-authentication).

```swift
// After sign-in, with a token from your backend
SeggWat.setChatToken(tokenFromYourBackend)

// Open the chat directly, e.g. from a "Contact support" row
SeggWat.presentChat()

// On sign-out
SeggWat.setChatToken(nil)
```

### No backend? Use anonymous chat

Turn on **Anonymous chat in apps** under the project's widget settings (Live Chat must be on), then:

```swift
SeggWat.enableAnonymousChat()
```

The SDK creates a random identity per install and keeps it in the Keychain, so the conversation survives relaunches. You won't know who the user is and they get no reply emails, and a later `setChatToken(_:)` starts a separate conversation. Anyone can start an anonymous conversation, so set your **Apple Team ID** under the anonymous chat setting: SeggWat then requires [App Attest](https://developer.apple.com/documentation/devicecheck/establishing-your-app-s-integrity), and only genuine installs of your app on real devices can chat. The SDK attests automatically, once per install. The iOS Simulator can't attest, so leave the Team ID empty while testing there.

### Push notifications for replies

Upload your APNs key (`.p8`) in the project's widget settings, add the **Push Notifications** capability, and wire up your app delegate:

```swift
// App init, after configure
SeggWat.enablePushNotifications()

// AppDelegate
func application(_ application: UIApplication,
                 didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    SeggWat.setPushToken(deviceToken)
}

// UNUserNotificationCenterDelegate
func userNotificationCenter(_ center: UNUserNotificationCenter,
                            didReceive response: UNNotificationResponse) async {
    SeggWat.handleNotification(response.notification.request.content.userInfo) // opens the chat
}
```

The SDK asks for notification permission after the user's first chat message, and SeggWat only pushes a reply the user hasn't already seen in an open chat. See the [iOS SDK guide](https://seggwat.com/docs/guides/ios-sdk#push-notifications-for-replies).

With a token set, the feedback form shows a **Chat with us** button, and tapping the floating button while a reply is unread opens the conversation. `SeggWat.shared.unreadCount` is published if you want your own badge.

<a name="screenshots"></a>
## Screenshot Capture & Annotation

When `screenshotsEnabled` is `true`, the feedback form gains an **Add Screenshot** button that:

1. Captures the current screen.
2. Opens a fullscreen annotation editor with:
   - Pen drawing (PencilKit)
   - Arrow, rectangle, and text tools
   - Blackout / redaction for sensitive data
   - Color presets and stroke widths
   - Undo / redo
3. Attaches the annotated screenshot (JPEG) to the feedback submission.

<a name="configuration"></a>
## Configuration

`SeggWatOptions` supports:

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `buttonColor` | `Color` | `.blue` | Floating button color |
| `buttonPosition` | `ButtonPosition` | `.bottomTrailing` | Button placement |
| `appVersion` | `String?` | Auto from bundle | Version sent with feedback |
| `language` | `String?` | Auto from locale | UI language (`en`, `de`, `sv`) |
| `apiURL` | `URL` | `https://seggwat.com` | API base URL |
| `showPoweredBy` | `Bool` | `true` | Show branding footer |
| `screenshotsEnabled` | `Bool` | `true` | Enable screenshot capture |
| `compressionQuality` | `CGFloat` | `0.8` | JPEG quality (0.0–1.0) |
| `maxScreenshotSizeMB` | `Int` | `5` | Max screenshot size |
| `onSubmit` | Closure | `nil` | Callback after submission |

### Button positions

```swift
.bottomTrailing  // default
.bottomLeading
.topTrailing
.topLeading
```

<a name="localization"></a>
## Localization

The SDK ships with English, German, and Swedish. Language is auto-detected from the device, or pinned explicitly:

```swift
SeggWatOptions(language: "de")  // force German
```

<a name="privacy"></a>
## Privacy & Data Ownership

SeggWat is designed for teams that care where their data lives:

- **No third-party tracking or analytics** baked into the SDK.
- **Your data, your project** — submissions go straight to your SeggWat project.
- **EU hosting available** — hosted in Europe, or self-host the open platform.

The SDK sends `X-SeggWat-Platform: iOS` and `X-SeggWat-BundleID` headers so you can attribute and restrict native submissions by bundle ID (see [Origin & bundle-ID allowlisting](#api-compatibility)).

<a name="error-handling"></a>
## Error Handling

```swift
do {
    try await SeggWat.shared.submitFeedback(message: "Bug report")
} catch let error as SeggWatError {
    switch error {
    case .rateLimited(let seconds):
        print("Wait \(seconds) seconds")
    case .projectNotFound:
        print("Check your project key")
    case .validationFailed(let reason):
        print("Invalid input: \(reason)")
    default:
        print(error.localizedDescription)
    }
}
```

A 10-second client-side cooldown prevents accidental double submissions; the server enforces its own rate limits too.

<a name="api-compatibility"></a>
## API Compatibility

The SDK submits to the same public endpoints as the SeggWat web widgets:

- `POST /api/v1/feedback/submit` — feedback (JSON, no screenshot)
- `POST /api/v1/feedback/submit-with-screenshot` — feedback with screenshot (multipart)
- `POST /api/v1/ratings` — unified rating submission

### Origin & bundle-ID allowlisting

Native apps don't send an `Origin` or `Referer` header, so a project that allowlists specific web origins returns **403** to native submissions. The SDK automatically sends the app's bundle identifier as `X-SeggWat-BundleID` (alongside `X-SeggWat-Platform: iOS`) — add that bundle ID to your project's **Allowed Bundle IDs** in the dashboard settings, next to Allowed Origins, to accept submissions from the app.

Alternatively, include `"*"` in the project's **allowed origins**, but that accepts every web origin too — not recommended.

<a name="faq"></a>
## FAQ

**How do I add a feedback button to a SwiftUI app?**
Call `SeggWat.configure(projectKey:)` once, then add `.seggwatFeedbackButton()` to any view. That's the whole integration.

**Does the SeggWat iOS SDK have any dependencies?**
No. It's pure SwiftUI with zero external dependencies and supports iOS 16 and later.

**Can I collect NPS and star ratings, not just feedback?**
Yes. `submitRating(_:)` handles helpful, star (1–5 or custom max), and NPS (0–10) ratings, aggregated alongside your web ratings.

**Can users attach screenshots to bug reports?**
Yes. Enable `screenshotsEnabled` and users can capture and annotate the current screen before submitting.

**Where does the feedback go?**
To your own SeggWat project — visible in the dashboard, the MCP server, the CLI, and the iOS triage app. You own the data and can self-host or use the EU-hosted cloud.

**Can I white-label the feedback form?**
Yes. Set `showPoweredBy: false` and customize `buttonColor` and `buttonPosition`.

<a name="license"></a>
## License

[MIT](LICENSE) © SeggWat

---

Built with Rust, engineered in Germany, hosted in Europe. Learn more at **[seggwat.com](https://seggwat.com)**.
