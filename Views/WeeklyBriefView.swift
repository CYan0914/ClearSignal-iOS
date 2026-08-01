import SwiftUI

/// Weekly deep-dive summary — generated every Sunday.
/// Shows week-over-week metric comparisons, conflict stats, and feeling summary.
struct WeeklyBriefView: View {
    @State private var weeklyBrief: WeeklyBrief?
    @State private var isLoading = true

    private let store = LocalDataStore.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
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
        .task {
            await loadWeeklyBrief()
        }
    }

    // MARK: - Subviews

    private func briefCard(_ brief: WeeklyBrief) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("📊 Week of \(brief.weekStart)")
                    .font(.headline)
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

        // Try cached first
        if let cached = store.latestWeeklyBrief {
            weeklyBrief = cached
            return
        }

        // Generate a simple weekly brief from available data
        // In production, this would fetch full 2-week comparison
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
            conflictStats: ConflictStats(
                totalConflicts: 0,
                trustFeelingCount: 0,
                trustTrendCount: 0,
                flaggedForTrackingCount: 0
            ),
            feelingSummary: feelingSummary,
            itemsIgnoredThisWeek: store.ignoreList.count,
            briefText: comparisons.map(\.summary).joined(separator: "\n"),
            weeklySuggestion: "Keep checking in daily — the more data, the better the insights. 💪"
        )

        weeklyBrief = brief
        store.saveWeeklyBrief(brief)
    }
}
