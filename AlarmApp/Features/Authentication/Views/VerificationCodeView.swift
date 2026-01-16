import SwiftUI

/// SMS verification code entry view
struct VerificationCodeView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let phoneNumber: String

    @State private var code: [String] = Array(repeating: "", count: 6)
    @State private var focusedIndex: Int = 0
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var resendCountdown = 60
    @State private var canResend = false

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Header
            VStack(spacing: 16) {
                Image(systemName: "message.badge.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.orange)

                Text("Verification Code")
                    .font(.title.bold())

                Text("Enter the 6-digit code sent to")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(formattedPhoneNumber)
                    .font(.headline)
            }

            Spacer()

            // Code input
            VStack(spacing: 24) {
                // Hidden text field for keyboard input
                TextField("", text: Binding(
                    get: { code.joined() },
                    set: { newValue in
                        let filtered = newValue.filter { $0.isNumber }
                        let limited = String(filtered.prefix(6))

                        for (index, char) in limited.enumerated() {
                            code[index] = String(char)
                        }

                        for index in limited.count..<6 {
                            code[index] = ""
                        }

                        focusedIndex = min(limited.count, 5)

                        // Auto-submit when complete
                        if limited.count == 6 {
                            verifyCode()
                        }
                    }
                ))
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($isFocused)
                .frame(width: 0, height: 0)
                .opacity(0)

                // Visual code boxes
                HStack(spacing: 12) {
                    ForEach(0..<6, id: \.self) { index in
                        CodeBox(
                            digit: code[index],
                            isFocused: focusedIndex == index && isFocused
                        )
                        .onTapGesture {
                            isFocused = true
                            focusedIndex = index
                        }
                    }
                }
                .onTapGesture {
                    isFocused = true
                }

                // Error message
                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                // Resend code
                HStack {
                    Text("Didn't receive code?")
                        .foregroundStyle(.secondary)

                    if canResend {
                        Button("Resend") {
                            resendCode()
                        }
                        .fontWeight(.medium)
                        .foregroundStyle(.orange)
                    } else {
                        Text("Resend in \(resendCountdown)s")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.subheadline)
            }

            Spacer()

            // Verify button
            Button {
                verifyCode()
            } label: {
                HStack {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Verify")
                        Image(systemName: "checkmark")
                    }
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(isComplete ? Color.orange : Color.gray)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(!isComplete || isLoading)
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .navigationBarBackButtonHidden(isLoading)
        .onAppear {
            isFocused = true
            startResendCountdown()
        }
    }

    private var formattedPhoneNumber: String {
        // Format for display: +1 (415) 555-1234
        let cleaned = phoneNumber.replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression)

        if cleaned.hasPrefix("+1") && cleaned.count == 12 {
            let areaCode = String(cleaned.dropFirst(2).prefix(3))
            let prefix = String(cleaned.dropFirst(5).prefix(3))
            let suffix = String(cleaned.suffix(4))
            return "+1 (\(areaCode)) \(prefix)-\(suffix)"
        }

        return phoneNumber
    }

    private var isComplete: Bool {
        code.joined().count == 6
    }

    private func verifyCode() {
        guard let authService = appState.authService else { return }

        let fullCode = code.joined()
        guard fullCode.count == 6 else { return }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                let user = try await authService.verifyCode(fullCode)
                appState.currentUser = user

                // Determine next step
                if !appState.hasCompletedOnboarding {
                    appState.authState = .needsOnboarding
                } else if user.displayName.isEmpty {
                    appState.authState = .needsProfileSetup
                } else {
                    appState.authState = .authenticated
                }
            } catch {
                errorMessage = error.localizedDescription
                // Clear code on error
                code = Array(repeating: "", count: 6)
                focusedIndex = 0
            }
            isLoading = false
        }
    }

    private func resendCode() {
        guard let authService = appState.authService else { return }

        canResend = false
        resendCountdown = 60
        startResendCountdown()

        Task {
            do {
                try await authService.startPhoneVerification(phoneNumber: phoneNumber)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func startResendCountdown() {
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            if resendCountdown > 0 {
                resendCountdown -= 1
            } else {
                canResend = true
                timer.invalidate()
            }
        }
    }
}

// MARK: - Code Box

private struct CodeBox: View {
    let digit: String
    let isFocused: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
                .frame(width: 48, height: 56)

            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isFocused ? Color.orange : Color.clear, lineWidth: 2)
                .frame(width: 48, height: 56)

            if digit.isEmpty && isFocused {
                // Cursor
                Rectangle()
                    .fill(Color.orange)
                    .frame(width: 2, height: 24)
                    .opacity(isFocused ? 1 : 0)
            } else {
                Text(digit)
                    .font(.title.bold())
            }
        }
        .animation(.easeInOut(duration: 0.1), value: isFocused)
    }
}

#Preview {
    NavigationStack {
        VerificationCodeView(phoneNumber: "+14155551234")
            .environment(AppState())
    }
}
