/// Which Captures to delete so only the newest `keep` remain. `takenAt` is ms since 1970.
public func capturesToDelete(_ captures: [(id: String, takenAt: Double)], keep: Int = 20) -> [String] {
    captures.sorted { $0.takenAt > $1.takenAt }.dropFirst(keep).map(\.id)
}
