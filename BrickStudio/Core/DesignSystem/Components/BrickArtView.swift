import SwiftUI

/// Procedurally drawn brick-inspired artwork used wherever content has no
/// licensed image — the safe image fallback from §10.9. Deterministic per
/// seed, so each item keeps a stable look.
struct BrickArtView: View {
    var seed: Int
    var tint: Color
    var symbol: String?

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                LinearGradient(
                    colors: [tint.opacity(0.9), tint.opacity(0.55)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Canvas { context, canvasSize in
                    var random = SplitMix64(seed: UInt64(bitPattern: Int64(seed)))
                    // Stud grid texture.
                    let stud: CGFloat = 22
                    var y: CGFloat = stud / 2
                    while y < canvasSize.height {
                        var x: CGFloat = stud / 2
                        while x < canvasSize.width {
                            let circle = Path(ellipseIn: CGRect(x: x - 4, y: y - 4, width: 8, height: 8))
                            context.stroke(circle, with: .color(.white.opacity(0.10)), lineWidth: 1)
                            x += stud
                        }
                        y += stud
                    }
                    // A few scattered translucent "bricks".
                    for _ in 0..<5 {
                        let width = CGFloat(random.next(in: 40...110))
                        let height = width * 0.48
                        let originX = CGFloat(random.next(in: 0...Double(max(1, canvasSize.width - width))))
                        let originY = CGFloat(random.next(in: 0...Double(max(1, canvasSize.height - height))))
                        let rect = CGRect(x: originX, y: originY, width: width, height: height)
                        let path = Path(roundedRect: rect, cornerRadius: 6)
                        context.fill(path, with: .color(.white.opacity(0.08)))
                        // Studs on top of the brick.
                        let studCount = max(1, Int(width / 26))
                        for index in 0..<studCount {
                            let studX = rect.minX + (width / CGFloat(studCount)) * (CGFloat(index) + 0.5)
                            let studRect = CGRect(x: studX - 5, y: rect.minY + 6, width: 10, height: 10)
                            context.fill(Path(ellipseIn: studRect), with: .color(.white.opacity(0.12)))
                        }
                    }
                }
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: min(size.width, size.height) * 0.3, weight: .light))
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
        }
        .clipped()
        .accessibilityHidden(true)
    }
}

/// Small deterministic random generator for the art view.
struct SplitMix64 {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed &+ 0x9E3779B97F4A7C15
    }

    mutating func nextValue() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    mutating func next(in range: ClosedRange<Double>) -> Double {
        let unit = Double(nextValue() >> 11) / Double(1 << 53)
        return range.lowerBound + unit * (range.upperBound - range.lowerBound)
    }
}

extension ArticleCategory {
    var artTint: Color {
        switch self {
        case .stadiumBuilds, .events: return BrickColor.stadiumGreen
        case .rumours, .retiringSoon, .deals: return BrickColor.brickRed
        case .bricksInABagUpdates, .officialReveals: return Color(hex: 0x20325C)
        default: return BrickColor.gold
        }
    }
}

extension UUID {
    /// Stable art seed derived from the identifier.
    var artSeed: Int {
        var hash = 5381
        for byte in uuidString.utf8 {
            hash = ((hash << 5) &+ hash) &+ Int(byte)
        }
        return hash
    }
}
