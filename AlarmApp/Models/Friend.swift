import Foundation
import SwiftData

/// Represents a friendship between two users
@Model
final class Friend {
    /// Unique identifier
    @Attribute(.unique) var id: String

    /// The friend's user ID
    var friendUserId: String

    /// The friend's display name (cached for offline access)
    var displayName: String

    /// The friend's profile image URL (cached)
    var profileImageURL: String?

    /// The friend's phone number (for display, e.g., "from your contacts")
    var phoneNumber: String?

    /// Name from user's contacts (may differ from displayName)
    var contactName: String?

    /// When the friendship was established
    var connectedAt: Date

    /// Whether this friend is currently available to be an accountability partner
    var isAvailable: Bool

    /// Last time this friend helped with an alarm
    var lastAlarmHelpAt: Date?

    /// Number of times this friend has been notified
    var notificationCount: Int

    init(
        id: String = UUID().uuidString,
        friendUserId: String,
        displayName: String,
        profileImageURL: String? = nil,
        phoneNumber: String? = nil,
        contactName: String? = nil,
        connectedAt: Date = Date(),
        isAvailable: Bool = true,
        lastAlarmHelpAt: Date? = nil,
        notificationCount: Int = 0
    ) {
        self.id = id
        self.friendUserId = friendUserId
        self.displayName = displayName
        self.profileImageURL = profileImageURL
        self.phoneNumber = phoneNumber
        self.contactName = contactName
        self.connectedAt = connectedAt
        self.isAvailable = isAvailable
        self.lastAlarmHelpAt = lastAlarmHelpAt
        self.notificationCount = notificationCount
    }
}

// MARK: - Display Helpers

extension Friend {
    /// Best name to display (contact name if available, otherwise display name)
    var bestDisplayName: String {
        contactName ?? displayName
    }

    /// Initials for avatar fallback
    var initials: String {
        let name = bestDisplayName
        let components = name.split(separator: " ")

        if components.count >= 2 {
            let first = components[0].prefix(1)
            let last = components[1].prefix(1)
            return "\(first)\(last)".uppercased()
        }

        return String(name.prefix(2)).uppercased()
    }

    /// Subtitle text (e.g., "From your contacts")
    var subtitle: String? {
        if contactName != nil && contactName != displayName {
            return "Known as \"\(displayName)\" in app"
        }
        if phoneNumber != nil {
            return "From your contacts"
        }
        return nil
    }
}

// MARK: - Firestore Codable

extension Friend {
    /// Dictionary representation for Firestore
    var firestoreData: [String: Any] {
        var data: [String: Any] = [
            "id": id,
            "friendUserId": friendUserId,
            "displayName": displayName,
            "connectedAt": connectedAt,
            "isAvailable": isAvailable,
            "notificationCount": notificationCount
        ]

        if let profileImageURL {
            data["profileImageURL"] = profileImageURL
        }

        if let phoneNumber {
            data["phoneNumber"] = phoneNumber
        }

        if let lastAlarmHelpAt {
            data["lastAlarmHelpAt"] = lastAlarmHelpAt
        }

        return data
    }

    /// Creates Friend from Firestore document data
    convenience init?(firestoreData: [String: Any], id: String) {
        guard let friendUserId = firestoreData["friendUserId"] as? String,
              let displayName = firestoreData["displayName"] as? String else {
            return nil
        }

        self.init(
            id: id,
            friendUserId: friendUserId,
            displayName: displayName,
            profileImageURL: firestoreData["profileImageURL"] as? String,
            phoneNumber: firestoreData["phoneNumber"] as? String,
            contactName: firestoreData["contactName"] as? String,
            connectedAt: (firestoreData["connectedAt"] as? Date) ?? Date(),
            isAvailable: (firestoreData["isAvailable"] as? Bool) ?? true,
            lastAlarmHelpAt: firestoreData["lastAlarmHelpAt"] as? Date,
            notificationCount: (firestoreData["notificationCount"] as? Int) ?? 0
        )
    }
}

// MARK: - Contact Match Result

/// Result of matching a contact against registered users
struct ContactMatchResult: Identifiable {
    let id: String
    let contactName: String
    let phoneNumber: String
    let matchedUser: UserSummary?

    var isRegistered: Bool {
        matchedUser != nil
    }
}
