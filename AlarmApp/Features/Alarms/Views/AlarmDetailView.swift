import SwiftUI

/// Detail view for editing an existing alarm
struct AlarmDetailView: View {
    @Environment(\.dismiss) private var dismiss

    @Bindable var alarm: Alarm
    let repository: AlarmRepository

    // Local state for editing
    @State private var selectedTime: Date
    @State private var label: String
    @State private var repeatDays: [Int]
    @State private var soundName: String
    @State private var snoozeEnabled: Bool
    @State private var snoozeDuration: Int
    @State private var escalationEnabled: Bool
    @State private var escalationDelayMinutes: Int
    @State private var escalationFriendIds: [String]
    @State private var escalationMessage: String

    // UI state
    @State private var showSoundPicker = false
    @State private var showFriendSelector = false
    @State private var showDeleteConfirmation = false
    @State private var isSaving = false

    init(alarm: Alarm, repository: AlarmRepository) {
        self.alarm = alarm
        self.repository = repository

        // Initialize state from alarm
        let calendar = Calendar.current
        var components = DateComponents()
        components.hour = alarm.hour
        components.minute = alarm.minute
        let time = calendar.date(from: components) ?? Date()

        _selectedTime = State(initialValue: time)
        _label = State(initialValue: alarm.label)
        _repeatDays = State(initialValue: alarm.repeatDays)
        _soundName = State(initialValue: alarm.soundName)
        _snoozeEnabled = State(initialValue: alarm.snoozeEnabled)
        _snoozeDuration = State(initialValue: alarm.snoozeDuration)
        _escalationEnabled = State(initialValue: alarm.escalationEnabled)
        _escalationDelayMinutes = State(initialValue: alarm.escalationDelayMinutes)
        _escalationFriendIds = State(initialValue: alarm.escalationFriendIds)
        _escalationMessage = State(initialValue: alarm.escalationMessage ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Time picker
                    DatePicker(
                        "Time",
                        selection: $selectedTime,
                        displayedComponents: .hourAndMinute
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)

                    Divider()
                        .padding(.horizontal)

                    // Basic settings
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
                            showSoundPicker = true
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

                    Divider()
                        .padding(.horizontal)

                    // Escalation settings
                    VStack(spacing: 20) {
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
                                    showFriendSelector = true
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

                    Divider()
                        .padding(.horizontal)

                    // Delete button
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete Alarm")
                        }
                        .font(.headline)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.red.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 32)
                }
                .padding(.vertical)
            }
            .navigationTitle("Edit Alarm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        saveChanges()
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
            .confirmationDialog(
                "Delete Alarm",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    deleteAlarm()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete this alarm?")
            }
        }
    }

    private var displaySoundName: String {
        AlarmKitService.availableSounds.first { $0.name == soundName }?.displayName ?? "Default"
    }

    private func saveChanges() {
        let calendar = Calendar.current

        isSaving = true

        // Update alarm properties
        alarm.hour = calendar.component(.hour, from: selectedTime)
        alarm.minute = calendar.component(.minute, from: selectedTime)
        alarm.label = label.trimmingCharacters(in: .whitespacesAndNewlines)
        alarm.repeatDays = repeatDays
        alarm.soundName = soundName
        alarm.snoozeEnabled = snoozeEnabled
        alarm.snoozeDuration = snoozeDuration
        alarm.escalationEnabled = escalationEnabled
        alarm.escalationDelayMinutes = escalationDelayMinutes
        alarm.escalationFriendIds = escalationFriendIds
        alarm.escalationMessage = escalationMessage.isEmpty ? nil : escalationMessage

        Task {
            do {
                try await repository.updateAlarm(alarm)
                dismiss()
            } catch {
                print("Failed to save alarm: \(error)")
            }
            isSaving = false
        }
    }

    private func deleteAlarm() {
        Task {
            do {
                try await repository.deleteAlarm(alarm)
                dismiss()
            } catch {
                print("Failed to delete alarm: \(error)")
            }
        }
    }
}

#Preview {
    AlarmDetailView(
        alarm: Alarm(
            userId: "test",
            hour: 7,
            minute: 30,
            label: "Wake up",
            escalationEnabled: true
        ),
        repository: AlarmRepository()
    )
}
