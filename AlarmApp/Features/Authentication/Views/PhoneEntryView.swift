import SwiftUI

/// Phone number entry view for Firebase Phone Auth
struct PhoneEntryView: View {
    @Environment(AppState.self) private var appState

    @State private var selectedCountry = AuthenticationService.countryCodes[0]
    @State private var phoneNumber = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showCountryPicker = false
    @State private var navigateToVerification = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                // App icon and title
                VStack(spacing: 16) {
                    Image(systemName: "alarm.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.orange)

                    Text("WakeUp")
                        .font(.largeTitle.bold())

                    Text("The alarm that actually works")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Phone input section
                VStack(spacing: 16) {
                    Text("Enter your phone number")
                        .font(.headline)

                    Text("We'll send you a verification code")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    // Phone number input
                    HStack(spacing: 12) {
                        // Country code button
                        Button {
                            showCountryPicker = true
                        } label: {
                            HStack(spacing: 4) {
                                Text(selectedCountry.flag)
                                Text(selectedCountry.code)
                                    .fontWeight(.medium)
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 14)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)

                        // Phone number field
                        TextField("Phone number", text: $phoneNumber)
                            .keyboardType(.phonePad)
                            .textContentType(.telephoneNumber)
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
                }

                Spacer()

                // Continue button
                Button {
                    startVerification()
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
                    .background(isValidPhoneNumber ? Color.orange : Color.gray)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(!isValidPhoneNumber || isLoading)
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .navigationDestination(isPresented: $navigateToVerification) {
                VerificationCodeView(phoneNumber: fullPhoneNumber)
            }
            .sheet(isPresented: $showCountryPicker) {
                CountryPickerView(selectedCountry: $selectedCountry)
            }
        }
    }

    private var fullPhoneNumber: String {
        selectedCountry.code + phoneNumber.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
    }

    private var isValidPhoneNumber: Bool {
        let digits = phoneNumber.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        return digits.count >= 10
    }

    private func startVerification() {
        guard let authService = appState.authService else { return }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                try await authService.startPhoneVerification(phoneNumber: fullPhoneNumber)
                navigateToVerification = true
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

// MARK: - Country Picker

struct CountryPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedCountry: (code: String, name: String, flag: String)

    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredCountries, id: \.code) { country in
                    Button {
                        selectedCountry = country
                        dismiss()
                    } label: {
                        HStack {
                            Text(country.flag)
                            Text(country.name)
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(country.code)
                                .foregroundStyle(.secondary)

                            if country.code == selectedCountry.code {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search countries")
            .navigationTitle("Select Country")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var filteredCountries: [(code: String, name: String, flag: String)] {
        if searchText.isEmpty {
            return AuthenticationService.countryCodes
        }
        return AuthenticationService.countryCodes.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.code.contains(searchText)
        }
    }
}

#Preview {
    PhoneEntryView()
        .environment(AppState())
}
