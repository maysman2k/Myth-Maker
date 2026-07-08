import UIKit

/// Turns a photo into a brick-mosaic preview: sample the image into a stud
/// grid, snap each cell to the chosen brick palette, then draw studs.
enum MosaicRenderer {
    struct Output {
        var preview: UIImage
        var estimate: MosaicEstimate
    }

    static func generate(from image: UIImage, size: MosaicSize, colourMode: MosaicColourMode) -> Output? {
        let (width, height) = size.studs
        guard let grid = sampleGrid(from: image.normalisedUp(), width: width, height: height) else {
            return nil
        }
        let mapped = MosaicEngine.mapGrid(grid, mode: colourMode)
        let estimate = MosaicEngine.estimate(for: mapped)
        let preview = renderPreview(mapped)
        return Output(preview: preview, estimate: estimate)
    }

    /// Aspect-fill samples the image into a `width` × `height` grid of RGB values.
    static func sampleGrid(from image: UIImage, width: Int, height: Int) -> [[RGB]]? {
        guard width > 0, height > 0, let cgImage = image.cgImage else { return nil }
        let bytesPerRow = width * 4
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)
        let scale = max(CGFloat(width) / imageWidth, CGFloat(height) / imageHeight)
        let drawWidth = imageWidth * scale
        let drawHeight = imageHeight * scale
        let drawRect = CGRect(
            x: (CGFloat(width) - drawWidth) / 2,
            y: (CGFloat(height) - drawHeight) / 2,
            width: drawWidth,
            height: drawHeight
        )
        context.interpolationQuality = .high
        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.draw(cgImage, in: drawRect)

        guard let data = context.data else { return nil }
        let buffer = data.bindMemory(to: UInt8.self, capacity: bytesPerRow * height)

        var grid: [[RGB]] = []
        grid.reserveCapacity(height)
        // CGContext row 0 is the bottom of the image; flip so the grid reads top-down.
        for y in stride(from: height - 1, through: 0, by: -1) {
            var row: [RGB] = []
            row.reserveCapacity(width)
            for x in 0..<width {
                let offset = y * bytesPerRow + x * 4
                row.append(RGB(r: Int(buffer[offset]), g: Int(buffer[offset + 1]), b: Int(buffer[offset + 2])))
            }
            grid.append(row)
        }
        return grid
    }

    /// Draws the mapped grid as studded brick cells.
    static func renderPreview(_ mapped: [[BrickPaletteColour]], cellSize: CGFloat = 14) -> UIImage {
        let rows = mapped.count
        let columns = mapped.first?.count ?? 0
        let canvasSize = CGSize(width: CGFloat(columns) * cellSize, height: CGFloat(rows) * cellSize)
        let renderer = UIGraphicsImageRenderer(size: canvasSize)
        return renderer.image { context in
            for (rowIndex, row) in mapped.enumerated() {
                for (columnIndex, colour) in row.enumerated() {
                    let rect = CGRect(
                        x: CGFloat(columnIndex) * cellSize,
                        y: CGFloat(rowIndex) * cellSize,
                        width: cellSize,
                        height: cellSize
                    )
                    let base = UIColor(
                        red: CGFloat(colour.rgb.r) / 255,
                        green: CGFloat(colour.rgb.g) / 255,
                        blue: CGFloat(colour.rgb.b) / 255,
                        alpha: 1
                    )
                    base.setFill()
                    context.fill(rect)

                    // Stud: a subtle highlight circle with a shaded rim.
                    let studRect = rect.insetBy(dx: cellSize * 0.22, dy: cellSize * 0.22)
                    UIColor.black.withAlphaComponent(0.14).setStroke()
                    let rim = UIBezierPath(ovalIn: studRect)
                    rim.lineWidth = max(1, cellSize * 0.07)
                    rim.stroke()
                    UIColor.white.withAlphaComponent(0.16).setFill()
                    UIBezierPath(ovalIn: studRect.insetBy(dx: rim.lineWidth, dy: rim.lineWidth)).fill()
                }
            }
        }
    }
}

extension UIImage {
    /// Redraws the image so its orientation metadata is baked in, giving the
    /// sampler a predictable pixel layout.
    func normalisedUp() -> UIImage {
        guard imageOrientation != .up else { return self }
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
