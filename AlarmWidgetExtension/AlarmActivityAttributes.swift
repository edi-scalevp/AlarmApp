import ActivityKit
import Foundation

/// Defines the data model for the alarm Live Activity
/// Used by AlarmKit to display alarm UI on Lock Screen and Dynamic Island
struct AlarmActivityAttributes: ActivityAttributes {

    /// Static content that doesn't change during the activity
    public struct ContentState: Codable, Hashable {
        var alarmTime: Date
        var label: String
        var isSnoozed: Bool
        var snoozeEndTime: Date?
        var escalationEnabled: Bool
        var escalationFriendName: String?
        var minutesUntilEscalation: Int?
    }

    // Fixed attributes set when activity starts
    var alarmId: String
    var soundName: String
}

/// Extension for creating Live Activity content
extension AlarmActivityAttributes {

    /// Creates initial content state for an alarm
    static func initialState(
        alarmTime: Date,
        label: String,
        escalationEnabled: Bool,
        escalationFriendName: String?,
        escalationDelayMinutes: Int?
    ) -> ContentState {
        ContentState(
            alarmTime: alarmTime,
            label: label,
            isSnoozed: false,
            snoozeEndTime: nil,
            escalationEnabled: escalationEnabled,
            escalationFriendName: escalationFriendName,
            minutesUntilEscalation: escalationDelayMinutes
        )
    }

    /// Creates snoozed content state
    static func snoozedState(
        from state: ContentState,
        snoozeEndTime: Date
    ) -> ContentState {
        var newState = state
        newState.isSnoozed = true
        newState.snoozeEndTime = snoozeEndTime
        return newState
    }
}
