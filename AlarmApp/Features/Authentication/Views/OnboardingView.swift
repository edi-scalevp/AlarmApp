import SwiftUI

/// Onboarding view explaining the app concept and requesting permissions
struct OnboardingView: View {
    @Environment(AppState.self) private var appState

    @State private var currentPage = 0
    @State private var isRequestingPermissions = false

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "alarm.fill",
            iconColor: .orange,
            title: "Bulletproof Alarms",
            description: "Your alarms break through Silent Mode and Do Not Disturb. They WILL wake you up.",
            highlight: "No more excuses"
        ),
        OnboardingPage(
            icon: "person.2.fill",
            iconColor: .blue,
            title: "Social Accountability",
            description: "Add friends as backup. If you don't dismiss your alarm in time, they get notified to help wake you up.",
            highlight: "Real motivation to get up"
        ),
        OnboardingPage(
            icon: "bell.badge.fill",
            iconColor: .green,
            title: "Smart Notifications",
            description: "See your alarm on your Lock Screen and Dynamic Island. Dismiss or snooze with a tap.",
            highlight: "Always visible, easy to control"
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Page content
            TabView(selection: $currentPage) {
                ForEach(pages.indices, id: \.self) { index in
                    OnboardingPageView(page: pages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Page indicator
            HStack(spacing: 8) {
                ForEach(pages.indices, id: \.self) { index in
                    Circle()
                        .fill(currentPage == index ? Color.orange : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .animation(.easeInOut, value: currentPage)
                }
            }
            .padding(.bottom, 32)

            // Action buttons
            VStack(spacing: 16) {
                if currentPage < pages.count - 1 {
                    // Next button
                    Button {
                        withAnimation {
                            currentPage += 1
                        }
                    } label: {
                        Text("Next")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.orange)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    // Skip button
                    Button {
                        currentPage = pages.count - 1
                    } label: {
                        Text("Skip")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    // Get Started button
                    Button {
                        requestPermissionsAndContinue()
                    } label: {
                        HStack {
                            if isRequestingPermissions {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Get Started")
                                Image(systemName: "arrow.right")
                            }
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(isRequestingPermissions)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
    }

    private func requestPermissionsAndContinue() {
        isRequestingPermissions = true

        Task {
            // Request notification permissions
            do {
                _ = try await AlarmKitService.requestPermissions()
            } catch {
                print("Notification permission error: \(error)")
            }

            // Mark onboarding as complete
            appState.hasCompletedOnboarding = true

            // Check if profile setup is needed
            if let user = appState.currentUser, user.displayName.isEmpty {
                appState.authState = .needsProfileSetup
            } else {
                appState.authState = .authenticated
            }

            isRequestingPermissions = false
        }
    }
}

// MARK: - Onboarding Page Model

struct OnboardingPage {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let highlight: String
}

// MARK: - Onboarding Page View

struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(page.iconColor.opacity(0.15))
                    .frame(width: 140, height: 140)

                Image(systemName: page.icon)
                    .font(.system(size: 56))
                    .foregroundStyle(page.iconColor)
            }

            // Text content
            VStack(spacing: 16) {
                Text(page.title)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)

                Text(page.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Text(page.highlight)
                    .font(.subheadline.bold())
                    .foregroundStyle(page.iconColor)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(page.iconColor.opacity(0.1))
                    .clipShape(Capsule())
            }

            Spacer()
            Spacer()
        }
        .padding()
    }
}

// MARK: - Permission Request Views

struct PermissionRequestView: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let isGranted: Bool

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 48, height: 48)

                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    OnboardingView()
        .environment(AppState())
}
