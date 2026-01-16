import Foundation
import SwiftData

/// Represents an alarm with optional social accountability escalation
@Model
final class Alarm {
    /// Unique identifier
    @Attribute(.unique) var id: String

    /// User who owns this alarm
    var userId: String

    /// Hour component (0-23)
    var hour: Int

    /// Minute component (0-59)
    var minute: Int

    /// Optional label for the alarm
    var label: String

    /// Whether the alarm is currently active
    var isEnabled: Bool

    /// Days to repeat: 0=Sunday, 1=Monday, ..., 6=Saturday
    /// Empty array means one-time alarm
    var repeatDays: [Int]

    /// Name of the alarm sound
    var soundName: String

    /// Whether snooze is enabled
    var snoozeEnabled: Bool

    /// Snooze duration in minutes
    var snoozeDuration: Int

    // MARK: - Escalation (Social Accountability)

    /// Whether to alert a friend if not dismissed in time
    var escalationEnabled: Bool

    /// Minutes to wait before alerting friend (2, 5, 10, 15)
    var escalationDelayMinutes: Int

    /// Friend IDs to notify if escalation triggers
    var escalationFriendIds: [String]

    /// Custom message sent to friends
    var escalationMessage: String?

    // MARK: - Metadata

    /// When alarm was created
    var createdAt: Date

    /// When alarm was last modified
    var updatedAt: Date

    /// AlarmKit identifier (set after scheduling)
    var alarmKitId: String?

    init(
        id: String = UUID().uuidString,
        userId: String,
        hour: Int,
        minute: Int,
        label: String = "",
        isEnabled: Bool = true,
        repeatDays: [Int] = [],
        soundName: String = "default",
        snoozeEnabled: Bool = true,
        snoozeDuration: Int = 9,
        escalationEnabled: Bool = false,
        escalationDelayMinutes: Int = 5,
        escalationFriendIds: [String] = [],
        escalationMessage: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        alarmKitId: String? = nil
    ) {
        self.id = id
        self.userId = userId
        self.hour = hour
        self.minute = minute
        self.label = label
        self.isEnabled = isEnabled
        self.repeatDays = repeatDays
        self.soundName = soundName
        self.snoozeEnabled = snoozeEnabled
        self.snoozeDuration = snoozeDuration
        self.escalationEnabled = escalationEnabled
        self.escalationDelayMinutes = escalationDelayMinutes
        self.escalationFriendIds = escalationFriendIds
        self.escalationMessage = escalationMessage
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.alarmKitId = alarmKitId
    }
}

// MARK: - Computed Properties

extension Alarm {
    /// Formatted time string (e.g., "7:30 AM")
    var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"

        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        let calendar = Calendar.current
        guard let date = calendar.date(from: components) else {
            return "\(hour):\(String(format: "%02d", minute))"
        }

        return formatter.string(from: date)
    }

    /// Whether this is a one-time alarm (no repeat days)
    var isOneTime: Bool {
        repeatDays.isEmpty
    }

    /// Human-readable repeat schedule
    var repeatDescription: String {
        if repeatDays.isEmpty {
            return "One time"
        }

        if repeatDays.count == 7 {
            return "Every day"
        }

        let weekdays = [1, 2, 3, 4, 5]
        let weekends = [0, 6]

        if Set(repeatDays) == Set(weekdays) {
            return "Weekdays"
        }

        if Set(repeatDays) == Set(weekends) {
            return "Weekends"
        }

        let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let sortedDays = repeatDays.sorted()
        return sortedDays.map { dayNames[$0] }.joined(separator: ", ")
    }

    /// Next scheduled fire date
    var nextFireDate: Date? {
        let calendar = Calendar.current
        let now = Date()

        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        components.second = 0

        if repeatDays.isEmpty {
            // One-time alarm: find next occurrence of this time
            guard var date = calendar.nextDate(
                after: now,
                matching: components,
                matchingPolicy: .nextTime
            ) else {
                return nil
            }

            // If the time already passed today, schedule for tomorrow
            if date <= now {
                date = calendar.date(byAdding: .day, value: 1, to: date) ?? date
            }

            return date
        } else {
            // Repeating alarm: find next matching day
            var nextDates: [Date] = []

            for dayOffset in 0..<8 {
                guard let checkDate = calendar.date(byAdding: .day, value: dayOffset, to: now) else {
                    continue
                }

                let weekday = calendar.component(.weekday, from: checkDate) - 1 // 0-based
                if repeatDays.contains(weekday) {
                    var dateComponents = calendar.dateComponents([.year, .month, .day], from: checkDate)
                    dateComponents.hour = hour
                    dateComponents.minute = minute
                    dateComponents.second = 0

                    if let alarmDate = calendar.date(from: dateComponents), alarmDate > now {
                        nextDates.append(alarmDate)
                    }
                }
            }

            return nextDates.min()
        }
    }

    /// Time until next fire date
    var timeUntilNextFire: TimeInterval? {
        guard let next = nextFireDate else { return nil }
        return next.timeIntervalSince(Date())
    }
}

// MARK: - Repeat Day Helpers

extension Alarm {
    /// Day of week enum for cleaner code
    enum DayOfWeek: Int, CaseIterable {
        case sunday = 0
        case monday = 1
        case tuesday = 2
        case wednesday = 3
        case thursday = 4
        case friday = 5
        case saturday = 6

        var shortName: String {
            switch self {
            case .sunday: return "Sun"
            case .monday: return "Mon"
            case .tuesday: return "Tue"
            case .wednesday: return "Wed"
            case .thursday: return "Thu"
            case .friday: return "Fri"
            case .saturday: return "Sat"
            }
        }

        var initial: String {
            switch self {
            case .sunday: return "S"
            case .monday: return "M"
            case .tuesday: return "T"
            case .wednesday: return "W"
            case .thursday: return "T"
            case .friday: return "F"
            case .saturday: return "S"
            }
        }
    }

    func repeatsOn(_ day: DayOfWeek) -> Bool {
        repeatDays.contains(day.rawValue)
    }

    mutating func toggleRepeat(for day: DayOfWeek) {
        if let index = repeatDays.firstIndex(of: day.rawValue) {
            repeatDays.remove(at: index)
        } else {
            repeatDays.append(day.rawValue)
            repeatDays.sort()
        }
        updatedAt = Date()
    }
}

// MARK: - Escalation Delay Options

extension Alarm {
    /// Available escalation delay options in minutes
    static let escalationDelayOptions = [2, 5, 10, 15]

    /// Human-readable escalation delay
    var escalationDelayDescription: String {
        "\(escalationDelayMinutes) minutes"
    }
}
