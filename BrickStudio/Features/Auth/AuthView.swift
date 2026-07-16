import SwiftUI
import AuthenticationServices
import CryptoKit

struct AuthView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    private enum Mode: String, CaseIterable {
        case signIn = "Sign in"
        case create = "Create account"
    }

    @State private var mode: Mode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var dateOfBirth = Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()
    @State private var errorMessage: String?
    @State private var infoMessage: String?
    @State private var isSubmitting = false
    @State private var awaitingEmailConfirmation = false
    @State private var isShowingReset = false
    // Sign in with Apple replay protection: the raw nonce is hashed into the
    // request; Supabase verifies the raw value against the token.
    @State private var appleNonce = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: BrickSpacing.l) {
                    Image(systemName: "circle.grid.3x3.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(BrickColor.gold)
                        .padding(.top, BrickSpacing.l)
                    Text("Brick Studio")
                        .font(BrickFont.sectionTitle)
                        .foregroundStyle(BrickColor.primaryText)

                    if awaitingEmailConfirmation {
                        confirmationPane
                    } else {
                        formPane
                    }
                }
                .padding(BrickSpacing.l)
            }
            .background { BrickScreenBackground() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now") { dismiss() }
                }
            }
            .sheet(isPresented: $isShowingReset) {
                PasswordResetSheet(initialEmail: email)
            }
        }
    }

    // MARK: Panes

    @ViewBuilder
    private var formPane: some View {
        Picker("Mode", selection: $mode) {
            ForEach(Mode.allCases, id: \.self) { candidate in
                Text(candidate.rawValue).tag(candidate)
            }
        }
        .pickerStyle(.segmented)

        VStack(spacing: BrickSpacing.m) {
            if mode == .create {
                field("Display name", text: $displayName, symbol: "person")
            }
            field("Email", text: $email, symbol: "envelope", keyboard: .emailAddress)
            secureField("Password", text: $password)
            if mode == .create {
                datePickerRow
                Text("You need to be at least 13 to join. We never show your birthday.")
                    .font(.system(size: 11))
                    .foregroundStyle(BrickColor.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }

        if let errorMessage {
            Text(errorMessage)
                .font(BrickFont.meta)
                .foregroundStyle(BrickColor.brickRed)
                .multilineTextAlignment(.center)
        }
        if let infoMessage {
            Text(infoMessage)
                .font(BrickFont.meta)
                .foregroundStyle(BrickColor.stadiumGreen)
                .multilineTextAlignment(.center)
        }

        Button {
            submit()
        } label: {
            HStack {
                if isSubmitting { ProgressView().padding(.trailing, 4) }
                Text(isSubmitting ? "Working…" : (mode == .signIn ? "Sign In" : "Create Account"))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(StudButtonStyle())
        .disabled(isSubmitting)

        if mode == .signIn {
            Button("Forgotten your password?") {
                isShowingReset = true
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(BrickColor.gold)
        }

        divider

        SignInWithAppleButton(.continue) { request in
            appleNonce = Self.randomNonce()
            request.requestedScopes = [.fullName, .email]
            request.nonce = Self.sha256(appleNonce)
        } onCompletion: { result in
            handleAppleCompletion(result)
        }
        .signInWithAppleButtonStyle(.black)
        .frame(height: 50)
        .clipShape(Capsule())
        .accessibilityLabel("Continue with Apple")

        Text("By continuing you agree to the Community Rules and confirm you're 13 or over.")
            .font(.system(size: 11))
            .foregroundStyle(BrickColor.secondaryText)
            .multilineTextAlignment(.center)
            .padding(.top, BrickSpacing.s)
    }

    private var confirmationPane: some View {
        VStack(spacing: BrickSpacing.m) {
            Image(systemName: "envelope.badge")
                .font(.system(size: 44))
                .foregroundStyle(BrickColor.gold)
            Text("Check your inbox")
                .font(BrickFont.sectionTitle)
                .foregroundStyle(BrickColor.primaryText)
            Text("We've sent a confirmation link to \(email). Tap it, then come back and sign in.")
                .font(BrickFont.body)
                .foregroundStyle(BrickColor.secondaryText)
                .multilineTextAlignment(.center)

            if let infoMessage {
                Text(infoMessage)
                    .font(BrickFont.meta)
                    .foregroundStyle(BrickColor.stadiumGreen)
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(BrickFont.meta)
                    .foregroundStyle(BrickColor.brickRed)
            }

            Button("I've confirmed — sign in") {
                awaitingEmailConfirmation = false
                mode = .signIn
                infoMessage = nil
                errorMessage = nil
            }
            .buttonStyle(StudButtonStyle())

            Button("Resend the email") {
                resendConfirmation()
            }
            .buttonStyle(StudButtonStyle(tint: BrickColor.gold, prominent: false))
            .disabled(isSubmitting)
        }
        .padding(.top, BrickSpacing.l)
    }

    private var divider: some View {
        HStack(spacing: BrickSpacing.m) {
            Rectangle().fill(BrickColor.border).frame(height: 1)
            Text("or")
                .font(BrickFont.meta)
                .foregroundStyle(BrickColor.secondaryText)
            Rectangle().fill(BrickColor.border).frame(height: 1)
        }
    }

    private var datePickerRow: some View {
        HStack(spacing: BrickSpacing.s) {
            Image(systemName: "birthday.cake")
                .foregroundStyle(BrickColor.secondaryText)
                .frame(width: 24)
            DatePicker("Date of birth", selection: $dateOfBirth, in: ...Date(), displayedComponents: .date)
                .font(BrickFont.body)
        }
        .padding(BrickSpacing.m)
        .background(BrickColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(BrickColor.border, lineWidth: 1))
    }

    private func field(_ placeholder: String, text: Binding<String>, symbol: String, keyboard: UIKeyboardType = .default) -> some View {
        HStack(spacing: BrickSpacing.s) {
            Image(systemName: symbol)
                .foregroundStyle(BrickColor.secondaryText)
                .frame(width: 24)
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(keyboard == .emailAddress ? .never : .words)
                .autocorrectionDisabled(keyboard == .emailAddress)
        }
        .padding(BrickSpacing.m)
        .background(BrickColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(BrickColor.border, lineWidth: 1))
    }

    private func secureField(_ placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: BrickSpacing.s) {
            Image(systemName: "lock")
                .foregroundStyle(BrickColor.secondaryText)
                .frame(width: 24)
            SecureField(placeholder, text: text)
        }
        .padding(BrickSpacing.m)
        .background(BrickColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(BrickColor.border, lineWidth: 1))
    }

    // MARK: Actions

    private func submit() {
        errorMessage = nil
        infoMessage = nil
        isSubmitting = true
        Task {
            do {
                switch mode {
                case .signIn:
                    try await model.signInWithBackend(email: email, password: password)
                    dismiss()
                case .create:
                    let needsConfirmation = try await model.signUpWithBackend(
                        displayName: displayName,
                        email: email,
                        password: password,
                        dateOfBirth: dateOfBirth
                    )
                    if needsConfirmation {
                        awaitingEmailConfirmation = true
                    } else {
                        dismiss()
                    }
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isSubmitting = false
        }
    }

    private func resendConfirmation() {
        errorMessage = nil
        infoMessage = nil
        isSubmitting = true
        Task {
            do {
                try await model.resendConfirmationEmail(email: email)
                infoMessage = "Confirmation email sent again."
            } catch {
                errorMessage = error.localizedDescription
            }
            isSubmitting = false
        }
    }

    private func handleAppleCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let idToken = String(data: tokenData, encoding: .utf8)
            else {
                errorMessage = "Apple sign-in didn't return a usable token. Try again."
                return
            }
            let fullName = [credential.fullName?.givenName, credential.fullName?.familyName]
                .compactMap { $0 }
                .joined(separator: " ")
            errorMessage = nil
            isSubmitting = true
            Task {
                do {
                    try await model.signInWithApple(
                        idToken: idToken,
                        nonce: appleNonce,
                        fullName: fullName.isEmpty ? nil : fullName
                    )
                    dismiss()
                } catch {
                    errorMessage = error.localizedDescription
                }
                isSubmitting = false
            }
        case .failure(let error):
            // User cancellation isn't an error worth surfacing.
            if (error as? ASAuthorizationError)?.code != .canceled {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: Nonce helpers

    private static func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ-._")
        var result = ""
        for _ in 0..<length {
            var random: UInt8 = 0
            _ = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            result.append(charset[Int(random) % charset.count])
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Password reset

private struct PasswordResetSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var initialEmail: String
    @State private var email = ""
    @State private var message: String?
    @State private var isError = false
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            VStack(spacing: BrickSpacing.l) {
                Image(systemName: "key.horizontal")
                    .font(.system(size: 36))
                    .foregroundStyle(BrickColor.gold)
                    .padding(.top, BrickSpacing.l)
                Text("We'll email you a link to choose a new password.")
                    .font(BrickFont.body)
                    .foregroundStyle(BrickColor.secondaryText)
                    .multilineTextAlignment(.center)

                HStack(spacing: BrickSpacing.s) {
                    Image(systemName: "envelope")
                        .foregroundStyle(BrickColor.secondaryText)
                        .frame(width: 24)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                .padding(BrickSpacing.m)
                .background(BrickColor.card)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(BrickColor.border, lineWidth: 1))

                if let message {
                    Text(message)
                        .font(BrickFont.meta)
                        .foregroundStyle(isError ? BrickColor.brickRed : BrickColor.stadiumGreen)
                        .multilineTextAlignment(.center)
                }

                Button {
                    send()
                } label: {
                    HStack {
                        if isSubmitting { ProgressView().padding(.trailing, 4) }
                        Text("Send reset link")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(StudButtonStyle())
                .disabled(isSubmitting)

                Spacer()
            }
            .padding(BrickSpacing.l)
            .background { BrickScreenBackground() }
            .navigationTitle("Reset password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear { email = initialEmail }
        }
        .presentationDetents([.medium])
    }

    private func send() {
        message = nil
        isSubmitting = true
        Task {
            do {
                try await model.sendPasswordReset(email: email)
                isError = false
                message = "Sent. Check your inbox (and spam) for the reset link."
            } catch {
                isError = true
                message = error.localizedDescription
            }
            isSubmitting = false
        }
    }
}
