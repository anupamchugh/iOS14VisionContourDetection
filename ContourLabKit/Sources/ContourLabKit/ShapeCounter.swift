import CoreGraphics
import Foundation

/// One object of any shape, measured from its outline.
public struct MeasuredShape: Sendable, Identifiable {
    public enum Kind: String, Sendable, CaseIterable {
        /// At least 2.5 times longer than wide: screws, nails, pencils, keys.
        case long
        /// Close to a disc: coins, buttons, most cookies.
        case round
        /// Everything in between: squares, leaves, bolts lying flat.
        case compact
    }

    public let id: Int
    /// 0...1 on both axes, origin at the top left.
    public let boundingBox: CGRect
    /// The two points farthest apart, 0...1, origin at the top left: the line the length is measured on.
    public let lengthLine: (start: CGPoint, end: CGPoint)
    /// Pixels of the source image, holes included.
    public let area: Double
    /// Greatest extent in source pixels (the maximum Feret diameter).
    public let length: Double
    /// Narrowest extent in source pixels (the minimum Feret diameter).
    public let width: Double
    /// 4·area / (π·length²): 1 for a disc, about 0.64 for a square, near 0 for a thin rod.
    public let roundness: Double
    public let kind: Kind
}

public struct ShapeSummary: Sendable, Equatable {
    public let kinds: [MeasuredShape.Kind: Int]
    public let longestToShortest: Double

    public init(kinds: [MeasuredShape.Kind: Int], longestToShortest: Double) {
        self.kinds = kinds
        self.longestToShortest = longestToShortest
    }

    public var count: Int { kinds.values.reduce(0, +) }

    public var sentence: String {
        guard count > 0 else { return "Found no objects." }
        let parts = MeasuredShape.Kind.allCases.compactMap { kind in
            kinds[kind].flatMap { $0 > 0 ? "\($0) \(kind.rawValue)" : nil }
        }
        let head = "Found \(count) object\(count == 1 ? "" : "s"): \(parts.joined(separator: ", "))."
        guard count > 1 else { return head }
        return head + " The longest is \(String(format: "%.1f", longestToShortest))× the length of the shortest."
    }
}

public struct ShapeResult: Sendable {
    public let shapes: [MeasuredShape]
    public let outlines: [[CGPoint]]
    public let summary: ShapeSummary
}

/// Counts and measures objects of any shape on a plain background: screws, keys, leaves.
///
/// Each separate area of the object mask is one object, so objects must not touch. Length and width
/// come from the convex hull of the area (its widest and narrowest extent), which doesn't depend on
/// how the object is turned.
public struct ShapeCounter: Sendable {
    /// `BackgroundMask` for a plain background, `ForegroundMask` for a busy one.
    public var mask: any ObjectMasking = BackgroundMask()
    /// Smallest counted object, as a fraction of the image area.
    public var minimumAreaFraction = 0.0005

    public init() {}

    public init(mask: any ObjectMasking) {
        self.mask = mask
    }

    public func count(in image: CGImage) throws -> ShapeResult {
        guard let objectMask = try mask.mask(for: image), let maskImage = objectMask.image() else {
            return ShapeResult(shapes: [], outlines: [], summary: ShapeSummary(kinds: [:], longestToShortest: 1))
        }
        let width = Double(objectMask.width), height = Double(objectMask.height)
        let toSource = Double(image.width) / width
        let minimumArea = minimumAreaFraction * width * height

        var shapes: [MeasuredShape] = []
        for component in Self.components(of: objectMask) where Double(component.count) >= minimumArea {
            let hull = Self.convexHull(Self.boundaryCorners(component, mask: objectMask))
            let feret = Self.feret(hull)
            let area = Double(component.count) * toSource * toSource
            let length = feret.maximum * toSource, narrow = feret.minimum * toSource
            let roundness = length > 0 ? 4 * area / (.pi * length * length) : 0
            let kind: MeasuredShape.Kind = length >= 2.5 * narrow ? .long : (roundness >= 0.85 ? .round : .compact)
            let xs = hull.map(\.x), ys = hull.map(\.y)
            shapes.append(MeasuredShape(
                id: shapes.count,
                boundingBox: CGRect(
                    x: xs.min()! / width, y: ys.min()! / height,
                    width: (xs.max()! - xs.min()!) / width, height: (ys.max()! - ys.min()!) / height
                ),
                lengthLine: (
                    CGPoint(x: feret.start.x / width, y: feret.start.y / height),
                    CGPoint(x: feret.end.x / width, y: feret.end.y / height)
                ),
                area: area, length: length, width: narrow, roundness: roundness, kind: kind
            ))
        }

        let outlines = try ContourCounter.outlines(of: maskImage, width: width, height: height, minimumArea: minimumArea)
        let lengths = shapes.map(\.length)
        let summary = ShapeSummary(
            kinds: Dictionary(grouping: shapes, by: \.kind).mapValues(\.count),
            longestToShortest: (lengths.max() ?? 1) / max(lengths.min() ?? 1, 1)
        )
        return ShapeResult(shapes: shapes, outlines: outlines, summary: summary)
    }

    /// Pixel indices of each 4-connected object area.
    static func components(of mask: ObjectMask) -> [[Int]] {
        let width = mask.width, height = mask.height
        var seen = [Bool](repeating: false, count: mask.pixels.count)
        var components: [[Int]] = []
        for start in mask.pixels.indices where mask.pixels[start] && !seen[start] {
            var component: [Int] = []
            var stack = [start]
            seen[start] = true
            while let index = stack.popLast() {
                component.append(index)
                let x = index % width, y = index / width
                for (nx, ny) in [(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)]
                where nx >= 0 && ny >= 0 && nx < width && ny < height {
                    let next = ny * width + nx
                    if mask.pixels[next] && !seen[next] { seen[next] = true; stack.append(next) }
                }
            }
            components.append(component)
        }
        return components
    }

    /// The four corners of every edge pixel, so the hull spans whole pixels.
    static func boundaryCorners(_ component: [Int], mask: ObjectMask) -> [CGPoint] {
        let width = mask.width, height = mask.height
        var points: [CGPoint] = []
        for index in component {
            let x = index % width, y = index / width
            let onBorder = x == 0 || y == 0 || x == width - 1 || y == height - 1
            let isEdge = onBorder || !(mask.pixels[index - 1] && mask.pixels[index + 1]
                && mask.pixels[index - width] && mask.pixels[index + width])
            guard isEdge else { continue }
            let px = Double(x), py = Double(y)
            points += [CGPoint(x: px, y: py), CGPoint(x: px + 1, y: py), CGPoint(x: px, y: py + 1), CGPoint(x: px + 1, y: py + 1)]
        }
        return points
    }

    /// Andrew's monotone chain.
    static func convexHull(_ points: [CGPoint]) -> [CGPoint] {
        let unique: Set<SIMD2<Double>> = Set(points.map { SIMD2<Double>(Double($0.x), Double($0.y)) })
        let sorted: [SIMD2<Double>] = unique.sorted { (a: SIMD2<Double>, b: SIMD2<Double>) -> Bool in
            a.x != b.x ? a.x < b.x : a.y < b.y
        }
        guard sorted.count > 2 else { return sorted.map { CGPoint(x: $0.x, y: $0.y) } }
        func cross(_ o: SIMD2<Double>, _ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double {
            (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)
        }
        var lower: [SIMD2<Double>] = [], upper: [SIMD2<Double>] = []
        for p in sorted {
            while lower.count >= 2 && cross(lower[lower.count - 2], lower[lower.count - 1], p) <= 0 { lower.removeLast() }
            lower.append(p)
        }
        for p in sorted.reversed() {
            while upper.count >= 2 && cross(upper[upper.count - 2], upper[upper.count - 1], p) <= 0 { upper.removeLast() }
            upper.append(p)
        }
        return (lower.dropLast() + upper.dropLast()).map { CGPoint(x: $0.x, y: $0.y) }
    }

    /// Widest extent (farthest pair of hull points) and narrowest extent (the smallest gap between
    /// two parallel lines that hold the hull, one of them along a hull edge).
    static func feret(_ hull: [CGPoint]) -> (maximum: Double, minimum: Double, start: CGPoint, end: CGPoint) {
        guard hull.count > 1 else { return (0, 0, hull.first ?? .zero, hull.first ?? .zero) }
        var maximum = 0.0, start = hull[0], end = hull[0]
        for i in hull.indices {
            for j in (i + 1)..<hull.count {
                let distance = hypot(hull[i].x - hull[j].x, hull[i].y - hull[j].y)
                if distance > maximum { maximum = distance; start = hull[i]; end = hull[j] }
            }
        }
        var minimum = Double.infinity
        for i in hull.indices {
            let a = hull[i], b = hull[(i + 1) % hull.count]
            let edge = hypot(b.x - a.x, b.y - a.y)
            guard edge > 0 else { continue }
            let dx = Double(b.x - a.x), dy = Double(b.y - a.y)
            var farthest = 0.0
            for point in hull {
                let cross: Double = dx * Double(a.y - point.y) - Double(a.x - point.x) * dy
                farthest = max(farthest, abs(cross) / edge)
            }
            minimum = min(minimum, farthest)
        }
        return (maximum, minimum.isFinite ? minimum : 0, start, end)
    }
}
