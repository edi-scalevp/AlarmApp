import SwiftUI
import SwiftData

/// Main entry point for the Social Accountability Alarm App
@main
struct AlarmApp: App {
    /// Connect AppDelegate for Firebase and push notification setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    /// App-wide state manager
    @State private var appState = AppState()

    /// SwiftData model container
    var modelContainer: ModelContainer

    init() {
        // Configure SwiftData
        let schema = Schema([
            User.self,
            Alarm.self,
            Friend.self,
            FriendRequest.self
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }

        // Configure appearance
        configureAppearance()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .modelContainer(modelContainer)
        }
    }

    private func configureAppearance() {
        // Configure navigation bar appearance
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithOpaqueBackground()
        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance

        // Configure tab bar appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
    }
}

// MARK: - App State

/// Observable app-wide state
@Observable
final class AppState {
    /// Current authentication state
    var authState: AuthState = .loading

    /// Currently authenticated user
    var currentUser: User?

    /// Whether onboarding has been completed
    var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") }
        set { UserDefaults.standard.set(newValue, forKey: "hasCompletedOnboarding") }
    }

    /// Number of pending friend requests
    var pendingRequestCount: Int = 0

    /// Whether to show friend help alert
    var showFriendHelpAlert: Bool = false
    var friendNeedingHelpId: String?
    var friendNeedingHelpName: String?

    /// Services (initialized lazily)
    var authService: AuthenticationService?
    var alarmService: AlarmKitService?
    var escalationService: EscalationService?

    init() {
        setupNotificationObservers()
    }

    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: .friendNeedsHelp,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let userId = notification.userInfo?["userId"] as? String {
                self?.handleFriendNeedsHelp(userId: userId)
            }
        }
    }

    private func handleFriendNeedsHelp(userId: String) {
        friendNeedingHelpId = userId
        showFriendHelpAlert = true
    }
}

/// Authentication state enum
enum AuthState: Equatable {
    case loading
    case unauthenticated
    case authenticated
    case needsOnboarding
    case needsProfileSetup
}

// MARK: - Root View

/// Root view that handles navigation based on auth state
struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Group {
            switch appState.authState {
            case .loading:
                LoadingView()

            case .unauthenticated:
                PhoneEntryView()

            case .needsOnboarding:
                OnboardingView()

            case .needsProfileSetup:
                ProfileSetupView()

            case .authenticated:
                MainTabView()
            }
        }
        .animation(.easeInOut, value: appState.authState)
        .task {
            await initializeApp()
        }
        .alert("Friend Needs Help!", isPresented: Binding(
            get: { appState.showFriendHelpAlert },
            set: { appState.showFriendHelpAlert = $0 }
        )) {
            Button("Call Them") {
                callFriend()
            }
            Button("Dismiss", role: .cancel) {}
        } message: {
            if let name = appState.friendNeedingHelpName {
                Text("\(name) has been trying to wake up. Give them a call!")
            } else {
                Text("Your friend has been trying to wake up. Give them a call!")
            }
        }
    }

    private func initializeApp() async {
        // Initialize services
        let authService = AuthenticationService()
        appState.authService = authService

        let alarmService = AlarmKitService()
        appState.alarmService = alarmService

        let escalationService = EscalationService()
        appState.escalationService = escalationService

        // Check authentication state
        if let user = await authService.getCurrentUser() {
            appState.currentUser = user

            if !appState.hasCompletedOnboarding {
                appState.authState = .needsOnboarding
            } else if user.displayName.isEmpty {
                appState.authState = .needsProfileSetup
            } else {
                appState.authState = .authenticated
            }
        } else {
            appState.authState = .unauthenticated
        }
    }

    private func callFriend() {
        guard let userId = appState.friendNeedingHelpId else { return }

        // In a real app, we'd look up the friend's phone number and initiate a call
        // For now, we'll just log it
        print("Would call friend with user ID: \(userId)")

        // TODO: Look up friend's phone number from Firestore
        // Then use: UIApplication.shared.open(URL(string: "tel://\(phoneNumber)")!)
    }
}

// MARK: - Loading View

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Loading...")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Main Tab View

struct MainTabView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        TabView {
            AlarmListView()
                .tabItem {
                    Label("Alarms", systemImage: "alarm.fill")
                }

            FriendsListView()
                .tabItem {
                    Label("Friends", systemImage: "person.2.fill")
                }
                .badge(appState.pendingRequestCount)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .tint(.orange)
    }
}
