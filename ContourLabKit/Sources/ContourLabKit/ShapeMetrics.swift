import CoreGraphics
import Foundation

/// Area, perimeter and roundness of a closed outline.
public struct ShapeMetrics: Sendable, Equatable {
    public let area: Double
    public let perimeter: Double

    public init(points: [CGPoint]) {
        guard points.count >= 3 else {
            area = 0
            perimeter = 0
            return
        }
        var twiceArea = 0.0
        var length = 0.0
        for index in points.indices {
            let a = points[index]
            let b = points[(index + 1) % points.count]
            twiceArea += Double(a.x * b.y - b.x * a.y)
            length += Double(hypot(b.x - a.x, b.y - a.y))
        }
        area = abs(twiceArea) / 2
        perimeter = length
    }

    /// 4πA/P²: 1 for a perfect circle, about 0.785 for a square, near 0 for a thin line.
    public var circularity: Double {
        perimeter > 0 ? 4 * .pi * area / (perimeter * perimeter) : 0
    }

    /// The diameter of a circle with the same area.
    public var diameter: Double {
        2 * (area / .pi).squareRoot()
    }
}

public enum SizeGrouping {
    /// Sorts diameters and starts a new group wherever the next one is more than `relativeGap` larger.
    public static func groups(diameters: [Double], relativeGap: Double) -> [[Double]] {
        var groups: [[Double]] = []
        for diameter in diameters.sorted() {
            if let last = groups.last?.last, diameter <= last * (1 + relativeGap) {
                groups[groups.count - 1].append(diameter)
            } else {
                groups.append([diameter])
            }
        }
        return groups
    }
}
