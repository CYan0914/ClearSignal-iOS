import Foundation

/// The core Rule Engine.
///
/// All health data judgment is done HERE — deterministic, explainable, no AI.
/// The AI Translation Layer (AIService + BriefGenerator) only takes the rule engine's
/// output and expresses it in natural language.
///
/// Four subsystems:
/// 1. Trend Calculator — 7/30 day rolling averages, regression slope, anomaly detection
/// 2. Signal/Noise Classifier — per-metric verdict: worth watching or safe to ignore
/// 3. Conflict Arbitrator — when device score ≠ user feeling, who to trust
/// 4. Goal Filter — hide metrics irrelevant to the user's goal
struct RuleEngine {

    // MARK: - 1. Trend Calculator

    /// Calculate trend for a single metric from a window of values.
    static func calculateTrend(metric: HealthMetric,
                               values: [HealthMetricValue],
                               baseline: [HealthMetricValue] = []) -> TrendResult {
        let sorted = values.sorted(by: { $0.date < $1.date })
        let recent7 = Array(sorted.suffix(7))
        let recent30 = Array(sorted.suffix(30))

        let sevenDayMean = recent7.isEmpty ? nil : recent7.map(\.value).reduce(0, +) / Double(recent7.count)
        let thirtyDayMean = recent30.isEmpty ? nil : recent30.map(\.value).reduce(0, +) / Double(recent30.count)

        // Trend direction via simple linear regression slope
        let direction = calculateDirection(values: Array(sorted.suffix(14)))

        // Anomaly: ≥3 consecutive days outside personal baseline ±1.5σ
        let (baselineMean, baselineStd) = calculateBaseline(values: baseline.isEmpty ? sorted : baseline)
        let isAnomaly = detectAnomaly(recentValues: recent7, baselineMean: baselineMean, baselineStd: baselineStd)

        let summary = generateTrendSummary(
            metric: metric,
            sevenDayMean: sevenDayMean,
            direction: direction,
            isAnomaly: isAnomaly
        )

        return TrendResult(
            metric: metric,
            sevenDayMean: sevenDayMean,
            thirtyDayMean: thirtyDayMean,
            direction: direction,
            isTrendAnomaly: isAnomaly,
            baseline: baselineMean,
            baselineStdDev: baselineStd,
            summary: summary
        )
    }

    /// Calculate trend direction using linear regression over the last N values
    private static func calculateDirection(values: [HealthMetricValue]) -> TrendDirection {
        guard values.count >= 3 else { return .stable }

        let n = Double(values.count)
        let xMean = (n - 1) / 2.0
        let yMean = values.map(\.value).reduce(0, +) / n

        var numerator: Double = 0
        var denominator: Double = 0

        for (i, v) in values.enumerated() {
            let dx = Double(i) - xMean
            numerator += dx * (v.value - yMean)
            denominator += dx * dx
        }

        guard denominator > 0 else { return .stable }
        let slope = numerator / denominator
        let normalizedSlope = slope / (yMean > 0 ? yMean : 1.0) // Relative change

        // Threshold: < 2% change per data point = stable
        if abs(normalizedSlope) < 0.02 { return .stable }
        return normalizedSlope > 0 ? .rising : .falling
    }

    /// Establish personal baseline: mean and std dev from 60-day values
    private static func calculateBaseline(values: [HealthMetricValue]) -> (mean: Double?, std: Double?) {
        guard values.count >= 7 else { return (nil, nil) }
        let vals = values.map(\.value)
        let mean = vals.reduce(0, +) / Double(vals.count)
        let variance = vals.map { pow($0 - mean, 2) }.reduce(0, +) / Double(vals.count)
        return (mean, sqrt(variance))
    }

    /// Detect trend-level anomaly: ≥3 consecutive days outside baseline ±1.5σ
    private static func detectAnomaly(recentValues: [HealthMetricValue],
                                       baselineMean: Double?,
                                       baselineStd: Double?) -> Bool {
        guard let mean = baselineMean, let std = baselineStd, std > 0, recentValues.count >= 3 else {
            return false
        }

        let lowerBound = mean - 1.5 * std
        let upperBound = mean + 1.5 * std

        // Count consecutive days outside bounds
        var consecutiveAnomalies = 0
        for v in recentValues.sorted(by: { $0.date < $1.date }) {
            if v.value < lowerBound || v.value > upperBound {
                consecutiveAnomalies += 1
                if consecutiveAnomalies >= 3 { return true }
            } else {
                consecutiveAnomalies = 0
            }
        }
        return false
    }

    private static func generateTrendSummary(metric: HealthMetric,
                                              sevenDayMean: Double?,
                                              direction: TrendDirection,
                                              isAnomaly: Bool) -> String {
        guard let mean = sevenDayMean else {
            return "\(metric.displayName): insufficient data for trend analysis."
        }

        var parts: [String] = []
        parts.append("\(metric.displayName): 7-day avg \(String(format: "%.1f", mean)) \(metric.unit)")
        parts.append(direction.displayName)

        if isAnomaly {
            parts.append("— ⚠️ outside your personal baseline. Worth watching this week.")
        } else {
            parts.append("— within your normal range.")
        }
        return parts.joined(separator: " ")
    }

    // MARK: - 2. Signal/Noise Classifier

    /// Classify whether a metric reading is signal or noise.
    static func classifySignalNoise(metric: HealthMetric,
                                     isSingleDay: Bool,
                                     hasTrendAnomaly: Bool) -> SignalNoiseVerdict {
        return SignalNoiseVerdict.classify(
            metric: metric,
            isSingleDay: isSingleDay,
            hasTrendAnomaly: hasTrendAnomaly
        )
    }

    /// Batch classify all metrics for today's brief
    static func classifyAll(trends: [TrendResult]) -> [SignalNoiseVerdict] {
        return trends.map { trend in
            classifySignalNoise(
                metric: trend.metric,
                isSingleDay: false, // We never show single-day values
                hasTrendAnomaly: trend.isTrendAnomaly
            )
        }
    }

    // MARK: - 3. Conflict Arbitrator ⭐

    /// Resolve a conflict between how the user feels and what device scores say.
    ///
    /// Rules (priority order):
    /// 1. DEFAULT: trust the user's feeling over any single-day score
    /// 2. EXCEPTION: if ≥3 consecutive days of trend-level anomaly, flag it regardless
    /// 3. USER OVERRIDE: if user reports feeling bad but data is normal, track the pattern
    static func resolveConflict(userFeeling: Feeling,
                                 deviceScores: [TrendResult],
                                 recentFeelings: [FeelLog]) -> ConflictVerdict {
        // Build device concern summary
        let anomalies = deviceScores.filter(\.isTrendAnomaly)
        let deviceConcern: String
        if anomalies.isEmpty {
            deviceConcern = "No trend-level anomalies detected. All metrics within your normal range."
        } else {
            let names = anomalies.map(\.metric.displayName).joined(separator: ", ")
            deviceConcern = "Trend anomaly in: \(names)."
        }

        let trendSummary = deviceScores.map(\.summary).joined(separator: "\n")

        // Rule 2: If user feels good/okay BUT there's a trend anomaly → trust trend (exception)
        if userFeeling != .bad && !anomalies.isEmpty {
            let metricNames = anomalies.map(\.metric.displayName).joined(separator: ", ")
            return ConflictVerdict(
                userFeeling: userFeeling,
                deviceConcern: deviceConcern,
                trendSummary: trendSummary,
                resolution: .trustTrend,
                advice: "You feel \(userFeeling.label.lowercased()), but \(metricNames) show a consistent trend change over 3+ days. This is worth paying attention to — consider prioritizing rest and recovery this week."
            )
        }

        // Rule 3: User feels bad but data is normal → flag for tracking
        if userFeeling == .bad && anomalies.isEmpty {
            return ConflictVerdict(
                userFeeling: userFeeling,
                deviceConcern: deviceConcern,
                trendSummary: trendSummary,
                resolution: .flagForTracking,
                advice: "You're not feeling great, but your health metrics look fine. Sometimes how we feel is the first signal — I'll keep tracking this pattern. If it continues, consider checking in with your doctor."
            )
        }

        // Rule 1 (default): Trust the feeling
        return ConflictVerdict(
            userFeeling: userFeeling,
            deviceConcern: deviceConcern,
            trendSummary: trendSummary,
            resolution: .trustFeeling,
            advice: "You feel \(userFeeling.label.lowercased()) — that's the real signal. Your metrics look fine, and single-day wearable scores are unreliable anyway. Trust your body. 😌"
        )
    }

    // MARK: - 4. Goal Filter

    /// Filter metrics to only show those relevant to the user's goal.
    /// All other metrics = noise (auto-hidden).
    static func filterByGoal(_ goal: UserGoal, trends: [TrendResult]) -> [TrendResult] {
        let relevant = Set(HealthMetric.metricsForGoal(goal))
        return trends.filter { relevant.contains($0.metric) }
    }

    // MARK: - Sleep Consistency (Computed Metric)

    /// Calculate sleep consistency from bedtime data
    /// Lower variance = more consistent sleep schedule
    static func calculateSleepConsistency(bedtimes: [Date]) -> Double {
        guard bedtimes.count >= 3 else { return 0 }

        // Convert bedtimes to minutes since midnight
        let calendar = Calendar.current
        let minutesSinceMidnight = bedtimes.map { date -> Double in
            let components = calendar.dateComponents([.hour, .minute], from: date)
            return Double((components.hour ?? 0) * 60 + (components.minute ?? 0))
        }

        let mean = minutesSinceMidnight.reduce(0, +) / Double(minutesSinceMidnight.count)
        let variance = minutesSinceMidnight.map { pow($0 - mean, 2) }.reduce(0, +) / Double(minutesSinceMidnight.count)

        // Return standard deviation of bedtimes in minutes (lower = better consistency)
        return sqrt(variance)
    }
}
