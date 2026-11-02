import Foundation
import Testing
@testable import ContourLabKit

struct FolioImportLinkTests {
    @Test func readsObjectsAndSurfboardLinks() throws {
        let objects = try #require(FolioImportLink(url: URL(string: "contourlab://import?mode=objects&file=A1.png")!))
        #expect(objects.mode == .objects)
        #expect(objects.file == "A1.png")
        #expect(FolioImportLink(url: URL(string: "contourlab://import?file=B2.jpg&mode=surfboard")!)?.mode == .surfboard)
    }

    @Test(arguments: [
        "breakline://import?kind=surf&file=a.jpg",
        "contourlab://open?mode=objects&file=a.jpg",
        "contourlab://import?mode=round&file=a.jpg",
        "contourlab://import?mode=objects",
        "contourlab://import?mode=objects&file=",
        "contourlab://import?mode=objects&file=../a.jpg",
        "contourlab://import?mode=objects&file=a/b.jpg",
        "contourlab://import?mode=objects&file=.hidden",
    ])
    func rejectsOtherLinksAndPaths(_ link: String) {
        #expect(FolioImportLink(url: URL(string: link)!) == nil)
    }

    @Test func outboxPrefersTheAppGroupAndFallsBackOnlyWithoutIt() {
        let group = URL(filePath: "/group", directoryHint: .isDirectory)
        #expect(FolioImportLink.outbox(appGroupContainer: group, simulatorSharedFolder: "/sim/data")?.path() == "/group/Folio/Outbox/")
        #expect(FolioImportLink.outbox(appGroupContainer: nil, simulatorSharedFolder: "/sim/data")?.path() == "/sim/data/AlcorShared/Folio/Outbox/")
        #expect(FolioImportLink.outbox(appGroupContainer: nil, simulatorSharedFolder: nil) == nil)
    }
}
