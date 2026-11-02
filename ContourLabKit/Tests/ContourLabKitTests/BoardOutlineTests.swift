import CoreGraphics
import Foundation
import Testing
@testable import ContourLabKit

/// A board outline built from the measures a shaper would quote, in inches.
///
/// The half-width is a monotone cubic through five points: nose tip, 12 inches from the nose, the wide
/// point (flat there), 12 inches from the tail, and the tail block. So the drawn board has exactly the
/// quoted widths, and its widest point is exactly where it says.
struct SyntheticBoard {
    var length: Double
    var wide: Double
    /// Positive is ahead of centre.
    var widePointFromCentre: Double
    var nose: Double
    var tail: Double
    var tailBlock: Double
    /// Slope at the nose tip relative to the first segment's average: 3 is round, 1.5 is pointed.
    var noseRoundness: Double

    static let shortboard = SyntheticBoard(length: 74, wide: 19.25, widePointFromCentre: -1, nose: 11.5, tail: 14.25, tailBlock: 9.5, noseRoundness: 1.5)
    static let longboard = SyntheticBoard(length: 108, wide: 22.5, widePointFromCentre: 1, nose: 17.5, tail: 14.5, tailBlock: 11, noseRoundness: 3)

    func halfWidth(fromNose s: Double) -> Double {
        let widePoint = length / 2 - widePointFromCentre
        let knots: [(s: Double, h: Double)] = [(0, 0), (12, nose / 2), (widePoint, wide / 2), (length - 12, tail / 2), (length, tailBlock / 2)]
        let secants = (0..<4).map { (knots[$0 + 1].h - knots[$0].h) / (knots[$0 + 1].s - knots[$0].s) }
        func harmonic(_ a: Double, _ b: Double) -> Double { 2 / (1 / a + 1 / b) }
        let slopes = [noseRoundness * secants[0], harmonic(secants[0], secants[1]), 0, harmonic(secants[2], secants[3]), 1.5 * secants[3]]
        let i = min(3, max(0, (0..<4).last { knots[$0].s <= s } ?? 0))
        let span = knots[i + 1].s - knots[i].s, t = (s - knots[i].s) / span
        let t2 = t * t, t3 = t2 * t
        return (2 * t3 - 3 * t2 + 1) * knots[i].h + (t3 - 2 * t2 + t) * span * slopes[i]
            + (-2 * t3 + 3 * t2) * knots[i + 1].h + (t3 - t2) * span * slopes[i + 1]
    }

    /// Fills the board centred at (x, y) in the context's coordinates, nose towards `degrees`.
    /// Returns the nose tip's position in the image, 0...1 from the top left.
    @discardableResult
    func draw(in context: CGContext, x: Double, y: Double, pixelsPerInch: Double, degrees: Double) -> CGPoint {
        let steps = Int(length * 4)
        let rail = (0...steps).map { Double($0) / 4 }.map { CGPoint(x: length / 2 - $0, y: halfWidth(fromNose: $0)) }
        let other = rail.reversed().map { CGPoint(x: $0.x, y: -$0.y) }
        context.saveGState()
        context.translateBy(x: x, y: y)
        context.rotate(by: degrees * .pi / 180)
        context.scaleBy(x: pixelsPerInch, y: pixelsPerInch)
        context.addLines(between: rail + other)
        context.closePath()
        context.fillPath()
        context.restoreGState()
        let angle = degrees * .pi / 180, reach = length / 2 * pixelsPerInch
        return CGPoint(x: (x + cos(angle) * reach) / Double(context.width), y: 1 - (y + sin(angle) * reach) / Double(context.height))
    }
}

struct BoardOutlineTests {
    static let board = CGColor(red: 0.97, green: 0.96, blue: 0.9, alpha: 1)

    static func floor(width: Int, height: Int, stripes: Bool = false, draw: (CGContext) -> Void) -> CGImage {
        let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(CGColor(red: 0.45, green: 0.47, blue: 0.5, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        if stripes {
            // Floorboards: alternating warm planks the colour mask can't tell from a board.
            for (index, x) in stride(from: 0, to: width, by: 50).enumerated() {
                let shade = index.isMultiple(of: 2) ? 0.78 : 0.42
                context.setFillColor(CGColor(red: shade, green: shade * 0.8, blue: shade * 0.6, alpha: 1))
                context.fill(CGRect(x: x, y: 0, width: 50, height: height))
            }
        }
        context.setFillColor(board)
        draw(context)
        return context.makeImage()!
    }

    static func typed(_ inches: Double) -> ScaleSource { .typedLength(millimetres: inches * 25.4) }

    /// Widths within a quarter inch, as a tape measure on the real board would be read.
    ///
    /// The wide point's position is looser, within 1½ inches. Near it the rails run almost parallel:
    /// on the longboard the width is within 1/50 inch of its widest for about 4 inches, less than a
    /// pixel, so no photo (or tape) pins it closer. What is checked tightly is that the board really is
    /// at its widest, within 1/16 inch, where the wide point is reported.
    static func expectMatches(_ outline: BoardOutline, _ board: SyntheticBoard, widthTolerance: Double = 0.25, sourceLocation: SourceLocation = #_sourceLocation) {
        let inches = { (mm: Double) in mm / 25.4 }
        print("Board", board.length, "→ wide", inches(outline.wideWidth), "at", inches(outline.widePointFromCentre),
              "nose", inches(outline.noseWidth), "tail", inches(outline.tailWidth))
        #expect(abs(inches(outline.length) - board.length) < 0.01, sourceLocation: sourceLocation)
        #expect(abs(inches(outline.wideWidth) - board.wide) < widthTolerance, sourceLocation: sourceLocation)
        #expect(abs(inches(outline.widePointFromCentre) - board.widePointFromCentre) < 1.5, sourceLocation: sourceLocation)
        let reported = board.length / 2 - inches(outline.widePointFromCentre)
        #expect(board.wide - 2 * board.halfWidth(fromNose: reported) < 1.0 / 16, sourceLocation: sourceLocation)
        #expect(abs(inches(outline.noseWidth) - board.nose) < widthTolerance, sourceLocation: sourceLocation)
        #expect(abs(inches(outline.tailWidth) - board.tail) < widthTolerance, sourceLocation: sourceLocation)
        let middle = outline.halfCurve[outline.halfCurve.count / 2]
        #expect(abs(inches(middle.halfWidth) - board.halfWidth(fromNose: inches(middle.fromNose))) < widthTolerance, sourceLocation: sourceLocation)
    }

    @Test func measuresAShortboard() throws {
        var nose = CGPoint.zero
        let image = Self.floor(width: 1200, height: 700) { nose = SyntheticBoard.shortboard.draw(in: $0, x: 600, y: 350, pixelsPerInch: 12, degrees: 180) }
        let outline = try BoardOutline(tracing: image, scale: Self.typed(74))
        Self.expectMatches(outline, .shortboard)
        #expect(hypot(outline.nose.x - nose.x, outline.nose.y - nose.y) < 0.02)
        #expect(outline.otherObjects == 0)
        #expect(outline.otherObjectsNote == nil)
        #expect(outline.halfCurve.count == 61)
    }

    @Test func measuresALongboard() throws {
        let image = Self.floor(width: 1200, height: 600) { SyntheticBoard.longboard.draw(in: $0, x: 600, y: 300, pixelsPerInch: 10, degrees: 0) }
        Self.expectMatches(try BoardOutline(tracing: image, scale: Self.typed(108)), .longboard)
    }

    @Test func measuresATurnedPhoto() throws {
        var nose = CGPoint.zero
        let image = Self.floor(width: 1000, height: 1000) { nose = SyntheticBoard.shortboard.draw(in: $0, x: 500, y: 500, pixelsPerInch: 11, degrees: 125) }
        let outline = try BoardOutline(tracing: image, scale: Self.typed(74))
        Self.expectMatches(outline, .shortboard)
        #expect(hypot(outline.nose.x - nose.x, outline.nose.y - nose.y) < 0.02)
        let swapped = try BoardOutline(tracing: image, scale: Self.typed(74), swapsEnds: true)
        #expect(hypot(swapped.tail.x - nose.x, swapped.tail.y - nose.y) < 0.02)
    }

    @Test func measuresOnABusyFloorWithTheSubjectMask() throws {
        let image = Self.floor(width: 1200, height: 700, stripes: true) { SyntheticBoard.shortboard.draw(in: $0, x: 600, y: 350, pixelsPerInch: 12, degrees: 10) }
        let plain = try? BoardOutline(tracing: image, scale: Self.typed(74))
        #expect(plain.map { abs($0.wideWidth / 25.4 - SyntheticBoard.shortboard.wide) > 1 } ?? true)
        let outline = try BoardOutline(tracing: image, scale: Self.typed(74), counter: ShapeCounter(mask: ForegroundMask()))
        Self.expectMatches(outline, .shortboard, widthTolerance: 0.5)
    }

    @Test func measuresTheLargestOfTwoBoards() throws {
        let image = Self.floor(width: 1400, height: 900) {
            SyntheticBoard.longboard.draw(in: $0, x: 700, y: 620, pixelsPerInch: 11, degrees: 0)
            SyntheticBoard.shortboard.draw(in: $0, x: 700, y: 230, pixelsPerInch: 11, degrees: 180)
        }
        let outline = try BoardOutline(tracing: image, scale: Self.typed(108))
        Self.expectMatches(outline, .longboard)
        #expect(outline.otherObjects == 1)
        #expect(outline.otherObjectsNote == "Measured the largest object as the board; ignored 1 smaller object.")
    }

    @Test func refusesWhatItCannotMeasure() throws {
        let empty = Self.floor(width: 400, height: 300) { _ in }
        #expect(throws: BoardOutline.Failure.noBoard) { try BoardOutline(tracing: empty, scale: Self.typed(74)) }
        let image = Self.floor(width: 1200, height: 700) { SyntheticBoard.shortboard.draw(in: $0, x: 600, y: 350, pixelsPerInch: 12, degrees: 0) }
        #expect(throws: BoardOutline.Failure.scaleUnavailable) { try BoardOutline(tracing: image, scale: .lidarDepth) }
        #expect(throws: BoardOutline.Failure.tooShort) { try BoardOutline(tracing: image, scale: Self.typed(20)) }
    }

    @Test func readsBoardLengthsAsRidersWriteThem() {
        #expect(BoardLength.millimetres(from: "6'2\"") == 74 * 25.4)
        #expect(BoardLength.millimetres(from: "6’2”") == 74 * 25.4)
        #expect(BoardLength.millimetres(from: " 6' 2 ") == 74 * 25.4)
        #expect(BoardLength.millimetres(from: "6-2") == 74 * 25.4)
        #expect(BoardLength.millimetres(from: "9'") == 108 * 25.4)
        #expect(BoardLength.millimetres(from: "5'10.5\"") == 70.5 * 25.4)
        #expect(BoardLength.millimetres(from: "74\"") == 74 * 25.4)
        #expect(BoardLength.millimetres(from: "6'14\"") == nil)
        #expect(BoardLength.millimetres(from: "six two") == nil)
        #expect(BoardLength.millimetres(from: "6.2") == nil)
    }

    @Test func writesInchesAsShapersQuoteThem() {
        #expect(BoardLength.feetAndInches(74 * 25.4) == "6'2\"")
        #expect(BoardLength.inches(19.25 * 25.4) == "19 ¼\"")
        #expect(BoardLength.inches(11.5 * 25.4) == "11 ½\"")
        #expect(BoardLength.inches(14 * 25.4) == "14\"")
        #expect(BoardLength.inches(0.375 * 25.4) == "⅜\"")
    }
}
