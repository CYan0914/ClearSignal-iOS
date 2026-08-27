import SwiftUI

/// Persistently-visible list of sources the app's health information draws from
/// (App Review Guideline 1.4.1). Shown both from Settings and the AI chat's
/// welcome card, so the citations users see are always easy to find.
struct HealthInfoSourcesView: View {
    var body: some View {
        List {
            Section {
                Text("SignalVeil is a wellness-trend tool, not a medical device and not a provider of medical advice. Always consult a qualified healthcare professional for medical decisions.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Section("Health authorities consulted for health content") {
                sourceLink("CDC — Sleep and Sleep Disorders", url: "https://www.cdc.gov/sleep/index.html")
                sourceLink("American Heart Association — Heart Rate & HRV", url: "https://www.heart.org/en/health-topics/high-blood-pressure/the-facts-about-high-blood-pressure/all-about-heart-rate-pulse")
                sourceLink("Mayo Clinic — Stress, HRV & Recovery", url: "https://www.mayoclinic.org/diseases-conditions/adult-adhd/in-depth/exercise-and-stress/art-20044469")
                sourceLink("NIH — Physical Activity Guidelines", url: "https://health.gov/paguidelines/")
                sourceLink("WHO — Physical Activity Recommendations", url: "https://www.who.int/news-room/fact-sheets/detail/physical-activity")
                sourceLink("Sleep Foundation — Sleep Duration & Quality", url: "https://www.sleepfoundation.org/")
            }

            Section("Sensor accuracy & limitations") {
                sourceLink("Apple — Health & Fitness (HealthKit)", url: "https://www.apple.com/healthcare/apple-watch/")
                sourceLink("Apple Watch accuracy research", url: "https://www.apple.com/apple-watch/health-and-fitness/")
            }
        }
        .navigationTitle("Health Sources")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sourceLink(_ title: String, url: String) -> some View {
        Link(destination: URL(string: url)!) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.blue)
                Image(systemName: "arrow.up.right.square")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        HealthInfoSourcesView()
    }
}