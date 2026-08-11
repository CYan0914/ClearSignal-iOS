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

                    Text("SignalVeil Premium")
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
                    premiumFeature(icon: "calendar.badge.clock", title: "Weekly AI Deep Report", desc: "A Sunday deep-dive on your week — trends, conflicts, and what to adjust.")
                }
                .padding(.horizontal, 30)

                Spacer()

                // Pricing
                if let offering = subscriptionManager.offerings?.current {
                    VStack(spacing: 12) {
                        ForEach(offering.availablePackages, id: \.identifier) { package in
                            packageButton(package, monthlyPrice: offering.availablePackages.first { $0.packageType == .monthly }?.storeProduct.price)
                        }
                    }
                    .padding(.horizontal, 30)
                } else if subscriptionManager.isLoadingOfferings {
                    ProgressView("Loading pricing...")
                } else {
                    VStack(spacing: 10) {
                        Text(subscriptionManager.offeringError ?? "Pricing is temporarily unavailable.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Retry") { subscriptionManager.fetchOfferings() }
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 30)
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
            .task {
                // Re-fetch pricing each time the paywall appears, so a failed launch-time
                // fetch doesn't leave us stuck on a spinner.
                if subscriptionManager.offerings?.current == nil {
                    subscriptionManager.fetchOfferings()
                }
            }
        }
    }

    @ViewBuilder
    private func packageButton(_ package: Package, monthlyPrice: Decimal?) -> some View {
        Button(action: { purchase(package) }) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(package.storeProduct.localizedTitle)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(purchaseLabel(for: package, monthlyPrice: monthlyPrice))
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

    /// Full button label: per-period price (+ savings), plus the free-trial term when one exists.
    private func purchaseLabel(for package: Package, monthlyPrice: Decimal?) -> String {
        let price = priceLabel(for: package, monthlyPrice: monthlyPrice)
        if let trial = trialLabel(for: package) {
            return "\(price) · \(trial)"
        }
        return price
    }

    /// "7 days free" style label, only when the product actually has a free-trial intro offer.
    private func trialLabel(for package: Package) -> String? {
        guard let intro = package.storeProduct.introductoryDiscount,
              intro.paymentMode == .freeTrial else { return nil }
        let count = intro.numberOfPeriods
        switch intro.subscriptionPeriod.unit {
        case .day:   return count == 1 ? "1 day free" : "\(count) days free"
        case .week:  return count == 1 ? "1 week free" : "\(count) weeks free"
        case .month: return count == 1 ? "1 month free" : "\(count) months free"
        case .year:  return count == 1 ? "1 year free" : "\(count) years free"
        default:     return "Free trial"
        }
    }

    /// Localized per-period price, plus a savings badge vs the monthly tier when applicable.
    private func priceLabel(for package: Package, monthlyPrice: Decimal?) -> String {
        let price = periodPrice(for: package)
        if let save = savingsText(for: package, monthlyPrice: monthlyPrice) {
            return "\(price) — \(save)"
        }
        return price
    }

    private func periodPrice(for package: Package) -> String {
        switch package.packageType {
        case .weekly:      return "\(package.localizedPriceString)/week"
        case .monthly:     return "\(package.localizedPriceString)/month"
        case .twoMonth:    return "\(package.localizedPriceString)/2 months"
        case .threeMonth:  return "\(package.localizedPriceString)/quarter"
        case .sixMonth:    return "\(package.localizedPriceString)/6 months"
        case .annual:      return "\(package.localizedPriceString)/year"
        default:           return package.localizedPriceString
        }
    }

    private func savingsText(for package: Package, monthlyPrice: Decimal?) -> String? {
        guard let monthlyPrice,
              let period = package.storeProduct.subscriptionPeriod,
              monthlyPrice > 0 else { return nil }
        let months: Double
        switch period.unit {
        case .month: months = Double(period.value)
        case .year:  months = Double(period.value) * 12
        case .week:  months = Double(period.value) / 4.33
        case .day:   months = Double(period.value) / 30.44
        default:     months = Double(period.value)
        }
        let perMonth = NSDecimalNumber(decimal: package.storeProduct.price).doubleValue / months
        let monthly = NSDecimalNumber(decimal: monthlyPrice).doubleValue
        guard monthly > 0, perMonth > 0, perMonth < monthly else { return nil }
        let pct = Int(((monthly - perMonth) / monthly * 100).rounded())
        guard pct > 0 else { return nil }
        return "save \(pct)%"
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
