import Foundation
import SquareInAppPaymentsSDK

enum SquarePaymentConfiguration {
    static var applicationID: String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "SQUARE_APPLICATION_ID") as? String else {
            return ""
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static var isConfigured: Bool {
        !applicationID.isEmpty
    }

    @discardableResult
    static func configureSDK() -> Bool {
        guard isConfigured else {
            return false
        }

        SQIPInAppPaymentsSDK.squareApplicationID = applicationID
        return true
    }
}
