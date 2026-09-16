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

    func testPatchDisplayNameUsesSafeRenamedLabel() throws {
        let source = try loadProjectFile("ThreeOneOSFive/ContentView.swift")
        XCTAssertTrue(source.contains("return \"Hs Pescoço Baixo\""))
        XCTAssertTrue(source.contains("private func displayTitle(for item: PatchLibraryItem)"))
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

    func testExternalRestoreHandlesAbsentOriginalBaseline() throws {
        let service = try loadProjectFile("ThreeOneOSFive/helpers/DevicePatchService.swift")
        XCTAssertTrue(service.contains("originalAbsentMarker"))
        XCTAssertTrue(service.contains("original-absent"))
        XCTAssertTrue(service.contains("restored private working state (original file was absent)"))
    }

    func testExternalSwitchOnlyChangesStateAfterSuccessfulOperation() throws {
        let source = try loadProjectFile("ThreeOneOSFive/ContentView.swift")
        XCTAssertTrue(source.contains("if enabled { activeExternalPatchIDs.insert(function.id) }"))
        XCTAssertTrue(source.contains("else { activeExternalPatchIDs.remove(function.id) }"))
        XCTAssertTrue(source.contains("workingExternalPatchID = nil"))
    }

    func testUpdatedPatchCatalogContainsAllEditionCategories() throws {
        let manifest = try loadProjectFile("ThreeOneOSFive/FreeFirePatches/manifest.json")
        XCTAssertEqual(manifest.components(separatedBy: "\"category\": \"Avatar\"").count - 1, 5)
        XCTAssertEqual(manifest.components(separatedBy: "\"category\": \"Cache\"").count - 1, 8)
        XCTAssertEqual(manifest.components(separatedBy: "\"category\": \"External\"").count - 1, 5)
        XCTAssertTrue(manifest.contains("FF - Menu FFTH.3105"))
        XCTAssertTrue(manifest.contains("FFM - Menu FFM.3105"))
        XCTAssertFalse(manifest.contains("MenuFFM(1)_Chz_Priv.3105"))
        XCTAssertFalse(manifest.contains("MenuFFTH_Chz_Priv(1).3105"))
    }

    func testUpdatedPatchResourcesAreRegisteredInXcode() throws {
        let project = try loadProjectFile("ThreeOneOSFive.xcodeproj/project.pbxproj")
        XCTAssertTrue(project.contains("ThreeOneOSFive/FreeFirePatches/External/FF - Menu FFTH.3105"))
        XCTAssertTrue(project.contains("ThreeOneOSFive/FreeFirePatches/External/FFM - Menu FFM.3105"))
        XCTAssertFalse(project.contains("MenuFFM(1)_Chz_Priv.3105"))
        XCTAssertFalse(project.contains("MenuFFTH_Chz_Priv(1).3105"))
    }

    func testRestoreSnapshotsUnexpectedTargetBeforeVerifiedOriginal() throws {
        let source = try loadProjectFile("ThreeOneOSFive/helpers/PatchTransaction.swift")
        XCTAssertTrue(source.contains("unexpected-\\(UUID().uuidString)"))
        XCTAssertTrue(source.contains("snapshotted before restore"))
        XCTAssertTrue(source.contains("digestFile(snapshot) == currentDigest"))
    }

    func testExternalCardMatchesInjectorCardStructure() throws {
        let source = try loadProjectFile("ThreeOneOSFive/ContentView.swift")
        XCTAssertTrue(source.contains("private var externalFunctions: [ExternalPatchFunction]"))
        XCTAssertTrue(source.contains("RKN // SYSTEM LOG"))
        XCTAssertTrue(source.contains("stroke(AppTheme.outline, lineWidth: 1.0)"))
        XCTAssertTrue(source.contains("stroke(AppTheme.outlineStrong, lineWidth: 1.15)"))
        XCTAssertTrue(source.contains("ProgressView()"))
        XCTAssertTrue(source.contains("toggleStyle(CHZSwitchStyle())"))
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
