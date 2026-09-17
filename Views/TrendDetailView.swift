import SwiftUI

/// Detailed trend view for a single health metric.
/// Shows trend chart area, signal/noise verdict, and why this metric matters.
struct TrendDetailView: View {
    let metric: HealthMetric
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @StateObject private var healthKit = HealthKitService()
    @State private var values: [HealthMetricValue] = []
    @State private var trend: TrendResult?
    @State private var isLoading = true
    @State private var showPaywall = false

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
        .sheet(isPresented: $showPaywall) { PaywallView() }
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

                // 14 fixed-width bars overflow a narrow window (iPadOS 26 lets the
                // app be resized freely), which clipped the whole card — scroll
                // horizontally instead of pushing the layout wide.
                ScrollView(.horizontal, showsIndicators: false) {
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
                }
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

                Text("Remember: a single \(metric.displayName) reading is affected by measurement timing, body position and sensor contact. Trends are what count.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                // Guideline 1.4.1 — cite the sources behind the claim above.
                CitationFootnote(citations: HealthCitations.trendOverSingleDay)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    private var dataBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Raw Data (Last \(historyWindow) Days)", systemImage: "list.bullet.clipboard")
                .font(.headline)

            let sorted = values.sorted(by: { $0.date > $1.date }).prefix(historyWindow)
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

            if !subscriptionManager.isPro {
                Divider()
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Free plan shows 7 days. Upgrade to see the full 30-day picture.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Upgrade") { showPaywall = true }
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
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
                .fixedSize(horizontal: false, vertical: true)

            // Guideline 1.4.1 — every health topic explained here is cited.
            CitationFootnote(citations: HealthCitations.forMetric(metric))

            Text("Readings come from the sensors in your own device. Accuracy varies by device and measurement conditions.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
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

    // MARK: - Pro Gating

    /// Free users get 7 days of raw history; Pro unlocks the full 30 days.
    private var historyWindow: Int { subscriptionManager.isPro ? 30 : 7 }

    // MARK: - Education content

    /// Explanations are deliberately limited to what the cited sources state.
    /// (Guideline 1.4.1 — no uncited precision.)
    private var educationText: String {
        switch metric {
        case .sleepDuration:
            return "Sleep duration is your total time asleep per night. The CDC recommends 7 or more hours for adults. Wearables estimate sleep stages from movement and heart rate rather than brain activity, so total duration and night-to-night consistency are more dependable than stage breakdowns."
        case .restingHeartRate:
            return "RHR is your heart rate at complete rest. A lower resting rate generally reflects better cardiovascular fitness. A sustained rise can accompany fatigue, illness or overtraining — which is why the trend matters and a single reading does not."
        case .heartRateVariability:
            return "HRV measures the variation between successive heartbeats. Higher generally indicates a body that is recovering and adaptable. It is sensitive to measurement timing, sleep position, alcohol and stress, so single-day values swing widely and only the multi-day trend is informative."
        case .respiratoryRate:
            return "Your breathing rate at rest. It is a stable vital sign, so a sustained change carries more information than any single night's reading."
        case .activeEnergy:
            return "Calories burned through activity, estimated from heart rate and movement. Estimates vary between devices and activity types, so treat this as a directional trend rather than a precise count."
        case .stepCount:
            return "Daily steps — the simplest activity measure. Regular physical activity is associated with lower risk of chronic disease. The trend over weeks matters more than any single day's count."
        case .sleepConsistency:
            return "How regular your bedtime is, expressed as the standard deviation of your bedtimes in minutes. Keeping a consistent sleep and wake schedule supports sleep quality independently of total sleep duration."
        case .bodyWeight:
            return "Your weight trend from smart scale data. Day-to-day weight shifts with water, salt and food intake, so only the rolling multi-day average is meaningful."
        case .bloodOxygen:
            return "Blood oxygen saturation (SpO2). Wearable readings are estimates and are easily disturbed by a loose watch or sleeping position. Repeatedly low readings during sleep are worth raising with a clinician."
        }
    }
}
