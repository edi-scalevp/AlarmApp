import SwiftUI

/// View for creating a new alarm
struct CreateAlarmView: View {
    @Environment(\.dismiss) private var dismiss

    let repository: AlarmRepository

    // Alarm settings
    @State private var selectedTime = Date()
    @State private var label = ""
    @State private var repeatDays: [Int] = []
    @State private var soundName = "default"
    @State private var snoozeEnabled = true
    @State private var snoozeDuration = 9

    // Escalation settings
    @State private var escalationEnabled = false
    @State private var escalationDelayMinutes = 5
    @State private var escalationFriendIds: [String] = []
    @State private var escalationMessage = ""

    // UI state
    @State private var showSoundPicker = false
    @State private var showFriendSelector = false
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Time picker
                    TimePickerSection(selectedTime: $selectedTime)

                    Divider()
                        .padding(.horizontal)

                    // Basic settings
                    BasicSettingsSection(
                        label: $label,
                        repeatDays: $repeatDays,
                        soundName: $soundName,
                        snoozeEnabled: $snoozeEnabled,
                        onSoundTapped: { showSoundPicker = true }
                    )

                    Divider()
                        .padding(.horizontal)

                    // Escalation settings
                    EscalationSettingsSection(
                        escalationEnabled: $escalationEnabled,
                        escalationDelayMinutes: $escalationDelayMinutes,
                        escalationFriendIds: $escalationFriendIds,
                        escalationMessage: $escalationMessage,
                        onSelectFriends: { showFriendSelector = true }
                    )
                }
                .padding(.vertical)
            }
            .navigationTitle("New Alarm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        saveAlarm()
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                                .bold()
                        }
                    }
                    .disabled(isSaving)
                }
            }
            .sheet(isPresented: $showSoundPicker) {
                SoundPicker(selectedSound: $soundName)
            }
            .sheet(isPresented: $showFriendSelector) {
                FriendSelectorView(selectedFriendIds: $escalationFriendIds)
            }
        }
    }

    private func saveAlarm() {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: selectedTime)
        let minute = calendar.component(.minute, from: selectedTime)

        isSaving = true

        Task {
            do {
                _ = try await repository.createAlarm(
                    hour: hour,
                    minute: minute,
                    label: label.trimmingCharacters(in: .whitespacesAndNewlines),
                    repeatDays: repeatDays,
                    soundName: soundName,
                    snoozeEnabled: snoozeEnabled,
                    snoozeDuration: snoozeDuration,
                    escalationEnabled: escalationEnabled,
                    escalationDelayMinutes: escalationDelayMinutes,
                    escalationFriendIds: escalationFriendIds,
                    escalationMessage: escalationMessage.isEmpty ? nil : escalationMessage
                )

                dismiss()
            } catch {
                print("Failed to save alarm: \(error)")
            }

            isSaving = false
        }
    }
}

// MARK: - Time Picker Section

private struct TimePickerSection: View {
    @Binding var selectedTime: Date

    var body: some View {
        DatePicker(
            "Time",
            selection: $selectedTime,
            displayedComponents: .hourAndMinute
        )
        .datePickerStyle(.wheel)
        .labelsHidden()
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Basic Settings Section

private struct BasicSettingsSection: View {
    @Binding var label: String
    @Binding var repeatDays: [Int]
    @Binding var soundName: String
    @Binding var snoozeEnabled: Bool
    let onSoundTapped: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Label
            VStack(alignment: .leading, spacing: 8) {
                Text("Label")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextField("Alarm label", text: $label)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.horizontal)

            // Repeat days
            VStack(alignment: .leading, spacing: 8) {
                Text("Repeat")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                DaySelector(selectedDays: $repeatDays)
            }
            .padding(.horizontal)

            // Sound
            Button {
                onSoundTapped()
            } label: {
                HStack {
                    Text("Sound")
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(displaySoundName)
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .padding(.horizontal)

            // Snooze toggle
            Toggle("Snooze", isOn: $snoozeEnabled)
                .padding(.horizontal)
                .tint(.orange)
        }
    }

    private var displaySoundName: String {
        AlarmKitService.availableSounds.first { $0.name == soundName }?.displayName ?? "Default"
    }
}

// MARK: - Escalation Settings Section

private struct EscalationSettingsSection: View {
    @Binding var escalationEnabled: Bool
    @Binding var escalationDelayMinutes: Int
    @Binding var escalationFriendIds: [String]
    @Binding var escalationMessage: String
    let onSelectFriends: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Header with toggle
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Social Accountability")
                        .font(.headline)

                    Text("Alert a friend if you don't wake up")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle("", isOn: $escalationEnabled)
                    .labelsHidden()
                    .tint(.orange)
            }
            .padding(.horizontal)

            if escalationEnabled {
                VStack(spacing: 16) {
                    // Friend selector
                    Button {
                        onSelectFriends()
                    } label: {
                        HStack {
                            Image(systemName: "person.2.fill")
                                .foregroundStyle(.orange)

                            if escalationFriendIds.isEmpty {
                                Text("Select friend")
                                    .foregroundStyle(.primary)
                            } else {
                                Text("\(escalationFriendIds.count) friend\(escalationFriendIds.count == 1 ? "" : "s") selected")
                                    .foregroundStyle(.primary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)

                    // Delay picker
                    EscalationDelayPicker(selectedDelay: $escalationDelayMinutes)
                        .padding(.horizontal)

                    // Custom message
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Custom message (optional)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        TextField("Help me wake up!", text: $escalationMessage)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(.horizontal)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: escalationEnabled)
    }
}

// MARK: - Friend Selector View

struct FriendSelectorView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedFriendIds: [String]

    // In a real app, this would fetch from FriendRepository
    @State private var friends: [Friend] = []

    var body: some View {
        NavigationStack {
            Group {
                if friends.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)

                        Text("No Friends Yet")
                            .font(.headline)

                        Text("Add friends to enable social accountability")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(friends) { friend in
                            FriendSelectionRow(
                                friend: friend,
                                isSelected: selectedFriendIds.contains(friend.friendUserId),
                                onToggle: { toggleFriend(friend) }
                            )
                        }
                    }
                }
            }
            .navigationTitle("Select Friends")
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

    private func toggleFriend(_ friend: Friend) {
        if let index = selectedFriendIds.firstIndex(of: friend.friendUserId) {
            selectedFriendIds.remove(at: index)
        } else {
            selectedFriendIds.append(friend.friendUserId)
        }
    }
}

private struct FriendSelectionRow: View {
    let friend: Friend
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // Avatar
                Circle()
                    .fill(Color.orange.opacity(0.2))
                    .frame(width: 44, height: 44)
                    .overlay {
                        Text(friend.initials)
                            .font(.subheadline.bold())
                            .foregroundStyle(.orange)
                    }

                // Name
                VStack(alignment: .leading, spacing: 2) {
                    Text(friend.bestDisplayName)
                        .font(.body)
                        .foregroundStyle(.primary)

                    if let subtitle = friend.subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? .orange : .secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    CreateAlarmView(repository: AlarmRepository())
}
