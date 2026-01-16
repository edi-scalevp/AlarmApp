import Foundation
import FirebaseFirestore

/// General-purpose Firestore service for database operations
@Observable
final class FirestoreService {

    /// Firestore database instance
    private let db = Firestore.firestore()

    /// Collection references
    var usersCollection: CollectionReference { db.collection("users") }
    var friendsCollection: CollectionReference { db.collection("friends") }
    var friendRequestsCollection: CollectionReference { db.collection("friendRequests") }
    var escalationsCollection: CollectionReference { db.collection("escalations") }

    // MARK: - Users

    /// Fetch user by ID
    func fetchUser(id: String) async throws -> User? {
        let document = try await usersCollection.document(id).getDocument()
        guard document.exists, let data = document.data() else { return nil }
        return User(firestoreData: data, id: id)
    }

    /// Update user document
    func updateUser(id: String, data: [String: Any]) async throws {
        try await usersCollection.document(id).updateData(data)
    }

    /// Find users by phone number hashes
    func findUsersByPhoneHashes(_ hashes: [String]) async throws -> [UserSummary] {
        guard !hashes.isEmpty else { return [] }

        // Firestore 'in' query is limited to 10 items
        let batches = hashes.chunked(into: 10)
        var users: [UserSummary] = []

        for batch in batches {
            let snapshot = try await usersCollection
                .whereField("phoneNumberHash", in: batch)
                .getDocuments()

            let batchUsers = snapshot.documents.compactMap { doc -> UserSummary? in
                guard let displayName = doc.data()["displayName"] as? String else { return nil }
                return UserSummary(
                    id: doc.documentID,
                    displayName: displayName,
                    profileImageURL: doc.data()["profileImageURL"] as? String
                )
            }

            users.append(contentsOf: batchUsers)
        }

        return users
    }

    // MARK: - Friends

    /// Get user's friends subcollection reference
    func userFriendsCollection(userId: String) -> CollectionReference {
        usersCollection.document(userId).collection("friends")
    }

    /// Fetch all friends for a user
    func fetchFriends(userId: String) async throws -> [Friend] {
        let snapshot = try await userFriendsCollection(userId: userId).getDocuments()

        return snapshot.documents.compactMap { doc in
            Friend(firestoreData: doc.data(), id: doc.documentID)
        }
    }

    /// Add a friend
    func addFriend(userId: String, friend: Friend) async throws {
        try await userFriendsCollection(userId: userId)
            .document(friend.id)
            .setData(friend.firestoreData)
    }

    /// Remove a friend
    func removeFriend(userId: String, friendId: String) async throws {
        try await userFriendsCollection(userId: userId)
            .document(friendId)
            .delete()
    }

    // MARK: - Friend Requests

    /// Send a friend request
    func sendFriendRequest(_ request: FriendRequest) async throws {
        try await friendRequestsCollection
            .document(request.id)
            .setData(request.firestoreData)
    }

    /// Fetch pending friend requests for a user
    func fetchPendingRequests(userId: String) async throws -> [FriendRequest] {
        let snapshot = try await friendRequestsCollection
            .whereField("toUserId", isEqualTo: userId)
            .whereField("status", isEqualTo: "pending")
            .order(by: "createdAt", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            FriendRequest(firestoreData: doc.data(), id: doc.documentID)
        }
    }

    /// Fetch sent friend requests
    func fetchSentRequests(userId: String) async throws -> [FriendRequest] {
        let snapshot = try await friendRequestsCollection
            .whereField("fromUserId", isEqualTo: userId)
            .whereField("status", isEqualTo: "pending")
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            FriendRequest(firestoreData: doc.data(), id: doc.documentID)
        }
    }

    /// Update friend request status
    func updateRequestStatus(requestId: String, status: FriendRequest.RequestStatus) async throws {
        try await friendRequestsCollection.document(requestId).updateData([
            "status": status.rawValue,
            "respondedAt": FieldValue.serverTimestamp()
        ])
    }

    /// Listen for new friend requests
    func listenForRequests(
        userId: String,
        onChange: @escaping ([FriendRequest]) -> Void
    ) -> ListenerRegistration {
        return friendRequestsCollection
            .whereField("toUserId", isEqualTo: userId)
            .whereField("status", isEqualTo: "pending")
            .addSnapshotListener { snapshot, error in
                if let error {
                    print("Error listening for requests: \(error)")
                    return
                }

                guard let snapshot else { return }

                let requests = snapshot.documents.compactMap { doc in
                    FriendRequest(firestoreData: doc.data(), id: doc.documentID)
                }

                onChange(requests)
            }
    }

    // MARK: - Escalations

    /// Create an escalation event
    func createEscalation(_ escalation: EscalationEvent) async throws {
        try await escalationsCollection
            .document(escalation.id)
            .setData(escalation.firestoreData)
    }

    /// Update escalation status
    func updateEscalationStatus(id: String, status: EscalationEvent.Status) async throws {
        var data: [String: Any] = ["status": status.rawValue]

        if status == .dismissed {
            data["dismissedAt"] = FieldValue.serverTimestamp()
        } else if status == .escalated {
            data["escalatedAt"] = FieldValue.serverTimestamp()
        }

        try await escalationsCollection.document(id).updateData(data)
    }

    /// Fetch active escalation for an alarm
    func fetchActiveEscalation(alarmId: String) async throws -> EscalationEvent? {
        let snapshot = try await escalationsCollection
            .whereField("alarmId", isEqualTo: alarmId)
            .whereField("status", isEqualTo: "pending")
            .limit(to: 1)
            .getDocuments()

        guard let doc = snapshot.documents.first else { return nil }
        return EscalationEvent(firestoreData: doc.data(), id: doc.documentID)
    }

    // MARK: - Batch Operations

    /// Perform a batch write
    func performBatch(_ operations: (WriteBatch) -> Void) async throws {
        let batch = db.batch()
        operations(batch)
        try await batch.commit()
    }
}

// MARK: - Escalation Event

/// Represents an escalation event (potential friend notification)
struct EscalationEvent: Identifiable {
    let id: String
    let alarmId: String
    let userId: String
    let triggerTime: Date
    let escalationTime: Date
    let friendIds: [String]
    var status: Status
    var dismissedAt: Date?
    var escalatedAt: Date?

    enum Status: String, Codable {
        case pending
        case dismissed
        case escalated
        case expired
    }

    init(
        id: String = UUID().uuidString,
        alarmId: String,
        userId: String,
        triggerTime: Date,
        escalationTime: Date,
        friendIds: [String],
        status: Status = .pending
    ) {
        self.id = id
        self.alarmId = alarmId
        self.userId = userId
        self.triggerTime = triggerTime
        self.escalationTime = escalationTime
        self.friendIds = friendIds
        self.status = status
    }

    var firestoreData: [String: Any] {
        var data: [String: Any] = [
            "id": id,
            "alarmId": alarmId,
            "userId": userId,
            "triggerTime": triggerTime,
            "escalationTime": escalationTime,
            "friendIds": friendIds,
            "status": status.rawValue
        ]

        if let dismissedAt {
            data["dismissedAt"] = dismissedAt
        }

        if let escalatedAt {
            data["escalatedAt"] = escalatedAt
        }

        return data
    }

    init?(firestoreData: [String: Any], id: String) {
        guard let alarmId = firestoreData["alarmId"] as? String,
              let userId = firestoreData["userId"] as? String,
              let triggerTime = firestoreData["triggerTime"] as? Date,
              let escalationTime = firestoreData["escalationTime"] as? Date,
              let friendIds = firestoreData["friendIds"] as? [String],
              let statusString = firestoreData["status"] as? String,
              let status = Status(rawValue: statusString) else {
            return nil
        }

        self.id = id
        self.alarmId = alarmId
        self.userId = userId
        self.triggerTime = triggerTime
        self.escalationTime = escalationTime
        self.friendIds = friendIds
        self.status = status
        self.dismissedAt = firestoreData["dismissedAt"] as? Date
        self.escalatedAt = firestoreData["escalatedAt"] as? Date
    }
}
