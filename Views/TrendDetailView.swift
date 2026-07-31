import SwiftUI

/// Detailed trend view for a single health metric.
/// Shows trend chart area, signal/noise verdict, and why this metric matters.
struct TrendDetailView: View {
    let metric: HealthMetric
    @StateObject private var healthKit = HealthKitService()
    @State private var values: [HealthMetricValue] = []
    @State private var trend: TrendResult?
    @State private var isLoading = true

    private let store = LocalDataStore.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // --- Metric Header ---
                metricHeader

                // --- Trend Chart (placeholder for now) ---
                chartPlaceholder

                // --- Signal/Noise Verdict ---
                verdictCard

                // --- Raw Trend Data ---
                dataBreakdownCard

                // --- What This Metric Means ---
                educationCard
            }
            .padding()
        }
        .navigationTitle(metric.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadData()
        }
    }

    // MARK: - Subviews

    private var metricHeader: some View {
        VStack(spacing: 4) {
            if let trend = trend {
                HStack {
                    Image(systemName: trend.isTrendAnomaly ? "exclamationmark.triangle.fill" : "checkmark.shield.fill")
                        .foregroundColor(trend.isTrendAnomaly ? .orange : .green)
                        .font(.title)

                    if let mean = trend.sevenDayMean {
                        Text("\(String(format: "%.1f", mean)) \(metric.unit)")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                    }
                }

                Text("7-day average • \(trend.direction.displayName)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if trend.isTrendAnomaly {
                    Label("Outside your personal baseline", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.top, 4)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    private var chartPlaceholder: some View {
        VStack {
            // Simple trend visualization using bars
            if !values.isEmpty {
                let recent = Array(values.sorted(by: { $0.date < $1.date }).suffix(14))
                let maxVal = recent.map(\.value).max() ?? 1

                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(recent) { v in
                        VStack(spacing: 2) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(v.value / maxVal > 0.9 ? Color.orange : Color.blue.opacity(0.6))
                                .frame(width: 16, height: max(4, CGFloat(v.value / maxVal) * 80))

                            Text(v.date.formatted(date: .numeric, time: .omitted))
                                .font(.system(size: 8))
                                .foregroundColor(.secondary)
                                .rotationEffect(.degrees(-45))
                                .frame(width: 20)
                        }
                    }
                }
                .frame(height: 120)
                .padding(.vertical, 8)
            } else {
                ProgressView()
                    .frame(height: 100)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    private var verdictCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Signal or Noise?", systemImage: "waveform.path")
                .font(.headline)

            if let trend = trend {
                if trend.isTrendAnomaly {
                    HStack(spacing: 8) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .foregroundColor(.orange)
                        Text("SIGNAL — This is a trend-level change worth watching.")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                    }
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "speaker.slash")
                            .foregroundColor(.green)
                        Text("Noise-free — Your trend is stable. Single-day fluctuations don't matter.")
                            .font(.subheadline)
                            .foregroundColor(.green)
                    }
                }

                Text("Remember: \(metric.displayName) single-day readings can vary by \(metric.singleDayUnreliable ? "20-40%" : "10-15%") just from sensor noise. Trends are what count.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    private var dataBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Raw Data (Last 7 Days)", systemImage: "list.bullet.clipboard")
                .font(.headline)

            let sorted = values.sorted(by: { $0.date > $1.date }).prefix(7)
            ForEach(Array(sorted)) { v in
                HStack {
                    Text(v.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(String(format: "%.1f", v.value)) \(metric.unit)")
                        .font(.caption)
                        .fontWeight(.medium)
                    Text(v.source)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    private var educationCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("What This Metric Tells You", systemImage: "book.pages")
                .font(.headline)

            Text(educationText)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineSpacing(3)

            Text("Source: wearable sensors (Apple Watch / Oura / Fitbit). Accuracy varies by device and measurement conditions.")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    // MARK: - Data Loading

    private func loadData() async {
        isLoading = true
        defer { isLoading = false }

        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -30, to: endDate) ?? endDate
        let baselineStart = Calendar.current.date(byAdding: .day, value: -60, to: endDate) ?? endDate

        do {
            let fetched: [HealthMetricValue]
            if metric == .sleepDuration {
                fetched = try await healthKit.fetchSleepData(from: startDate, to: endDate)
            } else {
                fetched = try await healthKit.fetchValues(for: metric, from: startDate, to: endDate)
            }

            values = fetched

            // Run trend analysis
            var baselineValues: [HealthMetricValue] = []
            if metric == .sleepDuration {
                baselineValues = (try? await healthKit.fetchSleepData(from: baselineStart, to: endDate)) ?? []
            } else {
                baselineValues = (try? await healthKit.fetchValues(for: metric, from: baselineStart, to: endDate)) ?? []
            }

            trend = RuleEngine.calculateTrend(metric: metric, values: fetched, baseline: baselineValues)
        } catch {
            print("[TrendDetailView] Error loading \(metric.displayName): \(error)")
        }
    }

    // MARK: - Education content

    private var educationText: String {
        switch metric {
        case .sleepDuration:
            return "Sleep duration is your total time asleep per night. The CDC recommends 7+ hours for adults. Sleep stage accuracy from wearables is only ~60-75% compared to lab PSG, so focus on total duration and consistency rather than deep/REM breakdowns."
        case .restingHeartRate:
            return "RHR is your heart rate at complete rest. A lower RHR generally indicates better cardiovascular fitness. A sustained increase of 5+ bpm can signal fatigue, illness, or overtraining — that's why we track the trend, not single-day readings."
        case .heartRateVariability:
            return "HRV measures the variation between heartbeats. Higher is generally better — it indicates your body is adaptable and recovered. But single-day HRV can vary 20-40% just from measurement timing, sleep position, or alcohol. ONLY the weekly trend is meaningful."
        case .respiratoryRate:
            return "Your breathing rate at rest. Sudden sustained increases can signal stress, illness, or poor recovery. Normal adult range: 12-20 breaths/min."
        case .activeEnergy:
            return "Calories burned through activity. Useful as a trend metric for weight management, but wearable calorie estimates can be off by 20-30%. Don't obsess over the exact number."
        case .stepCount:
            return "Daily steps — the simplest activity metric. 7,000-10,000 steps/day is associated with lower all-cause mortality. Trend matters more than any single day's count."
        case .sleepConsistency:
            return "How consistent your bedtime is (standard deviation in minutes). Research shows sleep consistency may matter MORE than total sleep duration for cognitive performance and mood."
        case .bodyWeight:
            return "Your weight trend from smart scale data. Single-day weight can fluctuate 1-2 kg from water, salt, and food intake. Only the 7-day rolling average is meaningful."
        case .bloodOxygen:
            return "Blood oxygen saturation (SpO2). Normal is 95-100%. Consistently low readings (below 92%) during sleep may indicate sleep apnea — worth discussing with a doctor. Single-day dips are usually measurement errors (watch too loose, sleeping position)."
        }
    }
}
