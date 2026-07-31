import SwiftUI

struct ContentView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var selectedTab: Tab = .today

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView()
                .tabItem {
                    Label("Today", systemImage: "sun.max")
                }
                .tag(Tab.today)

            ChatView()
                .tabItem {
                    Label("Ask", systemImage: "bubble.left.and.bubble.right")
                }
                .tag(Tab.chat)

            IgnoreListView()
                .tabItem {
                    Label("Quiet", systemImage: "bell.slash")
                }
                .tag(Tab.ignore)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(Tab.settings)
        }
    }
}

enum Tab: Hashable {
    case today
    case chat
    case ignore
    case settings
}
