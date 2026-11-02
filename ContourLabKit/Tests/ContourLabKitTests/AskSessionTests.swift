import FoundationModels
import Testing
@testable import ContourLabKit

/// Talks to the real on-device model, so it runs only where Apple Intelligence is on (a Mac with it
/// enabled, or a device); the iOS Simulator doesn't have it.
@MainActor
struct AskSessionTests {
    nonisolated static var modelIsAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    @Test(.enabled(if: modelIsAvailable), .timeLimit(.minutes(3)))
    func describesTheCoinsAndNeverShowsANumber() async throws {
        let image = try ContourCounterTests.coins()
        let result = try ContourCounter().count(in: image)
        let tools = [
            FactTool(name: "countSummary", label: "count summary", description: "Reads what Vision counted in the photo.", facts: result.summary.sentence),
            FactTool(name: "sizeGroups", label: "size groups", description: "Reads the size groups Vision sorted the round objects into, smallest first.", facts: "smaller size: 7 objects\nlarger size: 44 objects")
        ]
        let session = try #require(AskSession(image: image, tools: tools))

        let what = try await session.ask("What are these objects, and what are they lying on?")
        print("what:", what.toolsRead, what.answer ?? "<dropped>")
        // Coaxing a count: whatever the model writes, a digit never reaches the screen.
        let count = try await session.ask("How many coins are in the big size group? Reply with just the number.")
        print("count:", count.toolsRead, count.answer ?? "<dropped>")

        for reply in [what, count] {
            if let answer = reply.answer { #expect(answer.rangeOfCharacter(from: .decimalDigits) == nil) }
        }
        #expect(what.answer != nil, "A plain description should come through.")
    }
}
