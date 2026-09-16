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
    @State private var showGamePicker = true
    @State private var selectedEdition: GameEdition = .freeFire
    @State private var showAttribution = false
    @State private var showCHZAccessOverlay = true
    @State private var sessionAuthenticated = false
    @State private var didEvaluateInitialSession = false
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

    private func startPostLoginWork() {
        guard !didStartPostLoginWork else { return }
        didStartPostLoginWork = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 180_000_000)
            appState.detectSupport()
            checkForUpdate()
        }
    }

    private func refreshAuthenticationState() {
        guard !sessionAuthenticated else { return }
        let hasSavedSession = CHZAuthManager.shared().hasValidSavedSession()
        sessionAuthenticated = hasSavedSession
        showCHZAccessOverlay = !hasSavedSession
        if hasSavedSession {
            startPostLoginWork()
        }
    }

    private func didAuthenticate() {
        sessionAuthenticated = true
        showCHZAccessOverlay = false
        startPostLoginWork()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                                    ContentView(
                        isFreeFireMax: selectedEdition == .freeFireMax,
                        onExitToGamePicker: {
                            withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                                showGamePicker = true
                            }
                        }
                    )

                    .environmentObject(appState)
                    .environmentObject(patchDraftCoordinator)
                    .environmentObject(fileOperationCoordinator)
                    .environment(\.appLanguage, language)
                    .environment(\.locale, language.locale)
                    .opacity(showOnboarding || showGamePicker ? 0 : 1)
                    .allowsHitTesting(!showOnboarding && !showGamePicker)

                if showGamePicker && !showOnboarding {
                    FreeFireSelectionView { edition in
                        selectedEdition = edition
                        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                            showGamePicker = false
                        }
                    }
                    .environment(\.appLanguage, language)
                    .environment(\.locale, language.locale)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .zIndex(1)
                }

                if showCHZAccessOverlay {
                    CHZAccessOverlay(
                        isPresented: $showCHZAccessOverlay,
                        onAuthenticated: didAuthenticate
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .zIndex(3)
                }

                if showOnboarding {
                    OnboardingView {
                        OnboardingStore.markCompleted()
                        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                            showOnboarding = false
                        }
                        if sessionAuthenticated {
                            startPostLoginWork()
                        }
                    }
                    .environment(\.appLanguage, language)
                    .environment(\.locale, language.locale)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                                        .zIndex(1)
                }
            }
            .displayIdentityAttribution(isPresented: $showAttribution, enabled: !showOnboarding && !showGamePicker)
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
                guard !didEvaluateInitialSession else { return }
                didEvaluateInitialSession = true
                refreshAuthenticationState()
            }
            .onChange(of: scenePhase) { phase in
                guard phase == .active, !showOnboarding, !sessionAuthenticated else { return }
                refreshAuthenticationState()
            }
            .onOpenURL { url in
                patchDraftCoordinator.presentImport(url)
            }
        }
    }
}

private enum GameEdition {
    case freeFire
    case freeFireMax
}

private struct FreeFireSelectionView: View {
    let onContinue: (GameEdition) -> Void

    private var artworkSide: CGFloat {
        min(108, max(88, UIScreen.main.bounds.width * 0.24))
    }

    private var hasFreeFireMaxPatch: Bool {
        let resources = Bundle.main.urls(forResourcesWithExtension: "3105", subdirectory: nil) ?? []
        return resources.contains { url in
            let name = url.deletingPathExtension().lastPathComponent
            return name.hasPrefix("FFM - ")
        }
    }

    var body: some View {
        ZStack {
            AppTheme.pageBackground.ignoresSafeArea()

            LinearGradient(
                colors: [AppTheme.accent.opacity(0.20), .clear, Color.black],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
            .ignoresSafeArea()

            Circle()
                .fill(AppTheme.accent.opacity(0.16))
                .frame(width: 320, height: 320)
                .blur(radius: 100)
                .offset(x: 145, y: -285)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("CHZ PRIV / GAME SELECT")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .tracking(1.2)
                                .foregroundStyle(AppTheme.accentBright)
                            Text("Escolha seu ambiente")
                                .font(.system(size: 27, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                            Text("Selecione uma edição para continuar")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                        Spacer()
                        CHZPrivWordmark(size: 31)
                    }
                    .padding(.top, 22)

                    HStack(spacing: 8) {
                        Circle()
                            .fill(AppTheme.success)
                            .frame(width: 8, height: 8)
                            .shadow(color: AppTheme.success.opacity(0.8), radius: 5)
                        Text("SISTEMA ONLINE")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .tracking(0.8)
                            .foregroundStyle(AppTheme.success)
                        Spacer()
                        Text("CHZ PRIV")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(AppTheme.tertiaryText)
                    }
                    .padding(.horizontal, 13)
                    .frame(height: 34)
                    .background(AppTheme.success.opacity(0.07), in: Capsule(style: .continuous))
                    .overlay {
                        Capsule(style: .continuous)
                            .stroke(AppTheme.outline, lineWidth: 1.0)
                    }

                    Text("EDIÇÕES DISPONÍVEIS")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .tracking(1.0)
                        .foregroundStyle(AppTheme.secondaryText)
                        .padding(.top, 8)

                    gameCard(
                        title: "Free Fire",
                        subtitle: "Edição principal",
                        status: "SUPORTE ATIVO",
                        artwork: "FreeFire",
                        edition: .freeFire,
                        supported: true
                    )

                    gameCard(
                        title: "Free Fire Max",
                        subtitle: "Edição expandida",
                        status: hasFreeFireMaxPatch ? "SUPORTE ATIVO" : "INDISPONÍVEL",
                        artwork: "FreeFireMax",
                        edition: .freeFireMax,
                        supported: hasFreeFireMaxPatch
                    )

                    HStack(spacing: 8) {
                        Image(systemName: "lock.shield.fill")
                            .foregroundStyle(AppTheme.accentBright)
                        Text("Acesso autorizado · Ambiente protegido")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 9)
                    .padding(.bottom, 22)
                }
                .padding(.horizontal, 18)
            }
        }
    }

    private func gameCard(
        title: String,
        subtitle: String,
        status: String,
        artwork: String,
        edition: GameEdition,
        supported: Bool
    ) -> some View {
        Button {
            onContinue(edition)
        } label: {
            HStack(spacing: 15) {
                Image(artwork)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 92, height: 92)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(supported ? AppTheme.outlineStrong : AppTheme.outline, lineWidth: 1.25)
                    }
                    .opacity(supported ? 1 : 0.60)
                    .shadow(color: supported ? AppTheme.accent.opacity(0.35) : .clear, radius: 14, y: 6)

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.custom(AppTheme.brandFontName, size: 25))
                        .fontWeight(.black)
                        .italic()
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.secondaryText)
                    Text(status)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(0.65)
                        .foregroundStyle(supported ? AppTheme.success : AppTheme.accentBright)
                }
                Spacer(minLength: 4)
                Image(systemName: supported ? "arrow.right.circle.fill" : "clock.badge.exclamationmark")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(supported ? AppTheme.accentBright : AppTheme.secondaryText)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 122)
            .background(.ultraThinMaterial.opacity(supported ? 0.84 : 0.56), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .background((supported ? AppTheme.accent : Color.white).opacity(supported ? 0.08 : 0.035), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(supported ? AppTheme.outlineStrong : AppTheme.outline, lineWidth: 1.05)
            }
            .shadow(color: supported ? AppTheme.accent.opacity(0.18) : .clear, radius: 16, y: 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(status)")
    }
}

class AppState: ObservableObject {
    @Published var exploitStatus: ExploitStatus = .notStarted
    @Published var unsupportedMessage: String?
    @Published var kernelExploitRunning = false

    private var autoRunAttempted = false

    var kernelExploitApplicable: Bool {
        KernelExploit.isApplicable(
            major: AppInfo.versionTuple.major,
            minor: AppInfo.versionTuple.minor,
            patch: AppInfo.versionTuple.patch,
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
#if targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("--simulate-access") {
            exploitStatus = .success(method: "Simulator preview")
        }
#endif

        unsupportedMessage = supported ? nil : "iOS \(AppInfo.osVersion) (\(AppInfo.osBuild))"
        if let unsupportedMessage {
            exploitStatus = .unsupported(unsupportedMessage)
            return
        }

        let applicable = KernelExploit.isApplicable(
            major: v.major,
            minor: v.minor,
            patch: v.patch,
            build: AppInfo.osBuild
        )
        guard applicable else { return }

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
        guard !kernelExploitRunning,
              !exploitStatus.isSuccess,
              !exploitStatus.isFailed else { return }
        kernelExploitRunning = true
        exploitStatus = .notStarted
        log("app: running kernel exploit on background...")
        DispatchQueue.global(qos: .userInitiated).async {
            let ok = KernelExploit.run()
            DispatchQueue.main.async {
                self.kernelExploitRunning = false
                if ok {
                    self.exploitStatus = .success(method: "kexploit")
                    if KernelExploit.requiresSandboxEscape {
                        log("app: kernel exploit success — sandbox access verified")
                    } else {
                        log("app: kernel exploit success — kernel access active")
                    }
                } else {
                    self.exploitStatus = .failed(method: "kexploit", code: -1)
                    log("app: kernel exploit failed — relaunch the app before retrying")
                }
            }
        }
    }
}
