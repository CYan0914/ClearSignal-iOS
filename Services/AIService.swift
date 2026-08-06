import Foundation

/// Makes API calls to the LLM (Qwen / DashScope) for translating rule engine output
/// into natural language briefs and answering user questions.
///
/// KEY PRINCIPLE: The LLM NEVER reads raw health data directly.
/// It receives structured output from the Rule Engine and only handles EXPRESSION.
struct AIService {

    // Using same DashScope config as TaoMind (from CLAUDE.md)
    private static let apiKey = "sk-735d0822786540739e195eaca4a5df06"
    private static let baseURL = "https://dashscope.aliyuncs.com/compatible-mode/v1"
    private static let model = "qwen-plus" // Good balance of speed/cost for translation tasks

    // MARK: - Translate Rule Engine Output → Natural Language Brief

    /// Generate the daily brief text from rule engine output.
    /// Prompt is tightly constrained — LLM translates, doesn't diagnose.
    static func generateDailyBriefText(
        trends: [TrendResult],
        classifications: [SignalNoiseVerdict],
        conflictVerdict: ConflictVerdict?,
        userGoal: UserGoal,
        ignoreCount: Int
    ) async throws -> String {
        let systemPrompt = """
        You are SignalVeil, a health data translator. Your job is to turn structured health data into a calm, helpful morning brief.

        CRITICAL RULES:
        - You are NOT a doctor. Never diagnose, never prescribe, never cause alarm.
        - If data is normal, say so briefly. Don't over-interpret.
        - If there's a trend anomaly, mention it calmly with a practical suggestion.
        - If there's a conflict between device scores and user feeling, ALWAYS side with the user's feeling unless a trend anomaly is present.
        - Use a friendly, concise tone. Like a trusted friend, not a medical report.
        - Keep the brief under 200 words.
        - NEVER use the word "concerning" — say "worth noting" instead.
        - Always end with one small, doable suggestion.
        """

        let userPrompt = buildDailyBriefPrompt(
            trends: trends,
            classifications: classifications,
            conflictVerdict: conflictVerdict,
            userGoal: userGoal,
            ignoreCount: ignoreCount
        )

        let response = try await callLLM(systemPrompt: systemPrompt, userPrompt: userPrompt)
        return response
    }

    /// Generate the weekly deep-dive brief
    static func generateWeeklyBriefText(
        comparisons: [MetricWeekComparison],
        conflictStats: ConflictStats,
        feelingSummary: FeelingSummary,
        userGoal: UserGoal
    ) async throws -> (brief: String, suggestion: String) {
        let systemPrompt = """
        You are SignalVeil, a health data translator. Generate a weekly summary from structured data.

        RULES:
        - Focus on trends, not single-day values.
        - Mention what's improving and what to watch.
        - Include the conflict stats naturally.
        - End with ONE actionable, small suggestion for next week.
        - Keep under 300 words. Friendly, calm tone.
        """

        let userPrompt = buildWeeklyBriefPrompt(
            comparisons: comparisons,
            conflictStats: conflictStats,
            feelingSummary: feelingSummary,
            userGoal: userGoal
        )

        let response = try await callLLM(systemPrompt: systemPrompt, userPrompt: userPrompt)

        // Extract suggestion (last line or sentence)
        let suggestion: String
        if let lastLine = response.split(separator: "\n").last {
            suggestion = String(lastLine)
        } else {
            suggestion = "Keep listening to your body — that's the best metric. 💪"
        }

        return (brief: response, suggestion: suggestion)
    }

    /// Answer a user's free-form question about their health data.
    /// IMPORTANT: The LLM receives pre-digested rule engine conclusions, not raw data.
    static func answerQuestion(
        userQuestion: String,
        trends: [TrendResult],
        recentFeelings: [FeelLog],
        userGoal: UserGoal
    ) async throws -> String {
        let systemPrompt = """
        You are SignalVeil, a calm, science-informed health translator. The user is asking about their health data.

        RULES:
        - You are NOT a doctor. Start with a disclaimer if the question is medical: "I'm not a doctor, but based on your data..."
        - Reference the user's actual trend data in your answer.
        - If the question is about a single-day reading, explain that single-day values are unreliable and suggest looking at trends instead.
        - Be honest about sensor limitations (Apple Watch sleep accuracy ~60-75%, HRV day-to-day variation ~20-40%).
        - Keep answers under 150 words unless the user asks for detail.
        - End with reassurance or a practical next step.
        """

        let dataContext = buildChatContext(
            trends: trends,
            recentFeelings: recentFeelings,
            userGoal: userGoal
        )

        let userPrompt = """
        USER'S HEALTH DATA CONTEXT:
        \(dataContext)

        USER'S QUESTION:
        \(userQuestion)

        Answer based on the data context above. If the data doesn't answer the question, be honest about the limitation.
        """

        return try await callLLM(systemPrompt: systemPrompt, userPrompt: userPrompt)
    }

    // MARK: - Private

    private static func callLLM(systemPrompt: String, userPrompt: String) async throws -> String {
        let url = URL(string: "\(baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt],
            ],
            "max_tokens": 600,
            "temperature": 0.7,
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AIServiceError.apiError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0, body: errorBody)
        }

        let result = try JSONDecoder().decode(DashScopeResponse.self, from: data)
        return result.choices.first?.message.content ?? "Unable to generate brief. Please try again."
    }

    // MARK: - Prompt Builders

    private static func buildDailyBriefPrompt(
        trends: [TrendResult],
        classifications: [SignalNoiseVerdict],
        conflictVerdict: ConflictVerdict?,
        userGoal: UserGoal,
        ignoreCount: Int
    ) -> String {
        var parts: [String] = []
        parts.append("USER GOAL: \(userGoal.displayName)")
        parts.append("")

        for trend in trends {
            let classif = classifications.first(where: { $0.metric == trend.metric })
            let noiseLabel = classif?.classification == .noise ? " [IGNORE — noise]" : ""
            parts.append(trend.summary + noiseLabel)
        }

        if let conflict = conflictVerdict {
            parts.append("")
            parts.append("CONFLICT: Device says: \(conflict.deviceConcern)")
            parts.append("User feels: \(conflict.userFeeling.label)")
            parts.append("Resolution: \(conflict.resolution.explanation)")
        }

        parts.append("")
        parts.append("Items ignored by user: \(ignoreCount)")
        parts.append("")
        parts.append("Write a calm, brief morning summary (~150 words). Include the conflict resolution if present.")

        return parts.joined(separator: "\n")
    }

    private static func buildWeeklyBriefPrompt(
        comparisons: [MetricWeekComparison],
        conflictStats: ConflictStats,
        feelingSummary: FeelingSummary,
        userGoal: UserGoal
    ) -> String {
        var parts: [String] = []
        parts.append("USER GOAL: \(userGoal.displayName)")
        parts.append("")

        parts.append("WEEK-OVER-WEEK COMPARISONS:")
        for c in comparisons {
            parts.append(c.summary)
        }

        parts.append("")
        parts.append("CONFLICT STATS: \(conflictStats.totalConflicts) total conflicts")
        parts.append("- Trusted feeling: \(conflictStats.trustFeelingCount)x")
        parts.append("- Trusted trend: \(conflictStats.trustTrendCount)x")
        parts.append("- Flagged for tracking: \(conflictStats.flaggedForTrackingCount)x")

        parts.append("")
        parts.append("FEELING: \(feelingSummary.goodDays) good days, \(feelingSummary.okayDays) okay, \(feelingSummary.badDays) bad")
        parts.append("")

        parts.append("Write a calm weekly summary (~250 words). End with ONE actionable suggestion.")

        return parts.joined(separator: "\n")
    }

    private static func buildChatContext(
        trends: [TrendResult],
        recentFeelings: [FeelLog],
        userGoal: UserGoal
    ) -> String {
        var parts: [String] = []
        parts.append("Goal: \(userGoal.displayName)")
        parts.append("")

        for trend in trends {
            parts.append(trend.summary)
        }

        if let latestFeeling = recentFeelings.last {
            parts.append("Latest feeling check-in: \(latestFeeling.feeling.label)")
        }

        return parts.joined(separator: "\n")
    }
}

// MARK: - Types

enum AIServiceError: Error, LocalizedError {
    case apiError(statusCode: Int, body: String)
    case noResponse

    var errorDescription: String? {
        switch self {
        case .apiError(let code, let body):
            return "AI service error (HTTP \(code)): \(body)"
        case .noResponse:
            return "AI service returned no response. Please try again."
        }
    }
}

private struct DashScopeResponse: Codable {
    let choices: [Choice]

    struct Choice: Codable {
        let message: Message
    }

    struct Message: Codable {
        let content: String
    }
}
