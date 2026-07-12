import Foundation
import UIKit

enum MosaicGeneratorError: LocalizedError {
    case invalidImage
    case couldNotReadPixels

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "That image could not be opened. Please choose a JPG or PNG photo."
        case .couldNotReadPixels:
            return "The app could not read the image pixels."
        }
    }
}

struct MosaicGenerator {
    private static let palette: [LegoColour] = [
        LegoColour(name: "Aqua", elementID: "6058016", ldrawCode: 118, red: 180, green: 210, blue: 227),
        LegoColour(name: "Black", elementID: "302426", ldrawCode: 0, red: 27, green: 42, blue: 52),
        LegoColour(name: "Brick Yellow", elementID: "4159553", ldrawCode: 19, red: 215, green: 197, blue: 153),
        LegoColour(name: "Bright Blue", elementID: "302423", ldrawCode: 1, red: 13, green: 105, blue: 171),
        LegoColour(name: "Bright Bluish Green", elementID: "6213778", ldrawCode: 3, red: 0, green: 143, blue: 155),
        LegoColour(name: "Bright Green", elementID: "6401817", ldrawCode: 10, red: 75, green: 151, blue: 74),
        LegoColour(name: "Bright Orange", elementID: "4524929", ldrawCode: 25, red: 218, green: 133, blue: 64),
        LegoColour(name: "Bright Purple", elementID: "6217797", ldrawCode: 5, red: 123, green: 46, blue: 129),
        LegoColour(name: "Bright Red", elementID: "302421", ldrawCode: 4, red: 196, green: 40, blue: 28),
        LegoColour(name: "Bright Reddish Violet", elementID: "6096942", ldrawCode: 26, red: 200, green: 112, blue: 160),
        LegoColour(name: "Bright Yellow", elementID: "302424", ldrawCode: 14, red: 242, green: 205, blue: 55),
        LegoColour(name: "Bright Yellowish Green", elementID: "4621557", ldrawCode: 27, red: 164, green: 189, blue: 71),
        LegoColour(name: "Cool Yellow", elementID: "6058014", ldrawCode: 226, red: 255, green: 236, blue: 108),
        LegoColour(name: "Dark Azur", elementID: "6151664", ldrawCode: 321, red: 0, green: 143, blue: 206),
        LegoColour(name: "Dark Brown", elementID: "6194729", ldrawCode: 308, red: 53, green: 33, blue: 0),
        LegoColour(name: "Dark Green", elementID: "302428", ldrawCode: 2, red: 24, green: 70, blue: 50),
        LegoColour(name: "Dark Orange", elementID: "6186012", ldrawCode: 484, red: 169, green: 85, blue: 30),
        LegoColour(name: "Dark Stone Grey", elementID: "4210719", ldrawCode: 72, red: 99, green: 95, blue: 98),
        LegoColour(name: "Earth Blue", elementID: "4184108", ldrawCode: 272, red: 25, green: 50, blue: 90),
        LegoColour(name: "Earth Green", elementID: "6055169", ldrawCode: 288, red: 0, green: 69, blue: 26),
        LegoColour(name: "Flame Yellowish Orange", elementID: "6073040", ldrawCode: 191, red: 252, green: 172, blue: 0),
        LegoColour(name: "Lavender", elementID: "6099363", ldrawCode: 31, red: 205, green: 164, blue: 222),
        LegoColour(name: "Light Nougat", elementID: "6357797", ldrawCode: 78, red: 246, green: 215, blue: 179),
        LegoColour(name: "Light Purple", elementID: "6031883", ldrawCode: 29, red: 228, green: 173, blue: 200),
        LegoColour(name: "Light Royal Blue", elementID: "6184484", ldrawCode: 212, red: 159, green: 195, blue: 233),
        LegoColour(name: "Medium Azur", elementID: "6097493", ldrawCode: 322, red: 104, green: 195, blue: 226),
        LegoColour(name: "Medium Blue", elementID: "4179826", ldrawCode: 73, red: 115, green: 150, blue: 200),
        LegoColour(name: "Medium Lavender", elementID: "4619521", ldrawCode: 30, red: 172, green: 120, blue: 186),
        LegoColour(name: "Medium Lilac", elementID: "6231376", ldrawCode: 85, red: 52, green: 43, blue: 117),
        LegoColour(name: "Medium Nougat", elementID: "6215606", ldrawCode: 84, red: 170, green: 125, blue: 85),
        LegoColour(name: "Medium Stone Grey", elementID: "4211399", ldrawCode: 71, red: 160, green: 165, blue: 169),
        LegoColour(name: "New Dark Red", elementID: "4539114", ldrawCode: 320, red: 114, green: 14, blue: 15),
        LegoColour(name: "Nougat", elementID: "6330584", ldrawCode: 92, red: 204, green: 142, blue: 104),
        LegoColour(name: "Olive Green", elementID: "6058245", ldrawCode: 330, red: 155, green: 154, blue: 90),
        LegoColour(name: "Reddish Brown", elementID: "4221744", ldrawCode: 70, red: 88, green: 42, blue: 18),
        LegoColour(name: "Reddish Orange", elementID: "6469084", ldrawCode: 402, red: 203, green: 73, blue: 41),
        LegoColour(name: "Sand Blue", elementID: "6257079", ldrawCode: 379, red: 96, green: 116, blue: 161),
        LegoColour(name: "Sand Green", elementID: "6099189", ldrawCode: 378, red: 120, green: 144, blue: 130),
        LegoColour(name: "Sand Yellow", elementID: "4549436", ldrawCode: 28, red: 160, green: 146, blue: 122),
        LegoColour(name: "Spring Yellowish Green", elementID: "6566896", ldrawCode: 326, red: 226, green: 249, blue: 154),
        LegoColour(name: "Vibrant Coral", elementID: "6258091", ldrawCode: 353, red: 255, green: 105, blue: 143),
        LegoColour(name: "Vibrant Yellow", elementID: "6465247", ldrawCode: 368, red: 255, green: 240, blue: 0),
        LegoColour(name: "Warm Gold", elementID: "6069887", ldrawCode: 297, red: 170, green: 127, blue: 46),
        LegoColour(name: "White", elementID: "302401", ldrawCode: 15, red: 242, green: 243, blue: 242)
    ]

    private static let monochromePaletteNames = [
        "Black",
        "Dark Stone Grey",
        "Medium Stone Grey",
        "White"
    ]

    static func generate(
        from imageData: Data,
        grid: MosaicGrid,
        background: MosaicBackground = .white,
        blackAndWhite: Bool = false
    ) throws -> MosaicResult {
        guard let image = UIImage(data: imageData) else {
            throw MosaicGeneratorError.invalidImage
        }

        let pixelColours = try pixelGrid(
            from: image,
            gridSize: grid.rawValue,
            background: background.uiColor,
            blackAndWhite: blackAndWhite
        )
        let parts = buildPartsList(from: pixelColours)
        let preview = renderPreview(from: pixelColours, gridSize: grid.rawValue)
        let ldraw = buildLDraw(from: pixelColours, gridSize: grid.rawValue)

        return MosaicResult(
            gridSize: grid.rawValue,
            price: grid.price,
            preview: preview,
            parts: parts,
            ldraw: ldraw
        )
    }

    static func hasTransparency(_ imageData: Data) -> Bool {
        guard let image = UIImage(data: imageData),
              let cgImage = image.cgImage,
              let alphaInfo = cgImage.alphaInfo.normalizedAlphaInfo else {
            return false
        }

        guard alphaInfo != .none && alphaInfo != .noneSkipLast && alphaInfo != .noneSkipFirst else {
            return false
        }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        var pixels = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return false
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return stride(from: 3, to: pixels.count, by: bytesPerPixel).contains { pixels[$0] < 255 }
    }

    private static func pixelGrid(
        from image: UIImage,
        gridSize: Int,
        background: UIColor,
        blackAndWhite: Bool
    ) throws -> [[LegoColour]] {
        guard let cgImage = squareRaster(
            from: image,
            background: background,
            outputSize: CGSize(width: gridSize, height: gridSize)
        )?.cgImage else {
            throw MosaicGeneratorError.invalidImage
        }

        let width = gridSize
        let height = gridSize
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        var pixels = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw MosaicGeneratorError.couldNotReadPixels
        }

        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        return (0..<height).map { y in
            (0..<width).map { x in
                let offset = ((y * width) + x) * bytesPerPixel
                let red = Int(pixels[offset])
                let green = Int(pixels[offset + 1])
                let blue = Int(pixels[offset + 2])

                if blackAndWhite {
                    return nearestMonochromeColour(red: red, green: green, blue: blue)
                }

                if isNeutral(red: red, green: green, blue: blue) {
                    return nearestMonochromeColour(red: red, green: green, blue: blue)
                }

                return nearestColour(red: red, green: green, blue: blue)
            }
        }
    }

    private static func squareRaster(
        from image: UIImage,
        background: UIColor,
        outputSize: CGSize
    ) -> UIImage? {
        let side = min(image.size.width, image.size.height)
        let origin = CGPoint(x: (image.size.width - side) / 2, y: (image.size.height - side) / 2)
        let scale = outputSize.width / side
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = true
        format.scale = 1

        return UIGraphicsImageRenderer(size: outputSize, format: format).image { context in
            background.setFill()
            context.fill(CGRect(origin: .zero, size: outputSize))
            image.draw(
                in: CGRect(
                    x: -origin.x * scale,
                    y: -origin.y * scale,
                    width: image.size.width * scale,
                    height: image.size.height * scale
                )
            )
        }
    }

    private static func nearestColour(red: Int, green: Int, blue: Int) -> LegoColour {
        palette.min { lhs, rhs in
            distanceSquared(red, green, blue, lhs) < distanceSquared(red, green, blue, rhs)
        } ?? palette[0]
    }

    private static func isNeutral(red: Int, green: Int, blue: Int) -> Bool {
        let maximum = max(red, green, blue)
        let minimum = min(red, green, blue)
        return maximum - minimum <= 14
    }

    private static func distanceSquared(_ red: Int, _ green: Int, _ blue: Int, _ colour: LegoColour) -> Int {
        let r = red - colour.red
        let g = green - colour.green
        let b = blue - colour.blue
        return (r * r) + (g * g) + (b * b)
    }

    private static func nearestMonochromeColour(red: Int, green: Int, blue: Int) -> LegoColour {
        let monochromePalette = palette.filter { monochromePaletteNames.contains($0.name) }
        return monochromePalette.min { lhs, rhs in
            distanceSquared(red, green, blue, lhs) < distanceSquared(red, green, blue, rhs)
        } ?? nearestColour(red: red, green: green, blue: blue)
    }

    private static func renderPreview(from grid: [[LegoColour]], gridSize: Int) -> UIImage {
        let tileSize = 20
        let border = 1
        let cell = tileSize + border
        let imageSize = (gridSize * cell) + border

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: imageSize, height: imageSize))
        return renderer.image { context in
            UIColor(red: 40 / 255, green: 40 / 255, blue: 40 / 255, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: imageSize, height: imageSize))

            for y in 0..<gridSize {
                for x in 0..<gridSize {
                    let colour = grid[y][x]
                    let px = border + (x * cell)
                    let py = border + (y * cell)
                    UIColor(colour).setFill()
                    context.fill(CGRect(x: px, y: py, width: tileSize, height: tileSize))
                }
            }
        }
    }

    private static func buildPartsList(from grid: [[LegoColour]]) -> [MosaicPart] {
        let counts = grid.flatMap { $0 }.reduce(into: [LegoColour: Int]()) { result, colour in
            result[colour, default: 0] += 1
        }

        return counts
            .map { colour, quantity in
                MosaicPart(
                    colour: colour.name,
                    elementID: colour.elementID,
                    ldrawCode: colour.ldrawCode,
                    quantity: quantity
                )
            }
            .sorted {
                if $0.quantity == $1.quantity {
                    return $0.colour < $1.colour
                }
                return $0.quantity > $1.quantity
            }
    }

    private static func buildLDraw(from grid: [[LegoColour]], gridSize: Int) -> String {
        let half = Double(gridSize - 1) / 2.0
        var lines = [
            "0 Bricks in a Bag Custom Mosaic \(gridSize)x\(gridSize)",
            "0 Generated by BIAB Mosaic Maker for iOS",
            "0 Part: 3070b.dat (1x1 tile)",
            "0 Total bricks: \(gridSize * gridSize)",
            "0"
        ]

        for y in 0..<gridSize {
            for x in 0..<gridSize {
                let colour = grid[y][x]
                let lx = -Int((Double(x) - half) * 20)
                let lz = Int((Double(y) - half) * 20)
                lines.append("1 \(colour.ldrawCode) \(lx) 0 \(lz) 1 0 0 0 1 0 0 0 1 3070b.dat")
            }
        }

        return lines.joined(separator: "\n") + "\n"
    }
}

private extension CGImageAlphaInfo {
    var normalizedAlphaInfo: CGImageAlphaInfo? {
        switch self {
        case .premultipliedLast, .premultipliedFirst, .last, .first, .none, .noneSkipLast, .noneSkipFirst:
            return self
        default:
            return nil
        }
    }
}

private extension UIColor {
    convenience init(_ colour: LegoColour) {
        self.init(
            red: CGFloat(colour.red) / 255,
            green: CGFloat(colour.green) / 255,
            blue: CGFloat(colour.blue) / 255,
            alpha: 1
        )
    }

    convenience init(red: Int, green: Int, blue: Int) {
        self.init(
            red: CGFloat(red) / 255,
            green: CGFloat(green) / 255,
            blue: CGFloat(blue) / 255,
            alpha: 1
        )
    }
}
