import Foundation

/// An item the user has chosen to ignore — metric, notification, or category.
/// This is the "declutter" action: the user actively removes noise sources.
struct IgnoreListItem: Identifiable, Codable {
    let id: UUID
    let type: IgnoreType
    let label: String       // Human-readable label
    let createdAt: Date
    let suggested: Bool     // Was this suggested by the app, or manually added?

    init(type: IgnoreType, label: String, suggested: Bool = false) {
        self.id = UUID()
        self.type = type
        self.label = label
        self.createdAt = Date()
        self.suggested = suggested
    }
}

enum IgnoreType: String, Codable, CaseIterable {
    case metric = "metric"            // A specific health metric
    case notification = "notification" // A specific push notification type
    case appFeature = "app_feature"   // A feature/screen the user wants to hide

    var icon: String {
        switch self {
        case .metric:        return "chart.bar.xaxis"
        case .notification:  return "bell.slash"
        case .appFeature:    return "eye.slash"
        }
    }
}

// MARK: - Pre-built Ignore Suggestions

/// Pre-built "ignore bundles" the app can suggest.
enum IgnoreBundle: String, CaseIterable {
    case ouraAnxietyKit = "Oura Anxiety Kit"
    case appleWatchPressure = "Apple Watch Pressure"
    case fitnessScoreOverload = "Fitness Score Overload"

    var description: String {
        switch self {
        case .ouraAnxietyKit:
            return "Oura Readiness, Stress & Resilience scores — single-day noise that creates anxiety."
        case .appleWatchPressure:
            return "Stand reminders, Move ring pressure — notifications that add stress, not health."
        case .fitnessScoreOverload:
            return "Recovery scores, training readiness — focus on how you feel, not the number."
        }
    }

    var items: [(IgnoreType, String)] {
        switch self {
        case .ouraAnxietyKit:
            return [
                (.notification, "Oura Readiness Score"),
                (.notification, "Oura Stress Score"),
                (.notification, "Oura Resilience Level"),
            ]
        case .appleWatchPressure:
            return [
                (.notification, "Stand Hours Reminder"),
                (.notification, "Move Ring Notification"),
                (.notification, "Exercise Ring Notification"),
            ]
        case .fitnessScoreOverload:
            return [
                (.metric, "Athlytic Recovery Score"),
                (.notification, "Whoop Strain Score"),
                (.notification, "Training Readiness Alerts"),
            ]
        }
    }
}
