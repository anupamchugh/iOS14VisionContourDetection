import PhotosUI
import SwiftUI

/// A photo on its way to a result screen, with what the person said is in it.
struct Photo: Hashable, Identifiable {
    let id = UUID()
    let image: CGImage
    let kind: Sample

    static func == (lhs: Photo, rhs: Photo) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// The colours from the 2 Nov 2026 mockups.
enum Theme {
    static let background = Color(red: 0.055, green: 0.063, blue: 0.071)
    static let card = Color(red: 0.098, green: 0.11, blue: 0.125)
    static let stroke = Color(red: 0.165, green: 0.18, blue: 0.204)
    static let secondary = Color(red: 0.64, green: 0.66, blue: 0.69)
    static let accent = Color(red: 1, green: 0.24, blue: 0.545)
    static let warning = Color(red: 0.965, green: 0.784, blue: 0.298)
}

struct ContentView: View {
    @State private var path: [Photo] = []
    @State private var pickedItem: PhotosPickerItem?
    @State private var showsCamera = false
    /// A photo the person took or chose, waiting for them to say what's in it.
    @State private var unsorted: CGImage?

    var body: some View {
        NavigationStack(path: $path) {
            StartView(
                open: { kind in kind.image.map { path.append(Photo(image: $0, kind: kind)) } },
                pickedItem: $pickedItem,
                takePhoto: { showsCamera = true }
            )
            .navigationDestination(for: Photo.self) { photo in
                switch photo.kind {
                case .coins: CoinsScreen(image: photo.image)
                case .leaves, .anything: ShapesScreen(image: photo.image, kind: photo.kind)
                case .surfboard: SurfboardView(image: photo.image)
                }
            }
        }
        .preferredColorScheme(.dark)
        .tint(Theme.accent)
        .confirmationDialog("What's in this photo?", isPresented: Binding(get: { unsorted != nil }, set: { if !$0 { unsorted = nil } }), titleVisibility: .visible) {
            ForEach(Sample.allCases) { kind in
                Button(kind.rawValue) {
                    if let unsorted { path.append(Photo(image: unsorted, kind: kind)) }
                    unsorted = nil
                }
            }
        }
        .fullScreenCover(isPresented: $showsCamera) {
            CameraPicker { photo in unsorted = Self.upright(photo) }
                .ignoresSafeArea()
        }
        .onChange(of: pickedItem) { _, item in
            guard let item else { return }
            pickedItem = nil
            Task {
                let data = try? await item.loadTransferable(type: Data.self)
                unsorted = data.flatMap(UIImage.init(data:)).flatMap(Self.upright)
            }
        }
    }

    /// Photos can carry an orientation flag; draw them upright so Vision and the overlay agree.
    private static func upright(_ image: UIImage) -> CGImage? {
        guard image.imageOrientation != .up else { return image.cgImage }
        return UIGraphicsImageRenderer(size: image.size).image { _ in image.draw(at: .zero) }.cgImage
    }
}

/// "What are you counting?": one tile per kind, each opening its bundled sample.
struct StartView: View {
    let open: (Sample) -> Void
    @Binding var pickedItem: PhotosPickerItem?
    let takePhoto: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Contour Lab")
                        .font(.largeTitle.weight(.heavy))
                    Text("What are you counting?")
                        .foregroundStyle(Theme.secondary)
                }
                .padding(.horizontal, 4)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(Sample.allCases) { kind in
                        Button { open(kind) } label: { Tile(kind: kind) }
                            .buttonStyle(.plain)
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("For a good count").font(.footnote.weight(.bold))
                    Text("Shoot from straight above, on a plain sheet that differs from the objects. On a busy table, turn on Busy background and Vision's subject mask finds the objects instead.")
                        .font(.footnote)
                        .foregroundStyle(Theme.secondary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.card.opacity(0.7), in: .rect(cornerRadius: 18))
            }
            .padding(16)
        }
        .background(Theme.background)
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 10) {
                if CameraPicker.isAvailable {
                    Button(action: takePhoto) {
                        Text("Take photo").font(.headline.weight(.heavy)).frame(maxWidth: .infinity, minHeight: 56)
                    }
                    .background(Theme.accent, in: .rect(cornerRadius: 18))
                    .foregroundStyle(Theme.background)
                }
                PhotosPicker(selection: $pickedItem, matching: .images) {
                    Text("Choose photo").font(.headline).frame(maxWidth: .infinity, minHeight: 56)
                }
                .background(Theme.card, in: .rect(cornerRadius: 18))
                .overlay { RoundedRectangle(cornerRadius: 18).stroke(Theme.stroke) }
                .foregroundStyle(.primary)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .background(Theme.background)
        }
        .toolbarVisibility(.hidden, for: .navigationBar)
    }
}

private struct Tile: View {
    let kind: Sample

    var body: some View {
        VStack(alignment: .leading) {
            TileArt(kind: kind)
                .frame(height: 70, alignment: .leading)
            Spacer()
            Text(kind.rawValue).font(.title3.weight(.bold))
            Text(kind.subtitle).font(.footnote).foregroundStyle(Theme.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 188, alignment: .leading)
        .background(Theme.card, in: .rect(cornerRadius: 22))
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .stroke(kind == .anything ? Color.gray.opacity(0.5) : Theme.stroke, style: StrokeStyle(lineWidth: 1, dash: kind == .anything ? [5, 4] : []))
        }
        .contentShape(.rect(cornerRadius: 22))
        .accessibilityElement(children: .combine)
    }
}

/// The small drawings on each tile, after the mockup.
private struct TileArt: View {
    let kind: Sample

    var body: some View {
        Canvas { context, _ in
            let pink = GraphicsContext.Shading.color(Theme.accent)
            func draw(_ path: Path, _ fill: Color) {
                context.fill(path, with: .color(fill))
                context.stroke(path, with: pink, lineWidth: 2.5)
            }
            switch kind {
            case .coins:
                for (x, y, r, colour) in [(22.0, 22.0, 16.0, Color(red: 0.72, green: 0.54, blue: 0.25)), (58, 20, 13, Color(red: 0.54, green: 0.32, blue: 0.2)), (40, 50, 15, Color(red: 0.79, green: 0.63, blue: 0.31)), (78, 48, 12, Color(white: 0.6))] {
                    draw(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)), colour)
                }
            case .leaves:
                var one = Path()
                one.move(to: CGPoint(x: 8, y: 58))
                one.addCurve(to: CGPoint(x: 62, y: 8), control1: CGPoint(x: 14, y: 26), control2: CGPoint(x: 38, y: 10))
                one.addCurve(to: CGPoint(x: 8, y: 58), control1: CGPoint(x: 58, y: 34), control2: CGPoint(x: 38, y: 56))
                draw(one, Color(red: 0.31, green: 0.54, blue: 0.24))
                var two = Path()
                two.move(to: CGPoint(x: 54, y: 62))
                two.addCurve(to: CGPoint(x: 90, y: 32), control1: CGPoint(x: 60, y: 44), control2: CGPoint(x: 74, y: 34))
                two.addCurve(to: CGPoint(x: 54, y: 62), control1: CGPoint(x: 86, y: 48), control2: CGPoint(x: 74, y: 60))
                draw(two, Color(red: 0.48, green: 0.64, blue: 0.29))
            case .surfboard:
                var board = Path()
                board.move(to: CGPoint(x: 6, y: 35))
                board.addCurve(to: CGPoint(x: 112, y: 24), control1: CGPoint(x: 30, y: 20), control2: CGPoint(x: 70, y: 16))
                board.addLine(to: CGPoint(x: 112, y: 46))
                board.addCurve(to: CGPoint(x: 6, y: 35), control1: CGPoint(x: 70, y: 54), control2: CGPoint(x: 30, y: 50))
                draw(board, Color(red: 0.96, green: 0.94, blue: 0.88))
                var station = Path()
                station.move(to: CGPoint(x: 50, y: 19))
                station.addLine(to: CGPoint(x: 50, y: 51))
                context.stroke(station, with: .color(.cyan), lineWidth: 2)
            case .anything:
                let grey = Color(white: 0.5)
                draw(Path(roundedRect: CGRect(x: 8, y: 14, width: 22, height: 10), cornerRadius: 3), grey)
                draw(Path(ellipseIn: CGRect(x: 40, y: 12, width: 20, height: 20)), grey)
                var cone = Path()
                cone.addLines([CGPoint(x: 14, y: 44), CGPoint(x: 26, y: 44), CGPoint(x: 32, y: 58), CGPoint(x: 8, y: 58)])
                cone.closeSubpath()
                draw(cone, grey)
                draw(Path(roundedRect: CGRect(x: 40, y: 42, width: 20, height: 18), cornerRadius: 4), grey)
            }
        }
        .frame(width: 120)
        .accessibilityHidden(true)
    }
}

extension Sample {
    var subtitle: String {
        switch self {
        case .coins: "and anything round"
        case .leaves: "any shape, measured"
        case .surfboard: "outline and widths"
        case .anything: "screws, keys, pills"
        }
    }
}

/// The "Ask about…" button pinned under each result.
struct AskButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: "sparkles")
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 52)
        }
        .background(Theme.card, in: .rect(cornerRadius: 16))
        .overlay { RoundedRectangle(cornerRadius: 16).stroke(Theme.stroke) }
        .foregroundStyle(.primary)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .background(Theme.background)
    }
}

/// The big number and what it counts.
struct Headline: View {
    let count: String
    let caption: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(count)
                .font(.system(size: 64, weight: .heavy))
                .monospacedDigit()
            Text(caption)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
