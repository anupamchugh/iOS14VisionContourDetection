import Testing
@testable import ContourLabKit

struct ModelTextTests {
    @Test func keepsADescriptionWithoutNumbers() {
        #expect(ModelText.withoutNumbers("  Euro coins on a grey sheet. ") == "Euro coins on a grey sheet.")
    }

    @Test func dropsAReplyThatCounts() {
        #expect(ModelText.withoutNumbers("There are 51 coins.") == nil)
        #expect(ModelText.withoutNumbers("   ") == nil)
    }
}

struct GuessGameTests {
    @Test func scoresTheMissBothWays() {
        #expect(GuessResult(guess: 45, actual: 51).offBy == 6)
        #expect(GuessResult(guess: 55, actual: 51).offBy == 4)
        #expect(GuessResult(guess: 51, actual: 51).message == "Spot on.")
        #expect(GuessResult(guess: 45, actual: 51).message.hasPrefix("Off by 6."))
    }

    @Test func keepsTheSmallestMiss() {
        #expect(GuessResult(guess: 45, actual: 51).best(after: nil) == 6)
        #expect(GuessResult(guess: 45, actual: 51).best(after: 2) == 2)
        #expect(GuessResult(guess: 50, actual: 51).best(after: 2) == 1)
        #expect(GuessResult.bestText(nil) == nil)
        #expect(GuessResult.bestText(0) == "Best: spot on")
        #expect(GuessResult.bestText(2) == "Best: off by 2")
    }
}

struct ReferenceScaleTests {
    @Test func turnsPixelsIntoMillimetres() throws {
        let scale = try #require(ReferenceScale(coin: .euro1, measuredPixels: 93))
        #expect(abs(scale.millimetres(93) - 23.25) < 0.0001)
        #expect(abs(scale.millimetres(372) - 93) < 0.0001)
    }

    @Test func refusesAnEmptyCoin() {
        #expect(ReferenceScale(coin: .euro2, measuredPixels: 0) == nil)
    }

    @Test func namesSizeGroupsSmallestFirst() {
        #expect(SizeGroupNames.names(count: 1) == ["same size"])
        #expect(SizeGroupNames.names(count: 2) == ["smaller size", "larger size"])
        #expect(SizeGroupNames.names(count: 4) == ["smallest size", "size 2", "size 3", "largest size"])
    }
}
