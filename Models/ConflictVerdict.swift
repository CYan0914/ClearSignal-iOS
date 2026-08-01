import Foundation

/// The result of resolving a conflict between device scores and subjective feeling.
/// ⭐ This is the #1 differentiator — no competitor does this.
struct ConflictVerdict: Identifiable, Codable {
    let id: UUID = UUID()
    let resolvedAt: Date = Date()

    /// The user's reported feeling
    let userFeeling: Feeling
    /// What the device score said
    let deviceConcern: String
    /// What the trend analysis shows
    let trendSummary: String
    /// The resolution: who to trust
    let resolution: ConflictResolution
    /// Human-readable advice to the user
    let advice: String
}

/// The daily feeling input from the user — one question, three choices.
enum Feeling: String, Codable, CaseIterable {
    case good = "good"       // 😊
    case okay = "okay"       // 😐
    case bad = "bad"         // 😞

    var emoji: String {
        switch self {
        case .good: return "😊"
        case .okay: return "😐"
        case .bad:  return "😞"
        }
    }

    var label: String {
        switch self {
        case .good: return "Feeling good"
        case .okay: return "So-so"
        case .bad:  return "Not great"
        }
    }
}

enum ConflictResolution: String, Codable {
    /// Default: trust how the user FEELS over what the device SCORES
    case trustFeeling = "trust_feeling"
    /// Exception: when there's a consistent trend-level anomaly, flag it
    case trustTrend = "trust_trend"
    /// User explicitly reported feeling bad despite normal data — track it
    case flagForTracking = "flag_for_tracking"

    var explanation: String {
        switch self {
        case .trustFeeling:
            return "You feel good — that's the real signal. Single-day scores are unreliable; ignore this one."
        case .trustTrend:
            return "Your data shows a consistent trend that's worth noting, even though you feel okay right now."
        case .flagForTracking:
            return "Noted. I'll keep an eye on this pattern between your feelings and the trend data."
        }
    }
}
