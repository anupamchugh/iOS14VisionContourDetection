/// Identifies the latest request when asynchronous work may finish out of order.
public struct RequestGeneration {
    private var current: UInt64 = 0

    public init() {}

    public mutating func begin() -> UInt64 {
        current &+= 1
        return current
    }

    public func isCurrent(_ request: UInt64) -> Bool {
        request == current
    }
}
