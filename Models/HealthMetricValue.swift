import Foundation

/// A single health metric reading at a point in time.
struct HealthMetricValue: Identifiable, Codable {
    let id: UUID
    let metric: HealthMetric
    let value: Double
    let date: Date
    let source: String  // e.g., "Apple Watch", "Oura", "HealthKit"

    init(metric: HealthMetric, value: Double, date: Date, source: String = "HealthKit") {
        self.id = UUID()
        self.metric = metric
        self.value = value
        self.date = date
        self.source = source
    }
}

/// A batch of metric values for a time window, with trend analysis already applied.
struct MetricWindow: Identifiable {
    let id: UUID
    let metric: HealthMetric
    let values: [HealthMetricValue]
    let windowStart: Date
    let windowEnd: Date

    /// 7-day rolling average
    var sevenDayAverage: Double? {
        guard values.count >= 3 else { return nil }
        let recent = values.suffix(7)
        return recent.map(\.value).reduce(0, +) / Double(recent.count)
    }

    /// 30-day rolling average
    var thirtyDayAverage: Double? {
        guard values.count >= 7 else { return nil }
        let recent = values.suffix(30)
        return recent.map(\.value).reduce(0, +) / Double(recent.count)
    }

    init(metric: HealthMetric, values: [HealthMetricValue], windowStart: Date, windowEnd: Date) {
        self.id = UUID()
        self.metric = metric
        self.values = values.sorted(by: { $0.date < $1.date })
        self.windowStart = windowStart
        self.windowEnd = windowEnd
    }
}
