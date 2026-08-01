import SwiftUI

/// The main view — shows the morning brief + trend card summary.
/// This is the "home screen" the user sees every day.
struct TodayView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @StateObject private var healthKit = HealthKitService()
    @State private var brief: DailyBrief?
    @State private var isLoading = true
    @State private var showFeelLog = false
    @State private var showOnboarding = false

    private let store = LocalDataStore.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // --- AM Brief Card ---
                    briefCard

                    // --- Quick Feel Check ---
                    feelCheckCard

                    // --- Today's Metric Cards ---
                    if let brief = brief {
                        metricsSection(brief: brief)
                    }

                    // --- Weekly Preview ---
                    weeklyPreviewCard
                }
                .padding()
            }
            .navigationTitle("Signalveil")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isLoading {
                        ProgressView()
                    }
                }
            }
            .refreshable {
                await loadBrief()
            }
            .sheet(isPresented: $showFeelLog) {
                FeelLogView()
            }
            .sheet(isPresented: $showOnboarding) {
                OnboardingView()
            }
            .task {
                if !store.isOnboardingComplete {
                    showOnboarding = true
                }
                await loadBrief()
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var briefCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("☀️ Morning Brief")
                    .font(.headline)
                Spacer()
                Text(Date().formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if isLoading {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Analyzing your health trends...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else if let brief = brief {
                Text(brief.briefText)
                    .font(.subheadline)
                    .lineSpacing(4)

                Divider()

                // Takeaway
                HStack {
                    Text("💡")
                    Text(brief.takeaway)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                }

                // Conflict highlight (if any)
                if let conflict = brief.conflictVerdict {
                    Divider()
                    HStack(alignment: .top, spacing: 8) {
                        Text("⚖️")
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Feel vs Score")
                                .font(.caption)
                                .fontWeight(.semibold)
                            Text(conflict.advice)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } else {
                Text("No brief yet. Pull to refresh, or complete your first feel check-in.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    private var feelCheckCard: some View {
        Button(action: { showFeelLog = true }) {
            HStack {
                Image(systemName: "heart.text.clipboard")
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text("How are you feeling today?")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    if let lastFeel = store.getFeelLog(for: Date()) {
                        Text("Today: \(lastFeel.feeling.emoji) \(lastFeel.feeling.label)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Tap to check in — it takes 2 seconds")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func metricsSection(brief: DailyBrief) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Today's Metrics")
                .font(.headline)

            ForEach(brief.metricTrends) { trend in
                NavigationLink(destination: TrendDetailView(metric: trend.metric)) {
                    metricRow(trend: trend, brief: brief)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func metricRow(trend: TrendResult, brief: DailyBrief) -> some View {
        let classification = brief.classifications.first(where: { $0.metric == trend.metric })
        let isNoise = classification?.classification == .noise

        HStack {
            Image(systemName: isNoise ? "bell.slash" : "chart.line.uptrend.xyaxis")
                .foregroundColor(isNoise ? .secondary : .green)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(trend.metric.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                if let mean = trend.sevenDayMean {
                    Text("7d avg: \(String(format: "%.1f", mean)) \(trend.metric.unit)  \(trend.direction.displayName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if isNoise {
                Text("IGNORE")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(.systemGray5))
                    .clipShape(Capsule())
            } else if trend.isTrendAnomaly {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.orange)
                    .font(.caption)
            }

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.03), radius: 4, y: 1)
    }

    private var weeklyPreviewCard: some View {
        NavigationLink(destination: WeeklyBriefView()) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Weekly Summary")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    Text("View your week-over-week trends")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Data Loading

    private func loadBrief() async {
        isLoading = true
        defer { isLoading = false }

        // 1. Check HealthKit authorization
        guard healthKit.isAvailable else {
            brief = nil
            return
        }

        // 2. Read recent data for each active metric
        let goal = store.userGoal
        let activeMetrics = HealthMetric.metricsForGoal(goal)
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -30, to: endDate) ?? endDate
        let baselineStart = Calendar.current.date(byAdding: .day, value: -60, to: endDate) ?? endDate

        var metricWindows: [MetricWindow] = []
        var baseline: [HealthMetric: [HealthMetricValue]] = [:]

        for metric in activeMetrics {
            do {
                let values: [HealthMetricValue]
                if metric == .sleepDuration {
                    values = try await healthKit.fetchSleepData(from: startDate, to: endDate)
                } else {
                    values = try await healthKit.fetchValues(for: metric, from: startDate, to: endDate)
                }
                metricWindows.append(MetricWindow(
                    metric: metric,
                    values: values,
                    windowStart: startDate,
                    windowEnd: endDate
                ))

                // Fetch baseline (60-day) for anomaly detection
                let baselineValues: [HealthMetricValue]
                if metric == .sleepDuration {
                    baselineValues = try await healthKit.fetchSleepData(from: baselineStart, to: endDate)
                } else {
                    baselineValues = try await healthKit.fetchValues(for: metric, from: baselineStart, to: endDate)
                }
                baseline[metric] = baselineValues

            } catch {
                print("[TodayView] Failed to fetch \(metric.displayName): \(error)")
            }
        }

        // 3. Generate brief via BriefGenerator (Rule Engine + AI)
        let latestFeeling = store.getFeelLog(for: Date())
        let recentFeelings = store.recentFeelingLogs
        let ignoreCount = store.ignoreList.count

        let generated = await BriefGenerator.generateDailyBrief(
            metricWindows: metricWindows,
            baseline: baseline,
            latestFeeling: latestFeeling,
            recentFeelings: recentFeelings,
            userGoal: goal,
            ignoreCount: ignoreCount,
            useAI: subscriptionManager.isPro
        )

        brief = generated
        store.saveDailyBrief(generated)
    }
}
