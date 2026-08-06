import Foundation
import HealthKit

/// HealthKit data reading service.
/// Reads ONLY the 8 core metrics. Never reads all HealthKit data.
/// All data stays on-device (read-only access).
@MainActor
final class HealthKitService: ObservableObject {
    private let healthStore = HKHealthStore()

    /// The metrics we actually read (subset of all available HealthKit types)
    static let readMetrics: [HealthMetric] = [
        .sleepDuration, .restingHeartRate, .heartRateVariability,
        .respiratoryRate, .activeEnergy, .stepCount, .bodyWeight, .bloodOxygen
    ]

    /// Whether HealthKit is available on this device
    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    /// Request read permission for our core metrics only
    func requestAuthorization() async throws {
        let readTypes = Self.readMetrics.compactMap { metric -> HKObjectType? in
            let id = metric.healthKitIdentifier
            guard !id.isEmpty else { return nil }
            if id.hasPrefix("HKCategory") {
                return HKObjectType.categoryType(forIdentifier: HKCategoryTypeIdentifier(rawValue: id))
            }
            return HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier(rawValue: id))
        }

        try await healthStore.requestAuthorization(toShare: [], read: Set(readTypes))
    }

    // MARK: - Fetch Data

    /// Fetch values for a specific metric over a date range
    func fetchValues(for metric: HealthMetric,
                     from startDate: Date,
                     to endDate: Date = Date()) async throws -> [HealthMetricValue] {
        guard let type = quantityType(for: metric) else {
            // Computed metrics (sleep consistency) handled separately
            return []
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let quantitySamples = samples as? [HKQuantitySample] else {
                    continuation.resume(returning: [])
                    return
                }

                let values = quantitySamples.map { sample in
                    HealthMetricValue(
                        metric: metric,
                        value: sample.quantity.doubleValue(for: Self.unit(for: metric)),
                        date: sample.endDate,
                        source: sample.sourceRevision.source.name
                    )
                }
                continuation.resume(returning: values)
            }
            healthStore.execute(query)
        }
    }

    /// Fetch sleep data (category type, handled differently from quantity types)
    func fetchSleepData(from startDate: Date, to endDate: Date = Date()) async throws -> [HealthMetricValue] {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            return []
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let sleepSamples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: [])
                    return
                }

                // Aggregate total sleep duration per day
                let calendar = Calendar.current
                var dailyTotals: [Date: Double] = [:]

                for sample in sleepSamples where sample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue {
                    let day = calendar.startOfDay(for: sample.endDate)
                    let duration = sample.endDate.timeIntervalSince(sample.startDate) / 3600.0 // hours
                    dailyTotals[day, default: 0] += duration
                }

                let values = dailyTotals.map { day, duration in
                    HealthMetricValue(
                        metric: .sleepDuration,
                        value: duration,
                        date: day,
                        source: "Apple Watch"
                    )
                }
                continuation.resume(returning: values)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Private Helpers

    private func quantityType(for metric: HealthMetric) -> HKQuantityType? {
        let id = metric.healthKitIdentifier
        guard !id.isEmpty else { return nil }
        return HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier(rawValue: id))
    }

    private static func unit(for metric: HealthMetric) -> HKUnit {
        switch metric {
        case .sleepDuration:         return HKUnit.hour()
        case .restingHeartRate:      return HKUnit(from: "count/min")
        case .heartRateVariability:  return HKUnit(from: "ms")
        case .respiratoryRate:       return HKUnit(from: "count/min")
        case .activeEnergy:          return HKUnit.kilocalorie()
        case .stepCount:             return HKUnit.count()
        case .bodyWeight:            return HKUnit.gramUnit(with: .kilo)
        case .bloodOxygen:           return HKUnit.percent()
        case .sleepConsistency:      return HKUnit.minute()
        }
    }
}
