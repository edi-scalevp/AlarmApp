import SwiftUI

/// Card view for displaying an alarm in the list
struct AlarmCard: View {
    @Bindable var alarm: Alarm
    let repository: AlarmRepository

    @State private var isToggling = false

    var body: some View {
        HStack(spacing: 16) {
            // Time and label
            VStack(alignment: .leading, spacing: 4) {
                Text(alarm.timeString)
                    .font(.system(size: 32, weight: .medium, design: .rounded))
                    .foregroundStyle(alarm.isEnabled ? .primary : .secondary)

                HStack(spacing: 8) {
                    if !alarm.label.isEmpty {
                        Text(alarm.label)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if !alarm.repeatDays.isEmpty {
                        Text(alarm.repeatDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Escalation badge
                if alarm.escalationEnabled {
                    HStack(spacing: 4) {
                        Image(systemName: "person.wave.2.fill")
                            .font(.caption2)
                        Text("\(alarm.escalationDelayMinutes)m")
                            .font(.caption2)
                    }
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.15))
                    .clipShape(Capsule())
                }
            }

            Spacer()

            // Toggle switch
            Toggle("", isOn: Binding(
                get: { alarm.isEnabled },
                set: { _ in toggleAlarm() }
            ))
            .labelsHidden()
            .tint(.orange)
            .disabled(isToggling)
        }
        .padding(.vertical, 8)
        .opacity(alarm.isEnabled ? 1 : 0.6)
    }

    private func toggleAlarm() {
        isToggling = true

        Task {
            try? await repository.toggleAlarm(alarm)
            isToggling = false
        }

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}

// MARK: - Day Selector

struct DaySelector: View {
    @Binding var selectedDays: [Int]

    private let days = Alarm.DayOfWeek.allCases

    var body: some View {
        HStack(spacing: 8) {
            ForEach(days, id: \.rawValue) { day in
                DayButton(
                    day: day,
                    isSelected: selectedDays.contains(day.rawValue),
                    onTap: { toggleDay(day) }
                )
            }
        }
    }

    private func toggleDay(_ day: Alarm.DayOfWeek) {
        if let index = selectedDays.firstIndex(of: day.rawValue) {
            selectedDays.remove(at: index)
        } else {
            selectedDays.append(day.rawValue)
            selectedDays.sort()
        }

        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
}

private struct DayButton: View {
    let day: Alarm.DayOfWeek
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(day.initial)
                .font(.caption.bold())
                .frame(width: 36, height: 36)
                .background(isSelected ? Color.orange : Color(.systemGray5))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Sound Picker

struct SoundPicker: View {
    @Binding var selectedSound: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(AlarmKitService.availableSounds, id: \.name) { sound in
                    HStack {
                        Text(sound.displayName)

                        Spacer()

                        if selectedSound == sound.name {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.orange)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedSound = sound.name
                        // Preview sound
                        previewSound(sound.name)
                    }
                }
            }
            .navigationTitle("Alarm Sound")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func previewSound(_ name: String) {
        // Play preview sound
        // In a real implementation, this would play the actual sound file
    }
}

// MARK: - Escalation Delay Picker

struct EscalationDelayPicker: View {
    @Binding var selectedDelay: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Alert friend after")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                ForEach(Alarm.escalationDelayOptions, id: \.self) { delay in
                    Button {
                        selectedDelay = delay
                    } label: {
                        Text("\(delay) min")
                            .font(.subheadline.bold())
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(selectedDelay == delay ? Color.orange : Color(.systemGray5))
                            .foregroundStyle(selectedDelay == delay ? .white : .primary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

#Preview {
    List {
        AlarmCard(
            alarm: Alarm(
                userId: "test",
                hour: 7,
                minute: 30,
                label: "Wake up",
                isEnabled: true,
                escalationEnabled: true,
                escalationDelayMinutes: 5
            ),
            repository: AlarmRepository()
        )
    }
}
