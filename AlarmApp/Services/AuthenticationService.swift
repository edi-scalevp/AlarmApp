import Foundation
import FirebaseAuth
import FirebaseFirestore
import CryptoKit

/// Handles Firebase Phone Authentication and user management
@Observable
final class AuthenticationService {

    /// Current Firebase auth state
    private(set) var isAuthenticated: Bool = false

    /// Verification ID from phone number submission (used for SMS code verification)
    private var verificationId: String?

    /// Firebase Firestore reference
    private let db = Firestore.firestore()

    /// Users collection reference
    private var usersCollection: CollectionReference {
        db.collection("users")
    }

    init() {
        // Listen for auth state changes
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.isAuthenticated = user != nil
        }

        // Listen for FCM token updates
        NotificationCenter.default.addObserver(
            forName: .fcmTokenReceived,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let token = notification.userInfo?["token"] as? String {
                Task {
                    await self?.updateFCMToken(token)
                }
            }
        }
    }

    // MARK: - Phone Number Authentication

    /// Start phone number verification (sends SMS code)
    /// - Parameter phoneNumber: Phone number in E.164 format (e.g., +14155551234)
    /// - Returns: Success or throws error
    func startPhoneVerification(phoneNumber: String) async throws {
        let verificationId = try await PhoneAuthProvider.provider()
            .verifyPhoneNumber(phoneNumber, uiDelegate: nil)

        self.verificationId = verificationId
    }

    /// Verify SMS code and sign in
    /// - Parameter code: 6-digit SMS verification code
    /// - Returns: The authenticated user
    @discardableResult
    func verifyCode(_ code: String) async throws -> User {
        guard let verificationId = verificationId else {
            throw AuthError.noVerificationId
        }

        let credential = PhoneAuthProvider.provider().credential(
            withVerificationID: verificationId,
            verificationCode: code
        )

        let authResult = try await Auth.auth().signIn(with: credential)
        let firebaseUser = authResult.user

        // Check if user exists in Firestore
        let existingUser = try await fetchUser(id: firebaseUser.uid)

        if let existingUser {
            // Update FCM token if we have one
            if let fcmToken = UserDefaults.standard.string(forKey: "fcmToken") {
                try await updateUserFCMToken(userId: firebaseUser.uid, token: fcmToken)
            }
            return existingUser
        }

        // Create new user
        let phoneNumber = firebaseUser.phoneNumber ?? ""
        let newUser = User(
            id: firebaseUser.uid,
            phoneNumber: phoneNumber,
            phoneNumberHash: hashPhoneNumber(phoneNumber),
            displayName: "",
            fcmToken: UserDefaults.standard.string(forKey: "fcmToken")
        )

        try await createUser(newUser)
        return newUser
    }

    /// Get currently authenticated user
    func getCurrentUser() async -> User? {
        guard let firebaseUser = Auth.auth().currentUser else {
            return nil
        }

        return try? await fetchUser(id: firebaseUser.uid)
    }

    /// Sign out the current user
    func signOut() throws {
        try Auth.auth().signOut()
    }

    // MARK: - User Management

    /// Fetch user from Firestore
    func fetchUser(id: String) async throws -> User? {
        let document = try await usersCollection.document(id).getDocument()

        guard document.exists,
              let data = document.data() else {
            return nil
        }

        return User(firestoreData: data, id: id)
    }

    /// Create new user in Firestore
    func createUser(_ user: User) async throws {
        try await usersCollection.document(user.id).setData(user.firestoreData)
    }

    /// Update user profile
    func updateProfile(userId: String, displayName: String, profileImageURL: String?) async throws {
        var data: [String: Any] = [
            "displayName": displayName,
            "lastActiveAt": FieldValue.serverTimestamp()
        ]

        if let profileImageURL {
            data["profileImageURL"] = profileImageURL
        }

        try await usersCollection.document(userId).updateData(data)
    }

    /// Update FCM token for push notifications
    func updateFCMToken(_ token: String) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        do {
            try await updateUserFCMToken(userId: userId, token: token)
        } catch {
            print("Failed to update FCM token: \(error)")
        }
    }

    private func updateUserFCMToken(userId: String, token: String) async throws {
        try await usersCollection.document(userId).updateData([
            "fcmToken": token,
            "lastActiveAt": FieldValue.serverTimestamp()
        ])
    }

    // MARK: - Phone Number Hashing

    /// Hash phone number for privacy-preserving contact matching
    func hashPhoneNumber(_ phoneNumber: String) -> String {
        // Normalize phone number (remove spaces, dashes, etc.)
        let normalized = normalizePhoneNumber(phoneNumber)

        // Create SHA256 hash
        let data = Data(normalized.utf8)
        let hash = SHA256.hash(data: data)

        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// Normalize phone number to E.164 format
    func normalizePhoneNumber(_ phoneNumber: String) -> String {
        // Remove all non-digit characters except leading +
        var normalized = phoneNumber.replacingOccurrences(
            of: "[^0-9+]",
            with: "",
            options: .regularExpression
        )

        // Ensure it starts with +
        if !normalized.hasPrefix("+") {
            // Assume US number if no country code
            if normalized.count == 10 {
                normalized = "+1" + normalized
            } else if normalized.count == 11 && normalized.hasPrefix("1") {
                normalized = "+" + normalized
            }
        }

        return normalized
    }

    // MARK: - Validation

    /// Validate phone number format
    func isValidPhoneNumber(_ phoneNumber: String) -> Bool {
        let normalized = normalizePhoneNumber(phoneNumber)

        // Basic validation: must start with + and have 10-15 digits
        let pattern = "^\\+[1-9]\\d{9,14}$"
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(normalized.startIndex..., in: normalized)

        return regex?.firstMatch(in: normalized, range: range) != nil
    }

    /// Validate SMS verification code format
    func isValidVerificationCode(_ code: String) -> Bool {
        let pattern = "^\\d{6}$"
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(code.startIndex..., in: code)

        return regex?.firstMatch(in: code, range: range) != nil
    }
}

// MARK: - Auth Errors

extension AuthenticationService {
    enum AuthError: LocalizedError {
        case noVerificationId
        case invalidPhoneNumber
        case invalidCode
        case userNotFound
        case unknown(Error)

        var errorDescription: String? {
            switch self {
            case .noVerificationId:
                return "Please request a verification code first."
            case .invalidPhoneNumber:
                return "Please enter a valid phone number."
            case .invalidCode:
                return "Please enter a valid 6-digit code."
            case .userNotFound:
                return "User not found."
            case .unknown(let error):
                return error.localizedDescription
            }
        }
    }
}

// MARK: - Country Codes

extension AuthenticationService {
    /// Common country codes for phone number input
    static let countryCodes: [(code: String, name: String, flag: String)] = [
        ("+1", "United States", "\u{1F1FA}\u{1F1F8}"),
        ("+1", "Canada", "\u{1F1E8}\u{1F1E6}"),
        ("+44", "United Kingdom", "\u{1F1EC}\u{1F1E7}"),
        ("+61", "Australia", "\u{1F1E6}\u{1F1FA}"),
        ("+49", "Germany", "\u{1F1E9}\u{1F1EA}"),
        ("+33", "France", "\u{1F1EB}\u{1F1F7}"),
        ("+81", "Japan", "\u{1F1EF}\u{1F1F5}"),
        ("+86", "China", "\u{1F1E8}\u{1F1F3}"),
        ("+91", "India", "\u{1F1EE}\u{1F1F3}"),
        ("+52", "Mexico", "\u{1F1F2}\u{1F1FD}"),
        ("+55", "Brazil", "\u{1F1E7}\u{1F1F7}"),
        ("+82", "South Korea", "\u{1F1F0}\u{1F1F7}"),
        ("+39", "Italy", "\u{1F1EE}\u{1F1F9}"),
        ("+34", "Spain", "\u{1F1EA}\u{1F1F8}"),
        ("+31", "Netherlands", "\u{1F1F3}\u{1F1F1}")
    ]
}
