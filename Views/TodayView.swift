import SwiftUI

/// The main view — shows the morning brief + trend card summary.
/// This is the "home screen" the user sees every day.
struct TodayView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @StateObject private var healthKit = HealthKitService()
    @StateObject private var store = LocalDataStore.shared
    @State private var brief: DailyBrief?
    @State private var isLoading = true
    @State private var showFeelLog = false
    @State private var showOnboarding = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // B.1.3 — "Today's noise" Veil banner sits above the brief
                    // so reviewers/users see SignalVeil's central verb ("ignore")
                    // before anything else.
                    veilNoiseBanner

                    // --- AM Brief Card ---
                    briefCard

                    // B.1.2 — ConflictVerdict promoted to a standalone C-position
                    // card between brief and feel check-in. Visually unmissable;
                    // its full advice text is always shown (no truncation).
                    if let conflict = brief?.conflictVerdict {
                        conflictCard(conflict)
                    } else if let brief = brief {
                        noConflictBadge
                    }

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
                // Keep cards readable on iPad (avoid stretched full-width rows).
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
                // iPad 11"+ landscape: show the trend grid in two columns.
                .modifier(AdaptiveMetricGrid())
            }
            .navigationTitle("SignalVeil")
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
                if brief?.aiUsed == true {
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

                // B.1.2 — conflict is now a separate C-position card above
                // (see `conflictCard`). Removed the inline mini-version here
                // so we don't show the same conflict twice.

                // Pro transparency: if AI was expected but failed, say so instead of silently downgrading.
                if subscriptionManager.isPro, brief.aiUsed == false {
                    Divider()
                    Text("AI briefly unavailable — showing the standard brief. Pull to refresh to retry.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
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

                    if isStreakMilestone {
                        Text("🎉 \(store.feelStreak)-day streak — milestone unlocked!")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                            .padding(.top, 2)
                    }
                }
                Spacer()
                streakBadge
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
                // B.1.3 — Loud, distinct NOISE badge. Different from a generic
                // metric label; reads as a deliberate "ignore this" verdict.
                HStack(spacing: 3) {
                    Text("🔇")
                    Text("NOISE")
                        .font(.caption2)
                        .fontWeight(.bold)
                }
                .foregroundColor(.red)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.red.opacity(0.12))
                .overlay(
                    Capsule().stroke(Color.red.opacity(0.4), lineWidth: 1)
                )
                .clipShape(Capsule())
                .accessibilityLabel("Noise — safe to ignore")
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

    // MARK: - B.1.2 / B.1.3 subviews

    /// B.1.3 — "Today's noise" banner. Counts how many metrics are classified
    /// NOISE today. Sits above the brief as the first thing the user sees.
    @ViewBuilder
    private var veilNoiseBanner: some View {
        let noiseCount = brief?.classifications.filter { $0.classification == .noise }.count ?? 0
        let total = brief?.classifications.count ?? 0
        HStack(spacing: 10) {
            Image(systemName: "bell.slash.fill")
                .font(.subheadline)
            VStack(alignment: .leading, spacing: 1) {
                Text("Today's noise: \(noiseCount) of \(total) metrics")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(noiseCount > 0
                     ? "We've marked them — you can skip them."
                     : "Nothing to ignore today.")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.85))
            }
            Spacer()
        }
        .foregroundColor(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            LinearGradient(
                colors: [Color(red: 0.45, green: 0.34, blue: 0.62), Color(red: 0.66, green: 0.55, blue: 0.82)],
                startPoint: .leading, endPoint: .trailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    /// B.1.2 — C-position conflict card. Always shows full advice; visually
    /// distinct (purple-veiled background) so reviewers can't miss it.
    @ViewBuilder
    private func conflictCard(_ conflict: ConflictVerdict) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text("⚖️")
                    .font(.title3)
                Text("Trust your body")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(Color(red: 0.30, green: 0.22, blue: 0.45))
                Spacer()
                Text(conflict.resolution == .trustFeeling ? "you" :
                     conflict.resolution == .trustTrend ? "watch" : "tracking")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(red: 0.45, green: 0.34, blue: 0.62))
                    .clipShape(Capsule())
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 6) {
                    Text("Watch said:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 86, alignment: .leading)
                    Text(conflict.deviceConcern)
                        .font(.caption)
                        .foregroundColor(.primary)
                }
                HStack(alignment: .top, spacing: 6) {
                    Text("You said:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 86, alignment: .leading)
                    Text("\(conflict.userFeeling.emoji) \(conflict.userFeeling.label)")
                        .font(.caption)
                        .foregroundColor(.primary)
                }
            }
            Text(conflict.advice)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(Color(red: 0.30, green: 0.22, blue: 0.45))
                .padding(.top, 2)
        }
        .padding(14)
        .background(Color(red: 0.94, green: 0.91, blue: 0.97))
        .overlay(
            RoundedRectangle(cornerRadius: 14).stroke(Color(red: 0.66, green: 0.55, blue: 0.82), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    /// Quiet empty-state when there's no conflict — still shows SignalVeil's stance.
    @ViewBuilder
    private var noConflictBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text("No conflicts today. Trust your body.")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    /// 🔥 Prominent streak badge on the check-in card — visible at a glance, not a footnote.
    @ViewBuilder
    private var streakBadge: some View {
        if store.feelStreak > 0 {
            HStack(spacing: 3) {
                Image(systemName: "flame.fill")
                    .font(.caption)
                Text("\(store.feelStreak)")
                    .font(.subheadline)
                    .fontWeight(.bold)
            }
            .foregroundColor(.orange)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.orange.opacity(0.12))
            .clipShape(Capsule())
            .accessibilityLabel("\(store.feelStreak)-day check-in streak")
        }
    }

    private var isStreakMilestone: Bool {
        LocalDataStore.streakMilestones.contains(store.feelStreak)
    }

    /// Free tier gets one AI brief per week (Sundays) as a taste of the premium layer.
    private var isFreeSunday: Bool {
        !subscriptionManager.isPro && Calendar.current.component(.weekday, from: Date()) == 1
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
            useAI: subscriptionManager.isPro || isFreeSunday
        )

        brief = generated
        store.saveDailyBrief(generated)
    }
}

/// On iPad (wide layouts) lay the metric rows out in a 2-column grid so each
/// row is narrower and doesn't stretch full-width — fixes "crowded, hard to
/// read" App Review feedback on iPad Air 11" (Guideline 4).
private struct AdaptiveMetricGrid: ViewModifier {
    @Environment(\.horizontalSizeClass) private var sizeClass

    func body(content: Content) -> some View {
        // Only wide screens (iPad) get the grid; iPhone stays a single column.
        Group {
            if sizeClass == .regular {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    content
                }
            } else {
                content
            }
        }
    }
}

extension View {
    /// True on iPad (any orientation except narrow split view); iPhone is always false.
    var isIpad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
}
