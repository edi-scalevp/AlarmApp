import SwiftUI

/// Main settings view
struct SettingsView: View {
    @Environment(AppState.self) private var appState

    @State private var showProfile = false
    @State private var showSignOutConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                // Profile section
                Section {
                    ProfileRow(user: appState.currentUser) {
                        showProfile = true
                    }
                }

                // Preferences section
                Section("Preferences") {
                    NavigationLink {
                        NotificationSettingsView()
                    } label: {
                        SettingsRow(
                            icon: "bell.fill",
                            iconColor: .red,
                            title: "Notifications"
                        )
                    }

                    NavigationLink {
                        SoundSettingsView()
                    } label: {
                        SettingsRow(
                            icon: "speaker.wave.3.fill",
                            iconColor: .blue,
                            title: "Sounds & Haptics"
                        )
                    }

                    NavigationLink {
                        AppearanceSettingsView()
                    } label: {
                        SettingsRow(
                            icon: "paintbrush.fill",
                            iconColor: .purple,
                            title: "Appearance"
                        )
                    }
                }

                // Wake-up stats section
                Section("Statistics") {
                    NavigationLink {
                        WakeUpStatsView()
                    } label: {
                        SettingsRow(
                            icon: "chart.bar.fill",
                            iconColor: .green,
                            title: "Wake-Up Stats"
                        )
                    }
                }

                // Support section
                Section("Support") {
                    Link(destination: URL(string: "https://wakeup.app/help")!) {
                        SettingsRow(
                            icon: "questionmark.circle.fill",
                            iconColor: .orange,
                            title: "Help & FAQ"
                        )
                    }

                    Link(destination: URL(string: "mailto:support@wakeup.app")!) {
                        SettingsRow(
                            icon: "envelope.fill",
                            iconColor: .blue,
                            title: "Contact Support"
                        )
                    }

                    NavigationLink {
                        PrivacyPolicyView()
                    } label: {
                        SettingsRow(
                            icon: "hand.raised.fill",
                            iconColor: .gray,
                            title: "Privacy Policy"
                        )
                    }
                }

                // Account section
                Section {
                    Button(role: .destructive) {
                        showSignOutConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Sign Out")
                        }
                    }
                }

                // App version
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showProfile) {
                ProfileView()
            }
            .confirmationDialog(
                "Sign Out",
                isPresented: $showSignOutConfirmation,
                titleVisibility: .visible
            ) {
                Button("Sign Out", role: .destructive) {
                    signOut()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to sign out?")
            }
        }
    }

    private func signOut() {
        do {
            try appState.authService?.signOut()
            appState.currentUser = nil
            appState.authState = .unauthenticated
        } catch {
            print("Failed to sign out: \(error)")
        }
    }
}

// MARK: - Profile Row

private struct ProfileRow: View {
    let user: User?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Avatar
                if let user {
                    if let imageURL = user.profileImageURL,
                       let url = URL(string: imageURL) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            InitialsAvatar(initials: initials(for: user), size: 56)
                        }
                        .frame(width: 56, height: 56)
                        .clipShape(Circle())
                    } else {
                        InitialsAvatar(initials: initials(for: user), size: 56)
                    }
                } else {
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: 56, height: 56)
                }

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(user?.displayName ?? "User")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(user?.phoneNumber ?? "")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private func initials(for user: User) -> String {
        let components = user.displayName.split(separator: " ")
        if components.count >= 2 {
            return "\(components[0].prefix(1))\(components[1].prefix(1))".uppercased()
        }
        return String(user.displayName.prefix(2)).uppercased()
    }
}

// MARK: - Settings Row

struct SettingsRow: View {
    let icon: String
    let iconColor: Color
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(iconColor)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            Text(title)
                .foregroundStyle(.primary)
        }
    }
}

// MARK: - Notification Settings View

struct NotificationSettingsView: View {
    @State private var criticalAlertsEnabled = true
    @State private var soundEnabled = true
    @State private var badgeEnabled = true

    var body: some View {
        List {
            Section {
                Toggle("Critical Alerts", isOn: $criticalAlertsEnabled)
                Toggle("Sound", isOn: $soundEnabled)
                Toggle("Badge", isOn: $badgeEnabled)
            } footer: {
                Text("Critical alerts allow alarms to bypass Do Not Disturb and Silent Mode.")
            }

            Section("Friend Notifications") {
                Toggle("Friend requests", isOn: .constant(true))
                Toggle("Wake-up help requests", isOn: .constant(true))
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Sound Settings View

struct SoundSettingsView: View {
    @State private var defaultSound = "default"
    @State private var hapticFeedback = true
    @State private var volume: Double = 0.8

    var body: some View {
        List {
            Section("Default Alarm Sound") {
                ForEach(AlarmKitService.availableSounds, id: \.name) { sound in
                    HStack {
                        Text(sound.displayName)
                        Spacer()
                        if defaultSound == sound.name {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.orange)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        defaultSound = sound.name
                    }
                }
            }

            Section {
                Toggle("Haptic Feedback", isOn: $hapticFeedback)
            }

            Section("Volume") {
                Slider(value: $volume, in: 0...1)
            }
        }
        .navigationTitle("Sounds & Haptics")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Appearance Settings View

struct AppearanceSettingsView: View {
    @State private var colorScheme: String = "system"

    var body: some View {
        List {
            Section("Theme") {
                ForEach(["system", "light", "dark"], id: \.self) { scheme in
                    HStack {
                        Text(scheme.capitalized)
                        Spacer()
                        if colorScheme == scheme {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.orange)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        colorScheme = scheme
                    }
                }
            }
        }
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Wake-Up Stats View

struct WakeUpStatsView: View {
    @State private var stats: WakeUpStats?
    @State private var isLoading = true

    var body: some View {
        List {
            if let stats {
                Section {
                    StatRow(title: "Total Alarms", value: "\(stats.totalAlarms)")
                    StatRow(title: "Woke Up On Time", value: "\(stats.dismissedOnTime)")
                    StatRow(title: "Friend Notified", value: "\(stats.escalated)")
                    StatRow(title: "Success Rate", value: String(format: "%.0f%%", stats.successRate))
                }

                Section("Streaks") {
                    StatRow(title: "Current Streak", value: "\(stats.currentStreak) days")
                    StatRow(title: "Best Streak", value: "\(stats.bestStreak) days")
                }
            } else if isLoading {
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
            } else {
                Section {
                    Text("No stats available yet")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Wake-Up Stats")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Load stats
            // In a real app, this would fetch from EscalationService
            stats = WakeUpStats(
                totalAlarms: 45,
                dismissedOnTime: 42,
                escalated: 3,
                currentStreak: 7,
                bestStreak: 21
            )
            isLoading = false
        }
    }
}

private struct StatRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Privacy Policy View

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Privacy Policy")
                    .font(.title.bold())

                Text("Last updated: January 2026")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("""
                WakeUp respects your privacy. Here's how we handle your data:

                **Phone Number**
                Your phone number is used for authentication and to help friends find you. We store a hashed version for contact matching.

                **Contacts**
                We access your contacts only to help you find friends who use WakeUp. Contact data is processed locally and only hashed phone numbers are sent to our servers.

                **Alarm Data**
                Your alarm settings are stored locally on your device and synced to our servers for backup and escalation features.

                **Notifications**
                We send push notifications for alarms and friend alerts. You can control notification settings in the app.

                **Data Retention**
                You can delete your account at any time, which removes all your data from our servers.

                For questions, contact us at privacy@wakeup.app
                """)
                .font(.body)
            }
            .padding()
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    SettingsView()
        .environment(AppState())
}
