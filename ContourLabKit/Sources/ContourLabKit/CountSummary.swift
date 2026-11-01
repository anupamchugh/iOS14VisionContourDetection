import Foundation

/// The sentence the app shows. Every number in it comes from Vision's measurements.
public struct CountSummary: Sendable, Equatable {
    public let count: Int
    public let groupCounts: [Int]
    public let largestToSmallest: Double

    public init(count: Int, groupCounts: [Int], largestToSmallest: Double) {
        self.count = count
        self.groupCounts = groupCounts
        self.largestToSmallest = largestToSmallest
    }

    public var sentence: String {
        switch count {
        case 0:
            return "Found no round objects."
        case 1:
            return "Found 1 round object."
        default:
            let ratio = String(format: "%.1f", largestToSmallest)
            guard groupCounts.count > 1 else {
                return "Found \(count) round objects of about the same size."
            }
            let list = ListFormatter.localizedString(byJoining: groupCounts.map(String.init))
            return "Found \(count) round objects in \(groupCounts.count) size groups (\(list)). "
                + "The largest is \(ratio)× the width of the smallest."
        }
    }
}
