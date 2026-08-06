import SwiftUI

/// Weekly deep-dive summary — generated every Sunday.
/// Shows week-over-week metric comparisons, conflict stats, and feeling summary.
/// Pro users get the full AI-translated deep report; free users get the template + an upsell.
struct WeeklyBriefView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @StateObject private var healthKit = HealthKitService()
    @State private var weeklyBrief: WeeklyBrief?
    @State private var isLoading = true
    @State private var showPaywall = false

    private let store = LocalDataStore.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if !subscriptionManager.isPro {
                    upsellBanner
                }

                if isLoading {
                    ProgressView("Generating weekly summary...")
                        .padding(.top, 60)
                } else if let brief = weeklyBrief {
                    // --- Brief text card ---
                    briefCard(brief)

                    // --- Metric WoW comparisons ---
                    comparisonsCard(brief)

                    // --- Conflict stats ---
                    conflictStatsCard(brief)

                    // --- Feeling summary ---
                    feelingSummaryCard(brief)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No Weekly Summary Yet")
                            .font(.headline)
                        Text("Weekly summaries are generated every Sunday. Check back then for your full week-over-week analysis.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                }
            }
            .padding()
        }
        .navigationTitle("Weekly Summary")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if weeklyBrief != nil {
                    ShareLink(item: shareText) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .task {
            await loadWeeklyBrief()
        }
        .sheet(isPresented: $showPaywall) { PaywallView() }
    }

    /// Free users see a taste of what the weekly AI deep-dive offers.
    private var upsellBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .foregroundColor(.orange)
            Text("Weekly AI deep-dive is a Premium feature.")
                .font(.caption)
            Spacer()
            Button("Upgrade") { showPaywall = true }
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.blue)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    /// Plain-text weekly summary — shareable to WeChat, notes, etc.
    private var shareText: String {
        guard let brief = weeklyBrief else { return "" }
        var lines = ["📊 SignalVeil Weekly Summary (\(brief.weekStart) → \(brief.weekEnd))", ""]
        lines.append(brief.briefText)
        lines.append("")
        lines.append("💡 \(brief.weeklySuggestion)")
        return lines.joined(separator: "\n")
    }

    // MARK: - Subviews

    private func briefCard(_ brief: WeeklyBrief) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("📊 Week of \(brief.weekStart)")
                    .font(.headline)
                if brief.aiUsed == true {
                    Text("AI")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue)
                        .clipShape(Capsule())
                }
                Spacer()
                Text("— \(brief.weekEnd)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(brief.briefText)
                .font(.subheadline)
                .lineSpacing(4)

            Divider()

            HStack {
                Text("💡")
                Text(brief.weeklySuggestion)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    private func comparisonsCard(_ brief: WeeklyBrief) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Week vs Week", systemImage: "arrow.left.arrow.right")
                .font(.headline)

            ForEach(brief.metricComparisons) { comp in
                VStack(spacing: 4) {
                    HStack {
                        Text(comp.metric.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Text(comp.summary)
                            .font(.caption)
                            .foregroundColor(comp.direction.isChange ? .orange : .green)
                    }
                }
                .padding(.vertical, 4)

                if comp.metric != brief.metricComparisons.last?.metric {
                    Divider()
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    private func conflictStatsCard(_ brief: WeeklyBrief) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Feel vs Score", systemImage: "person.fill.questionmark")
                .font(.headline)

            HStack {
                statBox(label: "Conflicts", value: "\(brief.conflictStats.totalConflicts)", color: .blue)
                statBox(label: "Trusted Feeling", value: "\(brief.conflictStats.trustFeelingCount)", color: .green)
                statBox(label: "Trend Alerts", value: "\(brief.conflictStats.trustTrendCount)", color: .orange)
                statBox(label: "Tracking", value: "\(brief.conflictStats.flaggedForTrackingCount)", color: .purple)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    private func feelingSummaryCard(_ brief: WeeklyBrief) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("How You Felt This Week", systemImage: "heart.text.square")
                .font(.headline)

            HStack(spacing: 16) {
                VStack {
                    Text("😊")
                        .font(.title)
                    Text("\(brief.feelingSummary.goodDays)d")
                        .font(.headline)
                    Text("Good")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                VStack {
                    Text("😐")
                        .font(.title)
                    Text("\(brief.feelingSummary.okayDays)d")
                        .font(.headline)
                    Text("Okay")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                VStack {
                    Text("😞")
                        .font(.title)
                    Text("\(brief.feelingSummary.badDays)d")
                        .font(.headline)
                    Text("Bad")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    private func statBox(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Data Loading

    private func loadWeeklyBrief() async {
        isLoading = true
        defer { isLoading = false }

        if subscriptionManager.isPro {
            await loadAIWeeklyBrief()
        } else {
            loadTemplateWeeklyBrief()
        }
    }

    /// Pro: fresh AI weekly deep-dive computed from HealthKit data.
    private func loadAIWeeklyBrief() async {
        let goal = store.userGoal
        let activeMetrics = HealthMetric.metricsForGoal(goal)
        let end = Date()
        guard let thisStart = Calendar.current.date(byAdding: .day, value: -7, to: end),
              let lastStart = Calendar.current.date(byAdding: .day, value: -14, to: end) else {
            loadTemplateWeeklyBrief()
            return
        }

        var thisWeek: [MetricWindow] = []
        var lastWeek: [MetricWindow] = []

        for metric in activeMetrics {
            do {
                let tv: [HealthMetricValue] = metric == .sleepDuration
                    ? (try await healthKit.fetchSleepData(from: thisStart, to: end))
                    : (try await healthKit.fetchValues(for: metric, from: thisStart, to: end))
                let lv: [HealthMetricValue] = metric == .sleepDuration
                    ? (try await healthKit.fetchSleepData(from: lastStart, to: thisStart))
                    : (try await healthKit.fetchValues(for: metric, from: lastStart, to: thisStart))
                thisWeek.append(MetricWindow(metric: metric, values: tv, windowStart: thisStart, windowEnd: end))
                lastWeek.append(MetricWindow(metric: metric, values: lv, windowStart: lastStart, windowEnd: thisStart))
            } catch {
                print("[WeeklyBrief] Failed to fetch \(metric.displayName): \(error)")
            }
        }

        let conflictStats = ConflictStats(totalConflicts: 0, trustFeelingCount: 0, trustTrendCount: 0, flaggedForTrackingCount: 0)

        let brief = await BriefGenerator.generateWeeklyBrief(
            thisWeekWindows: thisWeek,
            lastWeekWindows: lastWeek,
            conflictStats: conflictStats,
            feelingSummary: store.feelingSummary(forDays: 7),
            userGoal: goal,
            ignoreCount: store.ignoreList.count,
            useAI: true
        )

        weeklyBrief = brief
        store.saveWeeklyBrief(brief)
    }

    /// Free: cached template summary (or generate a simple one from the latest daily brief).
    private func loadTemplateWeeklyBrief() {
        if let cached = store.latestWeeklyBrief {
            weeklyBrief = cached
            return
        }
        guard let latestDaily = store.latestDailyBrief else {
            weeklyBrief = nil
            return
        }

        let feelingSummary = store.feelingSummary(forDays: 7)
        let comparisons = latestDaily.metricTrends.map { trend in
            MetricWeekComparison(
                metric: trend.metric,
                thisWeekAverage: trend.sevenDayMean ?? 0,
                lastWeekAverage: trend.thirtyDayMean ?? 0
            )
        }

        let brief = WeeklyBrief(
            weekStart: Date().addingDays(-7).dayKey(),
            weekEnd: Date().dayKey(),
            metricComparisons: comparisons,
            conflictStats: ConflictStats(totalConflicts: 0, trustFeelingCount: 0, trustTrendCount: 0, flaggedForTrackingCount: 0),
            feelingSummary: feelingSummary,
            itemsIgnoredThisWeek: store.ignoreList.count,
            briefText: comparisons.map(\.summary).joined(separator: "\n"),
            weeklySuggestion: "Keep checking in daily — the more data, the better the insights. 💪",
            aiUsed: false
        )

        weeklyBrief = brief
        store.saveWeeklyBrief(brief)
    }
}
