import Foundation
import SwiftData

/// Represents a user in the app
/// Uses phone number as primary identity via Firebase Phone Auth
@Model
final class User {
    /// Unique identifier (matches Firebase Auth UID)
    @Attribute(.unique) var id: String

    /// Phone number in E.164 format (e.g., +14155551234)
    var phoneNumber: String

    /// SHA256 hash of phone number for privacy-preserving contact matching
    var phoneNumberHash: String

    /// User's display name shown to friends
    var displayName: String

    /// Optional profile image URL (stored in Firebase Storage)
    var profileImageURL: String?

    /// Firebase Cloud Messaging token for push notifications
    var fcmToken: String?

    /// When the user account was created
    var createdAt: Date

    /// Last time user was active in the app
    var lastActiveAt: Date

    init(
        id: String,
        phoneNumber: String,
        phoneNumberHash: String,
        displayName: String,
        profileImageURL: String? = nil,
        fcmToken: String? = nil,
        createdAt: Date = Date(),
        lastActiveAt: Date = Date()
    ) {
        self.id = id
        self.phoneNumber = phoneNumber
        self.phoneNumberHash = phoneNumberHash
        self.displayName = displayName
        self.profileImageURL = profileImageURL
        self.fcmToken = fcmToken
        self.createdAt = createdAt
        self.lastActiveAt = lastActiveAt
    }
}

// MARK: - Firestore Codable

extension User {
    /// Dictionary representation for Firestore
    var firestoreData: [String: Any] {
        var data: [String: Any] = [
            "id": id,
            "phoneNumber": phoneNumber,
            "phoneNumberHash": phoneNumberHash,
            "displayName": displayName,
            "createdAt": createdAt,
            "lastActiveAt": lastActiveAt
        ]

        if let profileImageURL {
            data["profileImageURL"] = profileImageURL
        }

        if let fcmToken {
            data["fcmToken"] = fcmToken
        }

        return data
    }

    /// Creates User from Firestore document data
    convenience init?(firestoreData: [String: Any], id: String) {
        guard let phoneNumber = firestoreData["phoneNumber"] as? String,
              let phoneNumberHash = firestoreData["phoneNumberHash"] as? String,
              let displayName = firestoreData["displayName"] as? String else {
            return nil
        }

        let createdAt = (firestoreData["createdAt"] as? Date) ?? Date()
        let lastActiveAt = (firestoreData["lastActiveAt"] as? Date) ?? Date()

        self.init(
            id: id,
            phoneNumber: phoneNumber,
            phoneNumberHash: phoneNumberHash,
            displayName: displayName,
            profileImageURL: firestoreData["profileImageURL"] as? String,
            fcmToken: firestoreData["fcmToken"] as? String,
            createdAt: createdAt,
            lastActiveAt: lastActiveAt
        )
    }
}

// MARK: - User Summary (for display in friend lists)

/// Lightweight user info for display purposes
struct UserSummary: Identifiable, Codable, Hashable {
    let id: String
    let displayName: String
    let profileImageURL: String?

    init(from user: User) {
        self.id = user.id
        self.displayName = user.displayName
        self.profileImageURL = user.profileImageURL
    }

    init(id: String, displayName: String, profileImageURL: String? = nil) {
        self.id = id
        self.displayName = displayName
        self.profileImageURL = profileImageURL
    }
}
