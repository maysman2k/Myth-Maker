import Foundation

/// A simple RGB colour in 0...255 components, independent of UIKit so the
/// mosaic maths can be unit tested.
struct RGB: Equatable, Hashable {
    var r: Int
    var g: Int
    var b: Int
}

struct BrickPaletteColour: Equatable, Hashable {
    var name: String
    var rgb: RGB
}

enum BrickPalette {
    static let fullColour: [BrickPaletteColour] = [
        .init(name: "Black", rgb: RGB(r: 27, g: 27, b: 27)),
        .init(name: "Dark Grey", rgb: RGB(r: 99, g: 95, b: 98)),
        .init(name: "Light Grey", rgb: RGB(r: 160, g: 165, b: 169)),
        .init(name: "White", rgb: RGB(r: 244, g: 244, b: 244)),
        .init(name: "Red", rgb: RGB(r: 180, g: 0, b: 0)),
        .init(name: "Dark Red", rgb: RGB(r: 114, g: 14, b: 15)),
        .init(name: "Orange", rgb: RGB(r: 214, g: 121, b: 35)),
        .init(name: "Yellow", rgb: RGB(r: 250, g: 200, b: 10)),
        .init(name: "Tan", rgb: RGB(r: 222, g: 198, b: 156)),
        .init(name: "Brown", rgb: RGB(r: 88, g: 57, b: 39)),
        .init(name: "Green", rgb: RGB(r: 0, g: 133, b: 43)),
        .init(name: "Dark Green", rgb: RGB(r: 39, g: 70, b: 44)),
        .init(name: "Blue", rgb: RGB(r: 30, g: 90, b: 168)),
        .init(name: "Dark Blue", rgb: RGB(r: 32, g: 50, b: 92)),
        .init(name: "Azure", rgb: RGB(r: 104, g: 195, b: 226)),
        .init(name: "Pink", rgb: RGB(r: 228, g: 173, b: 200))
    ]

    static let limited: [BrickPaletteColour] = [
        .init(name: "Black", rgb: RGB(r: 27, g: 27, b: 27)),
        .init(name: "White", rgb: RGB(r: 244, g: 244, b: 244)),
        .init(name: "Grey", rgb: RGB(r: 130, g: 130, b: 132)),
        .init(name: "Red", rgb: RGB(r: 180, g: 0, b: 0)),
        .init(name: "Yellow", rgb: RGB(r: 250, g: 200, b: 10)),
        .init(name: "Blue", rgb: RGB(r: 30, g: 90, b: 168))
    ]

    static let blackAndWhite: [BrickPaletteColour] = [
        .init(name: "Black", rgb: RGB(r: 27, g: 27, b: 27)),
        .init(name: "Dark Grey", rgb: RGB(r: 80, g: 80, b: 82)),
        .init(name: "Grey", rgb: RGB(r: 130, g: 130, b: 132)),
        .init(name: "Light Grey", rgb: RGB(r: 190, g: 192, b: 194)),
        .init(name: "White", rgb: RGB(r: 244, g: 244, b: 244))
    ]

    static let sepia: [BrickPaletteColour] = [
        .init(name: "Brown", rgb: RGB(r: 62, g: 40, b: 26)),
        .init(name: "Reddish Brown", rgb: RGB(r: 110, g: 70, b: 42)),
        .init(name: "Nougat", rgb: RGB(r: 170, g: 125, b: 85)),
        .init(name: "Tan", rgb: RGB(r: 222, g: 198, b: 156)),
        .init(name: "Cream", rgb: RGB(r: 246, g: 235, b: 210))
    ]

    static func palette(for mode: MosaicColourMode) -> [BrickPaletteColour] {
        switch mode {
        case .fullColour: return fullColour
        case .limitedPalette: return limited
        case .blackAndWhite: return blackAndWhite
        case .sepia: return sepia
        }
    }
}

struct MosaicEstimate: Equatable {
    var brickCount: Int
    var colourCount: Int
    var difficulty: LessonDifficulty
}

enum MosaicEngine {
    /// Nearest palette colour by squared Euclidean distance in RGB space.
    /// Black-and-white and sepia modes match on luminance so the tonal
    /// mapping survives strongly coloured input.
    static func nearestColour(to sample: RGB, in palette: [BrickPaletteColour], matchLuminance: Bool = false) -> BrickPaletteColour {
        guard var best = palette.first else {
            return BrickPaletteColour(name: "Black", rgb: RGB(r: 0, g: 0, b: 0))
        }
        var bestDistance = Int.max
        for colour in palette {
            let distance: Int
            if matchLuminance {
                let delta = luminance(of: sample) - luminance(of: colour.rgb)
                distance = delta * delta
            } else {
                let dr = sample.r - colour.rgb.r
                let dg = sample.g - colour.rgb.g
                let db = sample.b - colour.rgb.b
                distance = dr * dr + dg * dg + db * db
            }
            if distance < bestDistance {
                bestDistance = distance
                best = colour
            }
        }
        return best
    }

    static func luminance(of rgb: RGB) -> Int {
        (rgb.r * 299 + rgb.g * 587 + rgb.b * 114) / 1000
    }

    /// Maps a grid of sampled colours onto the chosen brick palette.
    static func mapGrid(_ grid: [[RGB]], mode: MosaicColourMode) -> [[BrickPaletteColour]] {
        let palette = BrickPalette.palette(for: mode)
        let byLuminance = (mode == .blackAndWhite || mode == .sepia)
        return grid.map { row in
            row.map { nearestColour(to: $0, in: palette, matchLuminance: byLuminance) }
        }
    }

    static func estimate(for mapped: [[BrickPaletteColour]]) -> MosaicEstimate {
        let brickCount = mapped.reduce(0) { $0 + $1.count }
        let colourCount = Set(mapped.flatMap { $0 }).count
        return MosaicEstimate(
            brickCount: brickCount,
            colourCount: colourCount,
            difficulty: difficulty(brickCount: brickCount, colourCount: colourCount)
        )
    }

    static func difficulty(brickCount: Int, colourCount: Int) -> LessonDifficulty {
        if brickCount <= 1024 && colourCount <= 8 { return .beginner }
        if brickCount <= 2304 { return .intermediate }
        return .advanced
    }
}
