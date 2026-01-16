import Foundation
import SwiftData

/// Represents a pending friend request
@Model
final class FriendRequest {
    /// Unique identifier
    @Attribute(.unique) var id: String

    /// User who sent the request
    var fromUserId: String

    /// User who will receive the request
    var toUserId: String

    /// Sender's display name (for display without extra fetch)
    var fromDisplayName: String

    /// Sender's profile image URL
    var fromProfileImageURL: String?

    /// Current status of the request
    var status: RequestStatus

    /// When the request was created
    var createdAt: Date

    /// When the request was responded to (accepted/declined)
    var respondedAt: Date?

    /// Optional message from sender
    var message: String?

    init(
        id: String = UUID().uuidString,
        fromUserId: String,
        toUserId: String,
        fromDisplayName: String,
        fromProfileImageURL: String? = nil,
        status: RequestStatus = .pending,
        createdAt: Date = Date(),
        respondedAt: Date? = nil,
        message: String? = nil
    ) {
        self.id = id
        self.fromUserId = fromUserId
        self.toUserId = toUserId
        self.fromDisplayName = fromDisplayName
        self.fromProfileImageURL = fromProfileImageURL
        self.status = status
        self.createdAt = createdAt
        self.respondedAt = respondedAt
        self.message = message
    }
}

// MARK: - Request Status

extension FriendRequest {
    enum RequestStatus: String, Codable {
        case pending
        case accepted
        case declined
        case cancelled
    }
}

// MARK: - Computed Properties

extension FriendRequest {
    /// Whether this request can still be acted upon
    var isActionable: Bool {
        status == .pending
    }

    /// Human-readable time since request was sent
    var timeSinceCreated: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }

    /// Initials for avatar fallback
    var initials: String {
        let components = fromDisplayName.split(separator: " ")

        if components.count >= 2 {
            let first = components[0].prefix(1)
            let last = components[1].prefix(1)
            return "\(first)\(last)".uppercased()
        }

        return String(fromDisplayName.prefix(2)).uppercased()
    }
}

// MARK: - Firestore Codable

extension FriendRequest {
    /// Dictionary representation for Firestore
    var firestoreData: [String: Any] {
        var data: [String: Any] = [
            "id": id,
            "fromUserId": fromUserId,
            "toUserId": toUserId,
            "fromDisplayName": fromDisplayName,
            "status": status.rawValue,
            "createdAt": createdAt
        ]

        if let fromProfileImageURL {
            data["fromProfileImageURL"] = fromProfileImageURL
        }

        if let respondedAt {
            data["respondedAt"] = respondedAt
        }

        if let message {
            data["message"] = message
        }

        return data
    }

    /// Creates FriendRequest from Firestore document data
    convenience init?(firestoreData: [String: Any], id: String) {
        guard let fromUserId = firestoreData["fromUserId"] as? String,
              let toUserId = firestoreData["toUserId"] as? String,
              let fromDisplayName = firestoreData["fromDisplayName"] as? String,
              let statusString = firestoreData["status"] as? String,
              let status = RequestStatus(rawValue: statusString) else {
            return nil
        }

        self.init(
            id: id,
            fromUserId: fromUserId,
            toUserId: toUserId,
            fromDisplayName: fromDisplayName,
            fromProfileImageURL: firestoreData["fromProfileImageURL"] as? String,
            status: status,
            createdAt: (firestoreData["createdAt"] as? Date) ?? Date(),
            respondedAt: firestoreData["respondedAt"] as? Date,
            message: firestoreData["message"] as? String
        )
    }
}
