import Foundation
import Contacts
import CryptoKit

/// Service for accessing and processing contacts for friend discovery
@Observable
final class ContactsService {

    /// Authorization status for contacts access
    private(set) var authorizationStatus: CNAuthorizationStatus = .notDetermined

    /// Contacts store
    private let store = CNContactStore()

    init() {
        checkAuthorizationStatus()
    }

    // MARK: - Authorization

    /// Check current authorization status
    func checkAuthorizationStatus() {
        authorizationStatus = CNContactStore.authorizationStatus(for: .contacts)
    }

    /// Request contacts access permission
    func requestAccess() async throws -> Bool {
        let granted = try await store.requestAccess(for: .contacts)
        await MainActor.run {
            checkAuthorizationStatus()
        }
        return granted
    }

    /// Whether contacts access is authorized
    var isAuthorized: Bool {
        authorizationStatus == .authorized
    }

    // MARK: - Fetch Contacts

    /// Fetch all contacts with phone numbers
    func fetchContacts() async throws -> [ContactInfo] {
        guard isAuthorized else {
            throw ContactsError.notAuthorized
        }

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self else {
                    continuation.resume(throwing: ContactsError.unknown)
                    return
                }

                do {
                    let contacts = try self.fetchContactsSync()
                    continuation.resume(returning: contacts)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func fetchContactsSync() throws -> [ContactInfo] {
        let keysToFetch: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactThumbnailImageDataKey as CNKeyDescriptor,
            CNContactIdentifierKey as CNKeyDescriptor
        ]

        let request = CNContactFetchRequest(keysToFetch: keysToFetch)
        request.sortOrder = .givenName

        var contacts: [ContactInfo] = []

        try store.enumerateContacts(with: request) { contact, _ in
            // Only include contacts with phone numbers
            guard !contact.phoneNumbers.isEmpty else { return }

            let fullName = [contact.givenName, contact.familyName]
                .filter { !$0.isEmpty }
                .joined(separator: " ")

            // Get all phone numbers for this contact
            let phoneNumbers = contact.phoneNumbers.compactMap { phoneNumber -> PhoneNumberInfo? in
                let number = phoneNumber.value.stringValue
                let normalized = self.normalizePhoneNumber(number)

                guard !normalized.isEmpty else { return nil }

                let label = CNLabeledValue<NSString>.localizedString(forLabel: phoneNumber.label ?? "")

                return PhoneNumberInfo(
                    original: number,
                    normalized: normalized,
                    hash: self.hashPhoneNumber(normalized),
                    label: label
                )
            }

            guard !phoneNumbers.isEmpty else { return }

            let contactInfo = ContactInfo(
                id: contact.identifier,
                fullName: fullName.isEmpty ? "Unknown" : fullName,
                phoneNumbers: phoneNumbers,
                thumbnailData: contact.thumbnailImageData
            )

            contacts.append(contactInfo)
        }

        return contacts
    }

    // MARK: - Phone Number Processing

    /// Normalize phone number to E.164 format
    func normalizePhoneNumber(_ phoneNumber: String) -> String {
        // Remove all non-digit characters except leading +
        var normalized = phoneNumber.replacingOccurrences(
            of: "[^0-9+]",
            with: "",
            options: .regularExpression
        )

        // Handle various formats
        if normalized.hasPrefix("+") {
            // Already has country code
            return normalized
        }

        // Assume US/Canada if 10 digits
        if normalized.count == 10 {
            return "+1" + normalized
        }

        // Assume US/Canada if 11 digits starting with 1
        if normalized.count == 11 && normalized.hasPrefix("1") {
            return "+" + normalized
        }

        // Return as-is with + prefix for other formats
        return "+" + normalized
    }

    /// Hash phone number for privacy-preserving matching
    func hashPhoneNumber(_ phoneNumber: String) -> String {
        let data = Data(phoneNumber.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// Get all unique phone number hashes from contacts
    func getAllPhoneHashes() async throws -> [String] {
        let contacts = try await fetchContacts()
        var hashes = Set<String>()

        for contact in contacts {
            for phone in contact.phoneNumbers {
                hashes.insert(phone.hash)
            }
        }

        return Array(hashes)
    }

    /// Get phone hashes in batches (for Firestore 'in' query limit of 10)
    func getPhoneHashBatches() async throws -> [[String]] {
        let allHashes = try await getAllPhoneHashes()
        return allHashes.chunked(into: 10)
    }
}

// MARK: - Data Types

/// Information about a contact
struct ContactInfo: Identifiable {
    let id: String
    let fullName: String
    let phoneNumbers: [PhoneNumberInfo]
    let thumbnailData: Data?

    /// Primary phone number (first one)
    var primaryPhone: PhoneNumberInfo? {
        phoneNumbers.first
    }

    /// Initials for avatar fallback
    var initials: String {
        let components = fullName.split(separator: " ")
        if components.count >= 2 {
            return "\(components[0].prefix(1))\(components[1].prefix(1))".uppercased()
        }
        return String(fullName.prefix(2)).uppercased()
    }
}

/// Information about a phone number
struct PhoneNumberInfo: Identifiable {
    var id: String { hash }

    let original: String      // Original format from contacts
    let normalized: String    // E.164 format
    let hash: String          // SHA256 hash for matching
    let label: String         // "mobile", "home", etc.
}

// MARK: - Errors

extension ContactsService {
    enum ContactsError: LocalizedError {
        case notAuthorized
        case fetchFailed
        case unknown

        var errorDescription: String? {
            switch self {
            case .notAuthorized:
                return "Contacts access is required to find friends."
            case .fetchFailed:
                return "Failed to fetch contacts."
            case .unknown:
                return "An unknown error occurred."
            }
        }
    }
}

// MARK: - Array Extension

extension Array {
    /// Split array into chunks of specified size
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
