import ActivityKit
import SwiftUI
import WidgetKit

/// Live Activity widget for displaying alarm on Lock Screen and Dynamic Island
struct AlarmLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmActivityAttributes.self) { context in
            // Lock Screen / Banner UI
            LockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    ExpandedLeadingView(context: context)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ExpandedTrailingView(context: context)
                }
                DynamicIslandExpandedRegion(.center) {
                    ExpandedCenterView(context: context)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedBottomView(context: context)
                }
            } compactLeading: {
                CompactLeadingView(context: context)
            } compactTrailing: {
                CompactTrailingView(context: context)
            } minimal: {
                MinimalView(context: context)
            }
        }
    }
}

// MARK: - Lock Screen View

private struct LockScreenView: View {
    let context: ActivityViewContext<AlarmActivityAttributes>

    var body: some View {
        VStack(spacing: 16) {
            // Alarm info
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(context.state.label.isEmpty ? "Alarm" : context.state.label)
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    Text(timeString)
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                }

                Spacer()

                if context.state.isSnoozed, let snoozeEnd = context.state.snoozeEndTime {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Snoozed until")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(snoozeEnd, style: .time)
                            .font(.title2.bold())
                            .foregroundStyle(.orange)
                    }
                }
            }

            // Escalation warning
            if context.state.escalationEnabled,
               let friendName = context.state.escalationFriendName,
               let minutes = context.state.minutesUntilEscalation {
                HStack(spacing: 8) {
                    Image(systemName: "person.wave.2.fill")
                        .foregroundStyle(.orange)
                    Text("\(friendName) will be notified in \(minutes) min if not dismissed")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.orange.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            // Action buttons
            HStack(spacing: 16) {
                // Snooze button
                Button(intent: SnoozeAlarmIntent(alarmId: context.attributes.alarmId)) {
                    HStack {
                        Image(systemName: "zzz")
                        Text("Snooze")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)

                // Dismiss button
                Button(intent: DismissAlarmIntent(alarmId: context.attributes.alarmId)) {
                    HStack {
                        Image(systemName: "xmark")
                        Text("Dismiss")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.orange)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .background(.background)
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm"
        return formatter.string(from: context.state.alarmTime)
    }
}

// MARK: - Dynamic Island Views

private struct CompactLeadingView: View {
    let context: ActivityViewContext<AlarmActivityAttributes>

    var body: some View {
        Image(systemName: context.state.isSnoozed ? "zzz" : "alarm.fill")
            .foregroundStyle(.orange)
    }
}

private struct CompactTrailingView: View {
    let context: ActivityViewContext<AlarmActivityAttributes>

    var body: some View {
        Text(context.state.alarmTime, style: .time)
            .font(.caption.bold())
            .foregroundStyle(.orange)
    }
}

private struct MinimalView: View {
    let context: ActivityViewContext<AlarmActivityAttributes>

    var body: some View {
        Image(systemName: "alarm.fill")
            .foregroundStyle(.orange)
    }
}

private struct ExpandedLeadingView: View {
    let context: ActivityViewContext<AlarmActivityAttributes>

    var body: some View {
        VStack(alignment: .leading) {
            Image(systemName: "alarm.fill")
                .font(.title2)
                .foregroundStyle(.orange)
        }
    }
}

private struct ExpandedTrailingView: View {
    let context: ActivityViewContext<AlarmActivityAttributes>

    var body: some View {
        if context.state.escalationEnabled {
            Image(systemName: "person.wave.2.fill")
                .font(.title2)
                .foregroundStyle(.orange.opacity(0.7))
        }
    }
}

private struct ExpandedCenterView: View {
    let context: ActivityViewContext<AlarmActivityAttributes>

    var body: some View {
        VStack(spacing: 2) {
            Text(context.state.label.isEmpty ? "Alarm" : context.state.label)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(context.state.alarmTime, style: .time)
                .font(.title.bold())
                .foregroundStyle(.primary)

            if context.state.isSnoozed {
                Text("Snoozed")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
    }
}

private struct ExpandedBottomView: View {
    let context: ActivityViewContext<AlarmActivityAttributes>

    var body: some View {
        HStack(spacing: 12) {
            Button(intent: SnoozeAlarmIntent(alarmId: context.attributes.alarmId)) {
                HStack {
                    Image(systemName: "zzz")
                    Text("Snooze")
                }
                .font(.subheadline.bold())
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Button(intent: DismissAlarmIntent(alarmId: context.attributes.alarmId)) {
                HStack {
                    Image(systemName: "xmark")
                    Text("Dismiss")
                }
                .font(.subheadline.bold())
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(.orange)
                .foregroundStyle(.white)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - App Intents for Actions

import AppIntents

struct SnoozeAlarmIntent: AppIntent {
    static var title: LocalizedStringResource = "Snooze Alarm"
    static var description = IntentDescription("Snooze the currently ringing alarm")

    @Parameter(title: "Alarm ID")
    var alarmId: String

    init() {
        self.alarmId = ""
    }

    init(alarmId: String) {
        self.alarmId = alarmId
    }

    func perform() async throws -> some IntentResult {
        await AlarmActionHandler.shared.snoozeAlarm(id: alarmId)
        return .result()
    }
}

struct DismissAlarmIntent: AppIntent {
    static var title: LocalizedStringResource = "Dismiss Alarm"
    static var description = IntentDescription("Dismiss the currently ringing alarm")

    @Parameter(title: "Alarm ID")
    var alarmId: String

    init() {
        self.alarmId = ""
    }

    init(alarmId: String) {
        self.alarmId = alarmId
    }

    func perform() async throws -> some IntentResult {
        await AlarmActionHandler.shared.dismissAlarm(id: alarmId)
        return .result()
    }
}

/// Shared handler for alarm actions from Live Activity
@MainActor
final class AlarmActionHandler {
    static let shared = AlarmActionHandler()
    private init() {}

    var onSnooze: ((String) async -> Void)?
    var onDismiss: ((String) async -> Void)?

    func snoozeAlarm(id: String) async {
        await onSnooze?(id)
    }

    func dismissAlarm(id: String) async {
        await onDismiss?(id)
    }
}

// MARK: - Widget Bundle

@main
struct AlarmWidgetBundle: WidgetBundle {
    var body: some Widget {
        AlarmLiveActivity()
    }
}
