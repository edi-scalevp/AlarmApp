import SwiftUI
import SwiftData

/// Main alarm list view - displays all user's alarms
struct AlarmListView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var alarmRepository: AlarmRepository?
    @State private var showCreateAlarm = false
    @State private var selectedAlarm: Alarm?

    var body: some View {
        NavigationStack {
            Group {
                if let repository = alarmRepository {
                    if repository.alarms.isEmpty {
                        EmptyAlarmsView {
                            showCreateAlarm = true
                        }
                    } else {
                        AlarmListContent(
                            repository: repository,
                            onSelect: { selectedAlarm = $0 }
                        )
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Alarms")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCreateAlarm = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showCreateAlarm) {
                if let repository = alarmRepository {
                    CreateAlarmView(repository: repository)
                }
            }
            .sheet(item: $selectedAlarm) { alarm in
                if let repository = alarmRepository {
                    AlarmDetailView(alarm: alarm, repository: repository)
                }
            }
        }
        .task {
            setupRepository()
        }
    }

    private func setupRepository() {
        guard let userId = appState.currentUser?.id else { return }

        let repository = AlarmRepository(
            alarmService: appState.alarmService ?? AlarmKitService(),
            escalationService: appState.escalationService ?? EscalationService()
        )

        repository.configure(modelContext: modelContext, userId: userId)
        alarmRepository = repository
    }
}

// MARK: - Alarm List Content

private struct AlarmListContent: View {
    @Bindable var repository: AlarmRepository
    let onSelect: (Alarm) -> Void

    var body: some View {
        List {
            // Next alarm section
            if let nextAlarm = repository.nextAlarm {
                Section {
                    NextAlarmCard(alarm: nextAlarm)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            // All alarms section
            Section {
                ForEach(repository.alarms) { alarm in
                    AlarmCard(alarm: alarm, repository: repository)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onSelect(alarm)
                        }
                }
                .onDelete { indexSet in
                    deleteAlarms(at: indexSet)
                }
            } header: {
                if !repository.alarms.isEmpty {
                    Text("All Alarms")
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func deleteAlarms(at offsets: IndexSet) {
        Task {
            for index in offsets {
                let alarm = repository.alarms[index]
                try? await repository.deleteAlarm(alarm)
            }
        }
    }
}

// MARK: - Next Alarm Card

private struct NextAlarmCard: View {
    let alarm: Alarm

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Next Alarm")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(alarm.timeString)
                        .font(.system(size: 48, weight: .bold, design: .rounded))

                    if !alarm.label.isEmpty {
                        Text(alarm.label)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Time until
                if let timeUntil = alarm.timeUntilNextFire {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("in")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(formatTimeInterval(timeUntil))
                            .font(.headline)
                            .foregroundStyle(.orange)
                    }
                }
            }

            // Escalation indicator
            if alarm.escalationEnabled {
                HStack(spacing: 8) {
                    Image(systemName: "person.wave.2.fill")
                        .foregroundStyle(.orange)
                    Text("Friend will be notified after \(alarm.escalationDelayMinutes) min")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(12)
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes) min"
        }
    }
}

// MARK: - Empty State

private struct EmptyAlarmsView: View {
    let onCreateTapped: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "alarm")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text("No Alarms")
                    .font(.title2.bold())

                Text("Create your first alarm to get started")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button {
                onCreateTapped()
            } label: {
                HStack {
                    Image(systemName: "plus")
                    Text("Create Alarm")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(Color.orange)
                .clipShape(Capsule())
            }

            Spacer()
        }
    }
}

#Preview {
    AlarmListView()
        .environment(AppState())
        .modelContainer(for: [Alarm.self, User.self, Friend.self])
}
