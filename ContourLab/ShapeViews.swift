import ContourLabKit
import SwiftUI

/// Leaves and anything else: numbered outlines and one table row per object.
struct ShapesScreen: View {
    let image: CGImage
    let kind: Sample
    @State private var result: ShapeResult?
    @State private var failed = false
    @State private var busyBackground = false
    /// The object the person says is a coin, and which coin, so lengths can be given in centimetres.
    @State private var reference: (shape: Int, coin: ReferenceCoin)?
    @State private var asks = false
    /// False until the person guesses or skips: the count, numbers and table stay hidden.
    @State private var revealed = false

    private var scale: ReferenceScale? {
        guard let reference, let shape = result?.shapes.first(where: { $0.id == reference.shape }) else { return nil }
        return ReferenceScale(coin: reference.coin, measuredPixels: shape.length)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                ShapeImage(image: image, result: revealed ? result : nil)
                    .clipShape(.rect(cornerRadius: 20))
                GuessCard(question: "How many separate \(kind == .leaves ? "leaves and other objects" : "objects") are in the photo?", actual: result?.summary.count, key: kind.rawValue.lowercased(), revealed: $revealed)
                if !revealed {
                    EmptyView()
                } else if let result {
                    Headline(count: result.summary.count.formatted(), caption: Self.caption(result.summary))
                    ShapeTable(result: result, scale: scale)
                    referenceNote(result)
                } else if failed {
                    ContentUnavailableView(
                        "Couldn't measure this photo",
                        systemImage: "exclamationmark.triangle",
                        description: Text(busyBackground
                            ? "Vision's subject model isn't available here. It doesn't run in the Simulator; try a device, or turn off Busy background."
                            : "Try a photo with a plain background.")
                    )
                } else {
                    ProgressView("Measuring…").padding()
                }
            }
            .padding(12)
        }
        .background(Theme.background)
        .safeAreaInset(edge: .bottom) {
            if revealed, let result {
                AskButton(title: kind == .leaves ? "Ask about these leaves" : "Ask about these objects") { asks = true }
                    .sheet(isPresented: $asks) { AskSheet(context: .shapes(image: image, result: result, kind: kind, scale: scale)) }
            }
        }
        .navigationTitle(kind.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Toggle("Busy background", systemImage: "square.stack.3d.down.forward", isOn: $busyBackground)
            }
        }
        .task(id: busyBackground) { await measure() }
    }

    private func measure() async {
        result = nil
        failed = false
        reference = nil
        let image = image, busy = busyBackground
        let measured = try? await Task.detached {
            try ShapeCounter(mask: busy ? ForegroundMask() as any ObjectMasking : BackgroundMask()).count(in: image)
        }.value
        guard !Task.isCancelled else { return }
        result = measured
        failed = measured == nil
    }

    /// "objects · 4 long, 1 round"
    static func caption(_ summary: ShapeSummary) -> String {
        let noun = summary.count == 1 ? "object" : "objects"
        let parts = MeasuredShape.Kind.allCases.compactMap { kind in
            summary.kinds[kind].flatMap { $0 > 0 ? "\($0) \(kind.rawValue)" : nil }
        }
        return parts.isEmpty ? noun : "\(noun) · \(parts.joined(separator: ", "))"
    }

    @ViewBuilder
    private func referenceNote(_ result: ShapeResult) -> some View {
        let candidates = result.shapes.filter { $0.kind == .round }
        VStack(alignment: .leading, spacing: 10) {
            if let reference, scale != nil {
                Text("Centimetres, scaled from object \(reference.shape + 1) as a \(reference.coin.name). Only right for things lying flat beside the coin, shot from straight above.")
            } else {
                Text("Lengths are in photo pixels, not centimetres. Lay a coin beside the objects and pick it here to get centimetres.")
            }
            if !candidates.isEmpty {
                Menu {
                    Button("No reference coin") { reference = nil }
                    ForEach(candidates) { shape in
                        Section("Object \(shape.id + 1) is a…") {
                            ForEach(ReferenceCoin.allCases) { coin in
                                Button(coin.name) { reference = (shape.id, coin) }
                            }
                        }
                    }
                } label: {
                    Label(reference.map { "Object \($0.shape + 1) is a \($0.coin.name)" } ?? "Pick a reference coin", systemImage: "circle.dashed")
                        .font(.subheadline.weight(.semibold))
                }
            }
        }
        .font(.caption)
        .foregroundStyle(Theme.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }
}

/// # · shape · length · width · roundness, one row per numbered object.
struct ShapeTable: View {
    let result: ShapeResult
    let scale: ReferenceScale?

    var body: some View {
        Grid(alignment: .trailing, horizontalSpacing: 8, verticalSpacing: 0) {
            GridRow {
                Text("#").gridColumnAlignment(.leading)
                Text("Shape").gridColumnAlignment(.leading).frame(maxWidth: .infinity, alignment: .leading)
                Text(scale == nil ? "Length px" : "Length cm")
                Text(scale == nil ? "Width px" : "Width cm")
                Text("Round")
            }
            .font(.caption2.weight(.bold))
            .textCase(.uppercase)
            .foregroundStyle(Theme.secondary)
            .padding(.vertical, 8)
            Divider().overlay(Theme.stroke)
            ForEach(result.shapes) { shape in
                GridRow {
                    Text("\(shape.id + 1)").foregroundStyle(Theme.secondary)
                    Text(shape.kind.rawValue).frame(maxWidth: .infinity, alignment: .leading)
                    Text(length(shape.length))
                    Text(length(shape.width))
                    Text(shape.roundness, format: .number.precision(.fractionLength(2)))
                }
                .font(.subheadline)
                .monospacedDigit()
                .padding(.vertical, 9)
                .accessibilityElement(children: .combine)
                if shape.id != result.shapes.last?.id { Divider().overlay(Theme.stroke) }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .background(Theme.card, in: .rect(cornerRadius: 18))
    }

    private func length(_ pixels: Double) -> String {
        guard let scale else { return Int(pixels.rounded()).formatted() }
        return (scale.millimetres(pixels) / 10).formatted(.number.precision(.fractionLength(1)))
    }
}

/// The photo with each object's outline, a line along its length and its number.
struct ShapeImage: View {
    let image: CGImage
    let result: ShapeResult?

    var body: some View {
        Image(decorative: image, scale: 1)
            .resizable()
            .scaledToFit()
            .overlay {
                if let result {
                    Canvas { context, size in
                        func point(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x * size.width, y: p.y * size.height) }
                        for outline in result.outlines {
                            var path = Path()
                            path.addLines(outline.map(point))
                            path.closeSubpath()
                            context.stroke(path, with: .color(Theme.accent), lineWidth: 2.5)
                        }
                        for shape in result.shapes {
                            var line = Path()
                            line.move(to: point(shape.lengthLine.start))
                            line.addLine(to: point(shape.lengthLine.end))
                            context.stroke(line, with: .color(.white), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                            let label = Text("\(shape.id + 1)").font(.caption.bold()).foregroundStyle(.white)
                            let centre = point(CGPoint(x: shape.boundingBox.midX, y: shape.boundingBox.midY))
                            context.fill(Path(ellipseIn: CGRect(x: centre.x - 11, y: centre.y - 11, width: 22, height: 22)), with: .color(Theme.background))
                            context.draw(label, at: centre)
                        }
                    }
                    .allowsHitTesting(false)
                }
            }
            .accessibilityLabel(result?.summary.sentence ?? "Photo")
    }
}
