import Foundation

/// Coordinates the Rule Engine + AI Service to generate daily and weekly briefs.
///
/// This is the bridge between:
/// - Rule Engine (deterministic judgment — "what to say")
/// - AI Service (natural language expression — "how to say it")
struct BriefGenerator {

    // MARK: - Generate Daily Brief

    /// Generate the full daily brief from HealthKit data + feeling logs.
    static func generateDailyBrief(
        metricWindows: [MetricWindow],
        baseline: [HealthMetric: [HealthMetricValue]],
        latestFeeling: FeelLog?,
        recentFeelings: [FeelLog],
        userGoal: UserGoal,
        ignoreCount: Int,
        useAI: Bool = true
    ) async -> DailyBrief {
        // Step 1: Rule Engine — calculate trends
        let trends = metricWindows.map { window in
            let baselineValues = baseline[window.metric] ?? []
            return RuleEngine.calculateTrend(
                metric: window.metric,
                values: window.values,
                baseline: baselineValues
            )
        }

        // Step 2: Rule Engine — classify signal/noise
        let classifications = RuleEngine.classifyAll(trends: trends)

        // Step 3: Rule Engine — resolve conflict (if feeling log exists)
        var conflictVerdict: ConflictVerdict? = nil
        if let feeling = latestFeeling {
            conflictVerdict = RuleEngine.resolveConflict(
                userFeeling: feeling.feeling,
                deviceScores: trends,
                recentFeelings: recentFeelings
            )
        }

        // Step 4: AI — translate into natural language (or use template fallback)
        if useAI {
            do {
                let briefText = try await AIService.generateDailyBriefText(
                    trends: trends,
                    classifications: classifications,
                    conflictVerdict: conflictVerdict,
                    userGoal: userGoal,
                    ignoreCount: ignoreCount
                )

                let takeaway = extractTakeaway(from: briefText)

                return DailyBrief(
                    metricTrends: trends,
                    classifications: classifications,
                    latestFeeling: latestFeeling,
                    conflictVerdict: conflictVerdict,
                    ignoreCount: ignoreCount,
                    briefText: briefText,
                    takeaway: takeaway,
                    aiUsed: true
                )
            } catch {
                // Fallback to template on AI failure
                print("[BriefGenerator] AI failed, using template: \(error.localizedDescription)")
            }
        }

        // Template fallback (offline / no AI)
        return DailyBrief.templateBrief(
            from: trends,
            classifications: classifications,
            conflictVerdict: conflictVerdict,
            userGoal: userGoal
        )
    }

    // MARK: - Generate Weekly Brief

    static func generateWeeklyBrief(
        thisWeekWindows: [MetricWindow],
        lastWeekWindows: [MetricWindow],
        conflictStats: ConflictStats,
        feelingSummary: FeelingSummary,
        userGoal: UserGoal,
        ignoreCount: Int,
        useAI: Bool = true
    ) async -> WeeklyBrief {
        // Build week-over-week comparisons
        let comparisons = buildComparisons(thisWeek: thisWeekWindows, lastWeek: lastWeekWindows)

        if useAI {
            do {
                let (briefText, suggestion) = try await AIService.generateWeeklyBriefText(
                    comparisons: comparisons,
                    conflictStats: conflictStats,
                    feelingSummary: feelingSummary,
                    userGoal: userGoal
                )

                return WeeklyBrief(
                    weekStart: Date().addingDays(-7).dayKey(),
                    weekEnd: Date().dayKey(),
                    metricComparisons: comparisons,
                    conflictStats: conflictStats,
                    feelingSummary: feelingSummary,
                    itemsIgnoredThisWeek: ignoreCount,
                    briefText: briefText,
                    weeklySuggestion: suggestion,
                    aiUsed: true
                )
            } catch {
                print("[BriefGenerator] Weekly AI failed: \(error.localizedDescription)")
            }
        }

        // Template fallback
        let templateText = comparisons.map(\.summary).joined(separator: "\n")
        return WeeklyBrief(
            weekStart: Date().addingDays(-7).dayKey(),
            weekEnd: Date().dayKey(),
            metricComparisons: comparisons,
            conflictStats: conflictStats,
            feelingSummary: feelingSummary,
            itemsIgnoredThisWeek: ignoreCount,
            briefText: templateText,
            weeklySuggestion: "Keep listening to your body — that's the best metric. 💪",
            aiUsed: false
        )
    }

    // MARK: - Private

    private static func buildComparisons(
        thisWeek: [MetricWindow],
        lastWeek: [MetricWindow]
    ) -> [MetricWeekComparison] {
        var results: [MetricWeekComparison] = []

        for window in thisWeek {
            let thisAvg = window.sevenDayAverage ?? 0
            let lastWindow = lastWeek.first(where: { $0.metric == window.metric })
            let lastAvg = lastWindow?.sevenDayAverage ?? thisAvg

            results.append(MetricWeekComparison(
                metric: window.metric,
                thisWeekAverage: thisAvg,
                lastWeekAverage: lastAvg
            ))
        }

        return results
    }

    private static func extractTakeaway(from briefText: String) -> String {
        // Extract the last meaningful sentence as takeaway
        let sentences = briefText
            .split(separator: ".")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        return sentences.last ?? "Keep listening to your body. ✨"
    }
}

extension Date {
    func addingDays(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: self) ?? self
    }
}
