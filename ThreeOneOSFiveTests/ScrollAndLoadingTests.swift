import XCTest

final class ScrollAndLoadingTests: XCTestCase {
    func testLoadingCoordinatorStartsOnlyOnceUntilReset() {
        let coordinator = PatchLoadingCoordinator()
        XCTAssertTrue(coordinator.beginIfNeeded())
        XCTAssertFalse(coordinator.beginIfNeeded())
        coordinator.reset()
        XCTAssertTrue(coordinator.beginIfNeeded())
    }

    func testLoadingCoordinatorIsSafeForConcurrentCallers() {
        let coordinator = PatchLoadingCoordinator()
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "chz.tests.loading", attributes: .concurrent)
        let counter = LockedCounter()

        for _ in 0..<32 {
            group.enter()
            queue.async {
                if coordinator.beginIfNeeded() {
                    counter.increment()
                }
                group.leave()
            }
        }

        XCTAssertEqual(group.wait(timeout: .now() + 2), .success)
        XCTAssertEqual(counter.value, 1)
    }

    private final class LockedCounter: @unchecked Sendable {
        private let lock = NSLock()
        private var storage = 0

        var value: Int {
            lock.lock()
            defer { lock.unlock() }
            return storage
        }

        func increment() {
            lock.lock()
            storage += 1
            lock.unlock()
        }
    }

    func testScrollSourceUsesLazyVerticalAndHorizontalContainers() throws {
        let source = try loadProjectFile("ThreeOneOSFive/ContentView.swift")
        XCTAssertTrue(source.contains("ScrollView(.vertical, showsIndicators: false)"))
        XCTAssertTrue(source.contains("ScrollView(.horizontal, showsIndicators: false)"))
        XCTAssertTrue(source.contains("LazyVStack"))
        XCTAssertTrue(source.contains("LazyHStack"))
        XCTAssertTrue(source.contains("#available(iOS 16.4, *)"))
        XCTAssertTrue(source.contains("chzPrivScrollBounceBehavior"))
        XCTAssertFalse(source.contains("scrollTargetBehavior"))
        XCTAssertFalse(source.contains("scrollTargetLayout"))
        XCTAssertFalse(source.contains("scrollClipDisabled"))
        XCTAssertFalse(source.contains("scrollTransition"))
    }

    func testPatchLoadingSourceStaysOffMainThreadAndHasDuplicateGuard() throws {
        let source = try loadProjectFile("ThreeOneOSFive/ContentView.swift")
        XCTAssertTrue(source.contains("DispatchQueue.global(qos: .userInitiated).async"))
        XCTAssertTrue(source.contains("didLoadPatches"))
        XCTAssertTrue(source.contains("patchLoadingCoordinator.beginIfNeeded()"))
        XCTAssertTrue(source.contains("DispatchQueue.main.async"))
    }

    func testProjectKeepsIOS16DeploymentTarget() throws {
        let project = try loadProjectFile("ThreeOneOSFive.xcodeproj/project.pbxproj")
        XCTAssertTrue(project.contains("IPHONEOS_DEPLOYMENT_TARGET = 16.0;"))
    }

    private func loadProjectFile(_ relativePath: String) throws -> String {
        let testFile = URL(fileURLWithPath: #filePath)
        let repositoryRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = repositoryRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }
}
