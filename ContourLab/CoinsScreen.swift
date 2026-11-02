import ContourLabKit
import SwiftUI

/// Coins and anything round: the big count, one card per size group, and Photo or 3D.
struct CoinsScreen: View {
    let image: CGImage
    @State private var result: CountResult?
    @State private var colours: [Int: RGBColor] = [:]
    @State private var table: TableScene?
    @State private var modelNote: String?
    @State private var isCounting = true
    @State private var showsTable = false
    @State private var asks = false
    /// False until the person guesses or skips: the count and circles stay hidden.
    @State private var revealed = false

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Group {
                    if showsTable, let table {
                        TableView3D(scene: table)
                            .aspectRatio(Double(image.width) / Double(image.height), contentMode: .fit)
                    } else {
                        CountedImage(image: image, result: revealed ? result : nil)
                    }
                }
                .clipShape(.rect(cornerRadius: 20))
                GuessCard(question: "How many round things are in the photo?", actual: result?.summary.count, key: "coins", revealed: $revealed)
                if !revealed {
                    EmptyView()
                } else if isCounting {
                    ProgressView("Counting…").padding()
                } else if let result {
                    Headline(count: result.summary.count.formatted(), caption: result.summary.count == 1 ? "round object" : "round objects")
                    SizeGroupCards(groups: result.groups, colours: colours)
                    if let modelNote { ModelNoteCard(text: modelNote) }
                }
            }
            .padding(12)
        }
        .background(Theme.background)
        .safeAreaInset(edge: .bottom) {
            if revealed, result != nil { AskButton(title: "Ask about this photo") { asks = true } }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("View", selection: $showsTable) {
                    Text("Photo").tag(false)
                    Text("3D").tag(true)
                }
                .pickerStyle(.segmented)
                .disabled(table == nil || !revealed)
            }
            if revealed, let result {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: result.summary.sentence)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $asks) {
            if let result { AskSheet(context: .coins(image: image, result: result)) }
        }
        .task { await count() }
    }

    private func count() async {
        let image = image
        guard let counted = try? await Task.detached(operation: { try ContourCounter().count(in: image) }).value else {
            isCounting = false
            return
        }
        let sampled = await Task.detached {
            ColorSampler.averageColors(in: image, for: counted.objects)
        }.value
        guard !Task.isCancelled else { return }
        result = counted
        colours = Dictionary(uniqueKeysWithValues: zip(counted.objects.map(\.id), sampled))
        table = TableScene(result: counted, imageAspect: Double(image.width) / Double(image.height), colours: sampled)
        isCounting = false
        if counted.summary.count > 0 {
            modelNote = await ModelNote.describe(image: image, summary: counted.summary)
        }
    }
}

/// One card per size group, smallest first, each with a swatch in the group's average colour.
struct SizeGroupCards: View {
    let groups: [[CountedObject]]
    let colours: [Int: RGBColor]

    var body: some View {
        let names = SizeGroupNames.names(count: groups.count)
        let widest = groups.last.map(Self.meanDiameter) ?? 1
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            ForEach(Array(groups.enumerated()), id: \.offset) { index, group in
                HStack(spacing: 10) {
                    Circle()
                        .fill(swatch(for: group))
                        .frame(width: 26 * Self.meanDiameter(group) / widest, height: 26 * Self.meanDiameter(group) / widest)
                        .frame(width: 26, height: 26)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(group.count, format: .number).font(.title3.weight(.heavy)).monospacedDigit()
                        Text(names[index]).font(.caption).foregroundStyle(Theme.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Theme.card, in: .rect(cornerRadius: 16))
                .accessibilityElement(children: .combine)
            }
        }
    }

    private static func meanDiameter(_ group: [CountedObject]) -> Double {
        group.map(\.diameter).reduce(0, +) / Double(max(group.count, 1))
    }

    private func swatch(for group: [CountedObject]) -> Color {
        let picked = group.compactMap { colours[$0.id] }
        guard !picked.isEmpty else { return .gray }
        let n = Double(picked.count)
        return Color(red: picked.map(\.red).reduce(0, +) / n, green: picked.map(\.green).reduce(0, +) / n, blue: picked.map(\.blue).reduce(0, +) / n)
    }
}

struct ModelNoteCard: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Apple Intelligence says")
                .font(.caption2.weight(.bold))
                .textCase(.uppercase)
                .foregroundStyle(Theme.secondary)
            Text(text)
            Text("The count above is Vision's. The model never counts.")
                .font(.caption)
                .foregroundStyle(Theme.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay { RoundedRectangle(cornerRadius: 16).stroke(Theme.stroke) }
    }
}

/// The photo with Vision's outlines and one circle per counted object.
struct CountedImage: View {
    let image: CGImage
    let result: CountResult?

    var body: some View {
        Image(decorative: image, scale: 1)
            .resizable()
            .scaledToFit()
            .overlay {
                if let result {
                    Canvas { context, size in
                        for outline in result.outlines {
                            var path = Path()
                            path.addLines(outline.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) })
                            path.closeSubpath()
                            context.stroke(path, with: .color(.white.opacity(0.8)), lineWidth: 1)
                        }
                        for object in result.objects {
                            let box = object.boundingBox
                            let rect = CGRect(
                                x: box.minX * size.width, y: box.minY * size.height,
                                width: box.width * size.width, height: box.height * size.height
                            )
                            context.stroke(Path(ellipseIn: rect), with: .color(Theme.accent), lineWidth: 2.5)
                        }
                    }
                    .allowsHitTesting(false)
                }
            }
            .accessibilityLabel(result?.summary.sentence ?? "Photo")
    }
}
