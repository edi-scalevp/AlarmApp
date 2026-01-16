import SwiftUI
import PhotosUI

/// Profile setup view for new users to set their display name and optional photo
struct ProfileSetupView: View {
    @Environment(AppState.self) private var appState

    @State private var displayName = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var profileImage: Image?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Header
            VStack(spacing: 16) {
                Text("Set Up Your Profile")
                    .font(.title.bold())

                Text("This is how friends will see you")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Profile photo
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                ZStack {
                    if let profileImage {
                        profileImage
                            .resizable()
                            .scaledToFill()
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color(.systemGray5))
                            .frame(width: 120, height: 120)
                            .overlay {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 48))
                                    .foregroundStyle(.secondary)
                            }
                    }

                    // Edit badge
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 32, height: 32)
                        .overlay {
                            Image(systemName: "camera.fill")
                                .font(.caption)
                                .foregroundStyle(.white)
                        }
                        .offset(x: 40, y: 40)
                }
            }
            .onChange(of: selectedPhoto) { _, newValue in
                loadImage(from: newValue)
            }

            // Display name input
            VStack(alignment: .leading, spacing: 8) {
                Text("Display Name")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextField("Your name", text: $displayName)
                    .textContentType(.name)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal)

            // Error message
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            Spacer()

            // Continue button
            Button {
                saveProfile()
            } label: {
                HStack {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Continue")
                        Image(systemName: "arrow.right")
                    }
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(isValidName ? Color.orange : Color.gray)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(!isValidName || isLoading)
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
    }

    private var isValidName: Bool {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
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

        isLoading = true
        errorMessage = nil

        Task {
            do {
                // TODO: Upload profile image to Firebase Storage if selected
                let profileImageURL: String? = nil

                try await authService.updateProfile(
                    userId: userId,
                    displayName: trimmedName,
                    profileImageURL: profileImageURL
                )

                // Update local user
                appState.currentUser?.displayName = trimmedName
                appState.currentUser?.profileImageURL = profileImageURL

                // Move to main app
                appState.authState = .authenticated

            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

#Preview {
    ProfileSetupView()
        .environment(AppState())
}
