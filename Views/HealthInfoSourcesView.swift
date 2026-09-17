import SwiftUI

/// The full, always-reachable citation list for every health claim, recommendation
/// and calculation SignalVeil makes (App Review Guideline 1.4.1).
///
/// Reached from four places so it is never more than one tap away:
/// the Today tab footer, Settings → Health Information, the AI chat welcome card,
/// and the onboarding "How it works" step.
struct HealthInfoSourcesView: View {
    var body: some View {
        List {
            Section {
                Text("SignalVeil is a wellness-trend tool, not a medical device and not a provider of medical advice. Always consult a qualified healthcare professional about medical decisions.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            // MARK: How the app reaches its conclusions

            Section {
                ruleRow(
                    claim: "Only trends matter — a single day's reading is not meaningful.",
                    detail: "Wearable sensors are affected by measurement timing, body position, skin contact and sleep position. SignalVeil never shows a single-day value as a verdict.",
                    citation: HealthCitations.appleWatch
                )
                ruleRow(
                    claim: "A change counts as a signal only after 3 or more consecutive days outside your personal baseline.",
                    detail: "Your baseline is the mean of your own readings from the previous 60 days, and the band is ±1.5 standard deviations around it. This 3-day / ±1.5σ threshold is SignalVeil's own deterministic statistical rule (a standard process-control approach), not a clinical standard — it exists to filter out normal day-to-day variation.",
                    citation: HealthCitations.nhlbiHeart
                )
                ruleRow(
                    claim: "Sleep consistency is the standard deviation of your bedtimes, in minutes — lower is more consistent.",
                    detail: "Keeping a regular sleep and wake schedule is associated with better sleep quality and daytime function.",
                    citation: HealthCitations.nhlbiHealthySleepHabits
                )
                ruleRow(
                    claim: "When your wearable's score disagrees with how you feel, SignalVeil trusts how you feel.",
                    detail: "Self-reported wellbeing is itself health information, and single-day wearable scores are unreliable. The only exception is a 3-day trend anomaly (see above), which is flagged rather than ignored.",
                    citation: HealthCitations.medlineplusStress
                )
            } header: {
                Label("How SignalVeil reaches its conclusions", systemImage: "function")
            } footer: {
                Text("Every rule above is deterministic and runs on your device. No AI model makes these judgments.")
            }

            // MARK: Per-metric content

            Section {
                ForEach(HealthMetric.allCases) { metric in
                    DisclosureGroup {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(metricExplanation(metric))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            CitationFootnote(citations: HealthCitations.forMetric(metric))
                        }
                        .padding(.vertical, 4)
                    } label: {
                        Text(metric.displayName)
                            .font(.subheadline)
                    }
                }
            } header: {
                Label("Health topics referenced in the app", systemImage: "heart.text.square")
            } footer: {
                Text("These are the sources behind the explanations shown on each metric's detail screen.")
            }

            // MARK: Advice given by the app

            Section {
                ruleRow(
                    claim: "\"Consider prioritizing rest and recovery this week.\"",
                    detail: "Shown when a 3-day trend anomaly is detected while you report feeling fine.",
                    citation: HealthCitations.nhlbiSleepDeprivation
                )
                ruleRow(
                    claim: "\"If it continues, consider checking in with your doctor.\"",
                    detail: "Shown when you report feeling unwell but your metrics look normal. Persistent symptoms with normal readings are worth a professional opinion.",
                    citation: HealthCitations.medlineplusStress
                )
            } header: {
                Label("Advice the app can give you", systemImage: "text.bubble")
            }

            // MARK: Device limitations

            Section {
                sourceLink(HealthCitations.appleWatch)
                sourceLink(HealthCitations.appleHealth)
            } header: {
                Label("Sensor accuracy & limitations", systemImage: "applewatch")
            } footer: {
                Text("All readings come from the sensors in your own device. SignalVeil does not measure anything itself.")
            }

            Section {
                Text("Did we miss a source, or is a link broken? The sources above are the complete basis for the health information in this app.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Health Sources")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Rows

    private func ruleRow(claim: String, detail: String, citation: HealthCitation) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(claim)
                .font(.subheadline)
                .fontWeight(.medium)
                .fixedSize(horizontal: false, vertical: true)
            Text(detail)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            CitationFootnote(citations: [citation])
        }
        .padding(.vertical, 4)
    }

    private func sourceLink(_ citation: HealthCitation) -> some View {
        Link(destination: citation.link) {
            HStack(spacing: 8) {
                Text(citation.label)
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                Image(systemName: "arrow.up.right.square")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func metricExplanation(_ metric: HealthMetric) -> String {
        switch metric {
        case .sleepDuration:
            return "Total time asleep. Adults generally need 7 or more hours per night. Consumer wearables estimate sleep stages from movement and heart rate rather than brain activity, so total sleep time and night-to-night consistency are more dependable than stage breakdowns."
        case .restingHeartRate:
            return "Your heart rate at complete rest. A lower resting rate generally reflects better cardiovascular fitness. A sustained rise can accompany fatigue, illness or overtraining — which is why the trend matters and a single reading does not."
        case .heartRateVariability:
            return "The variation between successive heartbeats. Higher generally indicates a body that is recovering and adaptable. It is sensitive to measurement timing, sleep position, alcohol and stress, so single-day values swing widely and only the multi-day trend is informative."
        case .respiratoryRate:
            return "Your breathing rate at rest. It is a stable vital sign, so a sustained change is more meaningful than any one night's reading."
        case .activeEnergy:
            return "Calories burned through activity, estimated from heart rate and movement. Estimates vary between devices and activity types, so treat it as a directional trend rather than a precise count."
        case .stepCount:
            return "Daily step count — the simplest activity measure. Regular physical activity is associated with lower risk of chronic disease; the trend over weeks is what matters, not any single day."
        case .sleepConsistency:
            return "How regular your bedtime is, expressed as the standard deviation of your bedtimes in minutes. A consistent schedule supports sleep quality independently of total sleep duration."
        case .bodyWeight:
            return "Weight trend from a smart scale. Day-to-day weight shifts with water, salt and food intake, so only the rolling multi-day average is meaningful."
        case .bloodOxygen:
            return "Blood oxygen saturation (SpO2). Wearable readings are estimates and are easily disturbed by a loose watch or sleeping position. Repeatedly low readings during sleep are worth raising with a clinician."
        }
    }
}

#Preview {
    NavigationStack {
        HealthInfoSourcesView()
    }
}
