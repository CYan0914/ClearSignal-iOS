import SwiftUI
import RevenueCat

/// Subscription paywall — shown when free users try to access premium features.
/// Same pattern as TaoMind.
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()

                // Header
                VStack(spacing: 8) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)

                    Text("ClearSignal Premium")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Unlock the full experience")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // Features
                VStack(alignment: .leading, spacing: 16) {
                    premiumFeature(icon: "sun.max.fill", title: "Daily AI Morning Brief", desc: "Natural-language summary of your health trends — not a dashboard.")
                    premiumFeature(icon: "bubble.left.and.bubble.right.fill", title: "Conversational Q&A", desc: "Ask anything about your data. \"Why is my HRV down?\" — get a real answer.")
                    premiumFeature(icon: "bell.slash.fill", title: "Ignore Lists & Declutter", desc: "Tell us what to mute. We'll suggest what's noise.")
                    premiumFeature(icon: "target", title: "Goal Filtering", desc: "Only see metrics that matter for running, weight loss, or stress management.")
                }
                .padding(.horizontal, 30)

                Spacer()

                // Pricing
                if let offering = subscriptionManager.offerings?.current {
                    VStack(spacing: 12) {
                        ForEach(offering.availablePackages, id: \.identifier) { package in
                            packageButton(package)
                        }
                    }
                    .padding(.horizontal, 30)
                } else {
                    ProgressView("Loading pricing...")
                }

                // Error
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }

                // Restore
                Button("Restore Purchases") {
                    Task {
                        try? await subscriptionManager.restorePurchases()
                        if subscriptionManager.isPro {
                            dismiss()
                        }
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom, 20)
            }
            .navigationTitle("Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Maybe Later") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func packageButton(_ package: Package) -> some View {
        Button(action: { purchase(package) }) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(package.storeProduct.localizedTitle)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(package.packageType == .annual ? "\(package.localizedPriceString)/year — save 33%" : "\(package.localizedPriceString)/month")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if isLoading {
                    ProgressView()
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(package.packageType == .annual ? Color.blue.opacity(0.1) : Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(package.packageType == .annual ? Color.blue : Color(.systemGray4), lineWidth: package.packageType == .annual ? 2 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }

    private func purchase(_ package: Package) {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                try await subscriptionManager.purchase(package: package)
                if subscriptionManager.isPro {
                    dismiss()
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func premiumFeature(icon: String, title: String, desc: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(.blue)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(desc)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }
}
