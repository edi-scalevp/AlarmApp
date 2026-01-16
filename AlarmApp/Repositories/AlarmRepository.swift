import Foundation
import SwiftData

/// Repository for managing Alarm data (SwiftData + AlarmKit coordination)
@Observable
@MainActor
final class AlarmRepository {

    /// SwiftData model context
    private var modelContext: ModelContext?

    /// AlarmKit service for scheduling
    private let alarmService: AlarmKitService

    /// Escalation service for friend notifications
    private let escalationService: EscalationService

    /// Current user ID
    private var userId: String?

    /// All alarms for current user
    private(set) var alarms: [Alarm] = []

    init(alarmService: AlarmKitService = AlarmKitService(),
         escalationService: EscalationService = EscalationService()) {
        self.alarmService = alarmService
        self.escalationService = escalationService
        setupCallbacks()
    }

    /// Configure with model context and user ID
    func configure(modelContext: ModelContext, userId: String) {
        self.modelContext = modelContext
        self.userId = userId
        loadAlarms()
    }

    private func setupCallbacks() {
        // Handle alarm fired events
        alarmService.onAlarmFired = { [weak self] alarmId in
            await self?.handleAlarmFired(alarmId: alarmId)
        }

        // Handle alarm dismissed events
        alarmService.onAlarmDismissed = { [weak self] alarmId in
            await self?.handleAlarmDismissed(alarmId: alarmId)
        }

        // Handle alarm snoozed events
        alarmService.onAlarmSnoozed = { [weak self] alarmId, snoozeEnd in
            await self?.handleAlarmSnoozed(alarmId: alarmId, snoozeEnd: snoozeEnd)
        }
    }

    // MARK: - CRUD Operations

    /// Load all alarms for current user
    func loadAlarms() {
        guard let modelContext, let userId else { return }

        let descriptor = FetchDescriptor<Alarm>(
            predicate: #Predicate { $0.userId == userId },
            sortBy: [SortDescriptor(\.hour), SortDescriptor(\.minute)]
        )

        do {
            alarms = try modelContext.fetch(descriptor)
        } catch {
            print("Failed to load alarms: \(error)")
            alarms = []
        }
    }

    /// Create a new alarm
    func createAlarm(
        hour: Int,
        minute: Int,
        label: String = "",
        repeatDays: [Int] = [],
        soundName: String = "default",
        snoozeEnabled: Bool = true,
        snoozeDuration: Int = 9,
        escalationEnabled: Bool = false,
        escalationDelayMinutes: Int = 5,
        escalationFriendIds: [String] = [],
        escalationMessage: String? = nil
    ) async throws -> Alarm {
        guard let modelContext, let userId else {
            throw RepositoryError.notConfigured
        }

        let alarm = Alarm(
            userId: userId,
            hour: hour,
            minute: minute,
            label: label,
            isEnabled: true,
            repeatDays: repeatDays,
            soundName: soundName,
            snoozeEnabled: snoozeEnabled,
            snoozeDuration: snoozeDuration,
            escalationEnabled: escalationEnabled,
            escalationDelayMinutes: escalationDelayMinutes,
            escalationFriendIds: escalationFriendIds,
            escalationMessage: escalationMessage
        )

        // Save to SwiftData
        modelContext.insert(alarm)
        try modelContext.save()

        // Schedule with AlarmKit
        let alarmKitId = try await alarmService.scheduleAlarm(alarm)
        alarm.alarmKitId = alarmKitId
        try modelContext.save()

        // Reload alarms list
        loadAlarms()

        return alarm
    }

    /// Update an existing alarm
    func updateAlarm(_ alarm: Alarm) async throws {
        guard let modelContext else {
            throw RepositoryError.notConfigured
        }

        alarm.updatedAt = Date()

        // Cancel existing schedule
        if let alarmKitId = alarm.alarmKitId {
            await alarmService.cancelAlarm(alarmKitId: alarmKitId)
        }

        // Reschedule if enabled
        if alarm.isEnabled {
            let newAlarmKitId = try await alarmService.scheduleAlarm(alarm)
            alarm.alarmKitId = newAlarmKitId
        } else {
            alarm.alarmKitId = nil
        }

        try modelContext.save()
        loadAlarms()
    }

    /// Delete an alarm
    func deleteAlarm(_ alarm: Alarm) async throws {
        guard let modelContext else {
            throw RepositoryError.notConfigured
        }

        // Cancel AlarmKit schedule
        if let alarmKitId = alarm.alarmKitId {
            await alarmService.cancelAlarm(alarmKitId: alarmKitId)
        }

        // Remove from SwiftData
        modelContext.delete(alarm)
        try modelContext.save()

        loadAlarms()
    }

    /// Toggle alarm enabled state
    func toggleAlarm(_ alarm: Alarm) async throws {
        alarm.isEnabled.toggle()
        try await updateAlarm(alarm)
    }

    // MARK: - Alarm Events

    /// Handle alarm fired event
    private func handleAlarmFired(alarmId: String) async {
        guard let alarm = alarms.first(where: { $0.id == alarmId }),
              let userId else { return }

        do {
            // Trigger escalation if enabled
            _ = try await escalationService.alarmTriggered(alarm: alarm, userId: userId)
        } catch {
            print("Failed to trigger escalation: \(error)")
        }
    }

    /// Handle alarm dismissed event
    private func handleAlarmDismissed(alarmId: String) async {
        do {
            // Cancel any pending escalation
            try await escalationService.alarmDismissed(eventId: nil)

            // If one-time alarm, disable it
            if let alarm = alarms.first(where: { $0.id == alarmId }),
               alarm.isOneTime {
                alarm.isEnabled = false
                try await updateAlarm(alarm)
            }
        } catch {
            print("Failed to handle alarm dismissal: \(error)")
        }
    }

    /// Handle alarm snoozed event
    private func handleAlarmSnoozed(alarmId: String, snoozeEnd: Date) async {
        guard let alarm = alarms.first(where: { $0.id == alarmId }) else { return }

        do {
            // Extend escalation timer
            try await escalationService.alarmSnoozed(
                eventId: nil,
                additionalMinutes: alarm.snoozeDuration
            )
        } catch {
            print("Failed to handle alarm snooze: \(error)")
        }
    }

    // MARK: - Queries

    /// Get enabled alarms
    var enabledAlarms: [Alarm] {
        alarms.filter { $0.isEnabled }
    }

    /// Get next alarm to fire
    var nextAlarm: Alarm? {
        enabledAlarms
            .compactMap { alarm -> (Alarm, Date)? in
                guard let nextFire = alarm.nextFireDate else { return nil }
                return (alarm, nextFire)
            }
            .sorted { $0.1 < $1.1 }
            .first?.0
    }

    /// Get alarms that repeat on a specific day
    func alarms(repeatingOn day: Int) -> [Alarm] {
        alarms.filter { $0.repeatDays.contains(day) }
    }
}

// MARK: - Errors

extension AlarmRepository {
    enum RepositoryError: LocalizedError {
        case notConfigured
        case saveFailed
        case notFound

        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return "Repository not configured. Please sign in."
            case .saveFailed:
                return "Failed to save alarm."
            case .notFound:
                return "Alarm not found."
            }
        }
    }
}
