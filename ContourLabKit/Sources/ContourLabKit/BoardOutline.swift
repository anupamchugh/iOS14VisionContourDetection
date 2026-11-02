import CoreGraphics
import Foundation

/// Where a board photo's millimetres come from.
///
/// There is no bank-card option here, unlike for coins. A card's long side is 85.6 mm, so on a photo
/// that fits a 6-foot board it spans about 4% of the frame: one pixel of error on the card becomes
/// 2–3% of every measurement, close to an inch on the board's length. The card would also have to lie
/// flat beside the board at exactly the board's height. The board's own length, which riders know
/// from the shaper's stamp, spans the whole photo, so the same pixel of error costs 0.1%.
public enum ScaleSource: Sendable, Equatable {
    /// The board's overall length as the rider typed it, in millimetres.
    case typedLength(millimetres: Double)
    /// Reserved for a later step: LiDAR scene depth (`ARFrame.sceneDepth`) on a device that has it,
    /// which would give millimetres without typing anything. Not built yet.
    case lidarDepth
}

/// A surfboard's outline and the measures shapers quote, from one top-down photo of the board lying on
/// the floor.
///
/// The board is the largest object `ShapeCounter` finds. Its long axis (the stringer line) is the
/// principal axis of its pixels, so the photo can be turned any way. Everything is scaled from
/// `ScaleSource.typedLength`. Thickness, rocker and volume can't be read from above: they need a side
/// photo or depth.
public struct BoardOutline: Sendable {
    public enum Failure: Error, Equatable {
        /// Nothing in the photo stands out from the floor.
        case noBoard
        /// The scale source isn't available yet (LiDAR).
        case scaleUnavailable
        /// Shorter than 24 inches, so the nose and tail stations would overlap.
        case tooShort
    }

    /// One point of the half-outline: how far from the nose, and half the width there. Millimetres.
    public struct Station: Sendable, Equatable {
        public let fromNose: Double
        public let halfWidth: Double
    }

    /// Nose and tail widths are taken this far from each end: 12 inches.
    public static let endStation = 304.8

    public let scale: ScaleSource
    /// Millimetres. With a typed length this is the typed length.
    public let length: Double
    /// Width at the widest point, in millimetres.
    public let wideWidth: Double
    /// How far the wide point is from the middle of the length, in millimetres. Positive is towards the
    /// nose (ahead of centre), negative towards the tail (behind).
    public let widePointFromCentre: Double
    /// Width 12 inches from the nose tip, in millimetres.
    public let noseWidth: Double
    /// Width 12 inches from the tail, in millimetres.
    public let tailWidth: Double
    /// Half-widths from nose to tail at even steps, for drawing or exporting the curve.
    public let halfCurve: [Station]
    /// Other objects in the photo that were left out because they're smaller than the board.
    public let otherObjects: Int

    // For drawing over the photo: 0...1 on both axes, origin at the top left.
    /// The board's edge, nose to tail along one rail and back along the other.
    public let outline: [CGPoint]
    public let nose: CGPoint
    public let tail: CGPoint
    public let wideLine: (start: CGPoint, end: CGPoint)
    public let noseLine: (start: CGPoint, end: CGPoint)
    public let tailLine: (start: CGPoint, end: CGPoint)

    /// Says which object was measured when there was more than one.
    public var otherObjectsNote: String? {
        guard otherObjects > 0 else { return nil }
        return "Measured the largest object as the board; ignored \(otherObjects) smaller object\(otherObjects == 1 ? "" : "s")."
    }

    /// - Parameter swapsEnds: The narrower, more pointed end is taken as the nose. Pass `true` when that
    ///   guess is wrong, as it can be for a round-nosed longboard with a pin tail.
    public init(tracing image: CGImage, scale: ScaleSource, counter: ShapeCounter = ShapeCounter(), swapsEnds: Bool = false) throws {
        guard case .typedLength(let typedLength) = scale else { throw Failure.scaleUnavailable }
        guard typedLength > 2 * Self.endStation else { throw Failure.tooShort }
        guard let (mask, areas) = try counter.objectAreas(in: image),
              let board = areas.max(by: { $0.count < $1.count }) else { throw Failure.noBoard }

        // Principal axis of the board's pixels: for a board, the stringer line.
        let points = board.map { SIMD2<Double>(Double($0 % mask.width) + 0.5, Double($0 / mask.width) + 0.5) }
        let mean = points.reduce(.zero, +) / Double(points.count)
        var sxx = 0.0, syy = 0.0, sxy = 0.0
        for p in points {
            let d = p - mean
            sxx += d.x * d.x; syy += d.y * d.y; sxy += d.x * d.y
        }
        let angle = 0.5 * atan2(2 * sxy, sxx - syy)
        let axis = SIMD2(cos(angle), sin(angle)), across = SIMD2(-sin(angle), cos(angle))
        let along = points.map { ($0 - mean).dot(axis) }
        let side = points.map { ($0 - mean).dot(across) }
        let uMin = along.min()! - 0.5, uMax = along.max()! + 0.5

        let profile = Profile(along: along, side: side, from: uMin, to: uMax)
        let lengthPixels = uMax - uMin
        let millimetres = typedLength / lengthPixels

        // A tail is cut off (squash, square, swallow) and so wider an inch from its end than a nose is.
        let inch = 25.4 / millimetres
        let startIsNose = (profile.width(at: uMin + inch) <= profile.width(at: uMax - inch)) != swapsEnds
        let noseU = startIsNose ? uMin : uMax, direction = startIsNose ? 1.0 : -1.0
        func u(fromNose s: Double) -> Double { noseU + direction * s }

        // The wide point: the middle of the stretch within half a pixel of the widest width. Near it the
        // rails run almost parallel, so on a flat-sided longboard that stretch can be several inches long.
        let steps = Int(lengthPixels * 2)
        let widths = (0...steps).map { profile.width(at: u(fromNose: Double($0) / 2)) }
        let smoothed = widths.indices.map { i in
            let window = widths[max(0, i - 2)...min(widths.count - 1, i + 2)]
            return window.reduce(0, +) / Double(window.count)
        }
        let widest = smoothed.max() ?? 0
        let plateau = smoothed.indices.filter { smoothed[$0] >= widest - 0.5 }
        let wideS = Double(plateau.reduce(0, +)) / Double(max(plateau.count, 1)) / 2

        let station = Self.endStation / millimetres
        length = typedLength
        wideWidth = widest * millimetres
        widePointFromCentre = (lengthPixels / 2 - wideS) * millimetres
        noseWidth = profile.width(at: u(fromNose: station)) * millimetres
        tailWidth = profile.width(at: u(fromNose: lengthPixels - station)) * millimetres
        otherObjects = areas.count - 1
        self.scale = scale

        let count = 60
        let samples = (0...count).map { min(max(Double($0) / Double(count) * lengthPixels, 0.75), lengthPixels - 0.75) }
        halfCurve = samples.map { Station(fromNose: $0 * millimetres, halfWidth: profile.width(at: u(fromNose: $0)) * millimetres / 2) }

        let size = SIMD2(Double(mask.width), Double(mask.height))
        func picture(_ u: Double, _ v: Double) -> CGPoint {
            let p = (mean + axis * u + across * v) / size
            return CGPoint(x: p.x, y: p.y)
        }
        func line(atNose s: Double) -> (start: CGPoint, end: CGPoint) {
            let edges = profile.edges(at: u(fromNose: s))
            return (picture(u(fromNose: s), edges.lower), picture(u(fromNose: s), edges.upper))
        }
        let rails = samples.map { line(atNose: $0) }
        outline = rails.map { $0.start } + rails.reversed().map { $0.end }
        nose = picture(noseU, 0)
        tail = picture(u(fromNose: lengthPixels), 0)
        wideLine = line(atNose: wideS)
        noseLine = line(atNose: station)
        tailLine = line(atNose: lengthPixels - station)
    }

    /// The board's extent across its axis, read in thin slices along it.
    struct Profile {
        private let start: Double
        private var lower: [Double], upper: [Double]
        private static let slice = 0.5

        init(along: [Double], side: [Double], from start: Double, to end: Double) {
            self.start = start
            let count = Int((end - start) / Self.slice) + 1
            lower = Array(repeating: .infinity, count: count)
            upper = Array(repeating: -.infinity, count: count)
            for (u, v) in zip(along, side) {
                let index = min(count - 1, max(0, Int((u - start) / Self.slice)))
                lower[index] = min(lower[index], v)
                upper[index] = max(upper[index], v)
            }
        }

        /// The outermost pixel edges on each side, from slices within 0.75 px of `u`.
        func edges(at u: Double) -> (lower: Double, upper: Double) {
            let first = max(0, Int((u - 0.75 - start) / Self.slice))
            let last = min(lower.count - 1, Int((u + 0.75 - start) / Self.slice))
            guard first <= last else { return (0, 0) }
            let low = lower[first...last].min()!, high = upper[first...last].max()!
            return low <= high ? (low - 0.5, high + 0.5) : (0, 0)
        }

        func width(at u: Double) -> Double {
            let edges = edges(at: u)
            return edges.upper - edges.lower
        }
    }
}

private extension SIMD2 where Scalar == Double {
    func dot(_ other: Self) -> Double { x * other.x + y * other.y }
}

/// Board lengths as riders write them (6'2"), and inches as shapers quote them (19 ¼").
public enum BoardLength {
    /// Millimetres from text such as `6'2"`, `6' 2`, `6-2`, `9'` or `74"`. Nil when it can't tell.
    public static func millimetres(from text: String) -> Double? {
        let text = text.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "’", with: "'").replacingOccurrences(of: "′", with: "'")
            .replacingOccurrences(of: "”", with: "\"").replacingOccurrences(of: "″", with: "\"")
            .replacingOccurrences(of: "''", with: "\"")
        let inches: Double
        if let match = text.wholeMatch(of: #/(\d{1,2})\s*(?:'|ft|-|\s)\s*(\d{1,2}(?:\.\d+)?)?\s*(?:"|in)?/#) {
            let extra = match.2.flatMap { Double($0) } ?? 0
            guard extra < 12 else { return nil }
            inches = Double(match.1)! * 12 + extra
        } else if let match = text.wholeMatch(of: #/(\d{2,3}(?:\.\d+)?)\s*(?:"|in)/#) {
            inches = Double(match.1)!
        } else {
            return nil
        }
        return inches > 0 ? inches * 25.4 : nil
    }

    /// Feet and inches to the nearest inch: `6'2"`.
    public static func feetAndInches(_ millimetres: Double) -> String {
        let inches = Int((millimetres / 25.4).rounded())
        return "\(inches / 12)'\(inches % 12)\""
    }

    /// Inches to the nearest eighth: `19 ¼"`.
    public static func inches(_ millimetres: Double) -> String {
        let eighths = Int((millimetres / 25.4 * 8).rounded())
        let fractions = ["", "⅛", "¼", "⅜", "½", "⅝", "¾", "⅞"]
        let whole = eighths / 8, fraction = fractions[eighths % 8]
        if fraction.isEmpty { return "\(whole)\"" }
        return whole == 0 ? "\(fraction)\"" : "\(whole) \(fraction)\""
    }
}
