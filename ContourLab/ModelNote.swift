import ContourLabKit
import CoreGraphics
import FoundationModels

/// Asks Apple's on-device model what the counted objects look like.
///
/// The model sees the photo and Vision's numbers, and is told not to count. The app never shows a
/// number from the model: the count always comes from `ContourCounter`.
enum ModelNote {
    static func describe(image: CGImage, summary: CountSummary) async -> String? {
        guard case .available = SystemLanguageModel.default.availability else { return nil }
        let session = LanguageModelSession(instructions: """
            You describe objects in a photo in one short sentence. Never state a number or a count.
            """)
        do {
            let response = try await session.respond {
                "Vision found \(summary.count) round objects in this photo. What are they, and what are they on?"
                Attachment(image)
            }
            let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            // Keep the rule visible in code too: drop any reply that slipped a number in.
            return text.rangeOfCharacter(from: .decimalDigits) == nil ? text : nil
        } catch {
            return nil
        }
    }
}
