import CoreGraphics
import Foundation
import Testing
@testable import ContourLabKit

struct ShapeMetricsTests {
    @Test func squareAreaAndPerimeter() {
        let square = [CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 0), CGPoint(x: 10, y: 10), CGPoint(x: 0, y: 10)]
        let metrics = ShapeMetrics(points: square)
        #expect(metrics.area == 100)
        #expect(metrics.perimeter == 40)
        #expect(abs(metrics.circularity - Double.pi / 4) < 0.0001)
    }

    @Test func clockwiseOrderGivesTheSameArea() {
        let square = [CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 10), CGPoint(x: 10, y: 10), CGPoint(x: 10, y: 0)]
        #expect(ShapeMetrics(points: square).area == 100)
    }

    @Test func circleIsNearlyPerfectlyRound() {
        let circle = (0..<360).map { degree -> CGPoint in
            let angle = Double(degree) * .pi / 180
            return CGPoint(x: 50 + 20 * cos(angle), y: 50 + 20 * sin(angle))
        }
        let metrics = ShapeMetrics(points: circle)
        #expect(metrics.circularity > 0.99)
        #expect(abs(metrics.diameter - 40) < 0.1)
    }

    @Test func thinBarIsNotRound() {
        let bar = [CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 0), CGPoint(x: 100, y: 4), CGPoint(x: 0, y: 4)]
        #expect(ShapeMetrics(points: bar).circularity < 0.2)
    }

    @Test func tooFewPointsHaveNoArea() {
        let metrics = ShapeMetrics(points: [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 1)])
        #expect(metrics.area == 0)
        #expect(metrics.circularity == 0)
    }

    @Test func sizeGroupsSplitOnGaps() {
        let groups = SizeGrouping.groups(diameters: [20, 21, 20.5, 40, 41, 39.5], relativeGap: 0.12)
        #expect(groups.map(\.count) == [3, 3])
    }

    @Test func sizeGroupsKeepCloseSizesTogether() {
        let groups = SizeGrouping.groups(diameters: [20, 21, 22, 23, 24], relativeGap: 0.12)
        #expect(groups.count == 1)
    }

    @Test func summaryUsesOnlyMeasuredNumbers() {
        let summary = CountSummary(count: 8, groupCounts: [5, 3], largestToSmallest: 2.0)
        #expect(summary.sentence == "Found 8 round objects in 2 size groups (5 and 3). The largest is 2.0× the width of the smallest.")
    }

    @Test func summaryForNothingFound() {
        #expect(CountSummary(count: 0, groupCounts: [], largestToSmallest: 1).sentence == "Found no round objects.")
    }

    @Test func summaryForOneObject() {
        #expect(CountSummary(count: 1, groupCounts: [1], largestToSmallest: 1).sentence == "Found 1 round object.")
    }
}
