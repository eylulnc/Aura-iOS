import Foundation

enum ThemeMode: String, CaseIterable {
    case light  = "Light"
    case dark   = "Dark"
    case system = "System"
}

final class AppPreferences {
    static let shared = AppPreferences()

    private let defaults = UserDefaults.standard

    private enum Key {
        static let theme                = "theme_mode"
        static let onboardingDone       = "onboarding_done"
        static let notificationsEnabled = "notifications_enabled"
        static let reminderHour         = "reminder_hour"
        static let reminderMinute       = "reminder_minute"
        static let firstLaunch          = "first_launch_date"
    }

    private init() {
        defaults.register(defaults: [
            Key.theme:         ThemeMode.system.rawValue,
            Key.reminderHour:  20,
            Key.reminderMinute: 0
        ])
    }

    var themeMode: ThemeMode {
        get { ThemeMode(rawValue: defaults.string(forKey: Key.theme) ?? "") ?? .system }
        set { defaults.set(newValue.rawValue, forKey: Key.theme) }
    }

    var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: Key.onboardingDone) }
        set { defaults.set(newValue, forKey: Key.onboardingDone) }
    }

    func resetOnboarding() {
        defaults.removeObject(forKey: Key.onboardingDone)
    }

    var notificationsEnabled: Bool {
        get { defaults.bool(forKey: Key.notificationsEnabled) }
        set { defaults.set(newValue, forKey: Key.notificationsEnabled) }
    }

    var reminderHour: Int {
        get { defaults.integer(forKey: Key.reminderHour) }
        set { defaults.set(newValue, forKey: Key.reminderHour) }
    }

    var reminderMinute: Int {
        get { defaults.integer(forKey: Key.reminderMinute) }
        set { defaults.set(newValue, forKey: Key.reminderMinute) }
    }

    func setReminderTime(hour: Int, minute: Int) {
        reminderHour = hour
        reminderMinute = minute
    }

    func recordFirstLaunchIfNeeded() {
        guard defaults.string(forKey: Key.firstLaunch) == nil else { return }
        defaults.set(Self.todayString(), forKey: Key.firstLaunch)
    }

    var firstLaunchDate: String {
        defaults.string(forKey: Key.firstLaunch) ?? Self.todayString()
    }

    private static func todayString() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: Date())
    }

    func updateFirstLaunchIfEarlier(_ date: String) {
        if date < firstLaunchDate {
            defaults.set(date, forKey: Key.firstLaunch)
        }
    }
}
