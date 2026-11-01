import AppIntents
import ContourLabKit
import ImageIO
import UniformTypeIdentifiers

/// Counts round objects in a photo from Siri, Shortcuts or the Action button, without opening the app.
struct CountObjectsIntent: AppIntent {
    static let title: LocalizedStringResource = "Count Objects in Photo"
    static let description = IntentDescription("Counts round objects such as coins or fruit in a photo, on this device.")

    @Parameter(title: "Photo", supportedContentTypes: [.image])
    var photo: IntentFile

    func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog {
        guard let source = CGImageSourceCreateWithData(photo.data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw $photo.needsValueError("That file isn't a photo. Choose another one.")
        }
        let summary = try ContourCounter().count(in: image).summary
        return .result(value: summary.count, dialog: IntentDialog(stringLiteral: summary.sentence))
    }
}

struct ContourLabShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CountObjectsIntent(),
            phrases: [
                "Count objects with \(.applicationName)",
                "Count coins with \(.applicationName)"
            ],
            shortTitle: "Count Objects",
            systemImageName: "circle.grid.3x3"
        )
    }
}
