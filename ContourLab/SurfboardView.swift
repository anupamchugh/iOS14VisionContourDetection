import ContourLabKit
import SwiftUI

/// Surfboard mode: type the board's length, see its outline and the widths shapers quote.
struct SurfboardView: View {
    let image: CGImage
    let busyBackground: Bool
    @State private var lengthText = "6'2\""
    @State private var swapsEnds = false
    @State private var outline: BoardOutline?
    @State private var failure: String?
    @State private var isMeasuring = false

    private struct Input: Hashable {
        let image: ObjectIdentifier
        let length: Double?
        let swapsEnds: Bool
        let busy: Bool
    }

    private var length: Double? { BoardLength.millimetres(from: lengthText) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            LabeledContent("Board length") {
                TextField("6'2\"", text: $lengthText)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.numbersAndPunctuation)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .monospacedDigit()
            }
            if length == nil {
                Text("Type the length as feet and inches, like 6'2\" or 9'0\".")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            BoardImage(image: image, outline: outline)
            if isMeasuring {
                ProgressView("Measuring…")
            } else if let outline {
                BoardReport(outline: outline, swapsEnds: $swapsEnds)
            } else if let failure {
                ContentUnavailableView("Couldn't measure this photo", systemImage: "exclamationmark.triangle", description: Text(failure))
            }
        }
        .task(id: Input(image: ObjectIdentifier(image), length: length, swapsEnds: swapsEnds, busy: busyBackground)) {
            await measure()
        }
    }

    private func measure() async {
        outline = nil
        failure = nil
        guard let length else { return }
        isMeasuring = true
        defer { isMeasuring = false }
        let image = image, swaps = swapsEnds, busy = busyBackground
        do {
            outline = try await Task.detached {
                try BoardOutline(
                    tracing: image, scale: .typedLength(millimetres: length),
                    counter: ShapeCounter(mask: busy ? ForegroundMask() as any ObjectMasking : BackgroundMask()),
                    swapsEnds: swaps
                )
            }.value
        } catch BoardOutline.Failure.tooShort {
            failure = "Nose and tail widths are taken 12 inches from each end, so the board must be longer than 2 feet."
        } catch {
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
                        context.stroke(rail, with: .color(.pink), lineWidth: 2.5)

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
    @Binding var swapsEnds: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(BoardLength.feetAndInches(outline.length))
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .monospacedDigit()
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                row("Length", BoardUnits.text(outline.length))
                row("Wide point", BoardUnits.text(outline.wideWidth))
                row("", widePointPlace)
                row("Nose, 12\" in", BoardUnits.text(outline.noseWidth))
                row("Tail, 12\" in", BoardUnits.text(outline.tailWidth))
            }
            if let note = outline.otherObjectsNote {
                Label(note, systemImage: "info.circle")
                    .font(.subheadline)
            }
            Button("Swap nose and tail", systemImage: "arrow.up.arrow.down") { swapsEnds.toggle() }
                .buttonStyle(.bordered)
            Text("Measured from one photo taken from above, scaled from the length you typed. Thickness, rocker and volume need a side view.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: .rect(cornerRadius: 12))
    }

    private var widePointPlace: String {
        let offset = outline.widePointFromCentre
        guard abs(offset) >= 25.4 / 8 else { return "at the centre" }
        return "\(BoardUnits.text(abs(offset))) \(offset > 0 ? "ahead of" : "behind") centre"
    }

    private func row(_ name: String, _ value: String) -> some View {
        GridRow {
            Text(name).foregroundStyle(.secondary)
            Text(value).monospacedDigit()
        }
    }
}
