import CoreGraphics
import Testing
@testable import ContourLabKit

struct TableSceneTests {
    /// A red disc on the left and a blue disc on the right, on light grey.
    static func twoColours() -> CGImage {
        let context = CGContext(
            data: nil, width: 600, height: 300, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(CGColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 600, height: 300))
        context.setFillColor(CGColor(red: 0.8, green: 0.1, blue: 0.1, alpha: 1))
        context.fillEllipse(in: CGRect(x: 100, y: 100, width: 100, height: 100))
        context.setFillColor(CGColor(red: 0.1, green: 0.2, blue: 0.8, alpha: 1))
        context.fillEllipse(in: CGRect(x: 380, y: 80, width: 140, height: 140))
        return context.makeImage()!
    }

    @Test func eachObjectGetsItsOwnColour() throws {
        let image = Self.twoColours()
        let result = try ContourCounter().count(in: image)
        let colours = ColorSampler.averageColors(in: image, for: result.objects)
        #expect(colours.count == 2)
        let byX = zip(result.objects, colours).sorted { $0.0.boundingBox.midX < $1.0.boundingBox.midX }.map(\.1)
        #expect(byX[0].red > 0.7 && byX[0].blue < 0.25)
        #expect(byX[1].blue > 0.7 && byX[1].red < 0.25)
    }

    @Test func layoutKeepsPositionsAndRelativeSizes() throws {
        let image = Self.twoColours()
        let result = try ContourCounter().count(in: image)
        let scene = TableScene(result: result, imageAspect: 2, colours: ColorSampler.averageColors(in: image, for: result.objects))
        #expect(scene.tableWidth == 0.3)
        #expect(abs(scene.tableDepth - 0.15) < 0.0001)
        let tokens = scene.tokens.sorted { $0.x < $1.x }
        #expect(tokens[0].x < 0 && tokens[1].x > 0)
        // Discs 100 px and 140 px wide in a 600 px photo on a 0.3 m table: 0.05 m and 0.07 m.
        #expect(abs(tokens[0].radius - 0.025) < 0.003)
        #expect(abs(tokens[1].radius - 0.035) < 0.003)
        #expect(tokens.allSatisfy { $0.height > 0 && $0.height < $0.radius })
    }

    @Test func emptyResultHasNoTokens() {
        let scene = TableScene(
            result: CountResult(objects: [], outlines: [], groups: [], summary: CountSummary(count: 0, groupCounts: [], largestToSmallest: 1)),
            imageAspect: 1.5,
            colours: []
        )
        #expect(scene.tokens.isEmpty)
    }
}
