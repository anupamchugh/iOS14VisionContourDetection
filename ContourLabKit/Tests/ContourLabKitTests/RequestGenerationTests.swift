import Testing
@testable import ContourLabKit

@Test func staleRequestCannotReplaceNewInput() {
    var generation = RequestGeneration()
    let oldRequest = generation.begin()
    let newRequest = generation.begin() // The image or a setting changed.
    var displayed = "new result"
    if generation.isCurrent(oldRequest) { displayed = "old result" }
    #expect(displayed == "new result")
    #expect(generation.isCurrent(newRequest))
}
