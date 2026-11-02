import CoreGraphics
import Foundation
import Vision

/// One round object that was counted.
public struct CountedObject: Sendable, Identifiable {
    public let id: Int
    /// The fitted circle, 0...1 on both axes, origin at the top left (ready for SwiftUI).
    public let boundingBox: CGRect
    /// Diameter in pixels of the source image.
    public let diameter: Double
}

public struct CountResult: Sendable {
    public let objects: [CountedObject]
    /// Vision's outlines of the object areas, 0...1 on both axes, origin at the top left.
    public let outlines: [[CGPoint]]
    /// Objects grouped by size, smallest group first.
    public let groups: [[CountedObject]]
    public let summary: CountSummary
}

/// Counts round things on a plain background: coins, fruit, pills, seeds.
///
/// 1. `BackgroundMask` separates objects from the background by colour.
/// 2. Vision's `VNDetectContoursRequest` outlines the object areas.
/// 3. `CircleFinder` places one circle per object, so touching objects still count separately.
public struct ContourCounter: Sendable {
    public var mask = BackgroundMask()
    /// Smallest counted radius, as a fraction of the image's shorter side.
    public var minimumRadiusFraction = 0.015
    /// A new size group starts when an object is this much wider than the previous one.
    public var groupGap = 0.08

    public init() {}

    public func count(in image: CGImage) throws -> CountResult {
        guard let objectMask = mask.mask(for: image), let maskImage = objectMask.image() else {
            return Self.result(objects: [], outlines: [], groupGap: groupGap)
        }
        let width = Double(objectMask.width), height = Double(objectMask.height)
        let toSource = Double(image.width) / width

        let circles = CircleFinder.circles(
            in: objectMask,
            minimumRadius: minimumRadiusFraction * min(width, height)
        )
        let objects = circles.enumerated().map { index, circle in
            CountedObject(
                id: index,
                boundingBox: CGRect(
                    x: (circle.x - circle.radius) / width, y: (circle.y - circle.radius) / height,
                    width: 2 * circle.radius / width, height: 2 * circle.radius / height
                ),
                diameter: 2 * circle.radius * toSource
            )
        }

        let outlines = try Self.outlines(
            of: maskImage, width: width, height: height,
            minimumArea: .pi * pow(minimumRadiusFraction * min(width, height), 2)
        )
        return Self.result(objects: objects, outlines: outlines, groupGap: groupGap)
    }

    /// Vision's outlines of the object areas in a black-on-white mask, 0...1, origin at the top left.
    static func outlines(of maskImage: CGImage, width: Double, height: Double, minimumArea: Double) throws -> [[CGPoint]] {
        let request = VNDetectContoursRequest()
        request.detectsDarkOnLight = true
        request.maximumImageDimension = Int(max(width, height))
        try VNImageRequestHandler(cgImage: maskImage).perform([request])
        return (request.results?.first?.topLevelContours ?? []).compactMap { contour -> [CGPoint]? in
            // Vision's points are normalized with the origin at the bottom left.
            let points = contour.normalizedPoints.map { CGPoint(x: Double($0.x), y: 1 - Double($0.y)) }
            let area = ShapeMetrics(points: points.map { CGPoint(x: $0.x * width, y: $0.y * height) }).area
            return area >= minimumArea ? points : nil
        }
    }

    static func result(objects: [CountedObject], outlines: [[CGPoint]], groupGap: Double) -> CountResult {
        let sorted = objects.sorted { $0.diameter < $1.diameter }
        let sizes = SizeGrouping.groups(diameters: sorted.map(\.diameter), relativeGap: groupGap).map(\.count)
        var groups: [[CountedObject]] = []
        var start = 0
        for size in sizes {
            groups.append(Array(sorted[start..<(start + size)]))
            start += size
        }
        let ratio = (sorted.last?.diameter ?? 1) / max(sorted.first?.diameter ?? 1, 1)
        return CountResult(
            objects: objects,
            outlines: outlines,
            groups: groups,
            summary: CountSummary(count: objects.count, groupCounts: sizes, largestToSmallest: ratio)
        )
    }
}
