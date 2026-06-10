import SwiftUI

struct JoinEventView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var code = ""
    @State private var feedback: String?
    @State private var joinedEventTitle: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: PlanrSpacing.xl) {
                Image(systemName: "qrcode.viewfinder")
                    .font(.system(size: 48))
                    .foregroundStyle(PlanrColor.ember)
                    .padding(.top, PlanrSpacing.xxl)

                Text("Got an invite code?")
                    .font(PlanrFont.screenTitle)

                TextField("PLNR-XXXX-XXXX", text: $code)
                    .textFieldStyle(.roundedBorder)
                    .font(.title3.monospaced())
                    .multilineTextAlignment(.center)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .padding(.horizontal, PlanrSpacing.xxl)

                if let joinedEventTitle {
                    Label("You're in! Welcome to \(joinedEventTitle).", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(PlanrColor.statusSuccess)
                        .font(.subheadline.weight(.semibold))
                } else if let feedback {
                    Text(feedback)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, PlanrSpacing.xl)
                }

                Button {
                    join()
                } label: {
                    Text(joinedEventTitle == nil ? "Join event" : "Done")
                        .font(PlanrFont.cardTitle)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, PlanrSpacing.xs)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, PlanrSpacing.screenMargin)
                .disabled(code.trimmingCharacters(in: .whitespaces).isEmpty && joinedEventTitle == nil)

                Spacer()
            }
            .background(PlanrColor.backgroundPrimary.ignoresSafeArea())
            .navigationTitle("Join an event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func join() {
        if joinedEventTitle != nil {
            dismiss()
            return
        }
        guard InviteCodeFactory.isPlausible(code) else {
            feedback = AppError.invalidInviteCode.errorDescription
            return
        }
        if let event = model.joinEvent(code: code) {
            joinedEventTitle = event.title
            feedback = nil
        } else {
            // Honest about the local-first MVP: cross-device joins arrive
            // with the sync backend.
            feedback = "That code isn't on this device yet. Group sync across devices is coming soon — for now, codes work for events stored on this phone."
        }
    }
}
