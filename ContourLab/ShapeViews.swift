import ContourLabKit
import SwiftUI

enum CountMode: String, CaseIterable, Identifiable {
    case round, shapes
    var id: Self { self }
    var title: String { self == .round ? "Round things" : "Any shape" }
}

/// The photo with each object's outline and a line along its length.
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
                            context.stroke(path, with: .color(.pink), lineWidth: 2)
                        }
                        for shape in result.shapes {
                            var line = Path()
                            line.move(to: point(shape.lengthLine.start))
                            line.addLine(to: point(shape.lengthLine.end))
                            context.stroke(line, with: .color(.yellow), style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                            let label = Text("\(shape.id + 1)").font(.caption.bold()).foregroundStyle(.white)
                            let centre = point(CGPoint(x: shape.boundingBox.midX, y: shape.boundingBox.midY))
                            context.fill(Path(ellipseIn: CGRect(x: centre.x - 11, y: centre.y - 11, width: 22, height: 22)), with: .color(.black.opacity(0.7)))
                            context.draw(label, at: centre)
                        }
                    }
                    .allowsHitTesting(false)
                }
            }
            .clipShape(.rect(cornerRadius: 12))
            .accessibilityLabel(result?.summary.sentence ?? "Photo")
    }
}

struct ShapeReport: View {
    let result: ShapeResult

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(result.summary.count, format: .number)
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text(result.summary.sentence)
                .font(.headline)
            ForEach(result.shapes) { shape in
                LabeledContent {
                    Text("\(Int(shape.length)) × \(Int(shape.width)) px · roundness \(shape.roundness, format: .number.precision(.fractionLength(2)))")
                        .monospacedDigit()
                } label: {
                    Text("\(shape.id + 1). \(shape.kind.rawValue.capitalized)")
                }
            }
            Text("Lengths are in pixels of the photo. Objects that touch count as one.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
