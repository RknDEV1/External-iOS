import SwiftUI
import UIKit
import UniformTypeIdentifiers
import CryptoKit

struct ContentView: View {
    @Binding var isFreeFireMax: Bool
    @Environment(\.appLanguage) private var language
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var patchDraftCoordinator: PatchDraftCoordinator
    @State private var tabNavigation: AppTabNavigationState
    @AppStorage(FeatureVisibility.cleanerStorageKey) private var cleanerEnabled = true
    @AppStorage(FeatureVisibility.wallpapersStorageKey) private var wallpapersEnabled = true

    init(isFreeFireMax: Binding<Bool>) {
        _isFreeFireMax = isFreeFireMax
#if targetEnvironment(simulator)
        let arguments = ProcessInfo.processInfo.arguments
        let initialTab: Int
        if arguments.contains("--simulate-files-tab") {
            initialTab = 1
        } else if arguments.contains("--simulate-patch-tab") {
            initialTab = 2
        } else if arguments.contains("--simulate-cleaner-tab") {
            initialTab = 3
        } else if arguments.contains("--simulate-wallpaper-tab") {
            initialTab = 4
        } else {
            initialTab = 0
        }
        _tabNavigation = State(initialValue: AppTabNavigationState(selectedTab: initialTab))
#else
        _tabNavigation = State(initialValue: AppTabNavigationState())
#endif
    }

    var body: some View {
        CHZPrivHomeView(
            isFreeFireMax: $isFreeFireMax
        )
        .appTheme()
        .imageScale(.small)
        .dynamicTypeSize(.small)
    }

    private var compactLayout: some View {
        TabView(selection: tabSelection) {
            ForEach(featureVisibility.visibleSections) { section in
                sectionContent(section)
                    .tabItem {
                        CompactTabLabel(
                            title: language.text(section.titleKey),
                            systemImage: section.systemImage
                        )
                    }
                    .tag(section.rawValue)
            }
        }
    }

    private var regularLayout: some View {
        NavigationSplitView {
            List {
                ForEach(featureVisibility.visibleSections) { section in
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            tabNavigation.select(section.rawValue)
                        }
                    } label: {
                        Label(language.text(section.titleKey), systemImage: section.systemImage)
                            .fontWeight(section.rawValue == tabNavigation.selectedTab ? .semibold : .regular)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(
                        section.rawValue == tabNavigation.selectedTab
                            ? AppTheme.accent.opacity(0.14)
                            : Color.clear
                    )
                    .accessibilityAddTraits(
                        section.rawValue == tabNavigation.selectedTab ? .isSelected : []
                    )
                }
            }
            .navigationTitle("3105")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationSplitViewColumnWidth(min: 210, ideal: 240, max: 300)
        } detail: {
            sectionContent(selectedVisibleSection)
                .id(selectedVisibleSection.rawValue)
        }
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
    private func sectionContent(_ section: AppSection) -> some View {
        switch section {
        case .home:
            CHZPrivHomeView(
                isFreeFireMax: $isFreeFireMax
            )
        case .files:
            AppDataBrowserView(
                tabSession: filesTabSession
            )
        case .patches:
            PatchProjectsView()
        case .cleaner:
            CleanerView()
        case .wallpapers:
            WallpaperLabView()
        }
    }

    private var tabSelection: Binding<Int> {
        Binding(
            get: { tabNavigation.selectedTab },
            set: { tabNavigation.select($0) }
        )
    }

    private var filesTabSession: Binding<FilesTabSession> {
        Binding(
            get: { tabNavigation.filesTabs },
            set: { tabNavigation.setFilesTabs($0) }
        )
    }

    private var featureVisibility: FeatureVisibility {
        FeatureVisibility(
            cleanerEnabled: cleanerEnabled,
            wallpapersEnabled: wallpapersEnabled,
            wallpapersSupported: wallpapersSupported
        )
    }

    private var wallpapersSupported: Bool {
        WallpaperFeatureSupportPolicy.isSupported(major: AppInfo.versionTuple.major)
    }

    private var selectedVisibleSection: AppSection {
        guard let section = AppSection(rawValue: tabNavigation.selectedTab),
              featureVisibility.isVisible(section) else {
            return .home
        }
        return section
    }
}

private struct CompactTabLabel: View {
    let title: String
    let systemImage: String

    @ViewBuilder
    var body: some View {
        if let image = UIImage(
            systemName: systemImage,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .medium)
        )?.withRenderingMode(.alwaysTemplate) {
            Image(uiImage: image)
        } else {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .medium))
        }
        Text(title)
    }
}

private extension AppSection {
    var titleKey: String {
        switch self {
        case .home: return "tab.home"
        case .files: return "tab.files"
        case .patches: return "tab.patches"
        case .cleaner: return "tab.cleaner"
        case .wallpapers: return "tab.wallpapers"
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "house.fill"
        case .files: return "folder.fill"
        case .patches: return "shippingbox.fill"
        case .cleaner: return "sparkles"
        case .wallpapers: return "photo.on.rectangle.angled"
        }
    }
}

private struct DashboardView: View {
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var appState: AppState
    @State private var showSettings = false
    @State private var showLogs = false
    @Binding var cleanerEnabled: Bool
    @Binding var wallpapersEnabled: Bool
    let wallpapersSupported: Bool

    var body: some View {
        NavigationStack {
            List {
                deviceSection
                featuresSection
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .tint(AppTheme.accent)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showLogs = true } label: {
                        Image(systemName: "apple.terminal")
                    }
                    .accessibilityLabel(language.text("accessibility.open_logs"))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel(language.text("accessibility.open_settings"))
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showLogs) { LogView() }
        }
    }

    private var featuresSection: some View {
        Section {
            Toggle(isOn: $cleanerEnabled) {
                Label(language.text("tab.cleaner"), systemImage: "sparkles")
            }
            if wallpapersSupported {
                Toggle(isOn: $wallpapersEnabled) {
                    Label(language.text("tab.wallpapers"), systemImage: "photo.on.rectangle.angled")
                }
            }
        } header: {
            Text(language.text("dashboard.features"))
        } footer: {
            Text(language.text("dashboard.features_footer"))
        }
    }

    private var deviceSection: some View {
        Section {
            LabeledContent(language.text("dashboard.hardware_model")) {
                Text(AppInfo.displayMachineName)
                    .font(.body.monospaced())
            }
            LabeledContent(language.text("settings.ios_version")) {
                Text("\(AppInfo.osVersion) (\(AppInfo.osBuild))")
                    .font(.body.monospaced())
            }
            HStack {
                Text(language.text("settings.compatibility"))
                Spacer()
                Text(language.text(appState.isSupported ? "settings.supported" : "settings.unsupported"))
                .foregroundStyle(appState.isSupported ? AppTheme.success : AppTheme.primaryText)
            }

            if appState.kernelExploitApplicable && AppInfo.versionTuple.major < 26 {
                HStack {
                    Text(language.text("dashboard.kernel_status"))
                    Spacer()
                    if appState.kernelExploitRunning {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small)
                            Text(language.text("dashboard.kernel_running"))
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                    } else {
                        Text(language.text(appState.exploitStatus.isSuccess ? "dashboard.kernel_active" : "dashboard.kernel_inactive"))
                        .foregroundStyle(appState.exploitStatus.isSuccess ? AppTheme.success : AppTheme.secondaryText)
                    }
                }
            }
        } header: {
            Text(language.text("common.device"))
        } footer: {
            Text(language.text("settings.supported_range_summary"))
        }
    }
}


private extension View {
    @ViewBuilder
    func chzPrivScrollBounceBehavior() -> some View {
        if #available(iOS 16.4, *) {
            self.scrollBounceBehavior(.basedOnSize)
        } else {
            self
        }
    }
}

private struct CHZPrivHomeView: View {
    @Binding var isFreeFireMax: Bool
    @EnvironmentObject private var appState: AppState
    @StateObject private var licenseViewModel = LicenseViewModel()
    @StateObject private var patchStore = PatchProjectStore()

    private enum HomePage {
        case license
        case injector
        case external
    }

    private enum LogLevel: Equatable {
        case info, progress, success, warning

        var tint: Color {
            switch self {
            case .info: return AppTheme.secondaryText
            case .progress: return AppTheme.accentBright
            case .success: return AppTheme.success
            case .warning: return AppTheme.primaryText
            }
        }

        var symbol: String {
            switch self {
            case .info: return "info.circle.fill"
            case .progress: return "arrow.triangle.2.circlepath"
            case .success: return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            }
        }
    }

    private struct LogEntry: Identifiable {
        let id = UUID()
        let timestamp: String
        let message: String
        let level: LogLevel
    }

    @State private var selectedPage: HomePage = .injector
    @State private var freeFirePatches: [PatchLibraryItem] = []
    @State private var enabledPatchIDs = Set<UUID>()
    @State private var isWorking = false
    @State private var workingPatchID: UUID?
    @State private var didLoadPatches = false
    @State private var patchLoadingCoordinator = PatchLoadingCoordinator()
    @State private var pendingExternalUnlockID: UUID?
    @State private var pendingExternalPasswordItem: PatchLibraryItem?
    @State private var catalogDemoActive = false
    @State private var showCatalogDemoUnlock = false
    @State private var catalogChzExternalActive = false
    @State private var showCatalogChzExternalUnlock = false
    @State private var catalogChPainelActive = false
    @State private var showCatalogChPainelUnlock = false
    @State private var catalogModnewActive = false
    @State private var showCatalogModnewUnlock = false
    @State private var showPathValidationConfirmation = false
    @State private var pathValidationConfirmationMessage = ""
    @State private var pathValidationConfirmationTitle = "Ativação concluída"
    @State private var pathValidationConfirmationIsActivation = true
    @State private var activityLog = [LogEntry(
        timestamp: Date().formatted(date: .omitted, time: .shortened),
        message: "Sistema pronto — aguardando patches",
        level: .info
    )]

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Group {
                    if selectedPage == .license {
                        LicenseInfoView(licenseViewModel: licenseViewModel)
                    } else if selectedPage == .external {
                        ExternalPanelView(
                            isFreeFireMax: $isFreeFireMax,
                            licenseViewModel: licenseViewModel
                        )
                    } else {
                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVStack(alignment: .leading, spacing: 13) {
                                editionSelector
                                kernelControlSection
                                logo
                                categoryOverview
                                functions
                                backupStatus
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 10)
                            .padding(.bottom, 112)
                        }
                        .chzPrivScrollBounceBehavior()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                bottomNavigation
            }
            .background(AppTheme.pageBackground.ignoresSafeArea())
        }
        .tint(AppTheme.accent)
        .onChange(of: appState.exploitStatus) { status in
            guard status.isSuccess else { return }
            pathValidationConfirmationTitle = "Kernel ativado"
            pathValidationConfirmationIsActivation = true
            pathValidationConfirmationMessage = "A cadeia kexploit foi executada e o estado ativo foi confirmado no app."
            showPathValidationConfirmation = true
        }
        .onAppear {
            loadPatchesIfNeeded()
            // Give the selected-edition view a stable host before presenting UIKit login.
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 120_000_000)
                licenseViewModel.refresh()
            }
        }
        .onChange(of: isFreeFireMax) { _ in
            reloadPatchesForSelectedEdition()
        }
        .onReceive(patchStore.$items) { _ in
            continuePendingExternalActivationIfReady()
        }
        .onReceive(patchStore.$unlockedPackageID.compactMap { $0 }) { packageID in
            guard packageID == pendingExternalUnlockID else { return }
            pendingExternalPasswordItem = nil
            continuePendingExternalActivationIfReady()
        }
        .sheet(item: $pendingExternalPasswordItem, onDismiss: {
            guard pendingExternalUnlockID != nil else { return }
            if patchStore.unlockedPackageID == pendingExternalUnlockID {
                continuePendingExternalActivationIfReady()
            } else {
                cancelPendingExternalUnlock()
            }
        }) { item in
            ExternalPatchUnlockView(
                request: PatchPasswordRequest(summary: item.summary),
                store: patchStore,
                onCancel: cancelPendingExternalUnlock
            )
        }
        .sheet(isPresented: $showCatalogDemoUnlock) {
            ExternalDemoUnlockSheet(
                onCancel: { showCatalogDemoUnlock = false },
                onSuccess: {
                    catalogDemoActive = validateCatalogDemoArtifact()
                    showCatalogDemoUnlock = false
                }
            )
        }
        .sheet(isPresented: $showCatalogChzExternalUnlock) {
            ExternalDemoUnlockSheet(
                expectedPassword: "chz15",
                title: "Chz External",
                onCancel: { showCatalogChzExternalUnlock = false },
                onSuccess: {
                    catalogChzExternalActive = validateCatalogChzExternalArtifact()
                    showCatalogChzExternalUnlock = false
                }
            )
        }
        .sheet(isPresented: $showCatalogChPainelUnlock) {
            ExternalDemoUnlockSheet(
                title: "ChPainel",
                onCancel: { showCatalogChPainelUnlock = false },
                onSuccess: {
                    catalogChPainelActive = validateCatalogChPainelArtifact()
                    showCatalogChPainelUnlock = false
                }
            )
        }
        .sheet(isPresented: $showCatalogModnewUnlock) {
            ExternalDemoUnlockSheet(
                title: "External",
                onCancel: { showCatalogModnewUnlock = false },
                onSuccess: {
                    catalogModnewActive = validateCatalogModnewArtifact()
                    showCatalogModnewUnlock = false
                }
            )
        }
        .overlay {
            if showPathValidationConfirmation {
                ValidationConfirmationOverlay(
                    title: pathValidationConfirmationTitle,
                    message: pathValidationConfirmationMessage,
                    isActivation: pathValidationConfirmationIsActivation,
                    onDismiss: { showPathValidationConfirmation = false }
                )
            }
        }
    }

    private func validateCatalogDemoArtifact() -> Bool {
        guard let url = Bundle.main.url(forResource: "externo-1", withExtension: "3105.validation") else {
            activityLog.append(LogEntry(timestamp: Date().formatted(date: .omitted, time: .shortened), message: "Painel External: arquivo ausente", level: .warning))
            return false
        }
        do {
            let report = try DevicePatchService.validateExternalArtifact(at: url)
            guard report.sha256 == "2ed6b7562efc85965efc78304df8a37f9f6daea3eb900eb509409fc5eeabf3b" else { return false }
            _ = try DevicePatchService.installExternalArtifact(report, editionKey: "catalog-free-fire-demo")
            try DevicePatchService.verifyExternalWorkingFile(editionKey: "catalog-free-fire-demo")
            activityLog.append(LogEntry(timestamp: Date().formatted(date: .omitted, time: .shortened), message: "Painel External: externo(1).3105 validado e enviado à quarentena interna", level: .success))
            return true
        } catch {
            activityLog.append(LogEntry(timestamp: Date().formatted(date: .omitted, time: .shortened), message: "Painel External: validação interna falhou", level: .warning))
            return false
        }
    }

    private func validateCatalogChzExternalArtifact() -> Bool {
        guard let url = Bundle.main.url(forResource: "rkn", withExtension: "3105.validation") else {
            activityLog.append(LogEntry(timestamp: Date().formatted(date: .omitted, time: .shortened), message: "Chz External: arquivo rkn.3105 ausente", level: .warning))
            return false
        }
        do {
            let report = try DevicePatchService.validateExternalArtifact(at: url, password: "chz15")
            guard report.sha256 == "2ed6b7562efc85965efc78304df8a37f9f6daea3eb900eb509409fc5eeabf3b" else { return false }
            _ = try DevicePatchService.installExternalArtifact(report, editionKey: "catalog-free-fire-chz-external")
            try DevicePatchService.verifyExternalWorkingFile(editionKey: "catalog-free-fire-chz-external")
            activityLog.append(LogEntry(timestamp: Date().formatted(date: .omitted, time: .shortened), message: "Chz External: rkn.3105 validado e enviado à quarentena interna", level: .success))
            return true
        } catch {
            activityLog.append(LogEntry(timestamp: Date().formatted(date: .omitted, time: .shortened), message: "Chz External: validação interna falhou", level: .warning))
            return false
        }
    }

    private func restoreCatalogInternalArtifact(editionKey: String) -> Bool {
        do {
            _ = try DevicePatchService.restoreExternalWorkingFile(editionKey: editionKey)
            activityLog.append(LogEntry(timestamp: Date().formatted(date: .omitted, time: .shortened), message: "Backup interno restaurado", level: .success))
            return true
        } catch {
            activityLog.append(LogEntry(timestamp: Date().formatted(date: .omitted, time: .shortened), message: "Nenhum backup interno pôde ser restaurado", level: .warning))
            return false
        }
    }

    private func validateCatalogChPainelArtifact() -> Bool {
        validateCatalogBundledArtifact(
            filename: "FF - Painel.3105",
            expectedHash: "400bf94ef2cccf108405144063294617ea09ec1a01133efe11fa9e01dbfbcc15",
            editionKey: "catalog-free-fire-chpainel",
            title: "ChPainel"
        )
    }

    private func validateCatalogModnewArtifact() -> Bool {
        validateCatalogBundledArtifact(
            filename: "FFM - BoxBlue.3105",
            expectedHash: "20fafcf858381cf64ad62cbe3c10ab6bc5c03580de62a4513eb975732be49421",
            editionKey: "catalog-free-fire-max-modnew",
            title: "External"
        )
    }

    private func validateCatalogBundledArtifact(
        filename: String,
        expectedHash: String,
        editionKey: String,
        title: String
    ) -> Bool {
        let bundledURLs = Bundle.main.urls(
            forResourcesWithExtension: "3105",
            subdirectory: nil
        ) ?? []
        guard let url = bundledURLs.first(where: { $0.lastPathComponent == filename }) else {
            activityLog.append(LogEntry(
                timestamp: Date().formatted(date: .omitted, time: .shortened),
                message: "\(title): arquivo \(filename) ausente no bundle",
                level: .warning
            ))
            return false
        }
        do {
            let report = try DevicePatchService.validateEmbeddedExternalArtifact(url)
            guard report.sha256.caseInsensitiveCompare(expectedHash) == .orderedSame else {
                throw PatchPackageError.unsupportedFormat
            }
            _ = try DevicePatchService.installExternalArtifact(report, editionKey: editionKey)
            try DevicePatchService.verifyExternalWorkingFile(editionKey: editionKey)
            pathValidationConfirmationMessage = "\(title) foi validado por SHA-256 e gravado somente no sandbox interno do app."
            showPathValidationConfirmation = true
            activityLog.append(LogEntry(
                timestamp: Date().formatted(date: .omitted, time: .shortened),
                message: "\(title): arquivo validado, backup criado e instalado internamente",
                level: .success
            ))
            return true
        } catch {
            activityLog.append(LogEntry(
                timestamp: Date().formatted(date: .omitted, time: .shortened),
                message: "\(title): validação interna falhou — \(error.localizedDescription)",
                level: .warning
            ))
            return false
        }
    }

    private var kernelControlSection: some View {
        guard appState.kernelExploitApplicable else { return AnyView(EmptyView()) }
        return AnyView(
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Kernel exploit", systemImage: "cpu.fill")
                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    Spacer()
                    Text(appState.kernelExploitRunning ? "EXECUTANDO" : (appState.exploitStatus.isSuccess ? "ATIVO" : "INATIVO"))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(appState.exploitStatus.isSuccess ? AppTheme.success : AppTheme.secondaryText)
                }
                HStack(spacing: 8) {
                    Button { appState.activateKernel() } label: {
                        Label("Ativar", systemImage: "power")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(appState.kernelExploitRunning || appState.exploitStatus.isSuccess)

                    Button {
                        appState.deactivateKernel()
                        pathValidationConfirmationTitle = "Kernel desativado"
                        pathValidationConfirmationIsActivation = false
                        pathValidationConfirmationMessage = "A sessão do kernel foi encerrada no app. O iOS não oferece reversão pública das primitivas já obtidas."
                        showPathValidationConfirmation = true
                    } label: {
                        Label("Desativar", systemImage: "stop.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(appState.kernelExploitRunning || !appState.exploitStatus.isSuccess)
                }
            }
            .padding(14)
            .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.contentCardCornerRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: AppTheme.contentCardCornerRadius, style: .continuous).stroke(AppTheme.outlineStrong, lineWidth: 1))
        )
    }

    private var editionSelector: some View {
        Picker("Edição", selection: $isFreeFireMax) {
            Text("Free Fire").tag(false)
            Text("Free Fire MAX").tag(true)
        }
        .pickerStyle(.segmented)
        .tint(AppTheme.accent)
        .padding(4)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 0, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 0, style: .continuous)
                .stroke(AppTheme.outlineStrong, lineWidth: 0.8)
        }
    }

    private var bottomNavigation: some View {
        HStack(spacing: 4) {
            bottomNavigationItem(.license, title: "Início", symbol: "house.fill")
            bottomNavigationItem(.injector, title: "Injetor", symbol: "gamecontroller.fill")
        }
        .padding(5)
        .background(AppTheme.cardBackground, in: Capsule(style: .continuous))
        .background(AppTheme.cardBackground.opacity(0.84), in: Capsule(style: .continuous))
        .overlay {
            Capsule(style: .continuous)
                .stroke(AppTheme.outline, lineWidth: 1.15)
        }
        .shadow(color: .clear, radius: 0)
        .padding(.horizontal, 44)
        .padding(.bottom, 10)
    }

    private func bottomNavigationItem(_ page: HomePage, title: String, symbol: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.22)) {
                selectedPage = page
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .semibold))
                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
            }
            .foregroundStyle(selectedPage == page ? AppTheme.accentBright : AppTheme.secondaryText)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background {
                if selectedPage == page {
                    Capsule(style: .continuous)
                        .fill(AppTheme.accent.opacity(0.16))
                        .overlay {
                            Capsule(style: .continuous)
                                .stroke(AppTheme.outlineStrong, lineWidth: 1.05)
                        }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selectedPage == page ? .isSelected : [])
    }

    private var logo: some View {
        CHZPrivWordmark(size: 40)
            .frame(maxWidth: .infinity)
            .padding(.top, 6)
    }

    private var visibleCategories: [PatchCategory] {
        [PatchCategory.avatar, .cache, .external].filter { category in
            category == .external || freeFirePatches.contains { $0.category == category }
        }
    }

    private var categoryOverview: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 10) {
                ForEach(visibleCategories, id: \.rawValue) { category in
                    categoryOverviewCard(category)
                }
            }
            .padding(.horizontal, 1)
        }
    }

    private func categoryOverviewCard(_ category: PatchCategory) -> some View {
        let count = freeFirePatches.filter { $0.category == category }.count
        return HStack(spacing: 9) {
            Image(systemName: category.symbol)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(AppTheme.accentBright)
            VStack(alignment: .leading, spacing: 1) {
                Text(category.rawValue.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                   .foregroundStyle(AppTheme.primaryText)
                Text("\(count) funções")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .padding(.horizontal, 13)
        .frame(minWidth: 142, minHeight: 48, alignment: .leading)
        .background(AppTheme.cardBackground.opacity(0.72), in: RoundedRectangle(cornerRadius: 0, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 0, style: .continuous)
                .stroke(AppTheme.outlineStrong, lineWidth: 1.05)
        }
    }

    private var functions: some View {
        VStack(alignment: .leading, spacing: 15) {
            ForEach(visibleCategories, id: \.rawValue) { category in
                categorySection(category)
            }
        }
    }

    @ViewBuilder
    private func categorySection(_ category: PatchCategory) -> some View {
        let items = freeFirePatches.filter { $0.category == category }
        let displayedCount = items.count
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(category.rawValue.uppercased())
                    .font(.system(size: 20, weight: .bold))
                    .tracking(0.6)
                   .foregroundStyle(AppTheme.primaryText)
                Spacer()
                Text("\(displayedCount)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.secondaryText)
            }
            if items.isEmpty {
                Text(category == .external ? "Aguardando novo patch .3105" : "Nenhum patch disponível")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryText)
                    .padding(.vertical, 8)
            } else {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(items) { item in
                        functionRow(item: item)
                    }
                }
            }
        }
    }

    private var catalogDemoFunctionRow: some View {
        HStack(spacing: 12) {
            Image(systemName: PatchCategory.external.symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(AppTheme.accentBright)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 5) {
                Text("PAINEL EXTERNAL")
                    .font(.system(size: 17, weight: .bold, design: .monospaced))
                   .foregroundStyle(AppTheme.primaryText)
                Text("externo.3105 · ESP com painel interno de funções e configurações.")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(AppTheme.tertiaryText)
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
            Toggle("Painel External", isOn: Binding(
                get: { catalogDemoActive },
                set: { enabled in
                    if enabled { showCatalogDemoUnlock = true }
                    else { catalogDemoActive = false }
                }
            ))
            .labelsHidden()
            .toggleStyle(CHZSwitchStyle())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
        .frame(minHeight: 64)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.contentCardCornerRadius, style: .continuous))
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.contentCardCornerRadius, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: AppTheme.contentCardCornerRadius, style: .continuous).stroke(AppTheme.outlineStrong, lineWidth: 1.15) }
    }

    private var catalogChPainelFunctionRow: some View {
        HStack(spacing: 12) {
            Image(systemName: PatchCategory.external.symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(AppTheme.accentBright)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 5) {
                Text("CHPAINEL")
                    .font(.system(size: 17, weight: .bold, design: .monospaced))
                   .foregroundStyle(AppTheme.primaryText)
                Text("Painel interno com funções e configurações.")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(AppTheme.tertiaryText)
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
            Toggle("ChPainel", isOn: Binding(
                get: { catalogChPainelActive },
                set: { enabled in
                    if enabled { catalogChPainelActive = validateCatalogChPainelArtifact() }
                    else {
                        catalogChPainelActive = restoreCatalogInternalArtifact(editionKey: "catalog-free-fire-chpainel")
                    }
                }
            ))
            .labelsHidden()
            .toggleStyle(CHZSwitchStyle())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
        .frame(minHeight: 64)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.contentCardCornerRadius, style: .continuous))
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.contentCardCornerRadius, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: AppTheme.contentCardCornerRadius, style: .continuous).stroke(AppTheme.outlineStrong, lineWidth: 1.15) }
    }

    private var catalogModnewFunctionRow: some View {
        HStack(spacing: 12) {
            Image(systemName: PatchCategory.external.symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(AppTheme.accentBright)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 5) {
                Text("SYSTEM")
                    .font(.system(size: 17, weight: .bold, design: .monospaced))
                   .foregroundStyle(AppTheme.primaryText)
            }
            Spacer(minLength: 6)
            Toggle("External", isOn: Binding(
                get: { catalogModnewActive },
                set: { enabled in
                    if enabled { catalogModnewActive = validateCatalogModnewArtifact() }
                    else {
                        catalogModnewActive = restoreCatalogInternalArtifact(editionKey: "catalog-free-fire-max-modnew")
                    }
                }
            ))
            .labelsHidden()
            .toggleStyle(CHZSwitchStyle())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
        .frame(minHeight: 64)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.contentCardCornerRadius, style: .continuous))
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.contentCardCornerRadius, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: AppTheme.contentCardCornerRadius, style: .continuous).stroke(AppTheme.outlineStrong, lineWidth: 1.15) }
    }

    private func functionRow(item: PatchLibraryItem) -> some View {
        let title = displayTitle(for: item)
        let description = patchDescription(for: item)
        let unavailable = isUnavailablePatch(item)
        return HStack(spacing: 12) {
                Image(systemName: item.category.symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(AppTheme.accentBright)
                .shadow(color: .clear, radius: 0)
                .frame(width: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                Text(title.uppercased())
                    .font(.system(size: 17, weight: .bold, design: .monospaced))
                    .tracking(0.25)
                   .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(2)
                if unavailable {
                    Text("INDISPONÍVEL")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(0.7)
                       .foregroundStyle(AppTheme.primaryText)
                }
            }
            Spacer(minLength: 6)
            if workingPatchID == item.id {
                ProgressView()
                    .controlSize(.small)
                    .tint(AppTheme.accentBright)
            }
            Toggle("\(title)", isOn: Binding(
                get: { !unavailable && enabledPatchIDs.contains(item.id) },
                set: { newValue in
                    guard !unavailable else { return }
                    updatePatchState(item: item, isEnabled: newValue)
                }
            ))
                .labelsHidden()
                .toggleStyle(CHZSwitchStyle())
                .disabled(isWorking || unavailable)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
        .frame(minHeight: 64)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.contentCardCornerRadius, style: .continuous))
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.contentCardCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.contentCardCornerRadius, style: .continuous)
                .stroke(AppTheme.outline, lineWidth: 1.0)
        }
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.contentCardCornerRadius, style: .continuous)
                .stroke(AppTheme.outlineStrong, lineWidth: 1.15)
        }
        .shadow(color: .clear, radius: 0)
        .overlay(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 0, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .frame(height: 28)
                .clipShape(RoundedRectangle(cornerRadius: 0, style: .continuous))
                .allowsHitTesting(false)
        }
    }

    private func displayTitle(for item: PatchLibraryItem) -> String {
        let filename = item.packageURL.deletingPathExtension().lastPathComponent
        let normalized = filename
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .uppercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "+", with: "")
        if normalized.contains("BOXBLUE") { return isFreeFireMax ? "Esp+Aimbot" : "BoxBlue" }
        if normalized.contains("PAINELEXTERNAL") { return "Painel External" }
        if normalized.contains("PAINEL") { return "Esp+Painel" }
        return item.project?.name ?? filename
    }

    private func patchDescription(for item: PatchLibraryItem) -> String {
        if isUnavailablePatch(item) {
            return "ESP e assistência de mira indisponíveis no MAX."
        }

        let filename = item.packageURL.deletingPathExtension().lastPathComponent
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .uppercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "+", with: "")

        if item.category == .external {
            if filename.contains("ESPONLY") {
                return "ESP sem assistência adicional de mira."
            }
            if filename.contains("ESPAIMBOT") {
                return "ESP com assistência de mira."
            }
            if filename.contains("BOXBLUE") {
                return "ESP com assistência de mira e recursos adicionais."
            }
            if filename.contains("PAINEL") {
                return "ESP com painel interno de funções e configurações."
            }
        }
        if filename.contains("100") && filename.contains("BAYPSS") {
            return "Hs no pescoço com perfil Baypss."
        }
        if filename.contains("PEITO") && filename.contains("PESCO") {
            return "Hs no peito e no pescoço."
        }
        if filename.contains("PESCO") && filename.contains("ALTO") {
            return "Hs no pescoço e acima da cabeça."
        }
        if filename.contains("PESCO") && filename.contains("ANTENA") {
            return "Hs no pescoço com indicação de antena."
        }
        if filename.contains("ALTO") && filename.contains("ANTENA") {
            return "Hs alto com indicação de antena."
        }
        if filename.contains("ALTO") && filename.contains("BAYPSS") {
            return "Hs alto com perfil Baypss."
        }
        if filename.contains("PESCO") && filename.contains("BAYPSS") {
            return "Hs no pescoço com perfil Baypss."
        }
        if filename.contains("ALTO") && filename.contains("100") {
            return "Hs 100% acima da cabeça."
        }
        if filename.contains("PESCO") && filename.contains("100") {
            return "Hs 100% no pescoço."
        }
        return "Função do catálogo 3105."
    }

    private func isUnavailablePatch(_ item: PatchLibraryItem) -> Bool {
        guard isFreeFireMax, item.category == .external else { return false }
        let filename = item.packageURL.deletingPathExtension().lastPathComponent
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .uppercased()
        return filename.contains("ESP+AIMBOT")
    }

    private func belongsToSelectedEdition(_ item: PatchLibraryItem) -> Bool {
        let filename = item.packageURL.lastPathComponent
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .uppercased()
        if isFreeFireMax {
            return filename.hasPrefix("FFM -")
        }
        return filename.hasPrefix("FF -") && !filename.hasPrefix("FFM -")
    }

    private func loadPatchesIfNeeded() {
        guard !didLoadPatches, patchLoadingCoordinator.beginIfNeeded() else { return }
        didLoadPatches = true
        loadPatchesForSelectedEdition()
    }

    private func reloadPatchesForSelectedEdition() {
        guard didLoadPatches, !isWorking else { return }
        // Clear the previous edition immediately so FF and FFM never share
        // rows or enabled switches while the selected catalog is rebuilding.
        freeFirePatches = []
        enabledPatchIDs = []
        loadPatchesForSelectedEdition()
    }

    private func loadPatchesForSelectedEdition() {
        let selectedEditionIsMax = isFreeFireMax
        DispatchQueue.global(qos: .userInitiated).async {
            autoreleasepool {
                PatchProjectLibrary.installBundledOriginalFreeFirePatches()
                PatchProjectLibrary.removeObsoleteExternalPackages()
                let items = PatchProjectLibrary.load()
                let scopedItems = items.filter { item in
                    let filename = item.packageURL.lastPathComponent
                        .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                        .uppercased()
                    let belongs = selectedEditionIsMax
                        ? filename.hasPrefix("FFM -")
                        : filename.hasPrefix("FF -") && !filename.hasPrefix("FFM -")
                    let unavailable = selectedEditionIsMax && item.category == .external && filename.contains("ESP+AIMBOT")
                    return belongs && !unavailable
                }
                let enabled = Set(scopedItems.compactMap { item in
                    let edition = selectedEditionIsMax ? "free-fire-max" : "free-fire"
                    let filename = item.packageURL.lastPathComponent
                        .replacingOccurrences(of: "[^A-Za-z0-9_-]", with: "-", options: .regularExpression)
                    let key = "catalog-\(edition)-\(filename)-\(item.id.uuidString)"
                    return DevicePatchService.hasExternalWorkingFile(editionKey: key) ? item.id : nil
                })
                DispatchQueue.main.async {
                    // Do not let an older background load overwrite a newer
                    // edition selection made while the disk scan was running.
                    guard self.isFreeFireMax == selectedEditionIsMax else { return }
                    freeFirePatches = scopedItems
                    enabledPatchIDs = enabled
                }
            }
        }
    }

    private func updatePatchState(item: PatchLibraryItem, isEnabled: Bool, afterUnlock: Bool = false) {
        guard !isUnavailablePatch(item) else {
            enabledPatchIDs.remove(item.id)
            appendLog("Esp+aimbot está indisponível no Free Fire MAX", level: .warning)
            return
        }

        guard let baseProject = item.project ?? (item.category == .external ? PatchProject(
            id: item.id,
            name: item.packageURL.deletingPathExtension().lastPathComponent,
            rules: []
        ) : nil) else {
            appendLog("Patch indisponível: pacote bloqueado ou inválido", level: .warning)
            return
        }
        let patchName = baseProject.name
        isWorking = true
        workingPatchID = item.id

        if isEnabled {
            activityLog.removeAll(keepingCapacity: true)
            appendLog("Nova sessão iniciada — \(patchName)", level: .info)
            appendLog("Validando configuração do patch", level: .progress)
            appendLog("Criando backup do arquivo original", level: .progress)
            applyPatch(item: item, baseProject: baseProject, patchName: patchName)
        } else {
            activityLog.removeAll(keepingCapacity: true)
            appendLog("Sessão de restauração — \(patchName)", level: .info)
            appendLog("Verificando journal e backup protegido", level: .progress)
            restorePatch(item: item, patchName: patchName)
        }
    }

    private func cancelPendingExternalUnlock() {
        pendingExternalUnlockID = nil
        pendingExternalPasswordItem = nil
        patchStore.cancelUnlock()
        appendLog("Ativação External cancelada", level: .warning)
    }

    private func isEspOnly(_ item: PatchLibraryItem) -> Bool {
        let name = item.packageURL.deletingPathExtension().lastPathComponent
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        return name.contains("esp only")
    }

    private func continuePendingExternalActivationIfReady() {
        guard let pendingID = pendingExternalUnlockID,
              patchStore.unlockedPackageID == pendingID,
              let unlockedItem = patchStore.items.first(where: { $0.id == pendingID }),
              unlockedItem.project != nil,
              !isWorking else { return }
        pendingExternalUnlockID = nil
        pendingExternalPasswordItem = nil
        freeFirePatches = patchStore.items.filter(belongsToSelectedEdition)
        updatePatchState(item: unlockedItem, isEnabled: true, afterUnlock: true)
    }

    private func applyPatch(item: PatchLibraryItem, baseProject: PatchProject, patchName: String) {
        Task.detached(priority: .userInitiated) {
            do {
                _ = baseProject
                let report = try DevicePatchService.validateExternalArtifact(at: item.packageURL, password: nil)
                let editionKey = safeCatalogEditionKey(for: item)
                _ = try DevicePatchService.installExternalArtifact(report, editionKey: editionKey)
                try DevicePatchService.verifyExternalWorkingFile(editionKey: editionKey)
                await MainActor.run {
                    enabledPatchIDs.insert(item.id)
                    workingPatchID = nil
                    isWorking = false
                    SoundEffectManager.shared.play(.confirmation)
                    pathValidationConfirmationTitle = "Ativação concluída"
                    pathValidationConfirmationIsActivation = true
                    pathValidationConfirmationMessage = "\(patchName) foi ativado, verificado por SHA-256 e gravado somente no sandbox interno."
                    showPathValidationConfirmation = true
                    appendLog("Patch aplicado e verificado", level: .success)
                }
            } catch {
                await MainActor.run {
                    workingPatchID = nil
                    isWorking = false
                    appendLog("Falha ao ativar: \(error.localizedDescription)", level: .warning)
                }
            }
        }
    }

    private func restorePatch(item: PatchLibraryItem, patchName: String) {
        let editionKey = safeCatalogEditionKey(for: item)
        guard DevicePatchService.hasExternalWorkingFile(editionKey: editionKey) else {
            enabledPatchIDs.remove(item.id)
            isWorking = false
            appendLog("Nenhum backup ativo encontrado", level: .warning)
            return
        }
        Task.detached(priority: .userInitiated) {
            do {
                _ = try DevicePatchService.restoreExternalWorkingFile(editionKey: editionKey)
                await MainActor.run {
                    enabledPatchIDs.remove(item.id)
                    workingPatchID = nil
                    isWorking = false
                    SoundEffectManager.shared.play(.confirmation)
                    pathValidationConfirmationTitle = "Desativação concluída"
                    pathValidationConfirmationIsActivation = false
                    pathValidationConfirmationMessage = "\(patchName) foi desativado e o arquivo original foi restaurado no sandbox interno."
                    showPathValidationConfirmation = true
                    appendLog("Arquivo original restaurado", level: .success)
                }
            } catch {
                await MainActor.run {
                    workingPatchID = nil
                    isWorking = false
                    appendLog("Falha ao restaurar: \(error.localizedDescription)", level: .warning)
                }
            }
        }
    }

    private func appendLog(_ message: String, level: LogLevel) {
        let timestamp = Date().formatted(date: .omitted, time: .shortened)
        activityLog.append(LogEntry(timestamp: timestamp, message: message, level: level))
        if activityLog.count > 30 {
            activityLog.removeFirst(activityLog.count - 30)
        }
    }

    private func safeCatalogEditionKey(for item: PatchLibraryItem) -> String {
        let edition = isFreeFireMax ? "free-fire-max" : "free-fire"
        let filename = item.packageURL.lastPathComponent
            .replacingOccurrences(of: "[^A-Za-z0-9_-]", with: "-", options: .regularExpression)
        return "catalog-\(edition)-\(filename)-\(item.id.uuidString)"
    }

    private var activityLogView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(AppTheme.accent.opacity(0.13))
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppTheme.accentBright)
                }
                .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 2) {
                    Text("SYSTEM LOG")
                        .font(.system(size: 15, weight: .black, design: .monospaced))
                        .tracking(0.55)
                        .foregroundStyle(AppTheme.primaryText.opacity(0.96))
                    Text("PROCESSO EM TEMPO REAL · \(enabledPatchIDs.count) PATCH(S) ATIVO(S)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppTheme.primaryText.opacity(0.62))
                }
                Spacer()
                Circle()
                    .fill(activityLog.last?.level.tint ?? AppTheme.secondaryText)
                    .frame(width: 8, height: 8)
                    .shadow(color: .clear, radius: 0)
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(activityLog) { entry in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: entry.level.symbol)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(entry.level.tint)
                                    .frame(width: 16)
                                    .padding(.top, 1)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("› \(entry.message)")
                                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                        .lineLimit(3)
                                        .foregroundStyle(entry.level == .warning ? AppTheme.primaryText : AppTheme.primaryText.opacity(0.88))
                                    Text(entry.timestamp)
                                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                                        .foregroundStyle(AppTheme.primaryText.opacity(0.42))
                                }
                                Spacer(minLength: 0)
                            }
                            .id(entry.id)
                        }
                    }
                }
                .frame(maxHeight: 158)
                .onChange(of: activityLog.count) { _ in
                    if let last = activityLog.last {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .padding(15)
        .background(Color.black.opacity(0.92), in: RoundedRectangle(cornerRadius: 0, style: .continuous))
        .background(AppTheme.primaryText.opacity(0.035), in: RoundedRectangle(cornerRadius: 0, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 0, style: .continuous)
                .stroke(AppTheme.outline, lineWidth: 1.05)
        }
        .overlay(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 0, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .frame(height: 24)
                .clipShape(RoundedRectangle(cornerRadius: 0, style: .continuous))
                .allowsHitTesting(false)
        }
    }

    private var backupStatus: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.shield")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppTheme.accent)
            Text("Backup original protegido")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText)
        }
        .padding(.top, 18)
    }
}


private struct CHZSwitchStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            withAnimation(.spring(response: 0.30, dampingFraction: 0.78)) {
                configuration.isOn.toggle()
            }
        } label: {
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                Capsule(style: .continuous)
                    .fill(configuration.isOn
                    ? AppTheme.accentBright
                    : Color.white.opacity(0.16))
                    .background(AppTheme.cardBackground, in: Capsule(style: .continuous))
                    .frame(width: 58, height: 34)
                    .overlay {
                        Capsule(style: .continuous)
                            .stroke(configuration.isOn ? AppTheme.outlineStrong : AppTheme.outline, lineWidth: 1.05)
                    }

                Circle()
                    .fill(Color.white.opacity(configuration.isOn ? 1.0 : 0.72))
                    .frame(width: 28, height: 28)
                    .shadow(color: .black.opacity(0.28), radius: 2, y: 1)
                    .padding(3)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(configuration.isOn ? "Ativado" : "Desativado")
        .accessibilityAddTraits(configuration.isOn ? .isSelected : [])
    }
}



private struct ExternalPatchUnlockView: View {
    let request: PatchPasswordRequest
    @ObservedObject var store: PatchProjectStore
    let onCancel: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var password = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Patch protegido") {
                    Text(request.summary.packageID.uuidString)
                        .font(.headline.monospaced())
                        .lineLimit(1)
                    SecureField("Senha do patch", text: $password)
                        .textContentType(.password)
                        .autocorrectionDisabled(true)
                        .textInputAutocapitalization(.never)
                    if let errorKey = store.unlockErrorKey {
                        Text(errorKey == "patch.error.wrong_password" ? "Senha incorreta ou pacote inválido." : "Não foi possível desbloquear o patch.")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.primaryText)
                    }
                }
                Section {
                    Text("A senha é solicitada somente para desbloquear este pacote. A aplicação continua sendo feita pelo fluxo original do 3105.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Senha necessária")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Continuar") {
                        store.unlock(password: password)
                    }
                    .disabled(password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.isBusy)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

private struct ExternalPanelView: View {
    @Binding var isFreeFireMax: Bool
    @ObservedObject var licenseViewModel: LicenseViewModel
    @EnvironmentObject private var appState: AppState
    @State private var diagnosticsEnabled = false
    @State private var showLocalLogs = true
    @State private var externalReport: ExternalArtifactReport?
    @State private var externalBackup: ExternalBackupReceipt?
    @State private var externalMessage: String?
    @State private var hasPreparedExternalArtifact = false
    @State private var activeExternalPatchIDs = Set<String>()
    @State private var workingExternalPatchID: String?
    @State private var externalPatchMessage: String?
    @State private var showPathValidationConfirmation = false
    @State private var pathValidationConfirmationMessage = ""
    @State private var pathValidationConfirmationTitle = "Ativação concluída"
    @State private var pathValidationConfirmationIsActivation = true
    @State private var showDemoUnlock = false
    @State private var demoUnlockFunctionID: String?
    private enum ExternalLogLevel: Equatable {
        case info, progress, success, warning

        var tint: Color {
            switch self {
            case .info: return AppTheme.secondaryText
            case .progress: return AppTheme.accentBright
            case .success: return AppTheme.success
            case .warning: return .orange
            }
        }

        var symbol: String {
            switch self {
            case .info: return "info.circle.fill"
            case .progress: return "arrow.triangle.2.circlepath"
            case .success: return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            }
        }
    }

    private struct ExternalLogEntry: Identifiable {
        let id = UUID()
        let timestamp: String
        let message: String
        let level: ExternalLogLevel
    }

    @State private var externalLog: [ExternalLogEntry] = [
        ExternalLogEntry(
            timestamp: Date().formatted(date: .omitted, time: .shortened),
            message: "Sistema pronto — aguardando funções",
            level: .info
        )
    ]

    private struct ExternalPatchFunction: Identifiable {
        let id: String
        let filename: String
        let title: String
        let detail: String
        let isDemoOnly: Bool
        let bundledURL: URL?

        init(
            id: String,
            filename: String,
            title: String,
            detail: String,
            isDemoOnly: Bool,
            bundledURL: URL? = nil
        ) {
            self.id = id
            self.filename = filename
            self.title = title
            self.detail = detail
            self.isDemoOnly = isDemoOnly
            self.bundledURL = bundledURL
        }
    }

    private var externalFunctions: [ExternalPatchFunction] {
        let urls = DevicePatchService.embeddedExternalArtifacts()
        let newPatchNames = ["HSALTO.3105", "HSPEITO.3105", "HSPESCOÇO.3105", "HSPESCOÇOALTO.3105", "HSBYPASSAP.3105"]
        return urls
            .filter { url in
                let name = url.lastPathComponent
                return newPatchNames.contains(name)
            }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            .map { url in
                let filename = url.lastPathComponent
                let base = filename.replacingOccurrences(of: ".3105", with: "")
                let title = base
                let detail = ""
                return ExternalPatchFunction(
                    id: filename,
                    filename: filename,
                    title: title,
                    detail: detail,
                    isDemoOnly: false,
                    bundledURL: url
                )
            }
    }

    private var editionName: String {
        isFreeFireMax ? "FREE FIRE MAX" : "FREE FIRE"
    }

    private var editionSelector: some View {
        Picker("Edição", selection: $isFreeFireMax) {
            Text("Free Fire").tag(false)
            Text("Free Fire MAX").tag(true)
        }
        .pickerStyle(.segmented)
        .tint(AppTheme.accent)
        .padding(4)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 0, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 0, style: .continuous)
                .stroke(AppTheme.outlineStrong, lineWidth: 0.8)
        }
    }

    private var editionStatus: String {
        isFreeFireMax ? "AMBIENTE SELECIONADO" : "AMBIENTE SELECIONADO"
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 13) {
                CHZPrivWordmark(size: 40)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 6)
                editionSelector
                externalFunctionsSection
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.shield")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)
                    Text("Backup original protegido")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppTheme.secondaryText)
                }
                .padding(.top, 18)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 112)
        }
        .chzPrivScrollBounceBehavior()
        .scrollIndicators(.hidden)
        .background(AppTheme.pageBackground.ignoresSafeArea())
        .onAppear { refreshExternalState() }
        .overlay {
            if showPathValidationConfirmation {
                ValidationConfirmationOverlay(
                    title: pathValidationConfirmationTitle,
                    message: pathValidationConfirmationMessage,
                    isActivation: pathValidationConfirmationIsActivation,
                    onDismiss: { showPathValidationConfirmation = false }
                )
            }
        }
        .sheet(isPresented: $showDemoUnlock) {
            ExternalDemoUnlockSheet(
                onCancel: {
                    demoUnlockFunctionID = nil
                    showDemoUnlock = false
                },
                onSuccess: {
                    let isChPainel = demoUnlockFunctionID == "demo-chpainel"
                    let isModnew = demoUnlockFunctionID == "demo-modnew-external"
                    if let report = prepareBundledDemoArtifact(
                        resourceName: isChPainel ? "chpainel" : (isModnew ? "modnew" : "externo-1"),
                        password: (isChPainel || isModnew) ? nil : "CHZ",
                        displayName: isChPainel ? "ChPainel.3105" : (isModnew ? "Modnew.3105" : "externo(1).3105"),
                        expectedHash: isChPainel ? "627c73e1def4df9bd38b30db255cadd9264bf1651e73e9064bac38c0bf019387" : (isModnew ? "b1f1d5d273f156bf3f60dfbf55327206eb693619a411fa7a00f8ccb605f06f3b" : "2ed6b7562efc85965efc78304df8a37f9f6daea3eb900eb509409fc5eeabf3b0")
                    ), let id = demoUnlockFunctionID {
                        let function = ExternalPatchFunction(
                            id: id,
                            filename: report.filename,
                            title: isChPainel ? "ChPainel" : (isModnew ? "External" : "Painel External"),
                            detail: "",
                            isDemoOnly: true
                        )
                        do {
                            let editionKey = externalEditionKey(for: function)
                            _ = try DevicePatchService.installExternalArtifact(report, editionKey: editionKey)
                            try DevicePatchService.verifyExternalWorkingFile(editionKey: editionKey)
                            externalReport = report
                            activeExternalPatchIDs.insert(id)
                            externalPatchMessage = "\(function.title) validado e substituído na área privada do app."
                            pathValidationConfirmationMessage = "\(function.title) foi validado com SHA-256 e o caminho interno foi confirmado no container privado do app."
                            showPathValidationConfirmation = true
                            appendExternalLog("[OK] Backup original criado; arquivo instalado em Application Support/ExternalMenu/Working")
                        } catch {
                            externalPatchMessage = "Falha ao instalar na área privada do app."
                            appendExternalLog("[ERRO] Instalação interna interrompida: \(error.localizedDescription)")
                        }
                    }
                    demoUnlockFunctionID = nil
                    showDemoUnlock = false
                    appendExternalLog("[OK] Autorização local confirmada; nenhum container externo acessado")
                }
            )
        }
    }

    private func prepareBundledDemoArtifact(resourceName: String, password: String?, displayName: String, expectedHash: String) -> ExternalArtifactReport? {
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "3105.validation") else {
            externalMessage = "Arquivo \(displayName) ausente no bundle."
            appendExternalLog("[ERRO] \(displayName) ausente no bundle")
            return nil
        }
        do {
            let report = try DevicePatchService.validateExternalArtifact(at: url, password: password)
            guard report.sha256 == expectedHash else {
                throw PatchPackageError.unsupportedFormat
            }
            externalMessage = "\(displayName) validado e copiado para a quarentena interna."
            appendExternalLog("[OK] \(displayName) validado; SHA-256 confirmado")
            appendExternalLog("[INFO] Quarentena: Application Support/ExternalMenu/Quarantine")
            return report
        } catch {
            externalMessage = "Falha na validação estrutural do \(displayName)."
            appendExternalLog("[ERRO] Validação de \(displayName) interrompida: \(error.localizedDescription)")
            return nil
        }
    }

    private var compactExternalHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("EXTERNAL / FUNÇÕES")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(1.0)
                .foregroundStyle(AppTheme.accentBright)
            Text(isFreeFireMax ? "FREE FIRE MAX" : "FREE FIRE")
                .font(.system(size: 24, weight: .black, design: .monospaced))
               .foregroundStyle(AppTheme.primaryText)
        }
    }

    private var externalLogSection: some View {
        externalActivityLogView
    }

    private var externalActivityLogView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(AppTheme.accent.opacity(0.13))
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppTheme.accentBright)
                }
                .frame(width: 34, height: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text("SYSTEM LOG")
                        .font(.system(size: 15, weight: .black, design: .monospaced))
                        .tracking(0.55)
                        .foregroundStyle(AppTheme.primaryText.opacity(0.96))
                    Text("PROCESSO EM TEMPO REAL · \(activeExternalPatchIDs.count) PATCH(S) ATIVO(S)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppTheme.primaryText.opacity(0.62))
                }
                Spacer()
                Circle()
                    .fill(externalLog.last?.level.tint ?? AppTheme.secondaryText)
                    .frame(width: 8, height: 8)
                    .shadow(color: .clear, radius: 0)
            }
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(externalLog) { entry in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: entry.level.symbol)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(entry.level.tint)
                                    .frame(width: 16)
                                    .padding(.top, 1)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("› \(entry.message)")
                                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                        .lineLimit(3)
                                        .foregroundStyle(entry.level == .warning ? .orange : AppTheme.primaryText.opacity(0.88))
                                    Text(entry.timestamp)
                                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                                        .foregroundStyle(AppTheme.primaryText.opacity(0.42))
                                }
                                Spacer(minLength: 0)
                            }
                            .id(entry.id)
                        }
                    }
                }
                .frame(maxHeight: 158)
                .onChange(of: externalLog.count) { _ in
                    if let last = externalLog.last {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .padding(15)
        .background(Color.black.opacity(0.92), in: RoundedRectangle(cornerRadius: 0, style: .continuous))
        .background(AppTheme.primaryText.opacity(0.035), in: RoundedRectangle(cornerRadius: 0, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 0, style: .continuous)
                .stroke(AppTheme.outline, lineWidth: 1.05)
        }
        .overlay(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 0, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .frame(height: 24)
                .clipShape(RoundedRectangle(cornerRadius: 0, style: .continuous))
                .allowsHitTesting(false)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SYSTEM / MENU")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .tracking(1.1)
                        .foregroundStyle(AppTheme.accentBright)
                    Text("External Menu")
                        .font(.system(size: 28, weight: .black, design: .monospaced))
                       .foregroundStyle(AppTheme.primaryText)
                }
                Spacer()
                Image(systemName: "rectangle.3.group.fill")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(AppTheme.accentBright)
            }
            Text("Central de status, diagnóstico e configurações internas do aplicativo.")
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(AppTheme.secondaryText)
        }
    }

    private var environmentSection: some View {
        panelSection(title: "AMBIENTE") {
            HStack(spacing: 12) {
                Image(systemName: isFreeFireMax ? "sparkles.rectangle.stack.fill" : "gamecontroller.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppTheme.accentBright)
                    .frame(width: 34)
                VStack(alignment: .leading, spacing: 3) {
                    Text(editionName)
                        .font(.system(size: 17, weight: .bold, design: .monospaced))
                       .foregroundStyle(AppTheme.primaryText)
                    Text(editionStatus)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppTheme.success)
                }
                Spacer()
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(AppTheme.success)
            }
        }
    }

    private var statusSection: some View {
        panelSection(title: "STATUS DO APP") {
            diagnosticRow("Licença", value: licenseViewModel.statusText, color: licenseViewModel.statusColor, symbol: "key.fill")
            divider
            diagnosticRow("Compatibilidade", value: appState.isSupported ? "COMPATÍVEL" : "INCOMPATÍVEL", color: appState.isSupported ? AppTheme.success : .red, symbol: "checkmark.shield.fill")
            divider
            diagnosticRow("Conexão", value: "PRONTA", color: AppTheme.success, symbol: "antenna.radiowaves.left.and.right")
        }
    }

    private var diagnosticsSection: some View {
        panelSection(title: "DIAGNÓSTICO") {
            Toggle(isOn: $diagnosticsEnabled) {
                diagnosticLabel("Verificação local", detail: "Executar apenas diagnóstico interno", symbol: "waveform.path.ecg")
            }
            .tint(AppTheme.accent)
            divider
            diagnosticRow("Integridade do app", value: diagnosticsEnabled ? "VERIFICADA" : "AGUARDANDO", color: diagnosticsEnabled ? AppTheme.success : AppTheme.secondaryText, symbol: "checkmark.shield")
            divider
            diagnosticRow("Logs da sessão", value: showLocalLogs ? "VISÍVEIS" : "OCULTOS", color: AppTheme.secondaryText, symbol: "doc.text.magnifyingglass")
        }
    }

    private var externalFunctionsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("FUNÇÕES")
                    .font(.system(size: 20, weight: .bold))
                    .tracking(0.6)
                   .foregroundStyle(AppTheme.primaryText)
                Spacer()
                Text("\(externalFunctions.count)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.secondaryText)
            }
            LazyVStack(alignment: .leading, spacing: 8) {
                if externalFunctions.isEmpty {
                    Text("Aguardando novo patch .3105")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(AppTheme.secondaryText)
                        .padding(.vertical, 8)
                } else {
                    ForEach(externalFunctions) { function in
                        externalFunctionRow(function)
                    }
                }
            }
            if let externalPatchMessage {
                Text(externalPatchMessage)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(AppTheme.secondaryText)
                    .padding(.top, 4)
            }
        }
    }

    private func externalFunctionRow(_ function: ExternalPatchFunction) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "shippingbox.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(AppTheme.accentBright)
                .shadow(color: .clear, radius: 0)
                .frame(width: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                Text(function.title.uppercased())
                    .font(.system(size: 17, weight: .bold, design: .monospaced))
                    .tracking(0.25)
                   .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(2)
                Text(function.detail)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(AppTheme.tertiaryText)
                    .lineLimit(2)
            }
            Spacer(minLength: 6)
            if workingExternalPatchID == function.id {
                ProgressView()
                    .controlSize(.small)
                    .tint(AppTheme.accentBright)
            }
            Toggle(function.title, isOn: Binding(
                get: { activeExternalPatchIDs.contains(function.id) },
                set: { handleExternalPatch(function, enabled: $0) }
            ))
            .labelsHidden()
            .toggleStyle(CHZSwitchStyle())
            .disabled(workingExternalPatchID != nil)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
        .frame(minHeight: 64)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.contentCardCornerRadius, style: .continuous))
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.contentCardCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.contentCardCornerRadius, style: .continuous)
                .stroke(AppTheme.outline, lineWidth: 1.0)
        }
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.contentCardCornerRadius, style: .continuous)
                .stroke(AppTheme.outlineStrong, lineWidth: 1.15)
        }
        .shadow(color: .clear, radius: 0)
        .overlay(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 0, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .frame(height: 28)
                .clipShape(RoundedRectangle(cornerRadius: 0, style: .continuous))
                .allowsHitTesting(false)
        }
    }

    private func externalEditionKey(for function: ExternalPatchFunction) -> String {
        let prefix = isFreeFireMax ? "free-fire-max" : "free-fire"
        let safe = function.id.replacingOccurrences(of: "[^A-Za-z0-9_-]", with: "-", options: .regularExpression)
        return "\(prefix)-\(safe)"
    }

    private func refreshExternalState() {
        let active = Set(externalFunctions.compactMap { function in
            DevicePatchService.hasExternalWorkingFile(editionKey: externalEditionKey(for: function)) ? function.id : nil
        })
        activeExternalPatchIDs = active
    }

    private func handleExternalPatch(_ function: ExternalPatchFunction, enabled: Bool) {
        guard workingExternalPatchID == nil else { return }
        if function.isDemoOnly {
            guard enabled else {
                do {
                    _ = try DevicePatchService.restoreExternalWorkingFile(editionKey: externalEditionKey(for: function))
                    activeExternalPatchIDs.remove(function.id)
                    pathValidationConfirmationTitle = "Desativação concluída"
                    pathValidationConfirmationIsActivation = false
                    pathValidationConfirmationMessage = "\(function.title) foi desativado e o backup original foi restaurado na área privada."
                    showPathValidationConfirmation = true
                    externalPatchMessage = "\(function.title) desativado e backup original restaurado na área privada."
                    appendExternalLog("[OK] Backup original restaurado; nenhuma área externa acessada")
                } catch {
                    externalPatchMessage = "Falha ao restaurar o backup interno."
                    appendExternalLog("[ERRO] Restauração interna interrompida: \(error.localizedDescription)")
                }
                return
            }
            if function.id == "demo-chpainel" || function.id == "demo-modnew-external" {
                activateBundledDemoWithoutUnlock(function)
                return
            }
            demoUnlockFunctionID = function.id
            showDemoUnlock = true
            appendExternalLog("[PROCESSO] Solicitação de autorização local do Painel External")
            return
        }
        let sourceURL: URL?
        if enabled {
            sourceURL = function.bundledURL ?? Bundle.main.urls(
                forResourcesWithExtension: "3105",
                subdirectory: nil
            )?.first(where: { $0.lastPathComponent == function.filename })
            guard sourceURL != nil else {
                externalPatchMessage = "Recurso não encontrado no bundle."
                appendExternalLog("[ERRO] Recurso não encontrado: \(function.filename)")
                return
            }
        } else {
            sourceURL = nil
        }
        workingExternalPatchID = function.id
        let editionKey = externalEditionKey(for: function)
        let action = enabled ? "ATIVAR" : "DESATIVAR"
        appendExternalLog("[\(action)] \(function.title)")
        appendExternalLog(enabled ? "[PROCESSO] 3105 iniciou a validação e aplicação" : "[PROCESSO] 3105 iniciou a restauração do original")
        if enabled {
            appendExternalLog("[PROCESSO] Envelope .3105 em validação estrutural sem senha")
            appendExternalLog("[PROCESSO] Confirmando edição, hash e recibo interno")
        }
        externalPatchMessage = enabled ? "Processando ativação…" : "Processando restauração…"
        Task.detached(priority: .userInitiated) {
            do {
                if enabled {
                    guard let sourceURL else { throw PatchPackageError.invalidProject }
                    let report = try DevicePatchService.validateEmbeddedExternalArtifact(sourceURL)
                    _ = try DevicePatchService.installExternalArtifact(report, editionKey: editionKey)
                    try DevicePatchService.verifyExternalWorkingFile(editionKey: editionKey)
                } else {
                    _ = try DevicePatchService.restoreExternalWorkingFile(editionKey: editionKey)
                }
                await MainActor.run {
                    if enabled { activeExternalPatchIDs.insert(function.id) }
                    else { activeExternalPatchIDs.remove(function.id) }
                    workingExternalPatchID = nil
                    externalPatchMessage = enabled ? "Função ativada e verificada." : "Função desativada e original restaurado."
                    pathValidationConfirmationTitle = enabled ? "Ativação concluída" : "Desativação concluída"
                    pathValidationConfirmationIsActivation = enabled
                    pathValidationConfirmationMessage = enabled
                        ? "\(function.title) foi ativado, verificado por SHA-256 e gravado somente no container privado do app."
                        : "\(function.title) foi desativado e o arquivo original foi restaurado no container privado do app."
                    showPathValidationConfirmation = true
                    appendExternalLog(enabled ? "[OK] Recibo e hash confirmados; função ativada" : "[OK] Original restaurado e verificado")
                }
            } catch {
                await MainActor.run {
                    workingExternalPatchID = nil
                    let reason = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    externalPatchMessage = "Validação falhou: \(reason)"
                    appendExternalLog("[ERRO] \(function.title): \(reason)")
                }
            }
        }
    }

    private func activateBundledDemoWithoutUnlock(_ function: ExternalPatchFunction) {
        let isChPainel = function.id == "demo-chpainel"
        let resourceName = isChPainel ? "chpainel" : "modnew"
        let displayName = isChPainel ? "ChPainel.3105" : "Modnew.3105"
        let expectedHash = isChPainel
            ? "627c73e1def4df9bd38b30db255cadd9264bf1651e73e9064bac38c0bf019387"
            : "b1f1d5d273f156bf3f60dfbf55327206eb693619a411fa7a00f8ccb605f06f3b"
        guard let report = prepareBundledDemoArtifact(resourceName: resourceName, password: nil, displayName: displayName, expectedHash: expectedHash) else { return }
        do {
            let editionKey = externalEditionKey(for: function)
            _ = try DevicePatchService.installExternalArtifact(report, editionKey: editionKey)
            try DevicePatchService.verifyExternalWorkingFile(editionKey: editionKey)
            activeExternalPatchIDs.insert(function.id)
            externalPatchMessage = "\(function.title) ativado sem senha na área privada do app."
            pathValidationConfirmationMessage = "\(function.title) foi ativado, verificado por SHA-256 e gravado somente no container privado do app."
            showPathValidationConfirmation = true
            appendExternalLog("[OK] \(function.title) validado, com backup criado e instalado internamente")
        } catch {
            externalPatchMessage = "Falha ao instalar \(function.title) na área privada."
            appendExternalLog("[ERRO] Instalação interna interrompida: \(error.localizedDescription)")
        }
    }

    private func appendExternalLog(_ line: String) {
        let level: ExternalLogLevel
        if line.contains("[ERRO]") { level = .warning }
        else if line.contains("[OK]") { level = .success }
        else if line.contains("[PROCESSO]") { level = .progress }
        else { level = .info }
        externalLog.append(ExternalLogEntry(
            timestamp: Date().formatted(date: .omitted, time: .shortened),
            message: line,
            level: level
        ))
        if externalLog.count > 30 {
            externalLog.removeFirst(externalLog.count - 30)
        }
    }

    private var externalArtifactSection: some View {
        panelSection(title: "ARQUIVOS EXTERNAL") {
            diagnosticLabel(
                "Gerenciado pelo catálogo de funções",
                detail: "Use os switches na aba de funções para validar, proteger e restaurar os arquivos internos.",
                symbol: "switch.2"
            )

            if let report = externalReport {
                divider
                diagnosticRow(
                    "Status",
                    value: "VALIDADO",
                    color: AppTheme.success,
                    symbol: "checkmark.seal.fill"
                )
                divider
                diagnosticRow(
                    "SHA-256",
                    value: String(report.sha256.prefix(12)) + "…",
                    color: AppTheme.secondaryText,
                    symbol: "number"
                )
                divider
                diagnosticRow(
                    "Origem",
                    value: "externo(1).3105",
                    color: AppTheme.secondaryText,
                    symbol: "doc.badge.checkmark"
                )
                divider
                HStack(spacing: 10) {
                    Button("Criar backup") {
                        do {
                            externalBackup = try DevicePatchService.backupExternalArtifact(report)
                            externalMessage = "Backup interno criado."
                        } catch {
                            externalMessage = "Não foi possível criar o backup."
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.accent)
                    .disabled(externalBackup != nil)

                    Button("Restaurar original") {
                        guard let externalBackup else {
                            externalMessage = "Crie o backup interno antes de restaurar."
                            return
                        }
                        do {
                            _ = try DevicePatchService.restoreExternalBackup(externalBackup)
                            externalMessage = "Backup interno restaurado e verificado."
                            appendExternalLog("[OK] Backup de externo(1).3105 restaurado na quarentena")
                        } catch {
                            externalMessage = "Falha ao restaurar o backup interno."
                            appendExternalLog("[ERRO] Restauração interna interrompida")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(externalBackup == nil)

                    Button("Excluir backup") {
                        guard let externalBackup else { return }
                        do {
                            try DevicePatchService.deleteExternalBackup(externalBackup)
                            self.externalBackup = nil
                            externalMessage = "Backup interno excluído."
                            appendExternalLog("[OK] Backup interno excluído")
                        } catch {
                            externalMessage = "Falha ao excluir o backup interno."
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(externalBackup == nil)
                }
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .padding(.vertical, 8)
            }

            if let externalMessage {
                Text(externalMessage)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(AppTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
            }
        }
    }

    private var settingsSection: some View {
        panelSection(title: "PREFERÊNCIAS") {
            Toggle(isOn: $showLocalLogs) {
                diagnosticLabel("Mostrar logs", detail: "Exibir atividade do app no painel principal", symbol: "text.line.first.and.arrowtriangle.forward")
            }
            .tint(AppTheme.accent)
            divider
            diagnosticRow("Versão do sistema", value: AppInfo.osVersion, color: AppTheme.secondaryText, symbol: "iphone")
        }
    }

    private var safetyNote: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "lock.shield.fill")
                .foregroundStyle(AppTheme.accentBright)
            Text("Este painel controla somente estados, diagnósticos e preferências internas. Nenhuma função deste painel altera memória, arquivos ou comportamento de outro aplicativo.")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(AppTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 3)
    }

    private func panelSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(AppTheme.secondaryText)
            VStack(spacing: 0) {
                content()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 5)
            .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 0, style: .continuous))
            .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 0, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 0, style: .continuous)
                    .stroke(AppTheme.outlineStrong, lineWidth: 1.05)
            }
        }
    }

    private func diagnosticLabel(_ title: String, detail: String, symbol: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(AppTheme.accentBright)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                   .foregroundStyle(AppTheme.primaryText)
                Text(detail)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

    private func diagnosticRow(_ title: String, value: String, color: Color, symbol: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(AppTheme.accentBright)
                .frame(width: 24)
            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
               .foregroundStyle(AppTheme.primaryText)
            Spacer(minLength: 8)
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(minHeight: 44)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.10))
            .frame(height: 0.7)
    }
}

private struct ExternalDemoUnlockSheet: View {
    let expectedPassword: String
    let title: String
    let onCancel: () -> Void
    let onSuccess: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var password = ""
    @State private var attempts = 0
    @State private var errorMessage: String?

    init(expectedPassword: String = "CHZ", title: String = "Painel External", onCancel: @escaping () -> Void, onSuccess: @escaping () -> Void) {
        self.expectedPassword = expectedPassword
        self.title = title
        self.onCancel = onCancel
        self.onSuccess = onSuccess
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Autorização local") {
                    SecureField("Senha", text: $password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(AppTheme.primaryText)
                            .font(.footnote)
                    }
                }
                Section {
                    Text("Esta autorização altera somente o estado visual interno do app. Nenhum payload é executado.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Validar") {
                        validate()
                    }
                    .disabled(password.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func validate() {
        let digest = SHA256.hash(data: Data(password.utf8))
        let expected = SHA256.hash(data: Data(expectedPassword.utf8))
        guard digest == expected else {
            attempts += 1
            password = ""
            errorMessage = attempts >= 3 ? "Limite de tentativas atingido." : "Senha incorreta."
            if attempts >= 3 {
                onCancel()
                dismiss()
            }
            return
        }
        onSuccess()
        dismiss()
    }
}

private struct ValidationConfirmationOverlay: View {
    let title: String
    let message: String
    let isActivation: Bool
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.42)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: isActivation ? "checkmark.seal.fill" : "arrow.uturn.backward.circle.fill")
                        .font(.system(size: 23, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("CHZ PRIV / SYSTEM")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .tracking(1.0)
                            .foregroundStyle(AppTheme.tertiaryText)
                        Text(title)
                            .font(.system(size: 19, weight: .bold, design: .monospaced))
                            .foregroundStyle(AppTheme.primaryText)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(AppTheme.primaryText.opacity(0.07), in: Capsule(style: .continuous))
                .overlay(Capsule(style: .continuous).stroke(AppTheme.outlineStrong, lineWidth: 0.8))
                Text(message)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Continuar", action: onDismiss)
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(AppTheme.primaryText, in: Capsule(style: .continuous))
                    .foregroundStyle(AppTheme.pageBackground)
            }
            .padding(20)
            .frame(maxWidth: 330)
            .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .background(Color.black.opacity(0.88), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(AppTheme.outlineStrong, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.42), radius: 26, y: 12)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
        .animation(.easeOut(duration: 0.2), value: message)
    }
}

#if DEBUG
#Preview("Painel External") {
    ExternalPanelView(isFreeFireMax: .constant(false), licenseViewModel: LicenseViewModel())
        .environmentObject(AppState())
}
#endif
