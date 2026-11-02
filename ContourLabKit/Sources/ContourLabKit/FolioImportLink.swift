import Foundation

/// A picture Folio routed to Contour Lab: `contourlab://import?mode=objects|surfboard&file=<name>`.
/// Folio copies the file into the Alcor App Group's `Folio/Outbox/` before opening the link.
public struct FolioImportLink: Equatable, Sendable {
    public enum Mode: String, Sendable {
        case objects
        case surfboard
    }

    public static let appGroup = "group.com.anupamchugh.alcor"
    static let outboxPath = "Folio/Outbox"

    public let mode: Mode
    /// A bare file name inside the outbox; never a path.
    public let file: String

    public init?(url: URL) {
        guard url.scheme == "contourlab", url.host() == "import",
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              let mode = items.first(where: { $0.name == "mode" })?.value.flatMap(Mode.init(rawValue:)),
              let file = items.first(where: { $0.name == "file" })?.value,
              !file.isEmpty, !file.hasPrefix("."), !file.contains("/"), !file.contains("\\")
        else { return nil }
        self.mode = mode
        self.file = file
    }

    /// Where Folio left the file: the App Group outbox, or, in a simulator build without that container,
    /// the simulated device's shared folder Folio falls back to (Folio's `docs/router.md`).
    public var fileURL: URL? {
        let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroup)
        #if targetEnvironment(simulator)
        let shared = ProcessInfo.processInfo.environment["SIMULATOR_SHARED_RESOURCES_DIRECTORY"]
        #else
        let shared: String? = nil
        #endif
        return Self.outbox(appGroupContainer: container, simulatorSharedFolder: shared)?.appending(path: file)
    }

    static func outbox(appGroupContainer: URL?, simulatorSharedFolder: String?) -> URL? {
        if let appGroupContainer { return appGroupContainer.appending(path: outboxPath, directoryHint: .isDirectory) }
        guard let simulatorSharedFolder else { return nil }
        return URL(filePath: simulatorSharedFolder, directoryHint: .isDirectory).appending(path: "AlcorShared/" + outboxPath, directoryHint: .isDirectory)
    }
}
