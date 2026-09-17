import SwiftUI

/// A cited source for health information shown anywhere in the app.
/// Required by App Review Guideline 1.4.1 — every medical claim, recommendation
/// and calculation must be traceable to a named source the user can open.
struct HealthCitation: Identifiable, Hashable {
    let id: String
    let organization: String
    let title: String
    let url: String

    /// "CDC — Sleep and Sleep Disorders"
    var label: String { "\(organization) — \(title)" }

    var link: URL { URL(string: url)! }
}

/// The single source of truth for every source SignalVeil cites.
/// Adding a health claim to the app means adding its source here.
enum HealthCitations {

    // MARK: - Sleep

    static let cdcSleep = HealthCitation(
        id: "cdc-sleep",
        organization: "CDC",
        title: "Sleep and Sleep Disorders",
        url: "https://www.cdc.gov/sleep/"
    )

    static let nhlbiSleepDeprivation = HealthCitation(
        id: "nhlbi-sleep-deprivation",
        organization: "NIH — NHLBI",
        title: "Sleep Deprivation and Deficiency",
        url: "https://www.nhlbi.nih.gov/health/sleep-deprivation"
    )

    static let nhlbiHowMuchSleep = HealthCitation(
        id: "nhlbi-how-much-sleep",
        organization: "NIH — NHLBI",
        title: "How Much Sleep Is Enough",
        url: "https://www.nhlbi.nih.gov/health/sleep-deprivation/how-much-sleep"
    )

    static let nhlbiHealthySleepHabits = HealthCitation(
        id: "nhlbi-healthy-sleep-habits",
        organization: "NIH — NHLBI",
        title: "Healthy Sleep Habits",
        url: "https://www.nhlbi.nih.gov/health/sleep-deprivation/healthy-sleep-habits"
    )

    static let nhlbiSleepApnea = HealthCitation(
        id: "nhlbi-sleep-apnea",
        organization: "NIH — NHLBI",
        title: "Sleep Apnea",
        url: "https://www.nhlbi.nih.gov/health/sleep-apnea"
    )

    static let sleepFoundationDuration = HealthCitation(
        id: "sleepfoundation-duration",
        organization: "Sleep Foundation",
        title: "How Much Sleep Do You Really Need",
        url: "https://www.sleepfoundation.org/how-sleep-works/how-much-sleep-do-we-really-need"
    )

    static let sleepFoundationHygiene = HealthCitation(
        id: "sleepfoundation-hygiene",
        organization: "Sleep Foundation",
        title: "Sleep Hygiene",
        url: "https://www.sleepfoundation.org/how-sleep-works/sleep-hygiene"
    )

    // MARK: - Heart, stress & recovery

    static let nhlbiHeart = HealthCitation(
        id: "nhlbi-heart",
        organization: "NIH — NHLBI",
        title: "The Heart — How It Works",
        url: "https://www.nhlbi.nih.gov/health/heart"
    )

    static let medlineplusStress = HealthCitation(
        id: "medlineplus-stress",
        organization: "NIH — MedlinePlus",
        title: "Stress and Your Health",
        url: "https://medlineplus.gov/stress.html"
    )

    // MARK: - Activity & weight

    static let hhsPhysicalActivity = HealthCitation(
        id: "hhs-physical-activity",
        organization: "U.S. DHHS",
        title: "Physical Activity Guidelines for Americans",
        url: "https://health.gov/paguidelines/"
    )

    static let whoPhysicalActivity = HealthCitation(
        id: "who-physical-activity",
        organization: "WHO",
        title: "Physical Activity — Fact Sheet",
        url: "https://www.who.int/news-room/fact-sheets/detail/physical-activity"
    )

    static let medlineplusWeight = HealthCitation(
        id: "medlineplus-weight",
        organization: "NIH — MedlinePlus",
        title: "Weight Control",
        url: "https://medlineplus.gov/weightcontrol.html"
    )

    // MARK: - Sensor accuracy & device limitations

    static let appleWatch = HealthCitation(
        id: "apple-watch",
        organization: "Apple",
        title: "Apple Watch — Health & Fitness Sensors",
        url: "https://www.apple.com/apple-watch/"
    )

    static let appleHealth = HealthCitation(
        id: "apple-health",
        organization: "Apple",
        title: "The Health App",
        url: "https://www.apple.com/health/"
    )

    // MARK: - Per-metric sources

    /// Every source backing the health information shown for a given metric.
    static func forMetric(_ metric: HealthMetric) -> [HealthCitation] {
        switch metric {
        case .sleepDuration:
            return [cdcSleep, nhlbiHowMuchSleep, appleWatch]
        case .restingHeartRate:
            return [nhlbiHeart, appleWatch]
        case .heartRateVariability:
            return [medlineplusStress, nhlbiHeart]
        case .respiratoryRate:
            return [medlineplusStress, nhlbiHeart]
        case .activeEnergy:
            return [hhsPhysicalActivity, appleWatch]
        case .stepCount:
            return [whoPhysicalActivity, hhsPhysicalActivity]
        case .sleepConsistency:
            return [nhlbiHealthySleepHabits, sleepFoundationHygiene]
        case .bodyWeight:
            return [medlineplusWeight]
        case .bloodOxygen:
            return [nhlbiSleepApnea]
        }
    }

    /// Sources behind the app's core claim: single-day readings are unreliable,
    /// only trend-level change carries information.
    static let trendOverSingleDay: [HealthCitation] = [appleWatch, appleHealth, nhlbiHeart]

    /// Sources behind the "trust how you feel" conflict rule.
    static let trustYourFeeling: [HealthCitation] = [medlineplusStress, nhlbiHealthySleepHabits]

    /// Sources behind the recovery advice given when a trend anomaly is flagged.
    static let recoveryAdvice: [HealthCitation] = [nhlbiHealthySleepHabits, nhlbiSleepDeprivation]

    /// Every distinct source cited anywhere in the app, in display order.
    static let all: [HealthCitation] = [
        cdcSleep,
        nhlbiSleepDeprivation,
        nhlbiHowMuchSleep,
        nhlbiHealthySleepHabits,
        nhlbiSleepApnea,
        sleepFoundationDuration,
        sleepFoundationHygiene,
        nhlbiHeart,
        medlineplusStress,
        hhsPhysicalActivity,
        whoPhysicalActivity,
        medlineplusWeight,
        appleWatch,
        appleHealth,
    ]
}

// MARK: - Inline citation view

/// A compact, always-visible citation block. Dropped directly beneath any health
/// claim, recommendation or calculation so the source is never more than a tap away.
struct CitationFootnote: View {
    let citations: [HealthCitation]
    var heading: String = "Sources"

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                Image(systemName: "book.closed")
                    .font(.system(size: 10))
                Text(heading)
                    .font(.caption2)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.secondary)

            ForEach(citations) { citation in
                Link(destination: citation.link) {
                    HStack(alignment: .top, spacing: 5) {
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 10))
                            .padding(.top, 1)
                        Text(citation.label)
                            .font(.caption2)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .foregroundColor(.blue)
                }
                .accessibilityLabel("Source: \(citation.label)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 2)
    }
}

/// One-line variant for tight rows (e.g. the conflict verdict card).
/// Expands into the full list of sources via an inline disclosure.
struct CompactCitationLink: View {
    let citations: [HealthCitation]
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { expanded.toggle() }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "book.closed")
                        .font(.system(size: 10))
                    Text(expanded ? "Hide sources" : "Sources (\(citations.count))")
                        .font(.caption2)
                        .fontWeight(.semibold)
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9))
                }
                .foregroundColor(.blue)
            }
            .buttonStyle(.plain)

            if expanded {
                ForEach(citations) { citation in
                    Link(destination: citation.link) {
                        HStack(alignment: .top, spacing: 5) {
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 10))
                                .padding(.top, 1)
                            Text(citation.label)
                                .font(.caption2)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .foregroundColor(.blue)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
