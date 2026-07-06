import Foundation

enum MosaicStyle: String, Codable, CaseIterable, Identifiable {
    case portrait = "Portrait"
    case pet = "Pet"
    case footballBadge = "Football badge"
    case stadium = "Stadium"
    case familyPhoto = "Family photo"
    case objectLogo = "Object or logo"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .portrait: return "person.crop.square"
        case .pet: return "pawprint"
        case .footballBadge: return "shield"
        case .stadium: return "sportscourt"
        case .familyPhoto: return "person.3"
        case .objectLogo: return "cube"
        }
    }
}

enum MosaicSize: String, Codable, CaseIterable, Identifiable {
    case small = "Small"
    case medium = "Medium"
    case large = "Large"

    var id: String { rawValue }

    /// Grid size in studs.
    var studs: (width: Int, height: Int) {
        switch self {
        case .small: return (32, 32)
        case .medium: return (48, 48)
        case .large: return (64, 64)
        }
    }

    var approximateDimensions: String {
        // One stud is 8mm.
        let side = studs.width * 8
        let cm = Double(side) / 10
        return "\(studs.width) × \(studs.height) studs · approx. \(cm.formatted(.number.precision(.fractionLength(0...1)))) cm square"
    }
}

enum MosaicColourMode: String, Codable, CaseIterable, Identifiable {
    case fullColour = "Full colour"
    case limitedPalette = "Limited palette"
    case blackAndWhite = "Black and white"
    case sepia = "Sepia / warm"

    var id: String { rawValue }
}

enum MosaicStatus: String, Codable {
    case draft
    case generated
    case sentToBrickBar = "sent_to_brick_bar"
    case archived
}

struct MosaicProject: Identifiable, Codable, Hashable {
    var id: UUID
    var userID: UUID
    var title: String
    var style: MosaicStyle
    var size: MosaicSize
    var widthStuds: Int
    var heightStuds: Int
    var colourMode: MosaicColourMode
    var estimatedBrickCount: Int
    var estimatedColourCount: Int
    var difficulty: LessonDifficulty
    var originalImageFilename: String
    var previewImageFilename: String
    var status: MosaicStatus
    var createdAt: Date
    var updatedAt: Date
}
