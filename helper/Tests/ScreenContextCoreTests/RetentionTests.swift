import Testing
import ScreenContextCore

@Test func deletesAllButTheNewest20() {
    // c0 is the oldest, c21 the newest.
    var captures = (0..<22).map { (id: "c\($0)", takenAt: Double($0) * 1_000) }
    captures.swapAt(0, 11)
    captures.swapAt(1, 21)
    #expect(Set(capturesToDelete(captures)) == ["c0", "c1"])
}
