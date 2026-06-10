import CoreImage.CIFilterBuiltins
import SwiftUI

/// Invite sheet: big readable code, QR for in-person sharing, and the
/// native share sheet for everything else. Leaders can rotate the code.
struct InviteSheetView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    let eventID: String

    var body: some View {
        NavigationStack {
            if let event = model.event(withID: eventID) {
                ScrollView {
                    VStack(spacing: PlanrSpacing.xl) {
                        Text("Get the gang in")
                            .font(PlanrFont.screenTitle)
                            .padding(.top, PlanrSpacing.lg)

                        if let qr = qrImage(for: InviteCodeFactory.shareURL(for: event.inviteCode).absoluteString) {
                            Image(uiImage: qr)
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 180, height: 180)
                                .padding(PlanrSpacing.md)
                                .background(.white,
                                            in: RoundedRectangle(cornerRadius: PlanrRadius.card))
                                .accessibilityLabel("QR code for invite \(event.inviteCode)")
                        }

                        Text(event.inviteCode)
                            .font(.title2.monospaced().bold())
                            .padding(.horizontal, PlanrSpacing.lg)
                            .padding(.vertical, PlanrSpacing.sm)
                            .background(Capsule().fill(.secondary.opacity(0.12)))
                            .textSelection(.enabled)

                        Text(event.privacy == .approvalRequired
                             ? "You'll approve each person before they're in."
                             : "Anyone with this code can join.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        ShareLink(item: InviteCodeFactory.shareURL(for: event.inviteCode),
                                  subject: Text("Join \(event.title) on Planr"),
                                  message: Text(InviteCodeFactory.shareMessage(for: event))) {
                            Label("Share invite", systemImage: "square.and.arrow.up")
                                .font(PlanrFont.cardTitle)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, PlanrSpacing.xs)
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.horizontal, PlanrSpacing.screenMargin)

                        if model.isLeader(of: event) {
                            Button(role: .destructive) {
                                model.regenerateInviteCode(for: event)
                            } label: {
                                Label("Revoke & make a new code", systemImage: "arrow.triangle.2.circlepath")
                                    .font(.subheadline)
                            }
                        }
                    }
                    .padding(.bottom, PlanrSpacing.xxl)
                }
                .background(PlanrColor.backgroundPrimary.ignoresSafeArea())
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
            }
        }
    }

    private func qrImage(for string: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        guard let output = filter.outputImage?
            .transformed(by: CGAffineTransform(scaleX: 8, y: 8)) else { return nil }
        let context = CIContext()
        guard let cgImage = context.createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
