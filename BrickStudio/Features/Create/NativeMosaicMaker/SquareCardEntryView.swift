import SwiftUI
import UIKit
import SquareInAppPaymentsSDK

struct SquareCardEntryView: UIViewControllerRepresentable {
    let onNonce: (String) async throws -> Void
    let onComplete: (Bool) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onNonce: onNonce, onComplete: onComplete)
    }

    func makeUIViewController(context: Context) -> UINavigationController {
        let theme = SQIPTheme()
        theme.tintColor = UIColor(red: 0.93, green: 0.45, blue: 0.12, alpha: 1)
        theme.saveButtonTitle = "Pay now"

        let cardEntryViewController = SQIPCardEntryViewController(theme: theme)
        cardEntryViewController.delegate = context.coordinator
        cardEntryViewController.collectPostalCode = true

        let navigationController = UINavigationController(rootViewController: cardEntryViewController)
        navigationController.presentationController?.delegate = context.coordinator
        return navigationController
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}

    final class Coordinator: NSObject, SQIPCardEntryViewControllerDelegate, UIAdaptivePresentationControllerDelegate {
        let onNonce: (String) async throws -> Void
        let onComplete: (Bool) -> Void
        private var didComplete = false

        init(onNonce: @escaping (String) async throws -> Void, onComplete: @escaping (Bool) -> Void) {
            self.onNonce = onNonce
            self.onComplete = onComplete
        }

        func cardEntryViewController(
            _ cardEntryViewController: SQIPCardEntryViewController,
            didObtain cardDetails: SQIPCardDetails,
            completionHandler: @escaping (Error?) -> Void
        ) {
            Task {
                do {
                    try await onNonce(cardDetails.nonce)
                    await MainActor.run {
                        completionHandler(nil)
                    }
                } catch {
                    await MainActor.run {
                        completionHandler(error)
                    }
                }
            }
        }

        func cardEntryViewController(
            _ cardEntryViewController: SQIPCardEntryViewController,
            didCompleteWith status: SQIPCardEntryCompletionStatus
        ) {
            didComplete = true
            onComplete(status == .success)
        }

        func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
            guard !didComplete else { return }
            didComplete = true
            onComplete(false)
        }
    }
}
