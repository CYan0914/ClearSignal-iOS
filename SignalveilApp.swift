import SwiftUI

@main
struct SignalVeilApp: App {
    @StateObject private var subscriptionManager = SubscriptionManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(subscriptionManager)
        }
    }
}
