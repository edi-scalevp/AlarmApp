import Foundation
import FirebaseFunctions

/// Service for managing alarm escalations (friend notifications)
@Observable
final class EscalationService {

    /// Firebase Cloud Functions reference
    private lazy var functions = Functions.functions()

    /// Firestore service for database operations
    private let firestoreService = FirestoreService()

    /// Currently active escalation event ID
    private(set) var activeEscalationId: String?

    /// Timer for local escalation countdown (backup)
    private var escalationTimer: Timer?

    // MARK: - Alarm Lifecycle

    /// Called when an alarm fires - creates escalation event if enabled
    func alarmTriggered(alarm: Alarm, userId: String) async throws -> String? {
        guard alarm.escalationEnabled, !alarm.escalationFriendIds.isEmpty else {
            return nil
        }

        // Call Cloud Function to create escalation event
        let result = try await callFunction("onAlarmTriggered", data: [
            "alarmId": alarm.id,
            "triggerTime": ISO8601DateFormatter().string(from: Date()),
            "escalationDelayMinutes": alarm.escalationDelayMinutes,
            "friendIds": alarm.escalationFriendIds,
            "message": alarm.escalationMessage ?? ""
        ])

        guard let eventId = result["eventId"] as? String else {
            throw EscalationError.invalidResponse
        }

        activeEscalationId = eventId

        // Start local backup timer (in case device loses connection)
        startLocalEscalationTimer(
            eventId: eventId,
            delayMinutes: alarm.escalationDelayMinutes
        )

        return eventId
    }

    /// Called when alarm is dismissed - cancels escalation
    func alarmDismissed(eventId: String?) async throws {
        guard let eventId = eventId ?? activeEscalationId else { return }

        // Stop local timer
        stopLocalEscalationTimer()

        // Call Cloud Function to mark as dismissed
        _ = try await callFunction("onAlarmDismissed", data: [
            "eventId": eventId
        ])

        activeEscalationId = nil
    }

    /// Called when alarm is snoozed - extends escalation timer
    func alarmSnoozed(eventId: String?, additionalMinutes: Int) async throws {
        guard let eventId = eventId ?? activeEscalationId else { return }

        // Update escalation time in backend
        _ = try await callFunction("onAlarmSnoozed", data: [
            "eventId": eventId,
            "additionalMinutes": additionalMinutes
        ])

        // Restart local timer with new delay
        stopLocalEscalationTimer()
        startLocalEscalationTimer(eventId: eventId, delayMinutes: additionalMinutes)
    }

    // MARK: - Cloud Functions

    private func callFunction(_ name: String, data: [String: Any]) async throws -> [String: Any] {
        let result = try await functions.httpsCallable(name).call(data)

        guard let response = result.data as? [String: Any] else {
            throw EscalationError.invalidResponse
        }

        if let error = response["error"] as? String {
            throw EscalationError.serverError(error)
        }

        return response
    }

    // MARK: - Local Backup Timer

    /// Starts a local timer as backup for server-side escalation
    /// This ensures escalation happens even if device loses connection
    private func startLocalEscalationTimer(eventId: String, delayMinutes: Int) {
        let delay = TimeInterval(delayMinutes * 60)

        escalationTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task {
                await self?.handleLocalEscalationTimeout(eventId: eventId)
            }
        }
    }

    private func stopLocalEscalationTimer() {
        escalationTimer?.invalidate()
        escalationTimer = nil
    }

    /// Handle local escalation timeout (backup mechanism)
    private func handleLocalEscalationTimeout(eventId: String) async {
        // Check if escalation is still pending
        guard let escalation = try? await firestoreService.fetchActiveEscalation(alarmId: eventId),
              escalation.status == .pending else {
            return
        }

        // Trigger local notification to prompt user
        await sendLocalEscalationWarning()
    }

    /// Send local notification warning that friends will be notified
    private func sendLocalEscalationWarning() async {
        let content = UNMutableNotificationContent()
        content.title = "Still trying to wake up?"
        content.body = "Your friend will be notified soon. Dismiss your alarm to cancel."
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let request = UNNotificationRequest(
            identifier: "escalation_warning",
            content: content,
            trigger: nil  // Immediate
        )

        try? await UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Friend Notifications

    /// Get escalation history for the current user
    func getEscalationHistory(userId: String, limit: Int = 20) async throws -> [EscalationHistoryItem] {
        let result = try await callFunction("getEscalationHistory", data: [
            "userId": userId,
            "limit": limit
        ])

        guard let items = result["history"] as? [[String: Any]] else {
            return []
        }

        return items.compactMap { EscalationHistoryItem(from: $0) }
    }

    /// Check if user can be notified (respect rate limits)
    func canNotifyFriend(friendId: String) async throws -> Bool {
        let result = try await callFunction("canNotifyFriend", data: [
            "friendId": friendId
        ])

        return result["canNotify"] as? Bool ?? false
    }
}

// MARK: - Errors

extension EscalationService {
    enum EscalationError: LocalizedError {
        case invalidResponse
        case serverError(String)
        case notEnabled
        case rateLimited

        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return "Invalid response from server."
            case .serverError(let message):
                return message
            case .notEnabled:
                return "Escalation is not enabled for this alarm."
            case .rateLimited:
                return "Please wait before sending another notification."
            }
        }
    }
}

// MARK: - History Item

/// Represents a past escalation event for history display
struct EscalationHistoryItem: Identifiable {
    let id: String
    let alarmLabel: String
    let triggerTime: Date
    let status: EscalationEvent.Status
    let friendName: String?
    let wasEscalated: Bool

    init?(from data: [String: Any]) {
        guard let id = data["id"] as? String,
              let triggerTimeString = data["triggerTime"] as? String,
              let triggerTime = ISO8601DateFormatter().date(from: triggerTimeString),
              let statusString = data["status"] as? String,
              let status = EscalationEvent.Status(rawValue: statusString) else {
            return nil
        }

        self.id = id
        self.alarmLabel = data["alarmLabel"] as? String ?? "Alarm"
        self.triggerTime = triggerTime
        self.status = status
        self.friendName = data["friendName"] as? String
        self.wasEscalated = status == .escalated
    }

    var statusDescription: String {
        switch status {
        case .pending:
            return "In progress"
        case .dismissed:
            return "Woke up in time"
        case .escalated:
            return "Friend notified"
        case .expired:
            return "Expired"
        }
    }
}

// MARK: - Statistics

extension EscalationService {
    /// Get wake-up statistics
    func getWakeUpStats(userId: String) async throws -> WakeUpStats {
        let result = try await callFunction("getWakeUpStats", data: [
            "userId": userId
        ])

        return WakeUpStats(
            totalAlarms: result["totalAlarms"] as? Int ?? 0,
            dismissedOnTime: result["dismissedOnTime"] as? Int ?? 0,
            escalated: result["escalated"] as? Int ?? 0,
            currentStreak: result["currentStreak"] as? Int ?? 0,
            bestStreak: result["bestStreak"] as? Int ?? 0
        )
    }
}

/// Wake-up statistics
struct WakeUpStats {
    let totalAlarms: Int
    let dismissedOnTime: Int
    let escalated: Int
    let currentStreak: Int
    let bestStreak: Int

    var successRate: Double {
        guard totalAlarms > 0 else { return 0 }
        return Double(dismissedOnTime) / Double(totalAlarms) * 100
    }
}
