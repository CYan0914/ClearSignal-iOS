import Foundation

/// The user's health/fitness goal — determines which metrics to show vs hide.
enum UserGoal: String, CaseIterable, Identifiable, Codable {
    case running = "running"
    case weightLoss = "weight_loss"
    case stressManagement = "stress_management"
    case generalHealth = "general_health"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .running:           return "Running / Marathon"
        case .weightLoss:        return "Weight Loss"
        case .stressManagement:  return "Stress Management"
        case .generalHealth:     return "General Health"
        }
    }

    var icon: String {
        switch self {
        case .running:           return "figure.run"
        case .weightLoss:        return "scalemass"
        case .stressManagement:  return "leaf"
        case .generalHealth:     return "heart"
        }
    }

    var description: String {
        switch self {
        case .running:
            return "Focus on recovery metrics: HRV, resting heart rate, sleep — the signals that predict performance."
        case .weightLoss:
            return "Focus on weight trend, activity, and sleep — the metrics that drive fat loss."
        case .stressManagement:
            return "Focus on HRV trend, breathing rate, sleep, and resting heart rate — your stress dashboard."
        case .generalHealth:
            return "Just the essentials: sleep, resting heart rate, and daily activity. No complexity."
        }
    }

    /// Metrics NOT relevant to this goal — should be hidden to reduce noise
    var hiddenMetrics: [HealthMetric] {
        HealthMetric.hiddenMetricsForGoal(self)
    }

    /// Metrics relevant to this goal
    var activeMetrics: [HealthMetric] {
        HealthMetric.metricsForGoal(self)
    }
}
