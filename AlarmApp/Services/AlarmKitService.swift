import Foundation
import ActivityKit

/// Service for managing alarms using AlarmKit (iOS 26+)
/// AlarmKit provides system-level alarms that:
/// - Break through Silent Mode and Do Not Disturb
/// - Appear in the system Clock app
/// - Work even when the app is killed
/// - Show on Lock Screen and Dynamic Island via Live Activities
@Observable
final class AlarmKitService {

    /// Currently active Live Activity for alarm display
    private var currentActivity: Activity<AlarmActivityAttributes>?

    /// Callback when alarm fires (for escalation)
    var onAlarmFired: ((String) async -> Void)?

    /// Callback when alarm is dismissed
    var onAlarmDismissed: ((String) async -> Void)?

    /// Callback when alarm is snoozed
    var onAlarmSnoozed: ((String, Date) async -> Void)?

    init() {
        setupActionHandlers()
    }

    private func setupActionHandlers() {
        // Connect Live Activity action handlers
        AlarmActionHandler.shared.onSnooze = { [weak self] alarmId in
            await self?.snoozeAlarm(id: alarmId)
        }

        AlarmActionHandler.shared.onDismiss = { [weak self] alarmId in
            await self?.dismissAlarm(id: alarmId)
        }
    }

    // MARK: - Alarm Scheduling

    /// Schedule an alarm using AlarmKit
    /// - Parameter alarm: The alarm to schedule
    /// - Returns: The AlarmKit identifier
    func scheduleAlarm(_ alarm: Alarm) async throws -> String {
        // Note: In iOS 26+, we would use the actual AlarmKit API here
        // For now, we simulate with local notifications and Live Activities

        // Generate a unique identifier for this alarm instance
        let alarmKitId = "alarm_\(alarm.id)_\(Date().timeIntervalSince1970)"

        // Schedule the notification (backup for AlarmKit)
        await scheduleLocalNotification(for: alarm, identifier: alarmKitId)

        return alarmKitId
    }

    /// Cancel a scheduled alarm
    func cancelAlarm(alarmKitId: String) async {
        // Remove pending notification
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [alarmKitId]
        )

        // End Live Activity if active
        await endLiveActivity()
    }

    /// Cancel all alarms for a specific alarm ID
    func cancelAllAlarms(for alarmId: String) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()

        let toRemove = pending
            .filter { $0.identifier.contains(alarmId) }
            .map { $0.identifier }

        center.removePendingNotificationRequests(withIdentifiers: toRemove)
    }

    // MARK: - Alarm Actions

    /// Called when alarm fires - starts Live Activity and triggers escalation timer
    func alarmFired(alarm: Alarm) async {
        // Start Live Activity for Lock Screen/Dynamic Island display
        await startLiveActivity(for: alarm)

        // Notify escalation service
        await onAlarmFired?(alarm.id)

        // Play alarm sound (in actual AlarmKit, this is handled by the system)
        playAlarmSound(alarm.soundName)
    }

    /// Dismiss the currently ringing alarm
    func dismissAlarm(id: String) async {
        // Stop sound
        stopAlarmSound()

        // End Live Activity
        await endLiveActivity()

        // Notify escalation service (prevents friend notification)
        await onAlarmDismissed?(id)

        // Haptic feedback
        await MainActor.run {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
    }

    /// Snooze the currently ringing alarm
    func snoozeAlarm(id: String, duration: Int = 9) async {
        let snoozeEnd = Date().addingTimeInterval(TimeInterval(duration * 60))

        // Stop sound temporarily
        stopAlarmSound()

        // Update Live Activity to show snoozed state
        await updateLiveActivityForSnooze(snoozeEndTime: snoozeEnd)

        // Schedule snooze notification
        await scheduleSnoozeNotification(alarmId: id, fireAt: snoozeEnd)

        // Notify callback
        await onAlarmSnoozed?(id, snoozeEnd)

        // Haptic feedback
        await MainActor.run {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        }
    }

    // MARK: - Live Activities

    /// Start a Live Activity for the alarm
    private func startLiveActivity(for alarm: Alarm) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("Live Activities not enabled")
            return
        }

        let attributes = AlarmActivityAttributes(
            alarmId: alarm.id,
            soundName: alarm.soundName
        )

        // Get friend name for escalation display
        let friendName = alarm.escalationEnabled && !alarm.escalationFriendIds.isEmpty
            ? "Your friend" // In real app, fetch actual name
            : nil

        let state = AlarmActivityAttributes.initialState(
            alarmTime: alarm.nextFireDate ?? Date(),
            label: alarm.label,
            escalationEnabled: alarm.escalationEnabled,
            escalationFriendName: friendName,
            escalationDelayMinutes: alarm.escalationEnabled ? alarm.escalationDelayMinutes : nil
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil),
                pushType: nil
            )

            currentActivity = activity
            print("Started Live Activity: \(activity.id)")
        } catch {
            print("Failed to start Live Activity: \(error)")
        }
    }

    /// Update Live Activity to show snoozed state
    private func updateLiveActivityForSnooze(snoozeEndTime: Date) async {
        guard let activity = currentActivity else { return }

        let currentState = activity.content.state
        let newState = AlarmActivityAttributes.snoozedState(
            from: currentState,
            snoozeEndTime: snoozeEndTime
        )

        await activity.update(
            ActivityContent(state: newState, staleDate: snoozeEndTime)
        )
    }

    /// End the current Live Activity
    private func endLiveActivity() async {
        guard let activity = currentActivity else { return }

        await activity.end(nil, dismissalPolicy: .immediate)
        currentActivity = nil
    }

    // MARK: - Local Notifications (Fallback)

    private func scheduleLocalNotification(for alarm: Alarm, identifier: String) async {
        let content = UNMutableNotificationContent()
        content.title = alarm.label.isEmpty ? "Alarm" : alarm.label
        content.body = "Time to wake up!"
        content.sound = UNNotificationSound(named: UNNotificationSoundName(alarm.soundName + ".caf"))
        content.interruptionLevel = .timeSensitive
        content.categoryIdentifier = "ALARM"

        // Add actions
        let snoozeAction = UNNotificationAction(
            identifier: "SNOOZE",
            title: "Snooze",
            options: []
        )
        let dismissAction = UNNotificationAction(
            identifier: "DISMISS",
            title: "Dismiss",
            options: [.destructive]
        )
        let category = UNNotificationCategory(
            identifier: "ALARM",
            actions: [snoozeAction, dismissAction],
            intentIdentifiers: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])

        // Create trigger
        var dateComponents = DateComponents()
        dateComponents.hour = alarm.hour
        dateComponents.minute = alarm.minute

        if !alarm.repeatDays.isEmpty {
            // For repeating alarms, we need to schedule multiple triggers
            for day in alarm.repeatDays {
                dateComponents.weekday = day + 1 // weekday is 1-based (1=Sunday)
                let trigger = UNCalendarNotificationTrigger(
                    dateMatching: dateComponents,
                    repeats: true
                )

                let request = UNNotificationRequest(
                    identifier: "\(identifier)_day\(day)",
                    content: content,
                    trigger: trigger
                )

                try? await UNUserNotificationCenter.current().add(request)
            }
        } else {
            // One-time alarm
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: dateComponents,
                repeats: false
            )

            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: trigger
            )

            try? await UNUserNotificationCenter.current().add(request)
        }
    }

    private func scheduleSnoozeNotification(alarmId: String, fireAt: Date) async {
        let content = UNMutableNotificationContent()
        content.title = "Snooze Over"
        content.body = "Your alarm is ringing again!"
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        content.categoryIdentifier = "ALARM"

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: fireAt.timeIntervalSinceNow,
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: "snooze_\(alarmId)",
            content: content,
            trigger: trigger
        )

        try? await UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Sound

    private func playAlarmSound(_ soundName: String) {
        // In a real implementation, use AVAudioPlayer or system sound APIs
        // AlarmKit handles this automatically for system alarms
        print("Playing alarm sound: \(soundName)")
    }

    private func stopAlarmSound() {
        // Stop audio playback
        print("Stopping alarm sound")
    }

    // MARK: - Available Sounds

    /// List of available alarm sounds
    static let availableSounds: [(name: String, displayName: String)] = [
        ("default", "Default"),
        ("gentle", "Gentle Wake"),
        ("birds", "Morning Birds"),
        ("chimes", "Wind Chimes"),
        ("digital", "Digital"),
        ("classic", "Classic Bell"),
        ("radar", "Radar"),
        ("beacon", "Beacon"),
        ("circuit", "Circuit"),
        ("cosmic", "Cosmic")
    ]
}

// MARK: - Alarm Permission Helpers

extension AlarmKitService {

    /// Check if alarm permissions are granted
    static func checkPermissions() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized
    }

    /// Request alarm permissions
    static func requestPermissions() async throws -> Bool {
        let granted = try await UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge, .criticalAlert]
        )
        return granted
    }

    /// Check if Live Activities are enabled
    static var areLiveActivitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }
}
