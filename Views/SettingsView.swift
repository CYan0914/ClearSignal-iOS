import SwiftUI

/// Settings screen — goal, notifications, ignore list, subscription, about.
struct SettingsView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var showPaywall = false
    @State private var showOnboarding = false

    private let store = LocalDataStore.shared

    var body: some View {
        NavigationStack {
            Form {
                // --- Goal ---
                Section {
                    NavigationLink {
                        goalPicker
                    } label: {
                        HStack {
                            Label("Health Goal", systemImage: "target")
                            Spacer()
                            Text(store.userGoal.displayName)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Health Focus")
                } footer: {
                    Text("Changing your goal will update which metrics appear in your daily brief.")
                }

                // --- Notifications ---
                Section {
                    Picker(selection: Binding(
                        get: { store.notificationPref },
                        set: { store.saveNotificationPref($0) }
                    )) {
                        ForEach(NotificationPref.allCases, id: \.self) { pref in
                            Text(pref.displayName).tag(pref)
                        }
                    } label: {
                        Label("Notifications", systemImage: "bell")
                    }

                    if store.notificationPref != .none {
                        Button("Schedule Morning Brief") {
                            NotificationService.shared.scheduleMorningBrief(
                                triggerOnTrendAnomalyOnly: store.notificationPref == .anomaliesOnly
                            )
                        }
                    }
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("At most 1 push per day. We believe in notification minimalism.")
                }

                // --- Subscription ---
                Section {
                    HStack {
                        Label("Status", systemImage: "crown")
                        Spacer()
                        Text(subscriptionManager.isPro ? "Premium" : "Free")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(subscriptionManager.isPro ? .orange : .secondary)
                    }

                    if !subscriptionManager.isPro {
                        Button(action: { showPaywall = true }) {
                            Label("Upgrade to Premium", systemImage: "sparkles")
                        }
                    }

                    Button("Restore Purchases") {
                        Task {
                            try? await subscriptionManager.restorePurchases()
                        }
                    }
                } header: {
                    Text("Subscription")
                } footer: {
                    if !subscriptionManager.isPro {
                        Text("Premium unlocks: daily AI briefs, conversational Q&A, ignore lists, and goal filtering.")
                    }
                }

                // --- Data & Privacy ---
                Section {
                    HStack {
                        Label("Data Storage", systemImage: "lock.shield")
                        Spacer()
                        Text("On-device only")
                            .font(.subheadline)
                            .foregroundColor(.green)
                    }

                    NavigationLink {
                        privacyInfo
                    } label: {
                        Label("Privacy & Data Usage", systemImage: "hand.raised")
                    }
                } header: {
                    Text("Data & Privacy")
                }

                // --- About ---
                Section {
                    HStack {
                        Label("Version", systemImage: "info.circle")
                        Spacer()
                        Text("1.0.0")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Label("Installed", systemImage: "calendar")
                        Spacer()
                        Text(store.installDate?.formatted(date: .abbreviated, time: .omitted) ?? "Unknown")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("About")
                }

                // --- Reset ---
                Section {
                    Button("Re-do Onboarding", action: { showOnboarding = true })
                    Button("Reset All Data", role: .destructive) {
                        // Clear all local data
                        store.ignoreList = []
                        store.feelLogs = []
                        store.latestDailyBrief = nil
                        store.latestWeeklyBrief = nil
                        store.isOnboardingComplete = false
                    }
                } header: {
                    Text("Advanced")
                } footer: {
                    Text("This will clear all local preferences and cached briefs. HealthKit data is never deleted by ClearSignal — it stays in Apple Health.")
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .sheet(isPresented: $showOnboarding) {
                OnboardingView()
            }
        }
    }

    // MARK: - Goal Picker

    private var goalPicker: some View {
        List(UserGoal.allCases) { goal in
            Button(action: {
                store.saveUserGoal(goal)
            }) {
                HStack {
                    Image(systemName: goal.icon)
                        .foregroundColor(.blue)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(goal.displayName)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        Text(goal.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if store.userGoal == goal {
                        Image(systemName: "checkmark")
                            .foregroundColor(.blue)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .navigationTitle("Health Goal")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Privacy Info

    private var privacyInfo: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("ClearSignal Privacy Philosophy")
                    .font(.title3)
                    .fontWeight(.bold)

                Text("Your health data is the most personal data there is. We take that seriously.")
                    .font(.subheadline)

                VStack(alignment: .leading, spacing: 12) {
                    privacyPoint(
                        icon: "iphone",
                        title: "Data stays on your device",
                        detail: "ClearSignal reads HealthKit data locally. We never upload your raw health data to any server."
                    )
                    privacyPoint(
                        icon: "eye.slash",
                        title: "Minimal reading",
                        detail: "We only read 5-8 core metrics (sleep, heart rate, HRV, breathing, activity). We never access: workouts, nutrition, cycle tracking, blood glucose, or ECG data."
                    )
                    privacyPoint(
                        icon: "brain",
                        title: "AI with guardrails",
                        detail: "When you use the AI chat, only pre-processed trend summaries (not raw data) are sent to the AI service. The AI never sees your individual health readings."
                    )
                    privacyPoint(
                        icon: "trash",
                        title: "Delete anytime",
                        detail: "Delete the app and all local data is gone. Your HealthKit data was never copied — it stays in Apple Health where it belongs."
                    )
                }

                Text("We comply with Apple's HealthKit privacy guidelines and never use health data for advertising or marketing.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func privacyPoint(icon: String, title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                    .frame(width: 24)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            Text(detail)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.leading, 32)
        }
    }
}
