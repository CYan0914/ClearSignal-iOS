import Foundation
import RevenueCat

/// RevenueCat subscription manager — same pattern as TaoMind.
/// Manages premium entitlement: "pro"
@MainActor
final class SubscriptionManager: ObservableObject {
    @Published var isPro: Bool = false
    @Published var offerings: Offerings?
    @Published var customerInfo: CustomerInfo?
    /// Set while an offerings fetch is in flight — lets the paywall distinguish "loading" from "failed".
    @Published var isLoadingOfferings = false
    /// Human-readable reason the paywall can't show pricing (network error, no offering configured, etc).
    @Published var offeringError: String?

    private let apiKey = "appl_FMDsmQuAewPKirJginmwmALxQiS"

    init() {
        configure()
    }

    private func configure() {
        Purchases.logLevel = .error
        Purchases.configure(withAPIKey: apiKey)
        fetchCustomerInfo()
        fetchOfferings()
    }

    func fetchCustomerInfo() {
        Task {
            do {
                let info = try await Purchases.shared.customerInfo()
                self.customerInfo = info
                self.isPro = info.entitlements["pro"]?.isActive == true
            } catch {
                print("[SubscriptionManager] Failed to fetch customer info: \(error)")
            }
        }
    }

    /// Fetch the RevenueCat offerings. Safe to call repeatedly (e.g. paywall onAppear / Retry).
    func fetchOfferings() {
        isLoadingOfferings = true
        offeringError = nil
        Task {
            do {
                let result = try await Purchases.shared.offerings()
                self.offerings = result
                if result.current == nil {
                    // Request succeeded but the dashboard has no current offering configured.
                    self.offeringError = "No pricing configured yet — check back soon."
                }
            } catch {
                self.offerings = nil
                self.offeringError = error.localizedDescription
            }
            self.isLoadingOfferings = false
        }
    }

    func purchase(package: Package) async throws {
        do {
            let result = try await Purchases.shared.purchase(package: package)
            self.isPro = result.customerInfo.entitlements["pro"]?.isActive == true
            self.customerInfo = result.customerInfo
        } catch {
            print("[SubscriptionManager] Purchase failed: \(error)")
            throw error
        }
    }

    func restorePurchases() async throws {
        let info = try await Purchases.shared.restorePurchases()
        self.customerInfo = info
        self.isPro = info.entitlements["pro"]?.isActive == true
    }
}
