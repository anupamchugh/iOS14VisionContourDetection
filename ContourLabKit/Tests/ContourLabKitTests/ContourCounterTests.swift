import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import ContourLabKit

struct ContourCounterTests {
    /// Five small and three large black discs, plus a thin bar that must not count, on white.
    static func drawnDiscs() -> CGImage {
        let width = 800, height = 600
        let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        for x in stride(from: 80, through: 720, by: 160) {
            context.fillEllipse(in: CGRect(x: x - 30, y: 440, width: 60, height: 60))
        }
        for x in [150, 400, 650] {
            context.fillEllipse(in: CGRect(x: x - 70, y: 180, width: 140, height: 140))
        }
        context.fill(CGRect(x: 100, y: 60, width: 600, height: 12))
        return context.makeImage()!
    }

    static func coins() throws -> CGImage {
        let url = try #require(Bundle.module.url(forResource: "Resources/coins", withExtension: "jpg"))
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        return try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
    }

    @Test func countsDrawnDiscsAndIgnoresTheBar() throws {
        let result = try ContourCounter().count(in: Self.drawnDiscs())
        #expect(result.objects.count == 8)
        #expect(result.groups.map(\.count).sorted() == [3, 5])
        #expect(result.summary.largestToSmallest > 2.0 && result.summary.largestToSmallest < 2.6)
    }

    @Test func objectsCarryNormalizedPaths() throws {
        let result = try ContourCounter().count(in: Self.drawnDiscs())
        for object in result.objects {
            #expect(object.boundingBox.minX >= 0 && object.boundingBox.maxX <= 1)
            #expect(object.boundingBox.minY >= 0 && object.boundingBox.maxY <= 1)
        }
        #expect(!result.outlines.isEmpty)
    }

    @Test func touchingDiscsCountSeparately() throws {
        let context = CGContext(
            data: nil, width: 400, height: 300, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(CGColor(red: 0.85, green: 0.86, blue: 0.9, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 400, height: 300))
        context.setFillColor(CGColor(red: 0.7, green: 0.45, blue: 0.2, alpha: 1))
        context.fillEllipse(in: CGRect(x: 100, y: 100, width: 100, height: 100))
        context.fillEllipse(in: CGRect(x: 195, y: 105, width: 90, height: 90))
        let result = try ContourCounter().count(in: context.makeImage()!)
        #expect(result.objects.count == 2)
        #expect(result.outlines.count == 1)
    }

    @Test func countsCoinsInTheBundledPhoto() throws {
        let result = try ContourCounter().count(in: try Self.coins())
        print("Coins found:", result.objects.count, "groups:", result.groups.map(\.count), "—", result.summary.sentence)
        #expect(result.objects.count == 51)
    }

    @Test func blankImageFindsNothing() throws {
        let context = CGContext(
            data: nil, width: 200, height: 200, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 200, height: 200))
        let result = try ContourCounter().count(in: context.makeImage()!)
        #expect(result.objects.isEmpty)
        #expect(result.summary.sentence == "Found no round objects.")
    }
}
