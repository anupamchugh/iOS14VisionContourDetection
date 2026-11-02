import ContourLabKit
import SwiftUI

/// Guess first, then Vision reveals the count. Until then the result screen hides its numbers and
/// circles. The best miss for each kind is kept on this device.
struct GuessCard: View {
    let question: String
    /// Vision's count; nil while it is still counting.
    let actual: Int?
    @Binding var revealed: Bool
    @State private var guessText = ""
    @State private var result: GuessResult?
    @AppStorage private var best: Int

    init(question: String, actual: Int?, key: String, revealed: Binding<Bool>) {
        self.question = question
        self.actual = actual
        _revealed = revealed
        // -1 means no guess yet.
        _best = AppStorage(wrappedValue: -1, "best.\(key)")
    }

    var body: some View {
        // Skipped: nothing to show. Guessed: the card stays with the score.
        if !revealed || result != nil { card }
    }

    private var card: some View {
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
            if let result {
                HStack(alignment: .firstTextBaseline) {
                    Text("You guessed \(result.guess). Vision counted \(result.actual).")
                    Spacer()
                }
                Text(result.message).foregroundStyle(Theme.warning)
            } else {
                Text(question)
                HStack(alignment: .bottom, spacing: 10) {
                    TextField("Your guess", text: $guessText)
                        .keyboardType(.numberPad)
                        .font(.title2.weight(.heavy))
                        .monospacedDigit()
                        .padding(.horizontal, 14)
                        .frame(height: 48)
                        .background(Theme.background, in: .rect(cornerRadius: 14))
                        .overlay { RoundedRectangle(cornerRadius: 14).stroke(Theme.stroke) }
                        .accessibilityLabel("Your guess")
                    Button("Reveal") { reveal() }
                        .buttonStyle(.borderedProminent)
                        .frame(minHeight: 48)
                        .disabled(Int(guessText) == nil || actual == nil)
                }
                HStack {
                    if actual == nil {
                        ProgressView().controlSize(.small)
                        Text("Vision is counting…").font(.caption).foregroundStyle(Theme.secondary)
                    }
                    Spacer()
                    Button("Skip and show the count") { revealed = true }
                        .font(.subheadline)
                }
            }
        }
        .padding(16)
        .background(Theme.card, in: .rect(cornerRadius: 20))
        .overlay { RoundedRectangle(cornerRadius: 20).stroke(Theme.stroke) }
    }

    private func reveal() {
        guard let guess = Int(guessText), let actual else { return }
        let scored = GuessResult(guess: guess, actual: actual)
        best = scored.best(after: best >= 0 ? best : nil)
        result = scored
        revealed = true
    }
}
