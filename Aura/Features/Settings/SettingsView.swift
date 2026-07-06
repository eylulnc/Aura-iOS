import SwiftUI
import SwiftData
import FirebaseAuth
import AuthenticationServices
import UIKit

struct SettingsView: View {
    @AppStorage("theme_mode") private var themeModeName: String = ThemeMode.system.rawValue
    @AppStorage("onboarding_done") private var hasCompletedOnboarding: Bool = false

    @Environment(AuthRepository.self) private var authRepo
    @Environment(\.modelContext) private var context
    @Environment(\.auraColors) private var colors

    @AppStorage("notifications_enabled") private var notificationsEnabled: Bool = false
    @AppStorage("reminder_hour") private var reminderHour: Int = 20
    @AppStorage("reminder_minute") private var reminderMinute: Int = 0

    @State private var isLoading = false
    @State private var showSignOutConfirm = false
    @State private var showSyncConflict = false
    @State private var showTimePicker = false
    @State private var showPermissionDenied = false
    @State private var pendingUserId: String? = nil
    @State private var errorMessage: String? = nil

    private var themeMode: ThemeMode { ThemeMode(rawValue: themeModeName) ?? .system }

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.xl) {

                        // Account
                        SettingsGroup(label: "ACCOUNT") {
                            if let user = authRepo.currentUser {
                                SignedInRow(user: user, onSignOut: { showSignOutConfirm = true })
                            } else {
                                GuestSignInRow(
                                    isLoading: isLoading,
                                    onAppleRequest: { request in
                                        request.requestedScopes = [.fullName, .email]
                                        request.nonce = authRepo.prepareAppleSignIn()
                                    },
                                    onAppleCompletion: { result in
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
                                    },
                                    onGoogle: {
                                        Task {
                                            do {
                                                let user = try await authRepo.signInWithGoogle()
                                                await handleSignIn(userId: user.uid)
                                            } catch {
                                                let nsErr = error as NSError
                                                if nsErr.domain != "com.google.GIDSignIn" || nsErr.code != -5 {
                                                    errorMessage = error.localizedDescription
                                                }
                                            }
                                        }
                                    }
                                )
                            }
                        }

                        // Appearance
                        SettingsGroup(label: "APPEARANCE") {
                            ThemePicker(selected: themeMode) { mode in
                                themeModeName = mode.rawValue
                            }
                        }

                        // Reminders
                        SettingsGroup(label: "REMINDERS") {
                            HStack {
                                Text("Daily reminder")
                                    .font(.system(size: FontSize.m))
                                    .foregroundStyle(colors.textPrimary)
                                Spacer()
                                Toggle("", isOn: Binding(
                                    get: { notificationsEnabled },
                                    set: { enabled in
                                        if enabled {
                                            Task { await enableNotifications() }
                                        } else {
                                            notificationsEnabled = false
                                            Task { await NotificationService.shared.cancelAll() }
                                        }
                                    }
                                ))
                                .tint(colors.accent)
                                .labelsHidden()
                            }
                            .padding(.vertical, Spacing.xs)

                            if notificationsEnabled {
                                Rectangle()
                                    .fill(colors.border)
                                    .frame(height: Spacing.borderWidth)
                                    .padding(.top, Spacing.s)

                                Button { showTimePicker = true } label: {
                                    HStack {
                                        Text("Reminder time")
                                            .font(.system(size: FontSize.m))
                                            .foregroundStyle(colors.textPrimary)
                                        Spacer()
                                        Text(formattedReminderTime)
                                            .font(.system(size: FontSize.m))
                                            .foregroundStyle(colors.textSecondary)
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: FontSize.s))
                                            .foregroundStyle(colors.textSecondary)
                                    }
                                    .padding(.vertical, Spacing.m)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        // Data & Privacy
                        SettingsGroup(label: "DATA & PRIVACY") {
                            NavigationLink {
                                DataPrivacyView(signedInUser: authRepo.currentUser)
                            } label: {
                                HStack {
                                    Text("Data & Privacy")
                                        .font(.system(size: FontSize.m))
                                        .foregroundStyle(colors.textPrimary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: FontSize.s))
                                        .foregroundStyle(colors.textSecondary)
                                }
                                .padding(.vertical, Spacing.xs)
                            }
                            .buttonStyle(.plain)
                        }

                        AppInfoFooter()
                    }
                    .padding(.horizontal, Spacing.l)
                    .padding(.top, Spacing.xl)
                    .padding(.bottom, Spacing.xxl)
                }
                .background(colors.background)
                .navigationBarTitleDisplayMode(.inline)

                if isLoading {
                    Color.black.opacity(0.3).ignoresSafeArea()
                    ProgressView().tint(colors.accent).scaleEffect(1.5)
                }
            }
        }
        .alert("Sign Out", isPresented: $showSignOutConfirm) {
            Button("Sign Out", role: .destructive) { signOut() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your local data will be cleared. You can sign back in to restore your entries from the cloud.")
        }
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .sheet(isPresented: $showTimePicker) {
            ReminderTimePickerSheet(hour: reminderHour, minute: reminderMinute) { hour, minute in
                reminderHour = hour
                reminderMinute = minute
                Task { await scheduleNotifications() }
            }
        }
        .alert("Notifications Disabled", isPresented: $showPermissionDenied) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("To receive daily reminders, enable notifications for Aura in iOS Settings.")
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

    private func handleSignIn(userId: String) async {
        isLoading = true
        let repo = MoodRepository(context: context)
        let state = await repo.checkSyncStateOnLogin(userId: userId)
        switch state {
        case .noData:       break
        case .uploadLocal:  await repo.pushLocalToRemote(userId: userId)
        case .downloadRemote: await repo.pullRemoteToLocal(userId: userId)
        case .conflict:
            pendingUserId = userId
            showSyncConflict = true
        }
        isLoading = false
    }

    private func resolveConflict(keepLocal: Bool, userId: String) async {
        isLoading = true
        let repo = MoodRepository(context: context)
        if keepLocal { await repo.pushLocalToRemote(userId: userId) }
        else         { await repo.pullRemoteToLocal(userId: userId) }
        isLoading = false
    }

    private func signOut() {
        isLoading = true
        Task {
            do {
                let repo = MoodRepository(context: context)
                try repo.deleteAllLocal()
                try authRepo.signOut()
                AppPreferences.shared.resetOnboarding()
                hasCompletedOnboarding = false
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    // MARK: - Notifications

    private var formattedReminderTime: String {
        var components = DateComponents()
        components.hour = reminderHour
        components.minute = reminderMinute
        let date = Calendar.current.date(from: components) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }

    private func enableNotifications() async {
        let status = await NotificationService.shared.authorizationStatus()
        switch status {
        case .notDetermined:
            let granted = await NotificationService.shared.requestPermission()
            if granted {
                notificationsEnabled = true
                await scheduleNotifications()
            } else {
                notificationsEnabled = false
            }
        case .authorized, .provisional, .ephemeral:
            notificationsEnabled = true
            await scheduleNotifications()
        case .denied:
            notificationsEnabled = false
            showPermissionDenied = true
        @unknown default:
            notificationsEnabled = false
        }
    }

    private func scheduleNotifications() async {
        let userId = authRepo.currentUser?.uid ?? ""
        let loggedToday = (try? MoodRepository(context: context)
            .getByDate(MoodEntry.todayString(), userId: userId)) != nil
        await NotificationService.shared.scheduleAll(
            hour: reminderHour,
            minute: reminderMinute,
            hasLoggedToday: loggedToday
        )
    }
}

// MARK: - Signed-in account row

private struct SignedInRow: View {
    let user: FirebaseAuth.User
    let onSignOut: () -> Void

    @Environment(\.auraColors) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            HStack(spacing: Spacing.m) {
                ZStack {
                    Circle()
                        .fill(colors.surfaceSubtle)
                        .frame(width: 40, height: 40)
                    Text(String((user.displayName ?? user.email ?? "?").prefix(1)).uppercased())
                        .font(.system(size: FontSize.m, weight: .semibold))
                        .foregroundStyle(colors.accent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    if let name = user.displayName, !name.isEmpty {
                        Text(name)
                            .font(.system(size: FontSize.m, weight: .medium))
                            .foregroundStyle(colors.textPrimary)
                    }
                    if let email = user.email {
                        Text(email)
                            .font(.system(size: FontSize.s))
                            .foregroundStyle(colors.textSecondary)
                    }
                }
            }

            Rectangle()
                .fill(colors.border)
                .frame(height: Spacing.borderWidth)

            Button(action: onSignOut) {
                Text("Sign Out")
                    .font(.system(size: FontSize.m))
                    .foregroundStyle(Color.red)
                    .padding(.vertical, Spacing.xs)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Guest sign-in row

private struct GuestSignInRow: View {
    let isLoading: Bool
    let onAppleRequest: (ASAuthorizationAppleIDRequest) -> Void
    let onAppleCompletion: (Result<ASAuthorization, Error>) -> Void
    let onGoogle: () -> Void

    @Environment(\.auraColors) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Signed in as Guest")
                    .font(.system(size: FontSize.m, weight: .medium))
                    .foregroundStyle(colors.textPrimary)
                Text("Sign in to back up your entries and sync across devices.")
                    .font(.system(size: FontSize.s))
                    .foregroundStyle(colors.textSecondary)
            }

            Rectangle()
                .fill(colors.border)
                .frame(height: Spacing.borderWidth)

            SignInWithAppleButton(.signIn, onRequest: onAppleRequest, onCompletion: onAppleCompletion)
                .signInWithAppleButtonStyle(colors.isDark ? .white : .black)
                .frame(height: 44)
                .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusPill))
                .disabled(isLoading)

            Button(action: onGoogle) {
                HStack(spacing: Spacing.m) {
                    ZStack {
                        Circle().fill(Color.white).frame(width: 20, height: 20)
                        Text("G")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color(hex: "#4285F4"))
                    }
                    Text("Sign in with Google")
                        .font(.system(size: FontSize.s, weight: .medium))
                        .foregroundStyle(colors.textPrimary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(colors.surfaceSubtle)
                .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusPill))
                .overlay(
                    RoundedRectangle(cornerRadius: Spacing.radiusPill)
                        .stroke(colors.border, lineWidth: Spacing.borderWidth)
                )
            }
            .buttonStyle(.plain)
            .disabled(isLoading)
        }
        .padding(.vertical, Spacing.xs)
    }
}

// MARK: - Theme Picker

private struct ThemePicker: View {
    let selected: ThemeMode
    let onSelect: (ThemeMode) -> Void

    @Environment(\.auraColors) private var colors

    private let options: [(ThemeMode, String)] = [(.system, "System"), (.light, "Light"), (.dark, "Dark")]

    var body: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(options, id: \.0.rawValue) { mode, label in
                let isSelected = selected == mode
                Button { onSelect(mode) } label: {
                    Text(label)
                        .font(.system(size: FontSize.s, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? colors.textPrimary : colors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.s)
                        .background(isSelected ? colors.background : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: Spacing.s))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Spacing.xs)
        .background(colors.textSecondary.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusButton))
    }
}

// MARK: - Settings Group

private struct SettingsGroup<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content
    @Environment(\.auraColors) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(label)
                .font(.system(size: FontSize.xs, weight: .semibold))
                .foregroundStyle(colors.textSecondary)
                .tracking(1.5)
                .padding(.leading, Spacing.s)
            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .padding(Spacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusCard))
        }
    }
}

// MARK: - App Info Footer

private struct AppInfoFooter: View {
    @Environment(\.auraColors) private var colors
    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }
    var body: some View {
        VStack(spacing: Spacing.xs) {
            Text("AURA")
                .font(.system(size: FontSize.xs, weight: .semibold))
                .foregroundStyle(colors.textSecondary)
                .tracking(1.5)
            Text("Version \(version)")
                .font(.system(size: FontSize.xs))
                .foregroundStyle(colors.textSecondary.opacity(0.7))
            Text("by Eylül Naz Can")
                .font(.system(size: FontSize.xs))
                .foregroundStyle(colors.textSecondary.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xl)
    }
}

// MARK: - Data & Privacy Screen

private enum PrivacyAlert: Identifiable {
    case deleteData, deleteAccount, error(String)
    var id: String {
        switch self {
        case .deleteData:     return "deleteData"
        case .deleteAccount:  return "deleteAccount"
        case .error(let msg): return "error_\(msg)"
        }
    }
}

private struct DataPrivacyView: View {
    let signedInUser: FirebaseAuth.User?

    @Environment(AuthRepository.self) private var authRepo
    @Environment(\.modelContext) private var context
    @Environment(\.auraColors) private var colors
    @AppStorage("onboarding_done") private var hasCompletedOnboarding: Bool = false

    @State private var activeAlert: PrivacyAlert? = nil
    @State private var isLoading = false
    @State private var toastMessage: String? = nil

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    DestructiveCard(
                        title: "Delete All Data",
                        description: signedInUser != nil
                            ? "Permanently removes all mood entries from this device and the cloud. Your account stays active."
                            : "Permanently removes all mood entries from this device.",
                        buttonLabel: "Delete All Data",
                        action: { activeAlert = .deleteData }
                    )

                    if signedInUser != nil {
                        DestructiveCard(
                            title: "Delete Account",
                            description: "Permanently deletes your account and all your mood entries, both locally and from the cloud.",
                            buttonLabel: "Delete Account",
                            action: { activeAlert = .deleteAccount }
                        )
                    }
                }
                .padding(.horizontal, Spacing.l)
                .padding(.top, Spacing.xl)
                .padding(.bottom, Spacing.xxl)
            }
            .background(colors.background)

            if isLoading {
                Color.black.opacity(0.3).ignoresSafeArea()
                ProgressView().tint(colors.accent).scaleEffect(1.5)
            }
        }
        .navigationTitle("Data & Privacy")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .bottom) {
            if let msg = toastMessage {
                Text(msg)
                    .font(.system(size: FontSize.s, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.l)
                    .padding(.vertical, Spacing.m)
                    .background(Color.black.opacity(0.75))
                    .clipShape(Capsule())
                    .padding(.bottom, Spacing.xl)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { toastMessage = nil }
                        }
                    }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: toastMessage)
        .alert(item: $activeAlert) { alert in
            switch alert {
            case .deleteData:
                return Alert(
                    title: Text("Delete All Data?"),
                    message: Text(
                        signedInUser != nil
                            ? "This will permanently delete all your mood entries, both locally and from the cloud. Your account will remain active. This cannot be undone."
                            : "This will permanently delete all your mood entries from this device. This cannot be undone."
                    ),
                    primaryButton: .destructive(Text("Delete")) { deleteAllData() },
                    secondaryButton: .cancel()
                )
            case .deleteAccount:
                return Alert(
                    title: Text("Delete Account?"),
                    message: Text("This will permanently delete your account and all your mood entries, both locally and from the cloud. This cannot be undone."),
                    primaryButton: .destructive(Text("Delete Account")) { deleteAccount() },
                    secondaryButton: .cancel()
                )
            case .error(let msg):
                return Alert(
                    title: Text("Error"),
                    message: Text(msg),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    private func deleteAllData() {
        let repo = MoodRepository(context: context)
        let uid = signedInUser?.uid
        try? repo.deleteAllLocal()
        if let uid { Task { await repo.deleteAllFromFirestore(userId: uid) } }
        withAnimation { toastMessage = "All data deleted successfully" }
    }

    private func deleteAccount() {
        guard let user = signedInUser else { return }
        isLoading = true
        Task {
            do {
                let repo = MoodRepository(context: context)
                try repo.deleteAllLocal()
                try await authRepo.deleteAccount(provider: user.authProviderID)
                AppPreferences.shared.resetOnboarding()
                isLoading = false
                withAnimation { toastMessage = "Account deleted successfully" }
                try? await Task.sleep(for: .seconds(1.5))
                hasCompletedOnboarding = false
            } catch {
                isLoading = false
                activeAlert = .error(error.localizedDescription)
            }
        }
    }
}

// MARK: - Reminder Time Picker Sheet

private struct ReminderTimePickerSheet: View {
    let onSave: (Int, Int) -> Void

    @State private var date: Date
    @Environment(\.dismiss) private var dismiss
    @Environment(\.auraColors) private var colors

    init(hour: Int, minute: Int, onSave: @escaping (Int, Int) -> Void) {
        self.onSave = onSave
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        _date = State(initialValue: Calendar.current.date(from: components) ?? Date())
    }

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Text("Reminder Time")
                .font(.system(size: FontSize.m, weight: .semibold))
                .foregroundStyle(colors.textPrimary)
                .padding(.top, Spacing.xxl)

            DatePicker("", selection: $date, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .padding(.horizontal, Spacing.l)

            Button {
                let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                onSave(components.hour ?? 20, components.minute ?? 0)
                dismiss()
            } label: {
                Text("Done")
                    .font(.system(size: FontSize.m, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.m)
                    .background(colors.accent)
                    .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusButton))
            }
            .padding(.horizontal, Spacing.l)
            .padding(.bottom, Spacing.xxl)
        }
        .background(colors.background)
        .presentationDetents([.height(340)])
    }
}

// MARK: - Destructive Action Card

private struct DestructiveCard: View {
    let title: String
    let description: String
    let buttonLabel: String
    let action: () -> Void

    @Environment(\.auraColors) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(title)
                .font(.system(size: FontSize.m, weight: .medium))
                .foregroundStyle(colors.textPrimary)
            Text(description)
                .font(.system(size: FontSize.s))
                .foregroundStyle(colors.textSecondary)
            Spacer().frame(height: Spacing.xs)
            Button(action: action) {
                Text(buttonLabel)
                    .font(.system(size: FontSize.s, weight: .medium))
                    .foregroundStyle(Color.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.m)
                    .overlay(
                        RoundedRectangle(cornerRadius: Spacing.radiusButton)
                            .stroke(Color.red, lineWidth: Spacing.borderWidth)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusCard))
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: MoodEntry.self, inMemory: true)
}
