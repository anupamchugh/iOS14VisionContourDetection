import ContourLabKit
import FoundationModels
import SwiftUI

/// What one result screen hands the Ask sheet: the photo, Vision's count for the game, and the
/// read-only facts the chat's tools return.
struct AskContext {
    let title: String
    let image: CGImage
    /// The guessing game's question and Vision's answer; none for a surfboard.
    let game: (question: String, actual: Int, key: String)?
    let tools: [FactTool]

    static func coins(image: CGImage, result: CountResult) -> AskContext {
        let names = SizeGroupNames.names(count: result.groups.count)
        let groups = result.groups.enumerated().map { index, group in
            let diameter = group.map(\.diameter).reduce(0, +) / Double(max(group.count, 1))
            return "\(names[index]): \(group.count) objects about \(Int(diameter)) photo pixels wide"
        }
        return AskContext(
            title: "Ask about this photo",
            image: image,
            game: ("How many round things are in the photo? Vision reveals the count after you guess.", result.summary.count, "coins"),
            tools: [
                FactTool(name: "countSummary", label: "count summary", description: "Reads what Vision counted in the photo.", facts: result.summary.sentence),
                FactTool(name: "sizeGroups", label: "size groups", description: "Reads the size groups Vision sorted the round objects into, smallest first.", facts: groups.joined(separator: "\n"))
            ]
        )
    }

    static func shapes(image: CGImage, result: ShapeResult, kind: Sample, scale: ReferenceScale?) -> AskContext {
        let unit = scale == nil ? "photo pixels" : "millimetres"
        let rows = result.shapes.map { shape in
            let length = scale?.millimetres(shape.length) ?? shape.length
            let width = scale?.millimetres(shape.width) ?? shape.width
            return "Object \(shape.id + 1): \(shape.kind.rawValue), \(Int(length)) long and \(Int(width)) wide in \(unit), roundness \(String(format: "%.2f", shape.roundness))"
        }
        let noun = kind == .leaves ? "leaves and other objects" : "objects"
        return AskContext(
            title: kind == .leaves ? "Ask about these leaves" : "Ask about these objects",
            image: image,
            game: ("How many separate \(noun) are in the photo? Vision reveals the count after you guess.", result.summary.count, kind.rawValue.lowercased()),
            tools: [
                FactTool(name: "countSummary", label: "count summary", description: "Reads what Vision counted and how it sorted the shapes.", facts: result.summary.sentence),
                FactTool(name: "objectTable", label: "object table", description: "Reads each numbered object's shape, length, width and roundness.", facts: rows.joined(separator: "\n"))
            ]
        )
    }

    static func board(image: CGImage, outline: BoardOutline) -> AskContext {
        let widths = [
            "Length: \(BoardUnits.text(outline.length))",
            "Wide point: \(BoardUnits.text(outline.wideWidth)), \(BoardReport(outline: outline).widePointPlace)",
            "Nose width 12 inches in: \(BoardUnits.text(outline.noseWidth))",
            "Tail width 12 inches in: \(BoardUnits.text(outline.tailWidth))"
        ]
        return AskContext(
            title: "Ask about this board",
            image: image,
            game: nil,
            tools: [
                FactTool(name: "boardWidths", label: "board widths", description: "Reads the board's length and widths that Vision measured.", facts: widths.joined(separator: "\n")),
                FactTool(name: "howMeasured", label: "how it was measured", description: "Explains how the outline was measured and what one photo can't tell.", facts: "Traced from one photo taken from straight above and scaled from the length the person typed. Thickness, rocker and volume need a side view.")
            ]
        )
    }
}

/// A read-only tool: hands the model facts Vision already measured. Nothing it returns is new.
struct FactTool: Tool {
    let name: String
    /// What the receipt under a reply says: "Read size groups".
    let label: String
    let description: String
    let facts: String

    @Generable
    struct Arguments {}

    func call(arguments: Arguments) async throws -> String { facts }
}

struct AskSheet: View {
    let context: AskContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let game = context.game {
                        GuessCard(question: game.question, actual: game.actual, key: game.key)
                    }
                    ChatView(context: context)
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.background)
            .navigationTitle(context.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .preferredColorScheme(.dark)
        .tint(Theme.accent)
    }
}

/// Guess first, then Vision reveals the count. The best miss for each kind is kept on this device.
struct GuessCard: View {
    let question: String
    let actual: Int
    let key: String
    @State private var guessText = ""
    @State private var result: GuessResult?
    @AppStorage private var best: Int

    init(question: String, actual: Int, key: String) {
        self.question = question
        self.actual = actual
        self.key = key
        // -1 means no guess yet.
        _best = AppStorage(wrappedValue: -1, "best.\(key)")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Guess first")
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.accent)
                Spacer()
                if let text = GuessResult.bestText(best >= 0 ? best : nil) {
                    Text(text).font(.caption).foregroundStyle(Theme.secondary)
                }
            }
            Text(question)
            HStack(alignment: .bottom, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your guess").font(.caption).foregroundStyle(Theme.secondary)
                    TextField("0", text: $guessText)
                        .keyboardType(.numberPad)
                        .font(.title2.weight(.heavy))
                        .monospacedDigit()
                        .padding(.horizontal, 14)
                        .frame(height: 48)
                        .background(Theme.background, in: .rect(cornerRadius: 14))
                        .overlay { RoundedRectangle(cornerRadius: 14).stroke(Theme.stroke) }
                        .disabled(result != nil)
                        .accessibilityLabel("Your guess")
                }
                if let result {
                    VStack(spacing: 2) {
                        Text("Vision").font(.caption).foregroundStyle(Theme.secondary)
                        Text(result.actual, format: .number).font(.system(size: 30, weight: .heavy)).monospacedDigit()
                    }
                    .padding(.horizontal, 10)
                    .accessibilityElement(children: .combine)
                } else {
                    Button("Reveal") { reveal() }
                        .buttonStyle(.borderedProminent)
                        .frame(minHeight: 48)
                        .disabled(Int(guessText) == nil)
                }
            }
            if let result {
                HStack {
                    Text(result.message).foregroundStyle(Theme.warning)
                    Spacer()
                    Button("Guess again") {
                        self.result = nil
                        guessText = ""
                    }
                    .font(.subheadline)
                }
            }
        }
        .padding(16)
        .background(Theme.card, in: .rect(cornerRadius: 20))
        .overlay { RoundedRectangle(cornerRadius: 20).stroke(Theme.stroke) }
    }

    private func reveal() {
        guard let guess = Int(guessText) else { return }
        let scored = GuessResult(guess: guess, actual: actual)
        best = scored.best(after: best >= 0 ? best : nil)
        result = scored
    }
}

/// A chat with the on-device model. It can read what Vision found through the tools, and describes;
/// any reply with a digit in it is dropped, so every number on screen comes from Vision.
struct ChatView: View {
    let context: AskContext
    @State private var chat: Chat?
    @State private var draft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                ForEach(context.tools.map(\.label) + ["the photo"], id: \.self) { label in
                    Text(label)
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .overlay { Capsule().stroke(Theme.stroke) }
                        .foregroundStyle(Theme.secondary)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("The model can read: \(context.tools.map(\.label).joined(separator: ", ")) and the photo")
            if let chat {
                ForEach(chat.lines) { line in LineView(line: line) }
                if chat.isThinking { ProgressView().frame(maxWidth: .infinity, alignment: .leading) }
                HStack(spacing: 10) {
                    TextField("Ask what they are, or what's on them", text: $draft)
                        .padding(.horizontal, 18)
                        .frame(height: 48)
                        .background(Theme.card, in: .capsule)
                        .overlay { Capsule().stroke(Theme.stroke) }
                        .onSubmit(send)
                        .accessibilityLabel("Ask")
                    Button("Send", systemImage: "arrow.up", action: send)
                        .labelStyle(.iconOnly)
                        .font(.headline)
                        .frame(width: 48, height: 48)
                        .background(Theme.accent, in: .circle)
                        .foregroundStyle(Theme.background)
                        .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty || chat.isThinking)
                }
            } else {
                Text(context.game == nil
                    ? "Apple Intelligence isn't available on this device, so the chat is off. Every number on the board comes from Vision."
                    : "Apple Intelligence isn't available on this device, so the chat is off. The guess game still works, and every number here comes from Vision.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondary)
            }
        }
        .onAppear { chat = Chat(context: context) }
    }

    private func send() {
        let question = draft.trimmingCharacters(in: .whitespaces)
        guard !question.isEmpty, let chat, !chat.isThinking else { return }
        draft = ""
        Task { await chat.ask(question) }
    }
}

private struct LineView: View {
    let line: Chat.Line

    var body: some View {
        switch line.kind {
        case .question:
            Text(line.text)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Color(white: 0.18), in: UnevenRoundedRectangle(topLeadingRadius: 16, bottomLeadingRadius: 16, bottomTrailingRadius: 4, topTrailingRadius: 16))
                .frame(maxWidth: .infinity, alignment: .trailing)
        case .receipt:
            Label(line.text, systemImage: "checkmark")
                .font(.caption)
                .foregroundStyle(Theme.secondary)
        case .answer, .dropped:
            Text(line.text)
                .foregroundStyle(line.kind == .dropped ? Theme.secondary : .primary)
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(Theme.card, in: UnevenRoundedRectangle(topLeadingRadius: 16, bottomLeadingRadius: 4, bottomTrailingRadius: 16, topTrailingRadius: 16))
                .overlay { UnevenRoundedRectangle(topLeadingRadius: 16, bottomLeadingRadius: 4, bottomTrailingRadius: 16, topTrailingRadius: 16).stroke(Theme.stroke) }
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

@MainActor @Observable
final class Chat {
    struct Line: Identifiable {
        enum Kind { case question, receipt, answer, dropped }
        let id = UUID()
        let kind: Kind
        let text: String
    }

    private(set) var lines: [Line] = []
    private(set) var isThinking = false
    private let session: LanguageModelSession
    private let image: CGImage
    private let labels: [String: String]
    private var hasSentPhoto = false

    /// Nil when Apple Intelligence isn't available.
    init?(context: AskContext) {
        guard case .available = SystemLanguageModel.default.availability else { return nil }
        image = context.image
        labels = Dictionary(uniqueKeysWithValues: context.tools.map { ($0.name, $0.label) })
        session = LanguageModelSession(tools: context.tools, instructions: """
            You answer questions about a photo of objects that Apple's Vision framework counted and measured.
            Describe what the objects look like: what they might be, their colour, material and what they lie on.
            Never write a number, a count, a size or a measurement, in digits or in words. When a question needs one,
            say that Vision's figures are shown on the screen. Use the tools to read what Vision found. Keep answers to two sentences.
            """)
    }

    func ask(_ question: String) async {
        lines.append(Line(kind: .question, text: question))
        isThinking = true
        defer { isThinking = false }
        let before = session.transcript.count
        do {
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
            for entry in session.transcript.dropFirst(before) {
                guard case .toolCalls(let calls) = entry else { continue }
                for call in calls {
                    lines.append(Line(kind: .receipt, text: "Read \(labels[call.toolName] ?? call.toolName)"))
                }
            }
            if let answer = ModelText.withoutNumbers(response.content) {
                lines.append(Line(kind: .answer, text: answer))
            } else {
                lines.append(Line(kind: .dropped, text: "The reply had a number in it, so the app hid it. Every number on this screen comes from Vision."))
            }
        } catch {
            lines.append(Line(kind: .dropped, text: "The on-device model couldn't answer that. Try asking another way."))
        }
    }
}
