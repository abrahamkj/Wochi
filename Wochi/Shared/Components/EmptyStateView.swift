import SwiftUI

/// A reusable empty-state placeholder used throughout the Wochi app.
struct EmptyStateView: View {
    let symbol: String
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    var actionTitle: LocalizedStringKey? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: symbol)
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)
                .foregroundStyle(Color.accentColor)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.headline)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                .padding(.top, 8)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}

// MARK: - Preview

#Preview("With action") {
    EmptyStateView(
        symbol: "cart",
        title: "shopping.empty.title",
        subtitle: "shopping.empty.subtitle",
        actionTitle: "button.add"
    ) {
        print("Add tapped")
    }
}

#Preview("Without action") {
    EmptyStateView(
        symbol: "house",
        title: "pantry.empty.title",
        subtitle: "pantry.empty.subtitle"
    )
}
