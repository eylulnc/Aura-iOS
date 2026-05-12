import SwiftUI
import SwiftData
import FirebaseAuth
import AuthenticationServices

struct OnboardingView: View {
    @Environment(AuthRepository.self) private var authRepo
    @Environment(\.modelContext) private var context
    @Environment(\.auraColors) private var colors

    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var showSyncConflict = false
    @State private var pendingUserId: String? = nil

    var body: some View {
        ZStack {
            colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo
                Image("ic_aura_wave")
                    .resizable()
                    .scaledToFit()
                    .frame(width: Spacing.loginIconSize, height: Spacing.loginIconSize)
                    .clipShape(RoundedRectangle(cornerRadius: Spacing.loginIconRadius))
                    .shadow(color: colors.accent.opacity(0.35), radius: 24, x: 0, y: 8)

                Spacer().frame(height: Spacing.xl)

                Text("AURA")
                    .font(.system(size: FontSize.xl, weight: .light, design: .serif))
                    .foregroundStyle(colors.textPrimary)
                    .tracking(10)

                Spacer().frame(height: Spacing.xs)

                Text("mood journal")
                    .font(.system(size: FontSize.s))
                    .foregroundStyle(colors.accent)
                    .tracking(3)

                Spacer().frame(height: Spacing.l)

                Rectangle()
                    .fill(colors.accent.opacity(0.3))
                    .frame(width: 48, height: 1)

                Spacer().frame(height: Spacing.l)

                Text("Track how you feel, find your patterns,\nunderstand yourself better.")
                    .font(.system(size: FontSize.s))
                    .foregroundStyle(colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                Spacer()

                // Sign in with Apple
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                    request.nonce = authRepo.prepareAppleSignIn()
                } onCompletion: { result in
                    switch result {
                    case .success(let auth):
                        Task {
                            do {
                                let user = try await authRepo.handleAppleSignIn(auth)
                                await handleSignIn(userId: user.uid)
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                        }
                    case .failure(let error):
                        if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                            errorMessage = error.localizedDescription
                        }
                    }
                }
                .signInWithAppleButtonStyle(colors.isDark ? .white : .black)
                .frame(height: 52)
                .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusPill))
                .disabled(isLoading)

                Spacer().frame(height: Spacing.m)

                // Sign in with Google
                Button {
                    Task {
                        do {
                            let user = try await authRepo.signInWithGoogle()
                            await handleSignIn(userId: user.uid)
                        } catch {
                            let nsErr = error as NSError
                            // Ignore user-cancelled Google sign-in
                            if nsErr.domain != "com.google.GIDSignIn" || nsErr.code != -5 {
                                errorMessage = error.localizedDescription
                            }
                        }
                    }
                } label: {
                    HStack(spacing: Spacing.m) {
                        // Google "G" mark
                        ZStack {
                            Circle().fill(Color.white).frame(width: 22, height: 22)
                            Text("G")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color(hex: "#4285F4"))
                        }
                        Text("Sign in with Google")
                            .font(.system(size: FontSize.m, weight: .medium))
                            .foregroundStyle(colors.textPrimary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusPill))
                    .overlay(
                        RoundedRectangle(cornerRadius: Spacing.radiusPill)
                            .stroke(colors.border, lineWidth: Spacing.borderWidth)
                    )
                }
                .buttonStyle(.plain)
                .disabled(isLoading)

                Spacer().frame(height: Spacing.m)

                // Continue as guest
                Button {
                    AppPreferences.shared.hasCompletedOnboarding = true
                } label: {
                    Text("Continue as Guest")
                        .font(.system(size: FontSize.m))
                        .foregroundStyle(colors.textSecondary)
                        .padding(.vertical, Spacing.m)
                        .frame(maxWidth: .infinity)
                }
                .disabled(isLoading)

                Spacer().frame(height: Spacing.xxl)
            }
            .padding(.horizontal, Spacing.xl)

            // Loading overlay
            if isLoading {
                Color.black.opacity(0.3).ignoresSafeArea()
                ProgressView()
                    .tint(colors.accent)
                    .scaleEffect(1.5)
            }
        }
        .alert("Sign In Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .alert("Account Data Found", isPresented: $showSyncConflict) {
            Button("Keep Device Data") {
                guard let uid = pendingUserId else { return }
                Task { await resolveConflict(keepLocal: true, userId: uid) }
            }
            Button("Keep Account Data", role: .destructive) {
                guard let uid = pendingUserId else { return }
                Task { await resolveConflict(keepLocal: false, userId: uid) }
            }
            Button("Cancel", role: .cancel) {
                try? authRepo.signOut()
                pendingUserId = nil
            }
        } message: {
            Text("Your account already has saved mood data, and this device also has local entries. Which would you like to keep?\n\nThe other data will be permanently deleted.")
        }
    }

    // MARK: - Helpers

    private func handleSignIn(userId: String) async {
        isLoading = true
        let repo = MoodRepository(context: context)
        let state = await repo.checkSyncStateOnLogin(userId: userId)
        switch state {
        case .noData:
            AppPreferences.shared.hasCompletedOnboarding = true
        case .uploadLocal:
            await repo.pushLocalToRemote(userId: userId)
            AppPreferences.shared.hasCompletedOnboarding = true
        case .downloadRemote:
            await repo.pullRemoteToLocal(userId: userId)
            AppPreferences.shared.hasCompletedOnboarding = true
        case .conflict:
            pendingUserId = userId
            showSyncConflict = true
        }
        isLoading = false
    }

    private func resolveConflict(keepLocal: Bool, userId: String) async {
        isLoading = true
        let repo = MoodRepository(context: context)
        if keepLocal {
            await repo.pushLocalToRemote(userId: userId)
        } else {
            await repo.pullRemoteToLocal(userId: userId)
        }
        AppPreferences.shared.hasCompletedOnboarding = true
        isLoading = false
    }
}
