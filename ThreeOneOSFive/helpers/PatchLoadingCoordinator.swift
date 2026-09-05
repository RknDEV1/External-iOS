import Foundation

/// Gate thread-safe para impedir carregamentos concorrentes ou repetidos dos patches.
final class PatchLoadingCoordinator: @unchecked Sendable {
    private let lock = NSLock()
    private var hasStarted = false

    /// Retorna true apenas na primeira chamada até `reset()`.
    func beginIfNeeded() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !hasStarted else { return false }
        hasStarted = true
        return true
    }

    func reset() {
        lock.lock()
        hasStarted = false
        lock.unlock()
    }
}

struct ScrollCompatibilityContract {
    static let minimumMajorVersion = 16

    static func supportsModernScrollAPIs(_ version: OperatingSystemVersion) -> Bool {
        version.majorVersion >= 17
    }
}
