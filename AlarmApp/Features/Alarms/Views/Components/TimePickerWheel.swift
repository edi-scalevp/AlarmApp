import SwiftUI

/// Custom time picker wheel with large, easy-to-read digits
struct TimePickerWheel: View {
    @Binding var hour: Int
    @Binding var minute: Int

    @State private var is24Hour: Bool = false

    var body: some View {
        HStack(spacing: 0) {
            // Hour picker
            Picker("Hour", selection: $hour) {
                ForEach(hourRange, id: \.self) { h in
                    Text(hourText(h))
                        .font(.system(size: 48, weight: .medium, design: .rounded))
                        .tag(h)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 100)
            .clipped()

            // Separator
            Text(":")
                .font(.system(size: 48, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)

            // Minute picker
            Picker("Minute", selection: $minute) {
                ForEach(0..<60, id: \.self) { m in
                    Text(String(format: "%02d", m))
                        .font(.system(size: 48, weight: .medium, design: .rounded))
                        .tag(m)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 100)
            .clipped()

            // AM/PM picker (for 12-hour format)
            if !is24Hour {
                Picker("Period", selection: Binding(
                    get: { hour >= 12 },
                    set: { isPM in
                        if isPM && hour < 12 {
                            hour += 12
                        } else if !isPM && hour >= 12 {
                            hour -= 12
                        }
                    }
                )) {
                    Text("AM").tag(false)
                    Text("PM").tag(true)
                }
                .pickerStyle(.wheel)
                .frame(width: 60)
                .clipped()
            }
        }
        .onAppear {
            // Check user's locale preference
            is24Hour = Locale.current.hourCycle == .oneToTwelve ? false : true
        }
    }

    private var hourRange: Range<Int> {
        is24Hour ? 0..<24 : 1..<13
    }

    private func hourText(_ h: Int) -> String {
        if is24Hour {
            return String(format: "%02d", h)
        } else {
            let display = h == 0 ? 12 : (h > 12 ? h - 12 : h)
            return String(display)
        }
    }
}

// MARK: - Compact Time Display

struct CompactTimeDisplay: View {
    let hour: Int
    let minute: Int

    var body: some View {
        HStack(spacing: 2) {
            Text(timeString)
                .font(.system(size: 64, weight: .bold, design: .rounded))

            Text(periodString)
                .font(.title2)
                .foregroundStyle(.secondary)
                .padding(.top, 16)
        }
    }

    private var timeString: String {
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return String(format: "%d:%02d", displayHour, minute)
    }

    private var periodString: String {
        hour >= 12 ? "PM" : "AM"
    }
}

// MARK: - Time Until Display

struct TimeUntilDisplay: View {
    let targetDate: Date

    @State private var timeRemaining: TimeInterval = 0
    @State private var timer: Timer?

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock")
                .font(.caption)

            Text("in \(formattedTime)")
                .font(.caption)
        }
        .foregroundStyle(.orange)
        .onAppear {
            updateTimeRemaining()
            startTimer()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }

    private var formattedTime: String {
        let hours = Int(timeRemaining) / 3600
        let minutes = (Int(timeRemaining) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes) min"
        } else {
            return "< 1 min"
        }
    }

    private func updateTimeRemaining() {
        timeRemaining = max(0, targetDate.timeIntervalSinceNow)
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            updateTimeRemaining()
        }
    }
}

#Preview {
    VStack(spacing: 32) {
        TimePickerWheel(hour: .constant(7), minute: .constant(30))

        CompactTimeDisplay(hour: 7, minute: 30)

        TimeUntilDisplay(targetDate: Date().addingTimeInterval(3600 * 8))
    }
}
