import SwiftUI

/// Thank-you view shown after successful feedback submission.
struct SuccessView: View {
    let onDismiss: () -> Void
    @EnvironmentObject private var seggwat: SeggWat
    @State private var checkmarkScale: CGFloat = 0

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)
                .scaleEffect(checkmarkScale)
                .onAppear {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                        checkmarkScale = 1
                    }
                }

            Text(seggwat.localizedString("success_message"))
                .font(.title3)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)

            Spacer()

            Button(action: onDismiss) {
                Text(seggwat.localizedString("button_close"))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(seggwat.options.buttonColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }

            PoweredByView()
        }
        .padding(24)
    }
}
