import Foundation

/// The 5-8 core health metrics Signalveil tracks.
/// Every metric is viewed as 7/30 day trend — NEVER single-day absolute value.
enum HealthMetric: String, CaseIterable, Identifiable, Codable {
    case sleepDuration = "sleep_duration"
    case restingHeartRate = "resting_heart_rate"
    case heartRateVariability = "heart_rate_variability"
    case respiratoryRate = "respiratory_rate"
    case activeEnergy = "active_energy"
    case stepCount = "step_count"
    case sleepConsistency = "sleep_consistency"
    case bodyWeight = "body_weight"
    case bloodOxygen = "blood_oxygen"

    var id: String { rawValue }

    /// Human-readable display name
    var displayName: String {
        switch self {
        case .sleepDuration:         return "Sleep Duration"
        case .restingHeartRate:      return "Resting Heart Rate"
        case .heartRateVariability:  return "HRV"
        case .respiratoryRate:       return "Respiratory Rate"
        case .activeEnergy:          return "Active Energy"
        case .stepCount:             return "Steps"
        case .sleepConsistency:      return "Sleep Consistency"
        case .bodyWeight:            return "Weight"
        case .bloodOxygen:           return "Blood Oxygen"
        }
    }

    /// Unit string for display
    var unit: String {
        switch self {
        case .sleepDuration:         return "hrs"
        case .restingHeartRate:      return "bpm"
        case .heartRateVariability:  return "ms"
        case .respiratoryRate:       return "breaths/min"
        case .activeEnergy:          return "kcal"
        case .stepCount:             return "steps"
        case .sleepConsistency:      return "min variance"
        case .bodyWeight:            return "kg"
        case .bloodOxygen:           return "%"
        }
    }

    /// HealthKit type identifier for reading
    var healthKitIdentifier: String {
        switch self {
        case .sleepDuration:         return "HKCategoryTypeIdentifierSleepAnalysis"
        case .restingHeartRate:      return "HKQuantityTypeIdentifierRestingHeartRate"
        case .heartRateVariability:  return "HKQuantityTypeIdentifierHeartRateVariabilitySDNN"
        case .respiratoryRate:       return "HKQuantityTypeIdentifierRespiratoryRate"
        case .activeEnergy:          return "HKQuantityTypeIdentifierActiveEnergyBurned"
        case .stepCount:             return "HKQuantityTypeIdentifierStepCount"
        case .sleepConsistency:      return "" // Computed locally
        case .bodyWeight:            return "HKQuantityTypeIdentifierBodyMass"
        case .bloodOxygen:           return "HKQuantityTypeIdentifierOxygenSaturation"
        }
    }

    /// Whether this metric's single-day values are unreliable (sensor accuracy limitation)
    var singleDayUnreliable: Bool {
        switch self {
        case .heartRateVariability, .sleepDuration, .bloodOxygen:
            return true
        case .restingHeartRate, .respiratoryRate, .activeEnergy, .stepCount, .bodyWeight:
            return true  // All metrics have day-to-day noise
        case .sleepConsistency:
            return false // Already a derived metric
        }
    }
}

// MARK: - Goal-to-Metric Mapping

extension HealthMetric {
    /// Metrics that matter for a given user goal
    static func metricsForGoal(_ goal: UserGoal) -> [HealthMetric] {
        switch goal {
        case .running:
            return [.heartRateVariability, .restingHeartRate, .sleepDuration, .sleepConsistency]
        case .weightLoss:
            return [.bodyWeight, .activeEnergy, .sleepDuration]
        case .stressManagement:
            return [.heartRateVariability, .respiratoryRate, .sleepDuration, .restingHeartRate]
        case .generalHealth:
            return [.sleepDuration, .restingHeartRate, .activeEnergy]
        }
    }

    /// Metrics to HIDE for a given goal (anti-noise: irrelevant metrics are noise)
    static func hiddenMetricsForGoal(_ goal: UserGoal) -> [HealthMetric] {
        let relevant = Set(metricsForGoal(goal))
        return HealthMetric.allCases.filter { !relevant.contains($0) }
    }
}
