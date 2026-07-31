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
        case done
    }

    var body: some View {
        VStack(spacing: 0) {
            // Progress dots
            HStack(spacing: 8) {
                ForEach(0..<4) { i in
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

                if currentStep != .welcome && currentStep != .done {
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
        case .done: return 3
        }
    }

    private var buttonLabel: String {
        switch currentStep {
        case .welcome: return "Get Started"
        case .goalSelection: return "Continue"
        case .healthKit: return "Connect Apple Health"
        case .done: return "Start Using ClearSignal"
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
                currentStep = .done
            }
        case .done:
            store.isOnboardingComplete = true
            dismiss()
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

            Text("ClearSignal")
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

            Text("Connect Apple Health")
                .font(.title2)
                .fontWeight(.bold)

            Text("We only read 5-8 core metrics — not everything.\nYour data never leaves your device.\nYou can revoke access anytime in Settings.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            VStack(alignment: .leading, spacing: 8) {
                Text("We read:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Label("Sleep, Heart Rate, HRV, Breathing, Activity", systemImage: "checkmark.circle.fill")
                    .font(.subheadline)
                    .foregroundColor(.green)
                Text("We DON'T read:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
                Label("Workouts, Nutrition, Cycle Tracking, Blood Glucose, ECG", systemImage: "xmark.circle.fill")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Spacer()
        }
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
