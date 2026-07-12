import Foundation
import UIKit

struct LegoColour: Hashable {
    let name: String
    let elementID: String
    let ldrawCode: Int
    let red: Int
    let green: Int
    let blue: Int
}

struct MosaicPart: Codable, Identifiable {
    var id: String { "\(colour)-\(elementID)" }

    let colour: String
    let elementID: String
    let ldrawCode: Int
    let quantity: Int
}

struct MosaicResult {
    let gridSize: Int
    let price: Int
    let preview: UIImage
    let parts: [MosaicPart]
    let ldraw: String

    var totalBricks: Int {
        gridSize * gridSize
    }

    var gridLabel: String {
        "\(gridSize) x \(gridSize)"
    }
}

enum MosaicBackground: String, CaseIterable, Identifiable {
    case white
    case black
    case yellow
    case orange
    case blue
    case darkGrey

    var id: String { rawValue }

    var label: String {
        switch self {
        case .white:
            return "White"
        case .black:
            return "Black"
        case .yellow:
            return "Yellow"
        case .orange:
            return "Orange"
        case .blue:
            return "Blue"
        case .darkGrey:
            return "Dark grey"
        }
    }

    var uiColor: UIColor {
        switch self {
        case .white:
            return .white
        case .black:
            return .black
        case .yellow:
            return UIColor(red: 1.0, green: 0.82, blue: 0.18, alpha: 1)
        case .orange:
            return UIColor(red: 0.93, green: 0.45, blue: 0.12, alpha: 1)
        case .blue:
            return UIColor(red: 0.45, green: 0.59, blue: 0.78, alpha: 1)
        case .darkGrey:
            return UIColor(red: 0.22, green: 0.21, blue: 0.20, alpha: 1)
        }
    }
}

enum MosaicGrid: Int, CaseIterable, Hashable, Identifiable {
    case small = 32
    case medium = 48
    case large = 64

    var id: Int { rawValue }

    var price: Int {
        switch self {
        case .small:
            return 10500
        case .medium:
            return 19500
        case .large:
            return 29500
        }
    }

    var label: String {
        "\(rawValue)x\(rawValue)"
    }
}
