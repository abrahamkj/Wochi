import SwiftUI

// MARK: - Error Banner View

/// A dismissible banner that slides in from the top to display a `WochiError` message.
/// Automatically dismisses after 4 seconds.
struct WochiErrorBanner: View {
    let error: WochiError

    /// Controls visibility; set to `false` to dismiss manually before the auto-timer fires.
    @Binding var isVisible: Bool

    // The banner offset starts above the screen and slides down when visible.
    @State private var offset: CGFloat = -200

    private var bannerColor: Color {
        switch error {
        case .networkUnavailable, .cloudKitSyncFailed, .supabaseFetchFailed:
            return Color.orange
        default:
            return Color.red
        }
    }

    var body: some View {
        VStack {
            if isVisible {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.white)
                        .font(.body.bold())

                    Text(verbatim: error.errorDescription ?? error.localizedDescription)
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.white.opacity(0.8))
                            .font(.caption.bold())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(bannerColor)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                .padding(.horizontal, 16)
                .transition(.move(edge: .top).combined(with: .opacity))
                .onAppear {
                    scheduleAutoDismiss()
                }
            }

            Spacer()
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: isVisible)
    }

    // MARK: - Helpers

    private func dismiss() {
        withAnimation {
            isVisible = false
        }
    }

    private func scheduleAutoDismiss() {
        Task {
            try? await Task.sleep(for: .seconds(4))
            dismiss()
        }
    }
}

// MARK: - View modifier for convenient usage

extension View {
    /// Overlays a `WochiErrorBanner` that slides from the top when `error` is non-nil.
    func wochiErrorBanner(error: Binding<WochiError?>) -> some View {
        overlay(alignment: .top) {
            if let boundError = error.wrappedValue {
                WochiErrorBanner(
                    error: boundError,
                    isVisible: Binding(
                        get: { error.wrappedValue != nil },
                        set: { visible in
                            if !visible { error.wrappedValue = nil }
                        }
                    )
                )
                .zIndex(999)
            }
        }
    }
}

// MARK: - Preview

#Preview("Network error") {
    @Previewable @State var visible = true
    return ZStack(alignment: .top) {
        Color(.systemGroupedBackground).ignoresSafeArea()

        WochiErrorBanner(
            error: .networkUnavailable,
            isVisible: $visible
        )
    }
}

#Preview("Household full (red)") {
    @Previewable @State var visible = true
    return ZStack(alignment: .top) {
        Color(.systemGroupedBackground).ignoresSafeArea()

        WochiErrorBanner(
            error: .householdFull,
            isVisible: $visible
        )
    }
}

#Preview("Via modifier") {
    @Previewable @State var currentError: WochiError? = .invalidInviteLink
    return NavigationStack {
        List {
            Text("Some content")
        }
        .navigationTitle("Preview")
    }
    .wochiErrorBanner(error: $currentError)
}
