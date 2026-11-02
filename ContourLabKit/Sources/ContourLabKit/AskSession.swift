import CoreGraphics
import FoundationModels

/// A read-only tool: hands the model facts Vision already measured. Nothing it returns is new.
public struct FactTool: Tool {
    public let name: String
    /// What the receipt under a reply says: "Read size groups".
    public let label: String
    public let description: String
    public let facts: String

    public init(name: String, label: String, description: String, facts: String) {
        self.name = name
        self.label = label
        self.description = description
        self.facts = facts
    }

    @Generable
    public struct Arguments {}

    public func call(arguments: Arguments) async throws -> String { facts }
}

/// One chat about one photo with the on-device model. It sees the photo once, reads Vision's results
/// through the tools, and describes. A reply with a digit in it comes back as `answer == nil`.
@MainActor
public final class AskSession {
    public struct Reply: Sendable {
        /// The labels of the tools the model read for this reply, in order.
        public let toolsRead: [String]
        /// Nil when the reply had a number in it and was dropped.
        public let answer: String?
    }

    public static let instructions = """
        You answer questions about a photo of objects that Apple's Vision framework counted and measured.
        Describe what the objects look like: what they might be, their colour, material and what they lie on.
        Never write a number, a count, a size or a measurement, in digits or in words. When a question needs one,
        say that Vision's figures are shown on the screen. Use the tools to read what Vision found. Keep answers to two sentences.
        """

    private let session: LanguageModelSession
    private let image: CGImage
    private let labels: [String: String]
    private var hasSentPhoto = false

    /// Nil when Apple Intelligence isn't available.
    public init?(image: CGImage, tools: [FactTool]) {
        guard case .available = SystemLanguageModel.default.availability else { return nil }
        self.image = image
        labels = Dictionary(uniqueKeysWithValues: tools.map { ($0.name, $0.label) })
        session = LanguageModelSession(tools: tools, instructions: Self.instructions)
    }

    public func ask(_ question: String) async throws -> Reply {
        let before = session.transcript.count
        let response: LanguageModelSession.Response<String>
        if hasSentPhoto {
            response = try await session.respond(to: question)
        } else {
            let image = image
            response = try await session.respond {
                question
                Attachment(image)
            }
            hasSentPhoto = true
        }
        var read: [String] = []
        for entry in session.transcript.dropFirst(before) {
            guard case .toolCalls(let calls) = entry else { continue }
            read += calls.map { labels[$0.toolName] ?? $0.toolName }
        }
        return Reply(toolsRead: read, answer: ModelText.withoutNumbers(response.content))
    }
}
