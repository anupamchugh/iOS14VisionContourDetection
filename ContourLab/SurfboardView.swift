import ContourLabKit
import SwiftUI

/// Surfboard mode: type the board's length, see its outline and the widths shapers quote.
struct SurfboardView: View {
    let image: CGImage
    @State private var busyBackground = false
    @State private var lengthText = "6'2\""
    @State private var swapsEnds = false
    @State private var outline: BoardOutline?
    @State private var failure: String?
    @State private var isMeasuring = false
    @State private var asks = false

    private struct Input: Hashable {
        let length: Double?
        let swapsEnds: Bool
        let busy: Bool
    }

    private var length: Double? { BoardLength.millimetres(from: lengthText) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                BoardImage(image: image, outline: outline)
                    .clipShape(.rect(cornerRadius: 20))
                HStack(alignment: .bottom) {
                    Text(outline.map { BoardLength.feetAndInches($0.length) } ?? " ")
                        .font(.system(size: 64, weight: .heavy))
                        .monospacedDigit()
                    Spacer()
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Length you typed").font(.caption).foregroundStyle(Theme.secondary)
                        TextField("6'2\"", text: $lengthText)
                            .font(.title3)
                            .keyboardType(.numbersAndPunctuation)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .monospacedDigit()
                            .padding(.horizontal, 12)
                            .frame(width: 104, height: 44)
                            .background(Theme.card, in: .rect(cornerRadius: 12))
                            .overlay { RoundedRectangle(cornerRadius: 12).stroke(Theme.stroke) }
                            .accessibilityLabel("Board length")
                    }
                }
                .padding(.horizontal, 8)
                if length == nil {
                    Text("Type the length as feet and inches, like 6'2\" or 9'0\".")
                        .font(.caption)
                        .foregroundStyle(Theme.warning)
                        .padding(.horizontal, 8)
                }
                if isMeasuring {
                    ProgressView("Measuring…").frame(maxWidth: .infinity).padding()
                } else if let outline {
                    BoardReport(outline: outline)
                } else if let failure {
                    ContentUnavailableView("Couldn't measure this photo", systemImage: "exclamationmark.triangle", description: Text(failure))
                }
            }
            .padding(12)
        }
        .background(Theme.background)
        .safeAreaInset(edge: .bottom) {
            if let outline {
                AskButton(title: "Ask about this board") { asks = true }
                    .sheet(isPresented: $asks) { AskSheet(context: .board(image: image, outline: outline)) }
            }
        }
        .navigationTitle("Surfboard")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Swap nose and tail", systemImage: "arrow.left.arrow.right") { swapsEnds.toggle() }
                    .disabled(outline == nil)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Toggle("Busy background", systemImage: "square.stack.3d.down.forward", isOn: $busyBackground)
            }
        }
        .task(id: Input(length: length, swapsEnds: swapsEnds, busy: busyBackground)) {
            await measure()
        }
    }

    private func measure() async {
        guard !Task.isCancelled else { return }
        outline = nil
        failure = nil
        isMeasuring = false
        guard let length else { return }
        isMeasuring = true
        defer { if !Task.isCancelled { isMeasuring = false } }
        let image = image, swaps = swapsEnds, busy = busyBackground
        do {
            let measured = try await Task.detached {
                try BoardOutline(
                    tracing: image, scale: .typedLength(millimetres: length),
                    counter: ShapeCounter(mask: busy ? ForegroundMask() as any ObjectMasking : BackgroundMask()),
                    swapsEnds: swaps
                )
            }.value
            guard !Task.isCancelled else { return }
            outline = measured
        } catch BoardOutline.Failure.tooShort {
            guard !Task.isCancelled else { return }
            failure = "Nose and tail widths are taken 12 inches from each end, so the board must be longer than 2 feet."
        } catch {
            guard !Task.isCancelled else { return }
            failure = busy
                ? "Vision's subject model isn't available here. It doesn't run in the Simulator; try a device, or turn off Busy background."
                : "Lay the board on a plain floor that differs from it in colour, and shoot from straight above."
        }
    }
}

/// A length in the locale's units, with inches alongside where those aren't inches.
enum BoardUnits {
    static func text(_ millimetres: Double) -> String {
        let inches = BoardLength.inches(millimetres)
        guard Locale.current.measurementSystem != .us else { return inches }
        return "\(centimetres(millimetres)) · \(inches)"
    }

    /// The shorter label drawn on the photo.
    static func label(_ millimetres: Double) -> String {
        Locale.current.measurementSystem == .us ? BoardLength.inches(millimetres) : centimetres(millimetres)
    }

    private static func centimetres(_ millimetres: Double) -> String {
        Measurement(value: millimetres / 10, unit: UnitLength.centimeters)
            .formatted(.measurement(width: .abbreviated, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(1))))
    }
}

/// The photo with the board's outline, its stringer line and the three width stations.
struct BoardImage: View {
    let image: CGImage
    let outline: BoardOutline?

    var body: some View {
        Image(decorative: image, scale: 1)
            .resizable()
            .scaledToFit()
            .overlay {
                if let outline {
                    Canvas { context, size in
                        func point(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x * size.width, y: p.y * size.height) }
                        var rail = Path()
                        rail.addLines(outline.outline.map(point))
                        rail.closeSubpath()
                        context.stroke(rail, with: .color(Theme.accent), lineWidth: 3)

                        var stringer = Path()
                        stringer.move(to: point(outline.nose))
                        stringer.addLine(to: point(outline.tail))
                        context.stroke(stringer, with: .color(.yellow), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))

                        let stations = [
                            ("Nose", outline.noseLine, outline.noseWidth),
                            ("Wide", outline.wideLine, outline.wideWidth),
                            ("Tail", outline.tailLine, outline.tailWidth)
                        ]
                        for (name, line, width) in stations {
                            var path = Path()
                            path.move(to: point(line.start))
                            path.addLine(to: point(line.end))
                            context.stroke(path, with: .color(.cyan), lineWidth: 2)
                            // Just past the rail, so labels don't pile up on the stringer.
                            let start = point(line.start), end = point(line.end)
                            let reach = max(hypot(end.x - start.x, end.y - start.y), 1)
                            let outside = CGPoint(x: end.x + (end.x - start.x) / reach * 16, y: end.y + (end.y - start.y) / reach * 16)
                            tag("\(name) \(BoardUnits.label(width))", at: outside, in: &context, within: size)
                        }
                        let quarter = CGPoint(x: outline.nose.x * 0.3 + outline.tail.x * 0.7, y: outline.nose.y * 0.3 + outline.tail.y * 0.7)
                        tag("Length \(BoardLength.feetAndInches(outline.length))", at: point(quarter), in: &context, within: size)
                        tag("N", at: point(outline.nose), in: &context, within: size)
                    }
                    .allowsHitTesting(false)
                }
            }
            .clipShape(.rect(cornerRadius: 12))
            .accessibilityLabel(outline.map { "Surfboard outline, \(BoardUnits.text($0.wideWidth)) wide" } ?? "Photo")
    }

    /// A label in a dark capsule, kept inside the photo.
    private func tag(_ string: String, at point: CGPoint, in context: inout GraphicsContext, within bounds: CGSize) {
        let text = context.resolve(Text(string).font(.caption.bold()).foregroundStyle(.white))
        let size = text.measure(in: CGSize(width: 300, height: 40))
        let centre = CGPoint(
            x: min(max(point.x, size.width / 2 + 8), bounds.width - size.width / 2 - 8),
            y: min(max(point.y, size.height / 2 + 5), bounds.height - size.height / 2 - 5)
        )
        let box = CGRect(x: centre.x - size.width / 2 - 6, y: centre.y - size.height / 2 - 3, width: size.width + 12, height: size.height + 6)
        context.fill(Path(roundedRect: box, cornerRadius: box.height / 2), with: .color(.black.opacity(0.7)))
        context.draw(text, at: centre)
    }
}

struct BoardReport: View {
    let outline: BoardOutline

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(spacing: 0) {
                row("Length", BoardUnits.text(outline.length))
                Divider().overlay(Theme.stroke)
                row("Wide point", BoardUnits.text(outline.wideWidth))
                Divider().overlay(Theme.stroke)
                row("Wide point sits", widePointPlace)
                Divider().overlay(Theme.stroke)
                row("Nose, 12\" in", BoardUnits.text(outline.noseWidth))
                Divider().overlay(Theme.stroke)
                row("Tail, 12\" in", BoardUnits.text(outline.tailWidth))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(Theme.card, in: .rect(cornerRadius: 18))
            if let note = outline.otherObjectsNote {
                Label(note, systemImage: "info.circle")
                    .font(.subheadline)
                    .padding(.horizontal, 8)
            }
            Text("From one photo taken from above, scaled from the length you typed. Thickness, rocker and volume need a side view.")
                .font(.caption)
                .foregroundStyle(Theme.secondary)
                .padding(.horizontal, 8)
        }
    }

    var widePointPlace: String {
        let offset = outline.widePointFromCentre
        guard abs(offset) >= 25.4 / 8 else { return "at the centre" }
        return "\(BoardUnits.text(abs(offset))) \(offset > 0 ? "ahead of" : "behind") centre"
    }

    private func row(_ name: String, _ value: String) -> some View {
        HStack {
            Text(name).foregroundStyle(Theme.secondary)
            Spacer()
            Text(value).monospacedDigit()
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }
}
