import ContourLabKit
import PhotosUI
import SwiftUI

struct ContentView: View {
    @State private var sample: Sample? = .coins
    @State private var pickedItem: PhotosPickerItem?
    @State private var image: CGImage?
    @State private var result: CountResult?
    @State private var isCounting = false
    @State private var modelNote: String?
    @State private var showsTable = false
    @State private var table: TableScene?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    sourcePicker
                    if let image, let result, !result.objects.isEmpty {
                        Picker("View", selection: $showsTable) {
                            Text("Photo").tag(false)
                            Text("3D").tag(true)
                        }
                        .pickerStyle(.segmented)
                        if showsTable, let table {
                            TableView3D(scene: table)
                            .aspectRatio(Double(image.width) / Double(image.height), contentMode: .fit)
                            .clipShape(.rect(cornerRadius: 12))
                        } else {
                            CountedImage(image: image, result: result)
                        }
                    } else if let image {
                        CountedImage(image: image, result: result)
                    }
                    if isCounting {
                        ProgressView("Counting…")
                    } else if let result {
                        CountReport(result: result, modelNote: modelNote)
                    }
                }
                .padding()
            }
            .navigationTitle("Contour Lab")
        }
        .task(id: sample) {
            guard let sample else { return }
            await load(sample.image)
        }
        .onChange(of: pickedItem) { _, item in
            guard let item else { return }
            sample = nil
            Task {
                let data = try? await item.loadTransferable(type: Data.self)
                await load(data.flatMap(UIImage.init(data:)).flatMap(Self.upright))
            }
        }
    }

    private var sourcePicker: some View {
        HStack {
            Picker("Sample", selection: $sample) {
                ForEach(Sample.allCases) { Text($0.rawValue).tag(Optional($0)) }
                if sample == nil { Text("Your photo").tag(Sample?.none) }
            }
            .pickerStyle(.segmented)
            PhotosPicker(selection: $pickedItem, matching: .images) {
                Label("Choose photo", systemImage: "photo.on.rectangle")
                    .labelStyle(.iconOnly)
                    .frame(minWidth: 44, minHeight: 44)
            }
        }
    }

    private func load(_ newImage: CGImage?) async {
        image = newImage
        result = nil
        table = nil
        modelNote = nil
        guard let newImage else { return }
        isCounting = true
        result = try? await Task.detached { try ContourCounter().count(in: newImage) }.value
        if let result {
            table = await Task.detached {
                TableScene(
                    result: result,
                    imageAspect: Double(newImage.width) / Double(newImage.height),
                    colours: ColorSampler.averageColors(in: newImage, for: result.objects)
                )
            }.value
        }
        isCounting = false
        if let result, result.summary.count > 0, #available(iOS 27, *) {
            modelNote = await ModelNote.describe(image: newImage, summary: result.summary)
        }
    }

    /// Photos can carry an orientation flag; draw them upright so Vision and the overlay agree.
    private static func upright(_ image: UIImage) -> CGImage? {
        guard image.imageOrientation != .up else { return image.cgImage }
        return UIGraphicsImageRenderer(size: image.size).image { _ in image.draw(at: .zero) }.cgImage
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
                            context.stroke(Path(ellipseIn: rect), with: .color(.pink), lineWidth: 2.5)
                        }
                    }
                    .allowsHitTesting(false)
                }
            }
            .clipShape(.rect(cornerRadius: 12))
            .accessibilityLabel(result?.summary.sentence ?? "Photo")
    }
}

struct CountReport: View {
    let result: CountResult
    let modelNote: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(result.summary.count, format: .number)
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text(result.summary.sentence)
                .font(.headline)
            if result.groups.count > 1 {
                ForEach(Array(result.groups.enumerated()), id: \.offset) { index, group in
                    LabeledContent("Size group \(index + 1)") {
                        Text("\(group.count) × about \(Int(group.map(\.diameter).reduce(0, +) / Double(group.count))) px wide")
                    }
                }
            }
            if let modelNote {
                VStack(alignment: .leading, spacing: 4) {
                    Label("On-device model", systemImage: "apple.intelligence")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(modelNote)
                    Text("The count above is Vision's. The model only says what the objects look like.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary, in: .rect(cornerRadius: 12))
            }
        }
    }
}
