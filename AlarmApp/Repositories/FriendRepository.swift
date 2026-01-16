import Foundation
import SwiftData
import FirebaseFirestore

/// Repository for managing friends and friend requests
@Observable
@MainActor
final class FriendRepository {

    /// SwiftData model context
    private var modelContext: ModelContext?

    /// Firestore service
    private let firestoreService = FirestoreService()

    /// Contacts service
    private let contactsService = ContactsService()

    /// Current user ID
    private var userId: String?

    /// All friends for current user
    private(set) var friends: [Friend] = []

    /// Pending incoming friend requests
    private(set) var pendingRequests: [FriendRequest] = []

    /// Contacts matched to registered users
    private(set) var matchedContacts: [ContactMatchResult] = []

    /// Firestore listener for friend requests
    private var requestsListener: ListenerRegistration?

    init() {}

    /// Configure with model context and user ID
    func configure(modelContext: ModelContext, userId: String) {
        self.modelContext = modelContext
        self.userId = userId

        // Start listening for friend requests
        startListeningForRequests()

        // Load initial data
        Task {
            await loadFriends()
            await loadPendingRequests()
        }
    }

    deinit {
        requestsListener?.remove()
    }

    // MARK: - Friends

    /// Load friends from Firestore and sync to local storage
    func loadFriends() async {
        guard let userId else { return }

        do {
            let firestoreFriends = try await firestoreService.fetchFriends(userId: userId)
            friends = firestoreFriends

            // Sync to local storage
            syncFriendsToLocal(firestoreFriends)
        } catch {
            print("Failed to load friends: \(error)")

            // Fall back to local storage
            loadFriendsFromLocal()
        }
    }

    private func syncFriendsToLocal(_ friends: [Friend]) {
        guard let modelContext else { return }

        // Clear existing local friends
        let descriptor = FetchDescriptor<Friend>()
        if let existing = try? modelContext.fetch(descriptor) {
            for friend in existing {
                modelContext.delete(friend)
            }
        }

        // Insert new friends
        for friend in friends {
            modelContext.insert(friend)
        }

        try? modelContext.save()
    }

    private func loadFriendsFromLocal() {
        guard let modelContext else { return }

        let descriptor = FetchDescriptor<Friend>(
            sortBy: [SortDescriptor(\.displayName)]
        )

        friends = (try? modelContext.fetch(descriptor)) ?? []
    }

    /// Get friend by ID
    func friend(id: String) -> Friend? {
        friends.first { $0.friendUserId == id }
    }

    /// Remove a friend
    func removeFriend(_ friend: Friend) async throws {
        guard let userId else { throw FriendError.notConfigured }

        // Remove from Firestore
        try await firestoreService.removeFriend(userId: userId, friendId: friend.id)

        // Also remove from friend's list
        try await firestoreService.removeFriend(userId: friend.friendUserId, friendId: friend.id)

        // Reload friends
        await loadFriends()
    }

    // MARK: - Friend Requests

    /// Load pending friend requests
    func loadPendingRequests() async {
        guard let userId else { return }

        do {
            pendingRequests = try await firestoreService.fetchPendingRequests(userId: userId)
        } catch {
            print("Failed to load pending requests: \(error)")
        }
    }

    /// Start real-time listener for friend requests
    private func startListeningForRequests() {
        guard let userId else { return }

        requestsListener = firestoreService.listenForRequests(userId: userId) { [weak self] requests in
            Task { @MainActor in
                self?.pendingRequests = requests
            }
        }
    }

    /// Send a friend request
    func sendFriendRequest(to targetUserId: String, currentUser: User) async throws {
        guard let userId else { throw FriendError.notConfigured }

        // Check if already friends
        if friends.contains(where: { $0.friendUserId == targetUserId }) {
            throw FriendError.alreadyFriends
        }

        // Check if request already sent
        let sentRequests = try await firestoreService.fetchSentRequests(userId: userId)
        if sentRequests.contains(where: { $0.toUserId == targetUserId }) {
            throw FriendError.requestAlreadySent
        }

        // Create and send request
        let request = FriendRequest(
            fromUserId: userId,
            toUserId: targetUserId,
            fromDisplayName: currentUser.displayName,
            fromProfileImageURL: currentUser.profileImageURL
        )

        try await firestoreService.sendFriendRequest(request)
    }

    /// Accept a friend request
    func acceptRequest(_ request: FriendRequest) async throws {
        guard let userId, let modelContext else { throw FriendError.notConfigured }

        // Update request status
        try await firestoreService.updateRequestStatus(requestId: request.id, status: .accepted)

        // Fetch sender's user info
        guard let senderUser = try await firestoreService.fetchUser(id: request.fromUserId) else {
            throw FriendError.userNotFound
        }

        // Create friend entries for both users
        let friendForMe = Friend(
            friendUserId: request.fromUserId,
            displayName: senderUser.displayName,
            profileImageURL: senderUser.profileImageURL
        )

        let friendForThem = Friend(
            id: friendForMe.id, // Same ID for both directions
            friendUserId: userId,
            displayName: "", // Will be filled by the other user's app
            profileImageURL: nil
        )

        // Save to Firestore
        try await firestoreService.addFriend(userId: userId, friend: friendForMe)
        try await firestoreService.addFriend(userId: request.fromUserId, friend: friendForThem)

        // Save to local storage
        modelContext.insert(friendForMe)
        try modelContext.save()

        // Reload data
        await loadFriends()
        await loadPendingRequests()
    }

    /// Decline a friend request
    func declineRequest(_ request: FriendRequest) async throws {
        try await firestoreService.updateRequestStatus(requestId: request.id, status: .declined)
        await loadPendingRequests()
    }

    // MARK: - Contact Discovery

    /// Find friends from contacts who are registered
    func discoverFriendsFromContacts() async throws {
        guard contactsService.isAuthorized else {
            throw FriendError.contactsNotAuthorized
        }

        // Get all contacts
        let contacts = try await contactsService.fetchContacts()

        // Get phone hashes in batches
        let hashBatches = try await contactsService.getPhoneHashBatches()

        // Query Firestore for matching users
        var allMatchedUsers: [UserSummary] = []
        for batch in hashBatches {
            let users = try await firestoreService.findUsersByPhoneHashes(batch)
            allMatchedUsers.append(contentsOf: users)
        }

        // Create a lookup by phone hash
        var usersByHash: [String: UserSummary] = [:]
        for user in allMatchedUsers {
            // We need to match the user back to their hash
            // In a real app, the backend would return this mapping
            // For now, we'll do a simple match
        }

        // Match contacts to users
        var results: [ContactMatchResult] = []

        for contact in contacts {
            // Check if any of this contact's phone numbers match a registered user
            var matchedUser: UserSummary?

            for phone in contact.phoneNumbers {
                if let user = allMatchedUsers.first(where: { _ in
                    // In a real implementation, we'd compare hashes
                    // For now, this is a placeholder
                    false
                }) {
                    matchedUser = user
                    break
                }
            }

            // For demo purposes, just show all contacts
            if let primaryPhone = contact.primaryPhone {
                results.append(ContactMatchResult(
                    id: contact.id,
                    contactName: contact.fullName,
                    phoneNumber: primaryPhone.original,
                    matchedUser: matchedUser
                ))
            }
        }

        matchedContacts = results
    }

    /// Request contacts permission
    func requestContactsAccess() async throws -> Bool {
        try await contactsService.requestAccess()
    }

    /// Whether contacts access is authorized
    var hasContactsAccess: Bool {
        contactsService.isAuthorized
    }
}

// MARK: - Errors

extension FriendRepository {
    enum FriendError: LocalizedError {
        case notConfigured
        case contactsNotAuthorized
        case alreadyFriends
        case requestAlreadySent
        case userNotFound

        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return "Please sign in to manage friends."
            case .contactsNotAuthorized:
                return "Contacts access is required to find friends."
            case .alreadyFriends:
                return "You're already friends with this person."
            case .requestAlreadySent:
                return "Friend request already sent."
            case .userNotFound:
                return "User not found."
            }
        }
    }
}
