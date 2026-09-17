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

    func testPatchDisplayNameUsesOriginalProjectName() throws {
        let source = try loadProjectFile("ThreeOneOSFive/ContentView.swift")
        XCTAssertTrue(source.contains("item.project?.name ?? item.packageURL.deletingPathExtension().lastPathComponent"))
        XCTAssertFalse(source.contains("return \"Hs Pescoço Baixo\""))
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

    func testTargetResolutionRetriesExactBundleWithoutGuessing() throws {
        let service = try loadProjectFile("ThreeOneOSFive/helpers/DevicePatchService.swift")
        XCTAssertTrue(service.contains("resolveContainerWithRetry(bundleID: bundleID)"))
        XCTAssertTrue(service.contains("let attempts = 3"))
        XCTAssertTrue(service.contains("Thread.sleep(forTimeInterval: 0.35)"))
        XCTAssertTrue(service.contains("ContainerStore.isApplicationContainerPath(path)"))
        XCTAssertTrue(service.contains("target unavailable after retry window"))
        XCTAssertTrue(service.contains("case \"com.dts.freefireth\": return \"Free Fire\""))
        XCTAssertTrue(service.contains("case \"com.dts.freefiremax\": return \"Free Fire MAX\""))
    }

    func testExternalRestoreHandlesAbsentOriginalBaseline() throws {
        let service = try loadProjectFile("ThreeOneOSFive/helpers/DevicePatchService.swift")
        XCTAssertTrue(service.contains("originalAbsentMarker"))
        XCTAssertTrue(service.contains("original-absent"))
        XCTAssertTrue(service.contains("restored private working state (original file was absent)"))
    }

    func testExternalSwitchOnlyChangesStateAfterSuccessfulOperation() throws {
        let source = try loadProjectFile("ThreeOneOSFive/ContentView.swift")
        XCTAssertTrue(source.contains("_ = try DevicePatchService.apply(project: project)"))
        XCTAssertTrue(source.contains("enabledPatchIDs.insert(item.id)"))
        XCTAssertTrue(source.contains("enabledPatchIDs.remove(item.id)"))
        XCTAssertTrue(source.contains("workingPatchID = nil"))
    }

    func testUpdatedPatchCatalogContainsAllEditionCategories() throws {
        let manifest = try loadProjectFile("ThreeOneOSFive/FreeFirePatches/manifest.json")
        XCTAssertEqual(manifest.components(separatedBy: "\"category\": \"Avatar\"").count - 1, 5)
        XCTAssertEqual(manifest.components(separatedBy: "\"category\": \"Cache\"").count - 1, 8)
        XCTAssertEqual(manifest.components(separatedBy: "\"category\": \"External\"").count - 1, 3)
        XCTAssertFalse(manifest.contains("FF - Menu FFTH.3105"))
        XCTAssertFalse(manifest.contains("FFM - Menu FFM.3105"))
        XCTAssertFalse(manifest.contains("MenuFFM(1)_Chz_Priv.3105"))
        XCTAssertFalse(manifest.contains("MenuFFTH_Chz_Priv(1).3105"))
    }

    func testUpdatedPatchResourcesAreRegisteredInXcode() throws {
        let project = try loadProjectFile("ThreeOneOSFive.xcodeproj/project.pbxproj")
        XCTAssertFalse(project.contains("ThreeOneOSFive/FreeFirePatches/External/FF - Menu FFTH.3105"))
        XCTAssertFalse(project.contains("ThreeOneOSFive/FreeFirePatches/External/FFM - Menu FFM.3105"))
        XCTAssertFalse(project.contains("MenuFFM(1)_Chz_Priv.3105"))
        XCTAssertFalse(project.contains("MenuFFTH_Chz_Priv(1).3105"))
    }

    func testRestoreSnapshotsUnexpectedTargetBeforeVerifiedOriginal() throws {
        let source = try loadProjectFile("ThreeOneOSFive/helpers/PatchTransaction.swift")
        XCTAssertTrue(source.contains("unexpected-\\(UUID().uuidString)"))
        XCTAssertTrue(source.contains("snapshotted before restore"))
        XCTAssertTrue(source.contains("digestFile(snapshot) == currentDigest"))
    }

    func testExternalCategoryUsesInjectorCardStructure() throws {
        let source = try loadProjectFile("ThreeOneOSFive/ContentView.swift")
        XCTAssertTrue(source.contains("categorySection(.external)"))
        XCTAssertTrue(source.contains("CHZ PRIV // SYSTEM LOG"))
        XCTAssertTrue(source.contains("stroke(AppTheme.outline, lineWidth: 1.0)"))
        XCTAssertTrue(source.contains("stroke(AppTheme.outlineStrong, lineWidth: 1.15)"))
        XCTAssertTrue(source.contains("ProgressView()"))
        XCTAssertTrue(source.contains("toggleStyle(CHZSwitchStyle())"))
    }

    func testExternalPasswordUnlockClosesSheetAfterSuccess() throws {
        let source = try loadProjectFile("ThreeOneOSFive/ContentView.swift")
        let store = try loadProjectFile("ThreeOneOSFive/helpers/PatchProjectStore.swift")
        XCTAssertTrue(source.contains(".onReceive(patchStore.$unlockedPackageID.compactMap { $0 })"))
        XCTAssertTrue(source.contains("pendingExternalPasswordItem = nil"))
        XCTAssertTrue(source.contains("pendingExternalUnlockID = nil"))
        XCTAssertTrue(source.contains("guard patchStore.requestUnlock(for: item, force: true) else"))
        XCTAssertTrue(store.contains("@Published private(set) var unlockedPackageID: UUID?"))
        XCTAssertTrue(store.contains("private var activeUnlockAttemptID: UUID?"))
        XCTAssertTrue(store.contains("markUnlockSucceeded("))
        XCTAssertTrue(store.contains("attemptID: attemptID"))
    }

    func testExternalCancellationCannotPublishUnlockOrActivatePatch() throws {
        let source = try loadProjectFile("ThreeOneOSFive/ContentView.swift")
        let store = try loadProjectFile("ThreeOneOSFive/helpers/PatchProjectStore.swift")

        XCTAssertTrue(source.contains("private func cancelPendingExternalUnlock()"))
        XCTAssertTrue(source.contains("pendingExternalUnlockID = nil"))
        XCTAssertTrue(source.contains("patchStore.cancelUnlock()"))
        XCTAssertTrue(source.contains("if patchStore.unlockedPackageID == pendingExternalUnlockID"))
        XCTAssertTrue(source.contains("patchStore.unlockedPackageID == pendingID"))
        XCTAssertTrue(store.contains("activeUnlockAttemptID = nil"))
        XCTAssertTrue(store.contains("unlockedPackageID = nil"))
        XCTAssertTrue(store.contains("guard await self?.isUnlockAttemptActive(attemptID) == true else { return }"))
        XCTAssertTrue(store.contains("pendingUnlock?.summary.packageID == packageID"))
    }

    func testFreeFireMaxAimbotIsUnavailableAndCannotReachActivationCallback() throws {
        let source = try loadProjectFile("ThreeOneOSFive/ContentView.swift")
        XCTAssertTrue(source.contains("private func isUnavailablePatch"))
        XCTAssertTrue(source.contains("filename.contains(\"ESP+AIMBOT\")"))
        XCTAssertTrue(source.contains("Text(\"INDISPONÍVEL\")"))
        XCTAssertTrue(source.contains(".disabled(isWorking || unavailable)"))
        XCTAssertTrue(source.contains("guard !isUnavailablePatch(item) else"))
    }

    func testSavedSessionRequiresRemoteRevalidationBeforeOverlayCloses() throws {
        let app = try loadProjectFile("ThreeOneOSFive/App.swift")
        let overlay = try loadProjectFile("ThreeOneOSFive/CHZAccessOverlay.swift")
        XCTAssertTrue(app.contains("manager.validateSavedSession(success:"))
        XCTAssertTrue(app.contains("isRestoringSession = true"))
        XCTAssertFalse(app.contains("sessionAuthenticated = hasSavedSession"))
        XCTAssertTrue(overlay.contains("let isRestoringSession: Bool"))
        XCTAssertTrue(overlay.contains("!isRestoringSession"))
    }

    func testExternalCategoryUsesOriginal3105PatchPath() throws {
        let source = try loadProjectFile("ThreeOneOSFive/ContentView.swift")
        let serviceSource = try loadProjectFile("ThreeOneOSFive/helpers/DevicePatchService.swift")
        XCTAssertTrue(source.contains("categorySection(.external)"))
        XCTAssertTrue(source.contains("guard let baseProject = item.project"))
        guard let applyStart = source.range(of: "private func applyPatch"),
              let logStart = source.range(of: "private func appendLog", range: applyStart.upperBound..<source.endIndex) else {
            XCTFail("Original Injetor patch callback not found")
            return
        }
        let injectorPath = String(source[applyStart.lowerBound..<logStart.lowerBound])
        XCTAssertTrue(injectorPath.contains("_ = try DevicePatchService.apply(project: project)"))
        XCTAssertTrue(injectorPath.contains("try DevicePatchService.restore(receipt: receipt)"))
        XCTAssertFalse(injectorPath.contains("installExternalArtifact"))
        XCTAssertFalse(injectorPath.contains("restoreExternalWorkingFile"))
        XCTAssertTrue(serviceSource.contains("PatchPackageCodec.decode(data, password: \"CHZ\")"))
        XCTAssertFalse(serviceSource.contains("PatchPackageCodec.decode(data, password: \"OG\")"))
    }

    func testFreeFireMaxNeverReusesFreeFireAvatarState() throws {
        let appSource = try loadProjectFile("ThreeOneOSFive/App.swift")
        let contentSource = try loadProjectFile("ThreeOneOSFive/ContentView.swift")
        let manifest = try loadProjectFile("ThreeOneOSFive/FreeFirePatches/manifest.json")

        XCTAssertTrue(appSource.contains(".id(selectedEdition == .freeFireMax ? \"free-fire-max\" : \"free-fire\")"))
        XCTAssertTrue(contentSource.contains("private func belongsToSelectedEdition"))
        XCTAssertTrue(contentSource.contains("return filename.hasPrefix(\"FFM -\")"))
        XCTAssertTrue(contentSource.contains("return filename.hasPrefix(\"FF -\") && !filename.hasPrefix(\"FFM -\")"))
        XCTAssertTrue(contentSource.contains("ForEach(visibleCategories, id: \\.rawValue)"))
        XCTAssertFalse(manifest.contains("\"category\": \"Avatar\",\n      \"filename\": \"FFM -"))
    }

    func testApprovedDescriptionsAreCompactAndSelectionTitleIsUpdated() throws {
        let contentSource = try loadProjectFile("ThreeOneOSFive/ContentView.swift")
        let appSource = try loadProjectFile("ThreeOneOSFive/App.swift")

        XCTAssertTrue(contentSource.contains(".lineLimit(1)"))
        XCTAssertTrue(contentSource.contains(".minimumScaleFactor(0.78)"))
        XCTAssertTrue(contentSource.contains("ESP sem assistência adicional de mira."))
        XCTAssertTrue(contentSource.contains("ESP com assistência de mira."))
        XCTAssertTrue(contentSource.contains("Hs no peito e no pescoço."))
        XCTAssertTrue(contentSource.contains("Hs no pescoço e acima da cabeça."))
        XCTAssertTrue(contentSource.contains("Hs 100% acima da cabeça."))
        XCTAssertTrue(contentSource.contains("Hs 100% no pescoço."))
        XCTAssertTrue(contentSource.contains("ESP e assistência de mira indisponíveis no MAX."))
        XCTAssertTrue(appSource.contains("Text(\"Selecione o seu Free Fire\")"))
        XCTAssertFalse(appSource.contains("Text(\"Escolha seu ambiente\")"))
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
