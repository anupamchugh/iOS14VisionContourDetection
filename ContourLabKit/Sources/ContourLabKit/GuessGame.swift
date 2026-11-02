/// Guess the count before Vision reveals it. The score is worked out here, never by the model.
public struct GuessResult: Sendable, Equatable {
    public let guess: Int
    public let actual: Int

    public init(guess: Int, actual: Int) {
        self.guess = guess
        self.actual = actual
    }

    public var offBy: Int { abs(guess - actual) }

    public var message: String {
        switch offBy {
        case 0: return "Spot on."
        case _ where guess < actual: return "Off by \(offBy). Objects that touch are easy to miss."
        default: return "Off by \(offBy). Shadows and specks can look like objects."
        }
    }

    /// The better of a previous best and this guess: the smaller miss.
    public func best(after previous: Int?) -> Int {
        min(previous ?? .max, offBy)
    }

    public static func bestText(_ best: Int?) -> String? {
        best.map { $0 == 0 ? "Best: spot on" : "Best: off by \($0)" }
    }
}
