import SwiftUI
import UIKit

struct ContentView: View {
    var isFreeFireMax: Bool = false
    let onExitToGamePicker: () -> Void
    @Environment(\.appLanguage) private var language
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var patchDraftCoordinator: PatchDraftCoordinator
    @State private var tabNavigation: AppTabNavigationState
    @AppStorage(FeatureVisibility.cleanerStorageKey) private var cleanerEnabled = true
    @AppStorage(FeatureVisibility.wallpapersStorageKey) private var wallpapersEnabled = true

    init(isFreeFireMax: Bool = false, onExitToGamePicker: @escaping () -> Void = {}) {
        self.isFreeFireMax = isFreeFireMax
        self.onExitToGamePicker = onExitToGamePicker
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
            isFreeFireMax: isFreeFireMax,
            onExitToGamePicker: onExitToGamePicker
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
                isFreeFireMax: isFreeFireMax,
                onExitToGamePicker: onExitToGamePicker
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
                .foregroundStyle(appState.isSupported ? AppTheme.success : Color.red)
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
    let isFreeFireMax: Bool
    let onExitToGamePicker: () -> Void
    @EnvironmentObject private var appState: AppState
    @StateObject private var licenseViewModel = LicenseViewModel()

    private enum HomePage {
        case license
        case injector
    }

    private enum LogLevel: Equatable {
        case info, progress, success, warning

        var tint: Color {
            switch self {
            case .info: return AppTheme.secondaryText
            case .progress: return AppTheme.accentBright
            case .success: return AppTheme.success
            case .warning: return Color.orange
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
    @State private var didLoadPatches = false
    @State private var patchLoadingCoordinator = PatchLoadingCoordinator()
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
                    } else {
                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVStack(alignment: .leading, spacing: 13) {
                                logo
                                activityLogView
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
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        onExitToGamePicker()
                    } label: {
                        Label("Início", systemImage: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .accessibilityLabel("Voltar para a tela inicial")
                }
            }
        }
        .tint(AppTheme.accent)
        .onAppear {
            licenseViewModel.refresh()
            loadPatchesIfNeeded()
        }
        .fullScreenCover(isPresented: $licenseViewModel.requiresLogin, onDismiss: {
            licenseViewModel.refresh()
        }) {
            CHZLoginViewControllerRepresentable()
                .ignoresSafeArea()
        }
    }

    private var bottomNavigation: some View {
        HStack(spacing: 4) {
            bottomNavigationItem(.license, title: "Início", symbol: "house.fill")
            bottomNavigationItem(.injector, title: "Injetor", symbol: "gamecontroller.fill")
        }
        .padding(5)
        .background(.ultraThinMaterial, in: Capsule(style: .continuous))
        .background(AppTheme.cardBackground.opacity(0.84), in: Capsule(style: .continuous))
        .overlay {
            Capsule(style: .continuous)
                .stroke(AppTheme.outline, lineWidth: 1.15)
        }
        .shadow(color: AppTheme.accent.opacity(0.22), radius: 18, y: 8)
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
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
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

    private var categoryOverview: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 10) {
                categoryOverviewCard(.avatar)
                categoryOverviewCard(.cache)
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
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.primaryText)
                Text("\(count) funções")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .padding(.horizontal, 13)
        .frame(minWidth: 142, minHeight: 48, alignment: .leading)
        .background(AppTheme.cardBackground.opacity(0.72), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.outlineStrong, lineWidth: 1.05)
        }
    }

    private var functions: some View {
        VStack(alignment: .leading, spacing: 15) {
            if isFreeFireMax {
                Text("Suporte em breve…")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 34)
                    .background(.ultraThinMaterial.opacity(0.55), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(AppTheme.outline, lineWidth: 1.0)
                    }
            } else {
                categorySection(.avatar)
                categorySection(.cache)
            }
        }
    }

    @ViewBuilder
    private func categorySection(_ category: PatchCategory) -> some View {
        let items = freeFirePatches.filter { $0.category == category }
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(category.rawValue.uppercased())
                    .font(.system(size: 20, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(AppTheme.primaryText)
                Spacer()
                Text("\(items.count)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.secondaryText)
            }
            if items.isEmpty {
                Text("Nenhum patch disponível")
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

    private func functionRow(item: PatchLibraryItem) -> some View {
        let title = displayTitle(for: item)
        return HStack(spacing: 12) {
                Image(systemName: item.category.symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(AppTheme.accentBright)
                .shadow(color: AppTheme.accent.opacity(0.55), radius: 7)
                .frame(width: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                Text(title.uppercased())
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .tracking(0.25)
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(2)
                Text(patchDescription(for: item))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.tertiaryText)
                    .lineLimit(2)
            }
            Spacer(minLength: 6)
            Toggle("\(title)", isOn: Binding(
                get: { enabledPatchIDs.contains(item.id) },
                set: { updatePatchState(item: item, isEnabled: $0) }
            ))
                .labelsHidden()
                .toggleStyle(CHZSwitchStyle())
                .disabled(item.project == nil || isWorking)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
        .frame(minHeight: 78)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppTheme.contentCardCornerRadius, style: .continuous))
        .background(AppTheme.cardBackground.opacity(0.74), in: RoundedRectangle(cornerRadius: AppTheme.contentCardCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.contentCardCornerRadius, style: .continuous)
                .stroke(AppTheme.outline, lineWidth: 1.0)
        }
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.contentCardCornerRadius, style: .continuous)
                .stroke(AppTheme.outlineStrong, lineWidth: 1.15)
        }
        .shadow(color: AppTheme.accent.opacity(0.12), radius: 5, y: 3)
        .overlay(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(LinearGradient(
                    colors: [.white.opacity(0.13), .clear],
                    startPoint: .topLeading,
                    endPoint: .center
                ))
                .frame(height: 28)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .allowsHitTesting(false)
        }
    }

    private func displayTitle(for item: PatchLibraryItem) -> String {
        let rawTitle = item.project?.name ?? item.packageURL.deletingPathExtension().lastPathComponent
        let normalized = rawTitle
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .uppercased()
        if normalized.contains("100") && normalized.contains("BAYPSS") {
            return "Hs Pescoço Baixo"
        }
        return rawTitle
    }

    private func patchDescription(for item: PatchLibraryItem) -> String {
        let filename = item.packageURL.deletingPathExtension().lastPathComponent
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .uppercased()
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "+", with: " ")

        if filename.contains("100") && filename.contains("BAYPSS") {
            return "Hs no pescoço do inimigo"
        }
        if filename.contains("PEITO") && filename.contains("PESCO") {
            return "Hs no pescoço e peito do inimigo"
        }
        if filename.contains("PESCO") && filename.contains("ALTO") {
            return "Hs no pescoço e acima do inimigo"
        }
        if filename.contains("ALTO") && filename.contains("ANTENA") {
            return "Hs acima da cabeça do inimigo"
        }
        if filename.contains("ALTO") {
            return "Hs acima da cabeça do inimigo"
        }
        if filename.contains("PESCO") {
            return "Hs apenas no pescoço do inimigo"
        }
        return ""
    }

    private func loadPatchesIfNeeded() {
        guard !isFreeFireMax, !didLoadPatches, patchLoadingCoordinator.beginIfNeeded() else { return }
        didLoadPatches = true
        DispatchQueue.global(qos: .userInitiated).async {
            autoreleasepool {
                PatchProjectLibrary.installBundledOriginalFreeFirePatches()
                let items = PatchProjectLibrary.load()
                let enabled = Set(items.compactMap { item in
                    DevicePatchService.latestReceipt(projectID: item.id) == nil ? nil : item.id
                })
                DispatchQueue.main.async {
                    freeFirePatches = items
                    enabledPatchIDs = enabled
                }
            }
        }
    }

    private func updatePatchState(item: PatchLibraryItem, isEnabled: Bool) {
        if isEnabled && !licenseViewModel.isActive {
            if licenseViewModel.isValidating {
                appendLog("Aguardando validação da licença pelo ChzLogin", level: .progress)
            } else {
                appendLog("Ativação bloqueada: licença ausente, inválida ou expirada", level: .warning)
            }
            return
        }

        guard let baseProject = item.project else {
            appendLog("Patch indisponível: pacote bloqueado ou inválido", level: .warning)
            return
        }
        let patchName = baseProject.name
        isWorking = true

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

    private func applyPatch(item: PatchLibraryItem, baseProject: PatchProject, patchName: String) {
        Task.detached(priority: .userInitiated) {
            do {
                let project = item.summary.schemaVersion >= 2
                    ? try PatchProjectLibrary.synchronizeWorkspace(item: item)
                    : baseProject
                _ = try DevicePatchService.apply(project: project)
                await MainActor.run {
                    enabledPatchIDs.insert(item.id)
                    isWorking = false
                    SoundEffectManager.shared.play(.confirmation)
                    appendLog("Patch aplicado e verificado", level: .success)
                }
            } catch {
                await MainActor.run {
                    isWorking = false
                    appendLog("Falha ao ativar: \(error.localizedDescription)", level: .warning)
                }
            }
        }
    }

    private func restorePatch(item: PatchLibraryItem, patchName: String) {
        guard let receipt = DevicePatchService.latestReceipt(projectID: item.id) else {
            enabledPatchIDs.remove(item.id)
            isWorking = false
            appendLog("Nenhum backup ativo encontrado", level: .warning)
            return
        }
        Task.detached(priority: .userInitiated) {
            do {
                try DevicePatchService.restore(receipt: receipt)
                await MainActor.run {
                    enabledPatchIDs.remove(item.id)
                    isWorking = false
                    SoundEffectManager.shared.play(.confirmation)
                    appendLog("Arquivo original restaurado", level: .success)
                }
            } catch {
                await MainActor.run {
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
                    Text("CHZ PRIV // SYSTEM LOG")
                        .font(.system(size: 15, weight: .black, design: .monospaced))
                        .tracking(0.55)
                        .foregroundStyle(Color.green.opacity(0.96))
                    Text("PROCESSO EM TEMPO REAL · \(enabledPatchIDs.count) PATCH(S) ATIVO(S)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.green.opacity(0.62))
                }
                Spacer()
                Circle()
                    .fill(activityLog.last?.level.tint ?? AppTheme.secondaryText)
                    .frame(width: 8, height: 8)
                    .shadow(color: (activityLog.last?.level.tint ?? AppTheme.secondaryText).opacity(0.65), radius: 5)
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
                                        .foregroundStyle(entry.level == .warning ? Color.orange : Color.green.opacity(0.88))
                                    Text(entry.timestamp)
                                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                                        .foregroundStyle(Color.green.opacity(0.42))
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
        .background(Color.black.opacity(0.92), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .background(Color.green.opacity(0.035), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(AppTheme.outline, lineWidth: 1.05)
        }
        .overlay(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(LinearGradient(
                    colors: [.white.opacity(0.10), .clear],
                    startPoint: .topLeading,
                    endPoint: .center
                ))
                .frame(height: 24)
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
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
                    ? LinearGradient(
                        colors: [AppTheme.accentBright, AppTheme.accent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    : LinearGradient(
                        colors: [Color.white.opacity(0.16), Color.black.opacity(0.35)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .background(.ultraThinMaterial, in: Capsule(style: .continuous))
                    .frame(width: 58, height: 34)
                    .overlay {
                        Capsule(style: .continuous)
                            .stroke(configuration.isOn ? AppTheme.outlineStrong : AppTheme.outline, lineWidth: 1.05)
                    }

                Circle()
                    .fill(configuration.isOn ? Color.white : Color(red: 0.70, green: 0.70, blue: 0.74))
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


private struct CHZLoginViewControllerRepresentable: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> CHZLoginViewController {
        CHZLoginViewController()
    }

    func updateUIViewController(_ viewController: CHZLoginViewController, context: Context) {}
}
