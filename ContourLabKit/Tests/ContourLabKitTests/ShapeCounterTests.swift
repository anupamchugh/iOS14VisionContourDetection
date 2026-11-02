import CoreGraphics
import Foundation
import Testing
@testable import ContourLabKit

struct ShapeCounterTests {
    static func canvas(width: Int = 800, height: Int = 600, draw: (CGContext) -> Void) -> CGImage {
        let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(CGColor(red: 0.92, green: 0.92, blue: 0.94, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(CGColor(red: 0.3, green: 0.32, blue: 0.36, alpha: 1))
        draw(context)
        return context.makeImage()!
    }

    /// A bar `length` × `width` px centred at (x, y), turned by `degrees`.
    static func bar(_ context: CGContext, x: Double, y: Double, length: Double, width: Double, degrees: Double) {
        context.saveGState()
        context.translateBy(x: x, y: y)
        context.rotate(by: degrees * .pi / 180)
        context.fill(CGRect(x: -length / 2, y: -width / 2, width: length, height: width))
        context.restoreGState()
    }

    @Test func measuresLengthWidthAndRoundnessOfTurnedBars() throws {
        let image = Self.canvas { context in
            Self.bar(context, x: 200, y: 300, length: 240, width: 30, degrees: 30)
            Self.bar(context, x: 560, y: 300, length: 160, width: 20, degrees: -70)
        }
        let result = try ShapeCounter().count(in: image)
        #expect(result.shapes.count == 2)
        let byLength = result.shapes.sorted { $0.length < $1.length }
        #expect(abs(byLength[0].length - 160) < 8)
        #expect(abs(byLength[0].width - 20) < 4)
        #expect(abs(byLength[1].length - 240) < 8)
        #expect(abs(byLength[1].width - 30) < 4)
        #expect(byLength.allSatisfy { $0.roundness < 0.25 })
        #expect(byLength.allSatisfy { $0.kind == .long })
    }

    @Test func discIsRoundAndSquareIsInBetween() throws {
        let image = Self.canvas { context in
            context.fillEllipse(in: CGRect(x: 100, y: 200, width: 160, height: 160))
            context.fill(CGRect(x: 500, y: 200, width: 150, height: 150))
        }
        let result = try ShapeCounter().count(in: image)
        #expect(result.shapes.count == 2)
        let disc = try #require(result.shapes.min { $0.boundingBox.midX < $1.boundingBox.midX })
        let square = try #require(result.shapes.max { $0.boundingBox.midX < $1.boundingBox.midX })
        #expect(disc.roundness > 0.9)
        #expect(disc.kind == .round)
        #expect(abs(disc.area - .pi * 80 * 80) / (.pi * 80 * 80) < 0.03)
        // A square's diagonal is its longest extent: 4A / (π·d²) = 2/π ≈ 0.64.
        #expect(square.roundness > 0.55 && square.roundness < 0.72)
        #expect(square.kind == .compact)
    }

    @Test func ignoresSpecksAndCountsTouchingShapesAsOne() throws {
        let image = Self.canvas { context in
            context.fill(CGRect(x: 100, y: 100, width: 3, height: 3))
            Self.bar(context, x: 300, y: 300, length: 200, width: 30, degrees: 0)
            Self.bar(context, x: 300, y: 300, length: 200, width: 30, degrees: 90)
        }
        let result = try ShapeCounter().count(in: image)
        #expect(result.shapes.count == 1)
    }

    @Test func summaryNamesTheKinds() {
        let summary = ShapeSummary(kinds: [.long: 3, .round: 2], longestToShortest: 2.54)
        #expect(summary.sentence == "Found 5 objects: 3 long, 2 round. The longest is 2.5× the length of the shortest.")
        #expect(ShapeSummary(kinds: [:], longestToShortest: 1).sentence == "Found no objects.")
        #expect(ShapeSummary(kinds: [.compact: 1], longestToShortest: 1).sentence == "Found 1 object: 1 compact.")
    }
}

struct ForegroundMaskTests {
    /// Two shapes on a striped background, where the background colour isn't one colour.
    static func stripes() -> CGImage {
        let context = CGContext(
            data: nil, width: 800, height: 600, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        for (index, x) in stride(from: 0, to: 800, by: 40).enumerated() {
            let shade = index.isMultiple(of: 2) ? 0.95 : 0.6
            context.setFillColor(CGColor(red: shade, green: shade * 0.95, blue: shade * 0.85, alpha: 1))
            context.fill(CGRect(x: x, y: 0, width: 40, height: 600))
        }
        context.setFillColor(CGColor(red: 0.15, green: 0.35, blue: 0.75, alpha: 1))
        ShapeCounterTests.bar(context, x: 230, y: 300, length: 260, width: 40, degrees: 25)
        context.setFillColor(CGColor(red: 0.85, green: 0.2, blue: 0.15, alpha: 1))
        context.fillEllipse(in: CGRect(x: 480, y: 200, width: 200, height: 200))
        return context.makeImage()!
    }

    @Test func plainColourMaskIsConfusedByStripes() throws {
        #expect(try ShapeCounter().count(in: Self.stripes()).shapes.count != 2)
    }

    @Test func foregroundMaskFindsBothShapesOnStripes() throws {
        let result = try ShapeCounter(mask: ForegroundMask()).count(in: Self.stripes())
        print("Foreground shapes:", result.shapes.map { "\($0.kind) \(Int($0.length))×\(Int($0.width))" })
        #expect(result.shapes.count == 2)
        #expect(Set(result.shapes.map(\.kind)) == [.long, .round])
    }
}
