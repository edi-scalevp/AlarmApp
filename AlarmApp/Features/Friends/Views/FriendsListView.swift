import SwiftUI
import SwiftData

/// Main friends list view showing connected friends and pending requests
struct FriendsListView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var friendRepository: FriendRepository?
    @State private var showAddFriend = false
    @State private var showRequests = false

    var body: some View {
        NavigationStack {
            Group {
                if let repository = friendRepository {
                    FriendsListContent(
                        repository: repository,
                        onShowRequests: { showRequests = true }
                    )
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Friends")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if let repo = friendRepository, !repo.pendingRequests.isEmpty {
                        Button {
                            showRequests = true
                        } label: {
                            Image(systemName: "bell.badge.fill")
                                .foregroundStyle(.orange)
                        }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddFriend = true
                    } label: {
                        Image(systemName: "person.badge.plus")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showAddFriend) {
                if let repository = friendRepository {
                    AddFriendView(repository: repository)
                }
            }
            .sheet(isPresented: $showRequests) {
                if let repository = friendRepository {
                    FriendRequestsView(repository: repository)
                }
            }
        }
        .task {
            setupRepository()
        }
    }

    private func setupRepository() {
        guard let userId = appState.currentUser?.id else { return }

        let repository = FriendRepository()
        repository.configure(modelContext: modelContext, userId: userId)
        friendRepository = repository

        // Update pending request count in app state
        Task {
            await repository.loadPendingRequests()
            appState.pendingRequestCount = repository.pendingRequests.count
        }
    }
}

// MARK: - Friends List Content

private struct FriendsListContent: View {
    @Bindable var repository: FriendRepository
    let onShowRequests: () -> Void

    var body: some View {
        List {
            // Pending requests banner
            if !repository.pendingRequests.isEmpty {
                Section {
                    PendingRequestsBanner(
                        count: repository.pendingRequests.count,
                        onTap: onShowRequests
                    )
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            // Friends list
            if repository.friends.isEmpty {
                Section {
                    EmptyFriendsView()
                }
                .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(repository.friends) { friend in
                        FriendRow(friend: friend)
                    }
                    .onDelete { indexSet in
                        deleteFriends(at: indexSet)
                    }
                } header: {
                    Text("Your Friends (\(repository.friends.count))")
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await repository.loadFriends()
            await repository.loadPendingRequests()
        }
    }

    private func deleteFriends(at offsets: IndexSet) {
        Task {
            for index in offsets {
                let friend = repository.friends[index]
                try? await repository.removeFriend(friend)
            }
        }
    }
}

// MARK: - Pending Requests Banner

private struct PendingRequestsBanner: View {
    let count: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 40, height: 40)

                    Image(systemName: "person.badge.clock")
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(count) Pending Request\(count == 1 ? "" : "s")")
                        .font(.headline)

                    Text("Tap to review")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

// MARK: - Friend Row

private struct FriendRow: View {
    let friend: Friend

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            FriendAvatar(friend: friend, size: 48)

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(friend.bestDisplayName)
                    .font(.body)

                if let subtitle = friend.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Stats
            if friend.notificationCount > 0 {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(friend.notificationCount)")
                        .font(.headline)
                        .foregroundStyle(.orange)

                    Text("wake-ups")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Friend Avatar

struct FriendAvatar: View {
    let friend: Friend
    let size: CGFloat

    var body: some View {
        if let imageURL = friend.profileImageURL,
           let url = URL(string: imageURL) {
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                InitialsAvatar(initials: friend.initials, size: size)
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
        } else {
            InitialsAvatar(initials: friend.initials, size: size)
        }
    }
}

struct InitialsAvatar: View {
    let initials: String
    let size: CGFloat

    var body: some View {
        Circle()
            .fill(Color.orange.opacity(0.2))
            .frame(width: size, height: size)
            .overlay {
                Text(initials)
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundStyle(.orange)
            }
    }
}

// MARK: - Empty State

private struct EmptyFriendsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Friends Yet")
                .font(.headline)

            Text("Add friends to enable social accountability for your alarms")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    FriendsListView()
        .environment(AppState())
        .modelContainer(for: [Friend.self, FriendRequest.self])
}
