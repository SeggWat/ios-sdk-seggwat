import SwiftUI

/// The main feedback sheet modal containing the form, screenshot, and success states.
struct SeggWatFeedbackView: View {
    @EnvironmentObject private var seggwat: SeggWat
    @Environment(\.dismiss) private var dismiss

    @State private var message = ""
    @State private var isSubmitting = false
    @State private var showSuccess = false
    @State private var errorMessage: String?
    @State private var screenshotImage: UIImage?
    @State private var showAnnotationEditor = false
    @State private var capturedImage: UIImage?

    var body: some View {
        NavigationStack {
            Group {
                if showSuccess {
                    SuccessView {
                        dismiss()
                        resetState()
                    }
                } else {
                    feedbackForm
                }
            }
            .navigationTitle(seggwat.localizedString("modal_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if !showSuccess {
                        Button(seggwat.localizedString("button_cancel")) {
                            dismiss()
                        }
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showAnnotationEditor) {
            if let capturedImage {
                AnnotationEditorView(
                    baseImage: capturedImage,
                    onSave: { annotated in
                        screenshotImage = annotated
                        showAnnotationEditor = false
                    },
                    onCancel: {
                        showAnnotationEditor = false
                    }
                )
                .environmentObject(seggwat)
            }
        }
    }

    private var feedbackForm: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(seggwat.localizedString("modal_subtitle"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                // Message input
                VStack(alignment: .leading, spacing: 6) {
                    Text(seggwat.localizedString("label_feedback"))
                        .font(.subheadline)
                        .fontWeight(.medium)

                    TextEditor(text: $message)
                        .frame(minHeight: 120)
                        .padding(8)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(10)
                        .overlay(
                            Group {
                                if message.isEmpty {
                                    Text(seggwat.localizedString("placeholder_message"))
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 16)
                                        .allowsHitTesting(false)
                                }
                            },
                            alignment: .topLeading
                        )

                    // Character count
                    HStack {
                        Spacer()
                        Text("\(message.trimmingCharacters(in: .whitespacesAndNewlines).count)/\(Validator.messageMaxLength)")
                            .font(.caption2)
                            .foregroundColor(
                                message.trimmingCharacters(in: .whitespacesAndNewlines).count > Validator.messageMaxLength
                                    ? .red : .secondary
                            )
                    }
                }

                // Screenshot section
                if seggwat.options.screenshotsEnabled {
                    if let screenshotImage {
                        ScreenshotPreviewView(image: screenshotImage) {
                            self.screenshotImage = nil
                        }
                    } else {
                        Button {
                            captureScreenshot()
                        } label: {
                            Label(
                                seggwat.localizedString("screenshot_button_label"),
                                systemImage: "camera.viewfinder"
                            )
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Error message
                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal, 4)
                }

                // Submit button
                Button {
                    Task { await submitFeedback() }
                } label: {
                    HStack {
                        if isSubmitting {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(isSubmitting
                             ? seggwat.localizedString("button_sending")
                             : seggwat.localizedString("button_submit"))
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(seggwat.options.buttonColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isSubmitting || message.trimmingCharacters(in: .whitespacesAndNewlines).count < Validator.messageMinLength)
                .opacity(isSubmitting ? 0.7 : 1)

                PoweredByView()
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(20)
        }
    }

    private func captureScreenshot() {
        // Dismiss sheet, capture, then re-present with editor
        dismiss()

        Task { @MainActor in
            // Wait for dismiss animation
            try? await Task.sleep(nanoseconds: 500_000_000)

            guard let data = ScreenshotCapture.capture(compressionQuality: seggwat.options.compressionQuality),
                  let image = UIImage(data: data) else {
                errorMessage = seggwat.localizedString("screenshot_error_capture")
                seggwat.isPresented = true
                return
            }

            capturedImage = image
            seggwat.isPresented = true

            // Small delay before presenting editor
            try? await Task.sleep(nanoseconds: 300_000_000)
            showAnnotationEditor = true
        }
    }

    private func submitFeedback() async {
        errorMessage = nil
        isSubmitting = true

        do {
            var screenshotData: Data?
            if let screenshotImage {
                screenshotData = ScreenshotCapture.compress(
                    screenshotImage,
                    quality: seggwat.options.compressionQuality,
                    maxSizeMB: seggwat.options.maxScreenshotSizeMB
                )
            }

            try await seggwat.submitFeedback(
                message: message,
                screenshotData: screenshotData
            )

            withAnimation {
                showSuccess = true
            }
        } catch let error as SeggWatError {
            errorMessage = error.errorDescription
            seggwat.options.onSubmit?(.failure(error))
        } catch {
            errorMessage = seggwat.localizedString("error_message")
        }

        isSubmitting = false
    }

    private func resetState() {
        message = ""
        screenshotImage = nil
        capturedImage = nil
        showSuccess = false
        errorMessage = nil
    }
}
