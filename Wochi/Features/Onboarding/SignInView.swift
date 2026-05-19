import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @Binding var showOnboarding: Bool
    @EnvironmentObject private var appState: AppState

    @State private var showHouseholdSetup: Bool = false
    @State private var errorMessage: String?
    @State private var showError: Bool = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 48) {
                Spacer()

                // MARK: Logo wordmark
                LogoView()

                Spacer()

                // MARK: Sign in with Apple
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    handleSignInResult(result)
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 24)

                Spacer()
                    .frame(height: 32)
            }
            .alert(
                Text(verbatim: errorMessage ?? ""),
                isPresented: $showError
            ) {
                Button("button.confirm", role: .cancel) { }
            }
            .fullScreenCover(isPresented: $showHouseholdSetup) {
                HouseholdSetupView(showOnboarding: $showOnboarding)
            }
        }
    }

    // MARK: - Sign-in handler

    private func handleSignInResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential
            else {
                showErrorMessage(String(localized: "signin.error.processing"))
                return
            }

            let appleUserID = credential.user
            let displayName: String = {
                if let firstName = credential.fullName?.givenName,
                   let lastName = credential.fullName?.familyName,
                   !firstName.isEmpty {
                    return "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
                }
                return String(localized: "signin.default_name")
            }()

            let member = HouseholdMember(
                appleUserID: appleUserID,
                displayName: displayName,
                role: .owner
            )
            member.email = credential.email
            member.isCurrentDevice = true

            appState.currentMember = member
            UserDefaults.standard.set(true, forKey: Constants.UserDefaults.onboardingCompleted)
            showHouseholdSetup = true

        case .failure(let error):
            // ASAuthorizationError.canceled (code 1001) means the user dismissed
            // the sheet intentionally – no need to surface an alert.
            let asError = error as? ASAuthorizationError
            if asError?.code != .canceled {
                showErrorMessage(error.localizedDescription)
            }
        }
    }

    private func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
    }
}

// MARK: - Logo wordmark

private struct LogoView: View {
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 96, height: 96)

                Text("W")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            Text(verbatim: "Wochi")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
        }
    }
}

// MARK: - Preview

#Preview {
    SignInView(showOnboarding: .constant(true))
        .environmentObject(AppState())
}
