import Foundation
import RevenueCat

/// RevenueCat subscription manager — same pattern as TaoMind.
/// Manages premium entitlement: "pro"
@MainActor
final class SubscriptionManager: ObservableObject {
    @Published var isPro: Bool = false
    @Published var offerings: Offerings?
    @Published var customerInfo: CustomerInfo?

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

    func fetchOfferings() {
        Task {
            do {
                self.offerings = try await Purchases.shared.offerings()
            } catch {
                print("[SubscriptionManager] Failed to fetch offerings: \(error)")
            }
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
