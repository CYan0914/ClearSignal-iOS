import Foundation

/// Local data persistence layer.
/// Uses UserDefaults for simple key-value and JSON-encoded arrays.
/// All health data stays in HealthKit (read-only) — we don't duplicate it.
/// We only store: user preferences, feeling logs, ignore list, cached briefs.
@MainActor
final class LocalDataStore: ObservableObject {
    static let shared = LocalDataStore()

    @Published var userGoal: UserGoal = .generalHealth
    @Published var ignoreList: [IgnoreListItem] = []
    @Published var feelLogs: [FeelLog] = []
    @Published var latestDailyBrief: DailyBrief?
    @Published var latestWeeklyBrief: WeeklyBrief?
    @Published var notificationPref: NotificationPref = .daily
    /// Free-trial questions used by non-Pro users in Chat (once exhausted → paywall).
    @Published var freeChatQuotaUsed: Int = 0

    /// Number of free AI chat questions a non-Pro user gets to taste the feature.
    static let freeChatTrialLimit = 3

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let userGoal = "user_goal"
        static let ignoreList = "ignore_list"
        static let feelLogs = "feel_logs"
        static let latestDailyBrief = "latest_daily_brief"
        static let latestWeeklyBrief = "latest_weekly_brief"
        static let notificationPref = "notification_pref"
        static let onboardingComplete = "onboarding_complete"
        static let installDate = "install_date"
        static let freeChatQuotaUsed = "free_chat_quota_used"
    }

    init() {
        loadAll()
    }

    // MARK: - Load

    func loadAll() {
        userGoal = loadCodable(key: Keys.userGoal) ?? .generalHealth
        ignoreList = loadCodable(key: Keys.ignoreList) ?? []
        feelLogs = loadCodable(key: Keys.feelLogs) ?? []
        latestDailyBrief = loadCodable(key: Keys.latestDailyBrief)
        latestWeeklyBrief = loadCodable(key: Keys.latestWeeklyBrief)
        notificationPref = loadCodable(key: Keys.notificationPref) ?? .daily
        freeChatQuotaUsed = defaults.integer(forKey: Keys.freeChatQuotaUsed)

        // Track install date
        if defaults.object(forKey: Keys.installDate) == nil {
            defaults.set(Date(), forKey: Keys.installDate)
        }
    }

    // MARK: - Save

    func saveUserGoal(_ goal: UserGoal) {
        userGoal = goal
        saveCodable(goal, key: Keys.userGoal)
    }

    func saveIgnoreList(_ items: [IgnoreListItem]) {
        ignoreList = items
        saveCodable(items, key: Keys.ignoreList)
    }

    func addIgnoreItem(_ item: IgnoreListItem) {
        ignoreList.append(item)
        saveCodable(ignoreList, key: Keys.ignoreList)
    }

    func removeIgnoreItem(id: UUID) {
        ignoreList.removeAll { $0.id == id }
        saveCodable(ignoreList, key: Keys.ignoreList)
    }

    func saveFeelLog(_ log: FeelLog) {
        // Replace existing entry for same day
        feelLogs.removeAll { $0.dayKey == log.dayKey }
        feelLogs.append(log)
        saveCodable(feelLogs, key: Keys.feelLogs)
    }

    func getFeelLog(for date: Date) -> FeelLog? {
        feelLogs.first { $0.dayKey == date.dayKey() }
    }

    func getFeelLogs(forDays days: Int) -> [FeelLog] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return feelLogs.filter { $0.date >= cutoff }
    }

    func saveDailyBrief(_ brief: DailyBrief) {
        latestDailyBrief = brief
        saveCodable(brief, key: Keys.latestDailyBrief)
    }

    func saveWeeklyBrief(_ brief: WeeklyBrief) {
        latestWeeklyBrief = brief
        saveCodable(brief, key: Keys.latestWeeklyBrief)
    }

    func saveNotificationPref(_ pref: NotificationPref) {
        notificationPref = pref
        saveCodable(pref, key: Keys.notificationPref)
    }

    var isOnboardingComplete: Bool {
        get { defaults.bool(forKey: Keys.onboardingComplete) }
        set { defaults.set(newValue, forKey: Keys.onboardingComplete) }
    }

    var installDate: Date? {
        defaults.object(forKey: Keys.installDate) as? Date
    }

    // MARK: - Computed

    /// Count of feeling logs in the past 7 days
    var recentFeelingLogs: [FeelLog] {
        getFeelLogs(forDays: 7)
    }

    func feelingSummary(forDays days: Int = 7) -> FeelingSummary {
        let logs = getFeelLogs(forDays: days)
        let good = logs.filter { $0.feeling == .good }.count
        let okay = logs.filter { $0.feeling == .okay }.count
        let bad = logs.filter { $0.feeling == .bad }.count
        return FeelingSummary(
            goodDays: good,
            okayDays: okay,
            badDays: bad,
            latestFeeling: logs.last?.feeling
        )
    }

    // MARK: - Free Chat Trial Quota

    /// Questions a non-Pro user can still ask before the paywall appears.
    var freeChatRemaining: Int {
        max(0, Self.freeChatTrialLimit - freeChatQuotaUsed)
    }

    func incrementChatQuota() {
        freeChatQuotaUsed = min(Self.freeChatTrialLimit, freeChatQuotaUsed + 1)
        defaults.set(freeChatQuotaUsed, forKey: Keys.freeChatQuotaUsed)
    }

    // MARK: - Check-in Streak

    /// Consecutive days with a feeling check-in (today, or yesterday if today not yet logged).
    /// Drives the retention habit loop: the longer the streak, the more your data is worth.
    var feelStreak: Int {
        let cal = Calendar.current
        let dayKeys = Set(feelLogs.map { $0.dayKey })
        guard !dayKeys.isEmpty else { return 0 }

        var streak = 0
        var date = Date()
        // If today isn't logged yet, a streak can still continue from yesterday.
        if !dayKeys.contains(date.dayKey()) {
            guard let y = cal.date(byAdding: .day, value: -1, to: date) else { return 0 }
            if !dayKeys.contains(y.dayKey()) { return 0 }
            date = y
        }
        while dayKeys.contains(date.dayKey()) {
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: date) else { break }
            date = prev
        }
        return streak
    }

    /// Celebratory checkpoints for the streak habit loop.
    static let streakMilestones: Set<Int> = [7, 14, 30, 60, 100]

    // MARK: - Codable Helpers

    private func saveCodable<T: Codable>(_ value: T, key: String) {
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key)
        }
    }

    private func loadCodable<T: Codable>(key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}

enum NotificationPref: String, Codable, CaseIterable {
    /// One push daily (morning brief)
    case daily = "daily"
    /// Only push when there's a trend anomaly
    case anomaliesOnly = "anomalies_only"
    /// No push at all
    case none = "none"

    var displayName: String {
        switch self {
        case .daily:         return "Daily Brief"
        case .anomaliesOnly: return "Trend Alerts Only"
        case .none:          return "Off"
        }
    }
}
