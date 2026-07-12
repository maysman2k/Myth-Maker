import SwiftUI

/// Manages the GitHub personal access token used for on-demand scanner runs
/// and editing the news source list. Stored in the iOS Keychain only.
struct GitHubTokenSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onSaved: (() -> Void)?

    @State private var token = ""
    @State private var hasSavedToken = KeychainStore.load(GitHubWorkflowService.tokenKeychainKey)?.isEmpty == false
    @State private var isTesting = false
    @State private var testResult: String?
    @State private var testPassed = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BrickSpacing.l) {
                    Text("GitHub connection")
                        .font(BrickFont.sectionTitle)
                        .foregroundStyle(BrickColor.primaryText)

                    HStack(spacing: BrickSpacing.s) {
                        Image(systemName: hasSavedToken ? "checkmark.seal.fill" : "seal")
                            .foregroundStyle(hasSavedToken ? BrickColor.stadiumGreen : BrickColor.secondaryText)
                        Text(hasSavedToken ? "A token is saved on this device." : "No token saved yet.")
                            .font(BrickFont.meta)
                            .foregroundStyle(BrickColor.secondaryText)
                    }

                    Text("This token lets the app start scanner runs and edit the news source list on \(GitHubWorkflowService.owner)/\(GitHubWorkflowService.repo).")
                        .font(BrickFont.body)
                        .foregroundStyle(BrickColor.secondaryText)

                    VStack(alignment: .leading, spacing: BrickSpacing.s) {
                        stepRow(1, "On github.com: Settings → Developer settings → Personal access tokens → Fine-grained tokens → Generate new token.")
                        stepRow(2, "Resource owner: \(GitHubWorkflowService.owner). Repository access: Only select repositories → \(GitHubWorkflowService.repo).")
                        stepRow(3, "Permissions → Repository permissions: set BOTH “Actions” and “Contents” to Read and write — NOT just Read, or runs and source edits get rejected.")
                        stepRow(4, "Generate, copy the token (starts github_pat_…), and paste it below.")
                    }
                    .padding(BrickSpacing.l)
                    .brickCard()

                    SecureField(hasSavedToken ? "Paste a new token to replace the saved one" : "github_pat_…", text: $token)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(BrickSpacing.m)
                        .background(BrickColor.card)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(BrickColor.border, lineWidth: 1))

                    Button {
                        runTest()
                    } label: {
                        HStack {
                            if isTesting { ProgressView().padding(.trailing, 4) }
                            Text(isTesting ? "Testing…" : "Test Connection")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(StudButtonStyle(tint: BrickColor.stadiumGreen, prominent: false))
                    .disabled(isTesting || (trimmedToken.isEmpty && !hasSavedToken))

                    if let testResult {
                        Label(testResult, systemImage: testPassed ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(BrickFont.meta)
                            .foregroundStyle(testPassed ? BrickColor.stadiumGreen : BrickColor.brickRed)
                    }

                    Button {
                        KeychainStore.save(trimmedToken, for: GitHubWorkflowService.tokenKeychainKey)
                        dismiss()
                        onSaved?()
                    } label: {
                        Text("Save Token")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(StudButtonStyle())
                    .disabled(trimmedToken.isEmpty)

                    if hasSavedToken {
                        Button("Remove saved token", role: .destructive) {
                            KeychainStore.delete(GitHubWorkflowService.tokenKeychainKey)
                            hasSavedToken = false
                            testResult = nil
                        }
                        .font(BrickFont.meta)
                        .foregroundStyle(BrickColor.brickRed)
                    }
                }
                .padding(BrickSpacing.l)
            }
            .background(BrickColor.background)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private var trimmedToken: String {
        token.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Tests the pasted token, or the saved one when the field is empty.
    private func runTest() {
        let candidate = trimmedToken.isEmpty
            ? (KeychainStore.load(GitHubWorkflowService.tokenKeychainKey) ?? "")
            : trimmedToken
        guard !candidate.isEmpty else { return }
        isTesting = true
        testResult = nil
        Task {
            do {
                try await GitHubWorkflowService.verifyToken(candidate)
                testResult = "Token works — write access confirmed. You can run scans and edit sources."
                testPassed = true
            } catch {
                testResult = error.localizedDescription
                testPassed = false
            }
            isTesting = false
        }
    }

    private func stepRow(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: BrickSpacing.m) {
            Text("\(number)")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(BrickColor.gold))
            Text(text)
                .font(BrickFont.meta)
                .foregroundStyle(BrickColor.secondaryText)
        }
    }
}
