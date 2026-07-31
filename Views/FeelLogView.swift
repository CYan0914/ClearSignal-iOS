import SwiftUI

/// The daily feeling check-in — ONE question: "How are you feeling?"
/// This is the input to the Conflict Arbitrator.
struct FeelLogView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFeeling: Feeling?
    @State private var note: String = ""

    private let store = LocalDataStore.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                // Question
                Text("How are you feeling today?")
                    .font(.title3)
                    .fontWeight(.medium)

                Text("This helps us compare how you feel vs what your device scores say.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                // Three-choice feeling selector
                HStack(spacing: 20) {
                    ForEach(Feeling.allCases, id: \.self) { feeling in
                        feelingButton(feeling)
                    }
                }
                .padding(.horizontal)

                // Optional note
                VStack(alignment: .leading, spacing: 4) {
                    Text("Anything to note? (optional)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("e.g., Slept poorly, stressed at work...", text: $note, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3)
                }
                .padding(.horizontal, 40)

                Spacer()

                // Save button
                Button(action: saveAndDismiss) {
                    Text("Save Check-in")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedFeeling != nil ? Color.blue : Color(.systemGray4))
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(selectedFeeling == nil)
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
            .navigationTitle("Daily Check-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func feelingButton(_ feeling: Feeling) -> some View {
        Button(action: { selectedFeeling = feeling }) {
            VStack(spacing: 8) {
                Text(feeling.emoji)
                    .font(.system(size: 48))
                Text(feeling.label)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(selectedFeeling == feeling ? Color.blue.opacity(0.1) : Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                selectedFeeling == feeling ? Color.blue : Color(.systemGray4),
                                lineWidth: selectedFeeling == feeling ? 2 : 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func saveAndDismiss() {
        guard let feeling = selectedFeeling else { return }
        let log = FeelLog(
            feeling: feeling,
            note: note.isEmpty ? nil : note
        )
        store.saveFeelLog(log)
        dismiss()
    }
}
