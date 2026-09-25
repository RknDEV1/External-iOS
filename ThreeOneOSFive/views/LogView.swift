import SwiftUI

struct LogView: View {
    @ObservedObject var appLog = AppLog.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.appLanguage) private var language
    @State private var copied = false

    private var shareText: String {
        var lines = [
            "Raki Log",
            "iOS \(AppInfo.osVersion) (\(AppInfo.osBuild)) — \(AppInfo.machineName)",
            "Generated: \(Date())",
            ""
        ]
        lines.append(contentsOf: appLog.entries)
        return lines.joined(separator: "\n")
    }

    var body: some View {
        NavigationStack {
            logContent
                .background(AppTheme.consoleBackground.ignoresSafeArea())
                .navigationTitle(language.text("logs.title"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { logToolbar }
        }
    }

    @ViewBuilder
    private var logContent: some View {
        if appLog.entries.isEmpty {
            emptyState
        } else {
            logList
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "apple.terminal")
                .font(.system(size: AppTheme.emptyIconSize, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText)
            Text(language.text("logs.empty_title"))
                .font(.title3.bold())
            Text(language.text("logs.empty_message"))
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }

    private var logList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(appLog.entries.indices, id: \.self) { index in
                        logRow(index: index, entry: appLog.entries[index])
                    }
                }
                .padding(AppTheme.pageInset)
                .background(AppTheme.consoleBackground)
            }
            .onChange(of: appLog.entries.count) { count in
                guard count > 0 else { return }
                let scroll = { proxy.scrollTo(count - 1, anchor: .bottom) }
                if reduceMotion {
                    scroll()
                } else {
                    withAnimation(.easeOut(duration: 0.2), scroll)
                }
            }
        }
    }

    private func logRow(index: Int, entry: String) -> some View {
        VStack(spacing: 0) {
            Text(entry)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(AppTheme.primaryText)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 11)
            if index < appLog.entries.count - 1 {
                Divider()
            }
        }
        .id(index)
        .accessibilityLabel(language.text("accessibility.log_entry", Int64(index + 1), entry))
    }

    @ToolbarContentBuilder
    private var logToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button(language.text("logs.clear"), role: .destructive) {
                appLog.clear()
            }
            .disabled(appLog.entries.isEmpty)
        }
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            Button {
                UIPasteboard.general.string = shareText
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
            }
            .disabled(appLog.entries.isEmpty)
            .accessibilityLabel(language.text("logs.copy"))

            ShareLink(item: shareText) {
                Image(systemName: "square.and.arrow.up")
            }
            .disabled(appLog.entries.isEmpty)
            .accessibilityLabel(language.text("logs.share"))

            Button(language.text("common.done")) { dismiss() }
                .fontWeight(.semibold)
        }
    }
}
