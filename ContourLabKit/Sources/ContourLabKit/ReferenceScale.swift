import Foundation

/// A coin of known size lying in the photo, so pixel lengths can be turned into millimetres.
public enum ReferenceCoin: String, Sendable, CaseIterable, Identifiable {
    case euro1, euro2, usQuarter, rupee10

    public var id: Self { self }

    public var name: String {
        switch self {
        case .euro1: "1 € coin"
        case .euro2: "2 € coin"
        case .usQuarter: "US quarter"
        case .rupee10: "₹10 coin"
        }
    }

    public var diameterMillimetres: Double {
        switch self {
        case .euro1: 23.25
        case .euro2: 25.75
        case .usQuarter: 24.26
        case .rupee10: 27
        }
    }
}

/// Millimetres per photo pixel, from one coin's measured width. Only true for objects lying flat
/// at the coin's distance from the camera, shot from straight above.
public struct ReferenceScale: Sendable, Equatable {
    public let millimetresPerPixel: Double

    public init?(coin: ReferenceCoin, measuredPixels: Double) {
        guard measuredPixels > 0 else { return nil }
        millimetresPerPixel = coin.diameterMillimetres / measuredPixels
    }

    public func millimetres(_ pixels: Double) -> Double { pixels * millimetresPerPixel }
}

/// Names for size groups, smallest first, as the result screen shows them.
public enum SizeGroupNames {
    public static func names(count: Int) -> [String] {
        switch count {
        case 0: return []
        case 1: return ["same size"]
        case 2: return ["smaller size", "larger size"]
        default: return ["smallest size"] + (2..<count).map { "size \($0)" } + ["largest size"]
        }
    }
}
