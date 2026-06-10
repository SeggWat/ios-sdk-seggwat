import SwiftUI

/// "Powered by SeggWat" branding footer.
struct PoweredByView: View {
    @EnvironmentObject private var seggwat: SeggWat

    var body: some View {
        if seggwat.options.showPoweredBy {
            Link(destination: URL(string: "https://seggwat.com")!) {
                Text(seggwat.localizedString("powered_by"))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 4)
        }
    }
}
