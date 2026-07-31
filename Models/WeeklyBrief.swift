import Foundation

/// The weekly deep-dive brief — generated every Sunday.
/// More detailed than the daily brief, includes week-over-week comparison.
struct WeeklyBrief: Identifiable, Codable {
    let id: UUID
    let weekStart: String       // Monday date string
    let weekEnd: String         // Sunday date string
    let generatedAt: Date

    // --- Rule Engine Outputs ---
    /// Per-metric week-over-week comparison
    let metricComparisons: [MetricWeekComparison]
    /// Conflict stats for the week
    let conflictStats: ConflictStats
    /// Feeling summary
    let feelingSummary: FeelingSummary
    /// Total things ignored this week
    let itemsIgnoredThisWeek: Int

    // --- AI Translation Output ---
    /// The full natural-language weekly brief
    let briefText: String
    /// The one actionable suggestion
    let weeklySuggestion: String

    init(weekStart: String,
         weekEnd: String,
         metricComparisons: [MetricWeekComparison],
         conflictStats: ConflictStats,
         feelingSummary: FeelingSummary,
         itemsIgnoredThisWeek: Int = 0,
         briefText: String,
         weeklySuggestion: String) {
        self.id = UUID()
        self.weekStart = weekStart
        self.weekEnd = weekEnd
        self.generatedAt = Date()
        self.metricComparisons = metricComparisons
        self.conflictStats = conflictStats
        self.feelingSummary = feelingSummary
        self.itemsIgnoredThisWeek = itemsIgnoredThisWeek
        self.briefText = briefText
        self.weeklySuggestion = weeklySuggestion
    }
}

/// Week-over-week comparison for a single metric
struct MetricWeekComparison: Identifiable, Codable {
    let id: UUID
    let metric: HealthMetric
    let thisWeekAverage: Double
    let lastWeekAverage: Double
    let percentChange: Double   // e.g., -5.2 means 5.2% lower this week
    let direction: TrendDirection

    init(metric: HealthMetric, thisWeekAverage: Double, lastWeekAverage: Double) {
        self.id = UUID()
        self.metric = metric
        self.thisWeekAverage = thisWeekAverage
        self.lastWeekAverage = lastWeekAverage
        self.percentChange = lastWeekAverage != 0
            ? ((thisWeekAverage - lastWeekAverage) / lastWeekAverage) * 100
            : 0
        self.direction = {
            if abs(percentChange) < 3 { return .stable }
            return percentChange > 0 ? .rising : .falling
        }()
    }

    var summary: String {
        let dir = percentChange > 0 ? "up" : "down"
        return "\(metric.displayName): \(String(format: "%.1f", thisWeekAverage)) \(metric.unit) (\(dir) \(String(format: "%.0f", abs(percentChange)))% vs last week)"
    }
}

/// Stats about conflicts between feelings and device scores this week
struct ConflictStats: Codable {
    let totalConflicts: Int
    /// How many were resolved as "trust feeling"
    let trustFeelingCount: Int
    /// How many triggered "trend anomaly" exception
    let trustTrendCount: Int
    /// How many were flagged for tracking
    let flaggedForTrackingCount: Int
}
