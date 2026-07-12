import Foundation

struct CheckoutService {
    private static let squareFullKitEndpoint: URL? = URL(string: "https://biab-mosaic-maker-api-549164471999.europe-west2.run.app/api/payments/square/full-kit")
    private static let squareInstructionsEndpoint: URL? = URL(string: "https://biab-mosaic-maker-api-549164471999.europe-west2.run.app/api/payments/square/instructions")
    private static let orderStatusBaseURL: URL? = URL(string: "https://biab-mosaic-maker-api-549164471999.europe-west2.run.app/api/orders/")

    static func createSquareFullKitPayment(
        result: MosaicResult,
        variant: String,
        sourceID: String,
        customer: CheckoutCustomer
    ) async throws -> SquarePaymentConfirmation {
        guard let squareFullKitEndpoint else {
            throw CheckoutError.notConfigured
        }

        var request = URLRequest(url: squareFullKitEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            SquarePaymentRequest(
                gridSize: result.gridSize,
                variant: variant,
                totalBricks: result.totalBricks,
                uniqueColours: result.parts.count,
                priceGBP: result.price,
                previewPNGBase64: result.preview.pngData()?.base64EncodedString(),
                parts: result.parts,
                ldraw: result.ldraw,
                sourceID: sourceID,
                customer: customer
            )
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CheckoutError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let errorResponse = try? JSONDecoder().decode(CheckoutErrorResponse.self, from: data)
            throw CheckoutError.server(errorResponse?.detail ?? "Payment could not be completed.")
        }

        return try JSONDecoder().decode(SquarePaymentConfirmation.self, from: data)
    }

    static func createSquareInstructionsPayment(
        result: MosaicResult,
        variant: String,
        sourceID: String,
        customer: CheckoutCustomer
    ) async throws -> SquarePaymentConfirmation {
        guard let squareInstructionsEndpoint else {
            throw CheckoutError.notConfigured
        }

        var request = URLRequest(url: squareInstructionsEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            SquarePaymentRequest(
                gridSize: result.gridSize,
                variant: variant,
                totalBricks: result.totalBricks,
                uniqueColours: result.parts.count,
                priceGBP: 500,
                previewPNGBase64: result.preview.pngData()?.base64EncodedString(),
                parts: result.parts,
                ldraw: result.ldraw,
                sourceID: sourceID,
                customer: customer
            )
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CheckoutError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let errorResponse = try? JSONDecoder().decode(CheckoutErrorResponse.self, from: data)
            throw CheckoutError.server(errorResponse?.detail ?? "Payment could not be completed.")
        }

        return try JSONDecoder().decode(SquarePaymentConfirmation.self, from: data)
    }

    static func fetchOrderStatus(orderReference: String) async throws -> OrderStatus {
        guard let orderStatusBaseURL else {
            throw CheckoutError.notConfigured
        }

        let url = orderStatusBaseURL.appendingPathComponent(orderReference)
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CheckoutError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let errorResponse = try? JSONDecoder().decode(CheckoutErrorResponse.self, from: data)
            throw CheckoutError.server(errorResponse?.detail ?? "Order status could not be checked.")
        }

        return try JSONDecoder().decode(OrderStatus.self, from: data)
    }
}

struct CheckoutCustomer: Encodable {
    let email: String
    let name: String
    let addressLine: String
    let city: String
    let postalCode: String
    let country: String

    var isComplete: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !addressLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !postalCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasContactDetails: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    enum CodingKeys: String, CodingKey {
        case email
        case name
        case addressLine = "address_line"
        case city
        case postalCode = "postal_code"
        case country
    }
}

struct SquarePaymentConfirmation: Decodable {
    let orderReference: String
    let paymentID: String
    let status: String
    let paid: Bool
    let fulfilmentURL: String
    let message: String

    enum CodingKeys: String, CodingKey {
        case orderReference = "order_reference"
        case paymentID = "payment_id"
        case status
        case paid
        case fulfilmentURL = "fulfilment_url"
        case message
    }
}

struct OrderStatus: Decodable {
    let orderReference: String
    let status: String
    let paid: Bool
    let paidAt: String?
    let product: String
    let gridSize: Int
    let variant: String
    let priceGBP: Int?
    let customerEmail: String?
    let customerName: String?
    let deliveryAddress: DeliveryAddress?
    let message: String

    enum CodingKeys: String, CodingKey {
        case orderReference = "order_reference"
        case status
        case paid
        case paidAt = "paid_at"
        case product
        case gridSize = "grid_size"
        case variant
        case priceGBP = "price_gbp"
        case customerEmail = "customer_email"
        case customerName = "customer_name"
        case deliveryAddress = "delivery_address"
        case message
    }
}

struct DeliveryAddress: Decodable {
    let formattedAddress: String?
    let addressLine: String?
    let city: String?
    let postalCode: String?
    let country: String?

    var displayText: String {
        if let formattedAddress, !formattedAddress.isEmpty {
            return formattedAddress
        }

        return [addressLine, city, postalCode, country]
            .compactMap { value in
                guard let value, !value.isEmpty else { return nil }
                return value
            }
            .joined(separator: "\n")
    }

    enum CodingKeys: String, CodingKey {
        case formattedAddress = "formatted_address"
        case addressLine = "address_line"
        case city
        case postalCode = "postal_code"
        case country
    }
}

enum CheckoutError: LocalizedError {
    case notConfigured
    case invalidResponse
    case invalidCheckoutURL
    case server(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Checkout is not connected yet."
        case .invalidResponse:
            return "Checkout returned an invalid response."
        case .invalidCheckoutURL:
            return "Checkout returned an invalid payment link."
        case .server(let message):
            return message
        }
    }
}

private struct CheckoutRequest: Encodable {
    let gridSize: Int
    let variant: String
    let totalBricks: Int
    let uniqueColours: Int
    let priceGBP: Int
    let previewPNGBase64: String?
    let parts: [MosaicPart]
    let ldraw: String

    enum CodingKeys: String, CodingKey {
        case gridSize = "grid_size"
        case variant
        case totalBricks = "total_bricks"
        case uniqueColours = "unique_colours"
        case priceGBP = "price_gbp"
        case previewPNGBase64 = "preview_png_base64"
        case parts
        case ldraw
    }
}

private struct SquarePaymentRequest: Encodable {
    let gridSize: Int
    let variant: String
    let totalBricks: Int
    let uniqueColours: Int
    let priceGBP: Int
    let previewPNGBase64: String?
    let parts: [MosaicPart]
    let ldraw: String
    let sourceID: String
    let customer: CheckoutCustomer

    enum CodingKeys: String, CodingKey {
        case gridSize = "grid_size"
        case variant
        case totalBricks = "total_bricks"
        case uniqueColours = "unique_colours"
        case priceGBP = "price_gbp"
        case previewPNGBase64 = "preview_png_base64"
        case parts
        case ldraw
        case sourceID = "source_id"
        case customer
    }
}

private struct CheckoutErrorResponse: Decodable {
    let detail: String
}
