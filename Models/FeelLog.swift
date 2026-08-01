import Foundation

/// A single daily feeling check-in — the user's subjective report.
/// One question per day: "How are you feeling?" → 😊 / 😐 / 😞
struct FeelLog: Identifiable, Codable {
    let id: UUID
    let date: Date
    let feeling: Feeling
    let note: String?  // Optional free-text note

    init(feeling: Feeling, note: String? = nil, date: Date = Date()) {
        self.id = UUID()
        self.date = date
        self.feeling = feeling
        self.note = note
    }

    /// Calendar day identifier for grouping
    var dayKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

/// Summary stats from feeling logs, used by the conflict arbitrator.
struct FeelingSummary: Codable {
    /// Count of good/okay/bad days in the window
    let goodDays: Int
    let okayDays: Int
    let badDays: Int
    /// Most recent feeling entry
    let latestFeeling: Feeling?
    /// Total days logged
    var totalDays: Int { goodDays + okayDays + badDays }

    /// Dominant feeling in this window
    var dominantFeeling: Feeling? {
        let maxCount = max(goodDays, okayDays, badDays)
        if maxCount == 0 { return nil }
        if goodDays >= okayDays && goodDays >= badDays { return .good }
        if okayDays >= goodDays && okayDays >= badDays { return .okay }
        return .bad
    }
}
