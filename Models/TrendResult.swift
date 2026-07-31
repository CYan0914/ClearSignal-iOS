import Foundation

/// The result of running a trend analysis on a metric's data window.
struct TrendResult: Identifiable, Codable {
    let id: UUID
    let metric: HealthMetric
    let analysedAt: Date

    /// The 7-day rolling mean
    let sevenDayMean: Double?
    /// The 30-day rolling mean
    let thirtyDayMean: Double?
    /// Trend direction determined by linear regression slope
    let direction: TrendDirection
    /// Whether this is a "trend-level anomaly" (≥3 consecutive days outside personal baseline ±1.5σ)
    let isTrendAnomaly: Bool
    /// The personal baseline mean (60-day)
    let baseline: Double?
    /// Standard deviation of the baseline
    let baselineStdDev: Double?
    /// Human-readable summary of the trend
    let summary: String

    init(metric: HealthMetric,
         sevenDayMean: Double?,
         thirtyDayMean: Double?,
         direction: TrendDirection,
         isTrendAnomaly: Bool = false,
         baseline: Double? = nil,
         baselineStdDev: Double? = nil,
         summary: String = "") {
        self.id = UUID()
        self.metric = metric
        self.analysedAt = Date()
        self.sevenDayMean = sevenDayMean
        self.thirtyDayMean = thirtyDayMean
        self.direction = direction
        self.isTrendAnomaly = isTrendAnomaly
        self.baseline = baseline
        self.baselineStdDev = baselineStdDev
        self.summary = summary
    }
}

enum TrendDirection: String, Codable {
    case rising = "rising"
    case falling = "falling"
    case stable = "stable"

    var displayName: String {
        switch self {
        case .rising:  return "↑ Rising"
        case .falling: return "↓ Falling"
        case .stable:  return "→ Stable"
        }
    }

    /// Whether the direction is concerning (context-dependent; caller must interpret per-metric)
    var isChange: Bool {
        self != .stable
    }
}
