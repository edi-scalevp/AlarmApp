import SwiftUI

/// View showing pending friend requests that can be accepted or declined
struct FriendRequestsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @Bindable var repository: FriendRepository

    @State private var processingRequestIds: Set<String> = []

    var body: some View {
        NavigationStack {
            Group {
                if repository.pendingRequests.isEmpty {
                    EmptyRequestsView()
                } else {
                    RequestsList(
                        requests: repository.pendingRequests,
                        processingIds: processingRequestIds,
                        onAccept: acceptRequest,
                        onDecline: declineRequest
                    )
                }
            }
            .navigationTitle("Friend Requests")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func acceptRequest(_ request: FriendRequest) {
        processingRequestIds.insert(request.id)

        Task {
            do {
                try await repository.acceptRequest(request)
                // Update app state badge count
                appState.pendingRequestCount = repository.pendingRequests.count
            } catch {
                print("Failed to accept request: \(error)")
            }
            processingRequestIds.remove(request.id)
        }
    }

    private func declineRequest(_ request: FriendRequest) {
        processingRequestIds.insert(request.id)

        Task {
            do {
                try await repository.declineRequest(request)
                // Update app state badge count
                appState.pendingRequestCount = repository.pendingRequests.count
            } catch {
                print("Failed to decline request: \(error)")
            }
            processingRequestIds.remove(request.id)
        }
    }
}

// MARK: - Requests List

private struct RequestsList: View {
    let requests: [FriendRequest]
    let processingIds: Set<String>
    let onAccept: (FriendRequest) -> Void
    let onDecline: (FriendRequest) -> Void

    var body: some View {
        List {
            ForEach(requests) { request in
                RequestRow(
                    request: request,
                    isProcessing: processingIds.contains(request.id),
                    onAccept: { onAccept(request) },
                    onDecline: { onDecline(request) }
                )
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Request Row

private struct RequestRow: View {
    let request: FriendRequest
    let isProcessing: Bool
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                // Avatar
                RequestAvatar(request: request)

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(request.fromDisplayName)
                        .font(.headline)

                    Text(request.timeSinceCreated)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            // Message if present
            if let message = request.message, !message.isEmpty {
                Text("\"\(message)\"")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .italic()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Action buttons
            if isProcessing {
                ProgressView()
                    .frame(height: 44)
            } else {
                HStack(spacing: 12) {
                    Button(action: onDecline) {
                        Text("Decline")
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(.systemGray5))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)

                    Button(action: onAccept) {
                        Text("Accept")
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.orange)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Request Avatar

private struct RequestAvatar: View {
    let request: FriendRequest

    var body: some View {
        if let imageURL = request.fromProfileImageURL,
           let url = URL(string: imageURL) {
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                InitialsAvatar(initials: request.initials, size: 56)
            }
            .frame(width: 56, height: 56)
            .clipShape(Circle())
        } else {
            InitialsAvatar(initials: request.initials, size: 56)
        }
    }
}

// MARK: - Empty State

private struct EmptyRequestsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Pending Requests")
                .font(.headline)

            Text("Friend requests you receive will appear here")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding()
    }
}

#Preview {
    FriendRequestsView(repository: FriendRepository())
        .environment(AppState())
}
