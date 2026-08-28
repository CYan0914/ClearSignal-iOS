import SwiftUI

/// Manage what to ignore — the "declutter" dashboard.
/// Users can add metrics, notifications, and app features to their ignore list.
struct IgnoreListView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var ignoreList: [IgnoreListItem] = []
    @State private var showAddSheet = false
    @State private var showPaywall = false

    private let store = LocalDataStore.shared

    /// Free-tier cap: 3 active ignore items. Pro unlocks unlimited.
    private let freeItemCap = 3

    var body: some View {
        NavigationStack {
            // B.1.1 — 4.3(b) anti-spam: the 3 Declutter Bundles are FREE for
            // every user so reviewers and free-tier users can see SignalVeil's
            // differentiator. Pro unlocks: unlimited custom items + 30-day
            // history. Cap is on `ignoreList.count` for free users; bundles
            // bypass the cap because they're the headline feature.
            ignoreListContent
                .navigationTitle("Quiet Mode")
                .sheet(isPresented: $showPaywall) { PaywallView() }
        }
    }

    private var ignoreListContent: some View {
        List {
                // --- Active ignores ---
                if !ignoreList.isEmpty {
                    Section {
                        ForEach(ignoreList) { item in
                            ignoreRow(item)
                        }
                        .onDelete(perform: deleteItems)
                    } header: {
                        Label("Currently Ignored", systemImage: "bell.slash.fill")
                    } footer: {
                        Text("These won't appear in your daily brief or notifications. You can re-enable them anytime.")
                    }
                }

                // --- Suggested bundles ---
                Section {
                    ForEach(IgnoreBundle.allCases, id: \.self) { bundle in
                        bundleRow(bundle)
                    }
                } header: {
                    Label("Quick Declutter Bundles", systemImage: "sparkles")
                } footer: {
                    Text("These are common sources of anxiety from wearables. Tap to ignore them all at once.")
                }

                // --- Stats ---
                Section {
                    statRow(label: "Total items ignored", value: "\(ignoreList.count)")
                    statRow(label: "App-suggested", value: "\(ignoreList.filter(\.suggested).count)")
                    statRow(label: "Manually added", value: "\(ignoreList.filter { !$0.suggested }.count)")
                } header: {
                    Label("Ignore Stats", systemImage: "chart.bar")
                }
            }
            .navigationTitle("Quiet Mode")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: tapAdd) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddIgnoreView { newItem in
                    store.addIgnoreItem(newItem)
                    ignoreList = store.ignoreList
                }
            }
            .onAppear {
                ignoreList = store.ignoreList
            }
    }

    /// "Add custom ignore" tap. Free users hit the cap → paywall; Pro goes straight to sheet.
    private func tapAdd() {
        if canAddCustomItem() {
            showAddSheet = true
        } else {
            showPaywall = true
        }
    }

    // MARK: - Subviews

    private func ignoreRow(_ item: IgnoreListItem) -> some View {
        HStack {
            Image(systemName: item.type.icon)
                .foregroundColor(.secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.label)
                    .font(.subheadline)
                HStack(spacing: 4) {
                    Text(item.type.rawValue.capitalized)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    if item.suggested {
                        Text("· Suggested")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func bundleRow(_ bundle: IgnoreBundle) -> some View {
        Button(action: { addBundle(bundle) }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(bundle.rawValue)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    Text(bundle.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(bundle.items.count) items")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }

                Spacer()

                Image(systemName: "plus.circle")
                    .foregroundColor(.blue)
            }
        }
        .buttonStyle(.plain)
    }

    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Actions

    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            store.removeIgnoreItem(id: ignoreList[index].id)
        }
        ignoreList = store.ignoreList
    }

    private func addBundle(_ bundle: IgnoreBundle) {
        // Bundles are always allowed — they're the headline feature, free for all.
        for (type, label) in bundle.items {
            if !ignoreList.contains(where: { $0.label == label }) {
                let item = IgnoreListItem(type: type, label: label, suggested: true)
                store.addIgnoreItem(item)
            }
        }
        ignoreList = store.ignoreList
    }

    /// Free users: stop at the cap and prompt upgrade. Pro: no cap.
    private func canAddCustomItem() -> Bool {
        if subscriptionManager.isPro { return true }
        return ignoreList.filter { !$0.suggested }.count < freeItemCap
    }
}

// MARK: - Add Ignore Sheet

struct AddIgnoreView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedType: IgnoreType = .metric
    @State private var label: String = ""
    var onAdd: (IgnoreListItem) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $selectedType) {
                        ForEach(IgnoreType.allCases, id: \.self) { type in
                            Label(type.rawValue.capitalized, systemImage: type.icon)
                                .tag(type)
                        }
                    }

                    TextField("What to ignore", text: $label)
                } header: {
                    Text("New Ignore Item")
                } footer: {
                    Text("You can always remove this later in Settings.")
                }

                Section {
                    Button(action: {
                        guard !label.isEmpty else { return }
                        let item = IgnoreListItem(type: selectedType, label: label)
                        onAdd(item)
                        dismiss()
                    }) {
                        Text("Add to Ignore List")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(label.isEmpty)
                }
            }
            .navigationTitle("Add to Ignore")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
