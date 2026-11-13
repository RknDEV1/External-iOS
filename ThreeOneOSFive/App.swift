import SwiftUI
import UIKit

@main
struct ThreeOneOSFiveApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var patchDraftCoordinator = PatchDraftCoordinator()
    @StateObject private var fileOperationCoordinator = FileOperationCoordinator()
    @AppStorage(AppLanguage.storageKey) private var languageCode = AppLanguage.english.rawValue
    // O app inicia diretamente no fluxo normal do 3105.
    @State private var showOnboarding = false
    @State private var isFreeFireMax = false
    @State private var showAttribution = false
    @State private var didStartPostLoginWork = false
    @State private var updateOffer: AppUpdateChecker.Offer?
    @Environment(\.scenePhase) private var scenePhase

    init() {
        setupLogCapture()
        log("app: 3105 launching — iOS \(AppInfo.osVersion) (\(AppInfo.osBuild)) \(AppInfo.machineName)")
    }

    private var language: AppLanguage {
        AppLanguage(rawValue: languageCode) ?? .english
    }

    private func checkForUpdate() {
        Task {
            guard let offer = await AppUpdateChecker.check() else { return }
            await MainActor.run { updateOffer = offer }
        }
    }

    private func startAppWork() {
        guard !didStartPostLoginWork else { return }
        didStartPostLoginWork = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 180_000_000)
            appState.detectSupport()
            checkForUpdate()
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if !showOnboarding {
                    ContentView(
                        isFreeFireMax: $isFreeFireMax
                    )
                    .environmentObject(appState)
                    .environmentObject(patchDraftCoordinator)
                    .environmentObject(fileOperationCoordinator)
                    .environment(\.appLanguage, language)
                    .environment(\.locale, language.locale)
                    .transition(.opacity)
                }

                if showOnboarding {
                    OnboardingView {
                        OnboardingStore.markCompleted()
                        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                            showOnboarding = false
                        }
                        startAppWork()
                    }
                    .environment(\.appLanguage, language)
                    .environment(\.locale, language.locale)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                                        .zIndex(1)
                }
            }
            .displayIdentityAttribution(isPresented: $showAttribution, enabled: !showOnboarding)
            .sheet(isPresented: $showAttribution) {
                DisplayAttributionSheet()
            }
            .alert(item: $updateOffer) { offer in
                Alert(
                    title: Text(language.text("update.title")),
                    message: Text(language.text("update.message", offer.version)),
                    primaryButton: .default(Text(language.text("update.agree"))) {
                        UIApplication.shared.open(offer.url)
                    },
                    secondaryButton: .cancel(Text(language.text("update.dismiss"))) {
                        AppUpdateChecker.dismiss(version: offer.version)
                    }
                )
            }
            .onAppear {
                startAppWork()
            }
            .onChange(of: scenePhase) { phase in
                guard phase == .active, !showOnboarding else { return }
                startAppWork()
            }
            .onOpenURL { url in
                patchDraftCoordinator.presentImport(url)
            }
        }
    }
}

class AppState: ObservableObject {
    @Published var exploitStatus: ExploitStatus = .notStarted
    @Published var unsupportedMessage: String?
    @Published var kernelExploitRunning = false

    private var autoRunAttempted = false

    var kernelExploitApplicable: Bool {
        let v = AppInfo.versionTuple
        return KernelExploit.isApplicable(
            major: v.major,
            minor: v.minor,
            patch: v.patch,
            build: AppInfo.osBuild
        )
    }

    var isSupported: Bool { unsupportedMessage == nil }

    func detectSupport() {
        let v = AppInfo.versionTuple
        let supported = ExploitSupportPolicy.isSupported(
            major: v.major,
            minor: v.minor,
            patch: v.patch,
            build: AppInfo.osBuild
        )
        kernelExploitRunning = false
#if targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("--simulate-access") {
            exploitStatus = .success(method: "Simulator preview")
            unsupportedMessage = nil
            return
        }
#endif
        guard supported else {
            unsupportedMessage = ExploitSupportPolicy.supportReason(
                major: v.major,
                minor: v.minor,
                patch: v.patch,
                build: AppInfo.osBuild
            )
            exploitStatus = .unsupported(unsupportedMessage ?? "Offsets não validados")
            log("kexploit: blocked safely — \(unsupportedMessage ?? "unknown compatibility reason")")
            return
        }
        unsupportedMessage = nil
        exploitStatus = .notStarted
        refreshKernelExploitStatus()
        maybeAutoRunKernelExploit()
    }

    private func maybeAutoRunKernelExploit() {
        guard !kernelExploitRunning,
              !exploitStatus.isSuccess,
              !exploitStatus.isFailed,
              !autoRunAttempted else { return }
        autoRunAttempted = true
        log("app: starting kernel exploit automatically")
        runKernelExploitIfNeeded()
    }

    private func refreshKernelExploitStatus() {
        guard !kernelExploitRunning else { return }

        // iOS < 26: kernel R/W success persists (no sandbox probe)
        // iOS >= 26: verify full sandbox escape is still active
        if KernelExploit.requiresSandboxEscape {
            if KernelExploit.hasSandboxAccess() {
                if !exploitStatus.isSuccess {
                    exploitStatus = .success(method: "kexploit")
                    log("app: existing sandbox access is still active; skipping kernel exploit")
                }
            } else if exploitStatus.isSuccess {
                exploitStatus = .notStarted
                log("app: sandbox access is no longer active")
            }
        }
    }

    func runKernelExploitIfNeeded() {
        refreshKernelExploitStatus()
        guard kernelExploitApplicable,
              !kernelExploitRunning,
              !exploitStatus.isSuccess,
              !exploitStatus.isFailed else { return }
        activateKernel()
    }

    func activateKernel() {
        guard kernelExploitApplicable else {
            let v = AppInfo.versionTuple
            unsupportedMessage = ExploitSupportPolicy.supportReason(
                major: v.major,
                minor: v.minor,
                patch: v.patch,
                build: AppInfo.osBuild
            )
            exploitStatus = .unsupported(unsupportedMessage ?? "Offsets não validados")
            log("kexploit: activation refused safely — offsets are not validated")
            return
        }
        guard !kernelExploitRunning else { return }
        kernelExploitRunning = true
        exploitStatus = .notStarted
        log("app: manual kernel activation requested")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let success = KernelExploit.run()
            DispatchQueue.main.async {
                guard let self else { return }
                self.kernelExploitRunning = false
                if success {
                    self.exploitStatus = .success(method: "kexploit")
                    self.unsupportedMessage = nil
                    log("app: kernel exploit active")
                } else {
                    let code = KernelExploit.lastFailureCode
                    self.exploitStatus = .failed(method: KernelExploit.lastFailureStage.isEmpty ? "kexploit" : KernelExploit.lastFailureStage, code: code)
                    log("app: kernel exploit activation failed — \(KernelExploit.lastFailureStage) (\(code))")
                }
            }
        }
    }

    func deactivateKernel() {
        guard !kernelExploitRunning else { return }
        // The app can end its use of the kernel session, but iOS does not
        // expose a safe public API to undo a kernel primitive in-process.
        exploitStatus = .notStarted
        log("app: kernel session deactivated by app; no external containers accessed")
    }
}
