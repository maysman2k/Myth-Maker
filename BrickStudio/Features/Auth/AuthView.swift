import SwiftUI

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
    @State private var errorMessage: String?
    @State private var isSendingMagicLink = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: BrickSpacing.l) {
                    Image(systemName: "circle.grid.3x3.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(BrickColor.gold)
                        .padding(.top, BrickSpacing.l)
                    Text("Bricks in a Bag Studio")
                        .font(BrickFont.sectionTitle)
                        .foregroundStyle(BrickColor.primaryText)

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
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(BrickFont.meta)
                            .foregroundStyle(BrickColor.brickRed)
                            .multilineTextAlignment(.center)
                    }

                    Button {
                        submit()
                    } label: {
                        Text(mode == .signIn ? "Continue" : "Create Account")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(StudButtonStyle())

                    if mode == .signIn {
                        Button {
                            magicLink()
                        } label: {
                            Label(isSendingMagicLink ? "Checking…" : "Email me a magic link", systemImage: "wand.and.stars")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(StudButtonStyle(tint: BrickColor.gold, prominent: false))
                        .disabled(isSendingMagicLink)
                    }

                    VStack(spacing: BrickSpacing.s) {
                        socialButton("Continue with Apple", symbol: "apple.logo")
                        socialButton("Continue with Google", symbol: "globe")
                    }

                    Text("Demo accounts: admin@bricksinabag.com, editor@bricksinabag.com or jess@example.com — password \(SeedFactory.demoPassword)")
                        .font(.system(size: 11))
                        .foregroundStyle(BrickColor.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.top, BrickSpacing.s)
                }
                .padding(BrickSpacing.l)
            }
            .background(BrickColor.background)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now") { dismiss() }
                }
            }
        }
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

    private func socialButton(_ title: String, symbol: String) -> some View {
        Button {
            model.showToast("Social sign-in is coming in a future update.", symbol: "info.circle")
        } label: {
            Label(title, systemImage: symbol)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(StudButtonStyle(tint: BrickColor.primaryText, prominent: false))
    }

    private func submit() {
        errorMessage = nil
        do {
            switch mode {
            case .signIn:
                try model.signIn(email: email, password: password)
            case .create:
                try model.signUp(displayName: displayName, email: email, password: password)
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func magicLink() {
        errorMessage = nil
        isSendingMagicLink = true
        do {
            try model.signInWithMagicLink(email: email)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSendingMagicLink = false
    }
}
