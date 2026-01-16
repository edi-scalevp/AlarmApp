import SwiftUI

/// View for adding new friends from contacts
struct AddFriendView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @Bindable var repository: FriendRepository

    @State private var isLoadingContacts = false
    @State private var searchText = ""
    @State private var errorMessage: String?
    @State private var showInviteSheet = false
    @State private var selectedContactForInvite: ContactMatchResult?

    var body: some View {
        NavigationStack {
            Group {
                if !repository.hasContactsAccess {
                    ContactsPermissionView {
                        requestContactsAccess()
                    }
                } else if isLoadingContacts {
                    LoadingContactsView()
                } else {
                    ContactsListView(
                        contacts: filteredContacts,
                        onSendRequest: sendFriendRequest,
                        onInvite: { contact in
                            selectedContactForInvite = contact
                            showInviteSheet = true
                        }
                    )
                }
            }
            .navigationTitle("Add Friends")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search contacts")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .sheet(isPresented: $showInviteSheet) {
                if let contact = selectedContactForInvite {
                    InviteContactSheet(contact: contact)
                }
            }
        }
        .task {
            if repository.hasContactsAccess {
                await loadContacts()
            }
        }
    }

    private var filteredContacts: [ContactMatchResult] {
        if searchText.isEmpty {
            return repository.matchedContacts
        }
        return repository.matchedContacts.filter {
            $0.contactName.localizedCaseInsensitiveContains(searchText) ||
            $0.phoneNumber.contains(searchText)
        }
    }

    private func requestContactsAccess() {
        Task {
            do {
                let granted = try await repository.requestContactsAccess()
                if granted {
                    await loadContacts()
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func loadContacts() async {
        isLoadingContacts = true
        do {
            try await repository.discoverFriendsFromContacts()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingContacts = false
    }

    private func sendFriendRequest(to contact: ContactMatchResult) {
        guard let matchedUser = contact.matchedUser,
              let currentUser = appState.currentUser else { return }

        Task {
            do {
                try await repository.sendFriendRequest(
                    to: matchedUser.id,
                    currentUser: currentUser
                )
                // Remove from list or mark as sent
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Contacts Permission View

private struct ContactsPermissionView: View {
    let onRequestAccess: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 64))
                .foregroundStyle(.orange)

            VStack(spacing: 12) {
                Text("Find Friends from Contacts")
                    .font(.title2.bold())

                Text("We'll check your contacts to find friends who are already using WakeUp. Your contacts are never stored on our servers.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button {
                onRequestAccess()
            } label: {
                HStack {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                    Text("Allow Access to Contacts")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(Color.orange)
                .clipShape(Capsule())
            }

            Spacer()
        }
    }
}

// MARK: - Loading View

private struct LoadingContactsView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Finding friends...")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Contacts List View

private struct ContactsListView: View {
    let contacts: [ContactMatchResult]
    let onSendRequest: (ContactMatchResult) -> Void
    let onInvite: (ContactMatchResult) -> Void

    var body: some View {
        List {
            // Registered users section
            let registered = contacts.filter { $0.isRegistered }
            if !registered.isEmpty {
                Section {
                    ForEach(registered) { contact in
                        ContactRow(
                            contact: contact,
                            onAction: { onSendRequest(contact) }
                        )
                    }
                } header: {
                    Text("On WakeUp (\(registered.count))")
                }
            }

            // Not registered section
            let notRegistered = contacts.filter { !$0.isRegistered }
            if !notRegistered.isEmpty {
                Section {
                    ForEach(notRegistered) { contact in
                        ContactRow(
                            contact: contact,
                            onAction: { onInvite(contact) }
                        )
                    }
                } header: {
                    Text("Invite to WakeUp")
                }
            }

            // Empty state
            if contacts.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 32))
                            .foregroundStyle(.secondary)

                        Text("No contacts found")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                }
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Contact Row

private struct ContactRow: View {
    let contact: ContactMatchResult
    let onAction: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            InitialsAvatar(
                initials: String(contact.contactName.prefix(2)).uppercased(),
                size: 44
            )

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(contact.contactName)
                    .font(.body)

                Text(contact.phoneNumber)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Action button
            Button(action: onAction) {
                Text(contact.isRegistered ? "Add" : "Invite")
                    .font(.subheadline.bold())
                    .foregroundStyle(contact.isRegistered ? .white : .orange)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(contact.isRegistered ? Color.orange : Color.orange.opacity(0.15))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Invite Sheet

private struct InviteContactSheet: View {
    @Environment(\.dismiss) private var dismiss

    let contact: ContactMatchResult

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                // Icon
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 48))
                    .foregroundStyle(.orange)

                // Text
                VStack(spacing: 12) {
                    Text("Invite \(contact.contactName)")
                        .font(.title2.bold())

                    Text("Send them an invitation to join WakeUp so you can be accountability partners!")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer()

                // Share button
                ShareLink(
                    item: URL(string: "https://wakeup.app/invite")!,
                    subject: Text("Join me on WakeUp!"),
                    message: Text("Hey! I'm using WakeUp to help me wake up on time. Want to be my accountability partner? Download the app here:")
                ) {
                    HStack {
                        Image(systemName: "paperplane.fill")
                        Text("Send Invite")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .navigationTitle("Invite Friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    AddFriendView(repository: FriendRepository())
        .environment(AppState())
}
