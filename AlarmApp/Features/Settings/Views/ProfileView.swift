import SwiftUI
import PhotosUI

/// Profile editing view
struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @State private var displayName = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var profileImage: Image?
    @State private var isSaving = false
    @State private var showDeleteAccountConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                // Profile photo section
                Section {
                    HStack {
                        Spacer()
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            VStack(spacing: 12) {
                                ZStack {
                                    if let profileImage {
                                        profileImage
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 100, height: 100)
                                            .clipShape(Circle())
                                    } else {
                                        CurrentProfileImage(user: appState.currentUser, size: 100)
                                    }

                                    Circle()
                                        .fill(Color.orange)
                                        .frame(width: 32, height: 32)
                                        .overlay {
                                            Image(systemName: "camera.fill")
                                                .font(.caption)
                                                .foregroundStyle(.white)
                                        }
                                        .offset(x: 35, y: 35)
                                }

                                Text("Change Photo")
                                    .font(.subheadline)
                                    .foregroundStyle(.orange)
                            }
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
                .onChange(of: selectedPhoto) { _, newValue in
                    loadImage(from: newValue)
                }

                // Display name section
                Section("Display Name") {
                    TextField("Your name", text: $displayName)
                        .textContentType(.name)
                        .autocorrectionDisabled()
                }

                // Phone number section (read-only)
                Section("Phone Number") {
                    HStack {
                        Text(formattedPhoneNumber)
                        Spacer()
                        Text("Cannot be changed")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Danger zone
                Section {
                    Button(role: .destructive) {
                        showDeleteAccountConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete Account")
                        }
                    }
                } footer: {
                    Text("This will permanently delete your account and all associated data.")
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        saveProfile()
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                                .bold()
                        }
                    }
                    .disabled(isSaving || !hasChanges)
                }
            }
            .onAppear {
                displayName = appState.currentUser?.displayName ?? ""
            }
            .confirmationDialog(
                "Delete Account",
                isPresented: $showDeleteAccountConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete Account", role: .destructive) {
                    deleteAccount()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This action cannot be undone. All your alarms, friends, and data will be permanently deleted.")
            }
        }
    }

    private var formattedPhoneNumber: String {
        guard let phoneNumber = appState.currentUser?.phoneNumber else {
            return "Unknown"
        }

        let cleaned = phoneNumber.replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression)

        if cleaned.hasPrefix("+1") && cleaned.count == 12 {
            let areaCode = String(cleaned.dropFirst(2).prefix(3))
            let prefix = String(cleaned.dropFirst(5).prefix(3))
            let suffix = String(cleaned.suffix(4))
            return "+1 (\(areaCode)) \(prefix)-\(suffix)"
        }

        return phoneNumber
    }

    private var hasChanges: Bool {
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName != appState.currentUser?.displayName || selectedPhoto != nil
    }

    private func loadImage(from item: PhotosPickerItem?) {
        guard let item else { return }

        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                profileImage = Image(uiImage: uiImage)
            }
        }
    }

    private func saveProfile() {
        guard let authService = appState.authService,
              let userId = appState.currentUser?.id else { return }

        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)

        isSaving = true

        Task {
            do {
                // TODO: Upload profile image to Firebase Storage if changed
                let profileImageURL: String? = appState.currentUser?.profileImageURL

                try await authService.updateProfile(
                    userId: userId,
                    displayName: trimmedName,
                    profileImageURL: profileImageURL
                )

                // Update local user
                appState.currentUser?.displayName = trimmedName

                dismiss()
            } catch {
                print("Failed to save profile: \(error)")
            }
            isSaving = false
        }
    }

    private func deleteAccount() {
        // In a real app, this would:
        // 1. Call a Cloud Function to delete user data
        // 2. Delete the Firebase Auth account
        // 3. Sign out and return to welcome screen

        print("Would delete account")
    }
}

// MARK: - Current Profile Image

private struct CurrentProfileImage: View {
    let user: User?
    let size: CGFloat

    var body: some View {
        if let user {
            if let imageURL = user.profileImageURL,
               let url = URL(string: imageURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    InitialsView(user: user, size: size)
                }
                .frame(width: size, height: size)
                .clipShape(Circle())
            } else {
                InitialsView(user: user, size: size)
            }
        } else {
            Circle()
                .fill(Color(.systemGray5))
                .frame(width: size, height: size)
                .overlay {
                    Image(systemName: "person.fill")
                        .font(.system(size: size * 0.4))
                        .foregroundStyle(.secondary)
                }
        }
    }
}

private struct InitialsView: View {
    let user: User
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

    private var initials: String {
        let components = user.displayName.split(separator: " ")
        if components.count >= 2 {
            return "\(components[0].prefix(1))\(components[1].prefix(1))".uppercased()
        }
        return String(user.displayName.prefix(2)).uppercased()
    }
}

#Preview {
    ProfileView()
        .environment(AppState())
}
