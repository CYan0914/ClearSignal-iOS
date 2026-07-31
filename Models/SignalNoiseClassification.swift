import Foundation

/// Classification of whether a metric reading is "worth paying attention to" or "safe to ignore."
/// This is the core of the noise-reduction philosophy.
enum SignalNoiseClassification: String, Codable {
    /// Backed by physiology; trend-level change is meaningful
    case signal = "signal"
    /// Single-day fluctuation, no independent meaning, or marketing concept
    case noise = "noise"
}

/// The result of classifying a specific metric + time window.
struct SignalNoiseVerdict: Identifiable, Codable {
    let id: UUID
    let metric: HealthMetric
    let classification: SignalNoiseClassification
    /// Why this classification was made (human-readable, shown to user)
    let reason: String
    let classifiedAt: Date

    init(metric: HealthMetric, classification: SignalNoiseClassification, reason: String) {
        self.id = UUID()
        self.metric = metric
        self.classification = classification
        self.reason = reason
        self.classifiedAt = Date()
    }
}

// MARK: - Classification Rules (Deterministic)

extension SignalNoiseVerdict {
    /// Classify a metric's reading based on the rule engine.
    /// Rules are deterministic — no AI involved in judgment.
    static func classify(metric: HealthMetric, isSingleDay: Bool, hasTrendAnomaly: Bool) -> SignalNoiseVerdict {
        // Rule 1: All single-day scores from wearables are NOISE
        // (Sleep stage accuracy ~60-75%, HRV day-to-day CV ~20-40%)
        if isSingleDay {
            return SignalNoiseVerdict(
                metric: metric,
                classification: .noise,
                reason: "Single-day measurements are unreliable due to sensor accuracy limits. Only trends matter."
            )
        }

        // Rule 2: 3+ consecutive days outside personal baseline = SIGNAL
        if hasTrendAnomaly {
            return SignalNoiseVerdict(
                metric: metric,
                classification: .signal,
                reason: "Three or more consecutive days outside your personal baseline. This is a trend worth noting."
            )
        }

        // Rule 3: Default — a stable trend is a signal (good news is information too)
        return SignalNoiseVerdict(
            metric: metric,
            classification: .signal,
            reason: "Trend is within your normal range. No action needed."
        )
    }
}
