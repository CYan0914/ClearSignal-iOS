import SwiftUI

/// First-launch onboarding: goal selection + HealthKit permission.
/// 2 screens, minimal friction.
struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep: Step = .welcome
    @State private var selectedGoal: UserGoal = .generalHealth
    @StateObject private var healthKit = HealthKitService()

    private let store = LocalDataStore.shared

    enum Step {
        case welcome
        case goalSelection
        case healthKit
        case howItWorks
        case done
    }

    var body: some View {
        VStack(spacing: 0) {
            // Progress dots (5 steps total)
            HStack(spacing: 8) {
                ForEach(0..<5) { i in
                    Circle()
                        .fill(i <= stepIndex ? Color.blue : Color(.systemGray4))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.top, 40)

            // Content
            Group {
                switch currentStep {
                case .welcome:
                    welcomeStep
                case .goalSelection:
                    goalStep
                case .healthKit:
                    healthKitStep
                case .howItWorks:
                    howItWorksStep
                case .done:
                    doneStep
                }
            }
            .transition(.opacity)
            .animation(.easeInOut, value: currentStep)

            // Bottom button
            VStack(spacing: 12) {
                Button(action: nextStep) {
                    Text(buttonLabel)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 40)

                // Note: no Skip on the HealthKit step — the permission prompt is
                // required by App Review (5.1.1(iv)); the user can still deny it
                // inside the system dialog, which is handled gracefully.
                if currentStep == .goalSelection {
                    Button("Skip") {
                        currentStep = .done
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .padding(.bottom, 40)
        }
        .background(Color(.systemGroupedBackground))
    }

    private var stepIndex: Int {
        switch currentStep {
        case .welcome: return 0
        case .goalSelection: return 1
        case .healthKit: return 2
        case .howItWorks: return 3
        case .done: return 4
        }
    }

    private var buttonLabel: String {
        switch currentStep {
        case .welcome: return "Get Started"
        case .goalSelection: return "Continue"
        case .healthKit: return "Continue"
        case .howItWorks: return "Got it"
        case .done: return "Start Using SignalVeil"
        }
    }

    private func nextStep() {
        switch currentStep {
        case .welcome:
            currentStep = .goalSelection
        case .goalSelection:
            store.saveUserGoal(selectedGoal)
            currentStep = .healthKit
        case .healthKit:
            Task {
                do {
                    try await healthKit.requestAuthorization()
                } catch {
                    // Continue even if user denies — we'll show a message in app
                    print("[Onboarding] HealthKit auth denied: \(error)")
                }
                // 5.1.1(iv) preserved: HealthKit step must not be skippable.
                // The new "How it works" explainer comes AFTER the permission
                // prompt so it cannot be used to bypass consent.
                currentStep = .howItWorks
            }
        case .howItWorks:
            currentStep = .done
        case .done:
            store.isOnboardingComplete = true
            scheduleDefaultNotifications()
            dismiss()
        }
    }

    /// On completion, we ask for notification permission and schedule the two
    /// retention pushes: the daily morning brief + the Sunday weekly report.
    /// (Still only ever 1 push/day — the app stays intentionally quiet.)
    private func scheduleDefaultNotifications() {
        Task {
            _ = try? await NotificationService.shared.requestPermission()
            NotificationService.shared.scheduleMorningBrief()
            NotificationService.shared.scheduleWeeklyBrief()
        }
    }

    // MARK: - Welcome

    private var welcomeStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 64))
                .foregroundColor(.blue)
                .padding(.bottom, 8)

            Text("SignalVeil")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Your health data, translated.\nNo noise. No anxiety. Just the signal.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            VStack(alignment: .leading, spacing: 12) {
                featureRow(icon: "chart.line.uptrend.xyaxis", text: "Trends only — never single-day noise")
                featureRow(icon: "bell.slash", text: "Tell you what to ignore, not just what to track")
                featureRow(icon: "person.fill.checkmark", text: "When data conflicts with how you feel → trust your body")
                featureRow(icon: "lock.shield", text: "Your data stays on your device")
            }
            .padding(.horizontal, 30)

            Spacer()
        }
    }

    // MARK: - Goal

    private var goalStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("What's your main health goal?")
                .font(.title2)
                .fontWeight(.bold)

            Text("We'll only show the metrics that matter for your goal. The rest = noise.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            VStack(spacing: 12) {
                ForEach(UserGoal.allCases) { goal in
                    goalCard(goal)
                }
            }
            .padding(.horizontal, 30)

            Spacer()
        }
    }

    @ViewBuilder
    private func goalCard(_ goal: UserGoal) -> some View {
        Button(action: { selectedGoal = goal }) {
            HStack(spacing: 12) {
                Image(systemName: goal.icon)
                    .font(.title3)
                    .foregroundColor(selectedGoal == goal ? .white : .blue)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(selectedGoal == goal ? .white : .primary)
                    Text(goal.description)
                        .font(.caption2)
                        .foregroundColor(selectedGoal == goal ? .white.opacity(0.8) : .secondary)
                }

                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(selectedGoal == goal ? Color.blue : Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selectedGoal == goal ? Color.blue : Color(.systemGray4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - HealthKit

    private var healthKitStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "heart.circle")
                .font(.system(size: 64))
                .foregroundColor(.pink)
                .padding(.bottom, 8)

            Text("Allow SignalVeil to read your Health data")
                .font(.title2)
                .fontWeight(.bold)

            Text("We'll ask for permission to read these 8 core metrics from Apple Health. Your data never leaves your device, and you can change access anytime in Settings → Health.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            VStack(alignment: .leading, spacing: 8) {
                Label("We read:", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Label("Sleep, Heart Rate, HRV, Breathing, Activity, Steps, Weight, Blood Oxygen", systemImage: "heart.circle")
                    .font(.subheadline)
                    .foregroundColor(.primary)
                Text("We never read or write workouts, nutrition, cycle tracking, blood glucose, or ECG.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Spacer()
        }
    }

    // MARK: - How it works (B.1.4 — 4.3(b) anti-spam explainer)

    private var howItWorksStep: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 56))
                .foregroundColor(.blue)
                .padding(.bottom, 4)

            Text("How SignalVeil works")
                .font(.title2)
                .fontWeight(.bold)

            Text("SignalVeil is a noise filter, not an AI coach. Here's the loop:")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)

            VStack(alignment: .leading, spacing: 14) {
                howItWorksRow(
                    number: "1",
                    icon: "function",
                    title: "Rule engine judges",
                    body: "Every metric is labeled SIGNAL (worth watching) or NOISE (safe to ignore). No AI makes the call."
                )
                howItWorksRow(
                    number: "2",
                    icon: "face.smiling",
                    title: "You check in daily",
                    body: "One tap: good / so-so / not great. Your feeling matters more than any score."
                )
                howItWorksRow(
                    number: "3",
                    icon: "scalemass",
                    title: "We arbitrate",
                    body: "If your watch says one thing and you feel another, we trust you (unless 3+ day trend anomaly)."
                )
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    private func howItWorksRow(number: String, icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 28, height: 28)
                Text(number)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                Text(body)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 1)
    }

    // MARK: - Done

    private var doneStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("🎉")
                .font(.system(size: 64))

            Text("You're all set!")
                .font(.title2)
                .fontWeight(.bold)

            VStack(spacing: 8) {
                Text("Goal: \(selectedGoal.displayName)")
                    .font(.subheadline)
                Text("We'll analyze your trends and send your first morning brief tomorrow.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()
        }
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(.blue)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
            Spacer()
        }
    }
}
