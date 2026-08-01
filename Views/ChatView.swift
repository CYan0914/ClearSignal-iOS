import SwiftUI

/// AI conversational Q&A — user asks questions about their health data.
/// The LLM receives pre-digested rule engine conclusions, NEVER raw data.
struct ChatView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var messages: [ChatMessage] = []
    @State private var inputText: String = ""
    @State private var isLoading = false
    @State private var showPaywall = false

    private let store = LocalDataStore.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Chat messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            // Welcome message
                            welcomeCard

                            ForEach(messages) { msg in
                                MessageBubble(message: msg)
                            }

                            if isLoading {
                                HStack {
                                    ProgressView()
                                        .padding(.horizontal)
                                    Text("Thinking...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messages.count) { _ in
                        if let last = messages.last {
                            withAnimation {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }

                // Input bar
                inputBar
            }
            .navigationTitle("Ask Signalveil")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }

    // MARK: - Subviews

    private var welcomeCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("👋 I'm your health data translator.")
                .font(.subheadline)
                .fontWeight(.medium)

            Text("Ask me about your trends — I'll explain what matters and what's just noise.\n\nTry:\n• \"Why is my HRV lower this week?\"\n• \"Should I trust my Oura readiness score?\"\n• \"Is my sleep actually okay?\"")
                .font(.caption)
                .foregroundColor(.secondary)
                .lineSpacing(3)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("Ask about your health data...", text: $inputText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3)
                .disabled(!subscriptionManager.isPro)

            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundColor(inputText.isEmpty || isLoading ? .secondary : .blue)
            }
            .disabled(inputText.isEmpty || isLoading)
        }
        .padding()
        .background(Color(.systemBackground))
        .overlay(Divider(), alignment: .top)
    }

    // MARK: - Actions

    private func sendMessage() {
        guard !inputText.isEmpty, subscriptionManager.isPro else {
            if !subscriptionManager.isPro { showPaywall = true }
            return
        }

        let userQuestion = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        inputText = ""

        let userMsg = ChatMessage(role: .user, content: userQuestion)
        messages.append(userMsg)

        isLoading = true

        Task {
            do {
                // Build context from latest brief and recent feelings
                let latestBrief = store.latestDailyBrief
                let trends = latestBrief?.metricTrends ?? []
                let recentFeelings = store.recentFeelingLogs

                let answer = try await AIService.answerQuestion(
                    userQuestion: userQuestion,
                    trends: trends,
                    recentFeelings: recentFeelings,
                    userGoal: store.userGoal
                )

                let assistantMsg = ChatMessage(role: .assistant, content: answer)
                messages.append(assistantMsg)
            } catch {
                let errorMsg = ChatMessage(
                    role: .assistant,
                    content: "Sorry, I couldn't process that right now. \(error.localizedDescription)"
                )
                messages.append(errorMsg)
            }

            isLoading = false
        }
    }
}

// MARK: - Chat Message Model & Bubble

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: MessageRole
    let content: String
    let timestamp = Date()

    enum MessageRole {
        case user, assistant
    }
}

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 60)
            }

            Text(message.content)
                .font(.subheadline)
                .padding(12)
                .background(message.role == .user ? Color.blue : Color(.systemGray6))
                .foregroundColor(message.role == .user ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .textSelection(.enabled)

            if message.role == .assistant {
                Spacer(minLength: 60)
            }
        }
    }
}
