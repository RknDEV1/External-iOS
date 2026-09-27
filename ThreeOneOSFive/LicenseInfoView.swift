import SwiftUI
import UIKit

struct LicenseInfoView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var licenseViewModel: LicenseViewModel

    private var deviceIdentifier: String {
        UIDevice.current.identifierForVendor?.uuidString ?? "Indisponível"
    }

    private var compatibilityText: String {
        appState.isSupported ? "COMPATÍVEL" : "INCOMPATÍVEL"
    }

    private var compatibilityColor: Color {
        appState.isSupported ? AppTheme.success : .red
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                pageHeader
                licenseSection
                deviceSection
                securitySection
                footerNote
            }
            .padding(.horizontal, AppTheme.pageInset)
            .padding(.top, 18)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .background(AppTheme.pageBackground.ignoresSafeArea())
        .navigationTitle("Licença")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            licenseViewModel.refresh()
        }
    }

    private var pageHeader: some View {
        HStack(spacing: 12) {
            AppLogo(size: 42)
            VStack(alignment: .leading, spacing: 3) {
                CHZPrivWordmark(size: 24)
                Text("INFORMAÇÕES DA LICENÇA")
                    .font(.system(size: 17, weight: .bold, design: .default))
                    .tracking(0.45)
                    .foregroundStyle(AppTheme.primaryText)
            }
            Spacer()
        }
    }

    private var licenseSection: some View {
        infoSection(title: "INFORMAÇÕES DA LICENÇA") {
            infoRow(label: "Produto", value: licenseViewModel.snapshot.product)
            divider
            infoRow(label: "Status da Key", value: licenseViewModel.statusText, valueColor: licenseViewModel.statusColor)
            divider
            infoRow(label: "Tempo da Key", value: licenseViewModel.expirationText, valueColor: AppTheme.secondaryText, monospaced: true)
            divider
            infoRow(label: "Expiração", value: licenseViewModel.expirationText, valueColor: AppTheme.secondaryText, monospaced: true)
            divider
            infoRow(label: "ID do Dispositivo", value: shortIdentifier(licenseViewModel.snapshot.deviceID), valueColor: AppTheme.secondaryText, monospaced: true)
        }
    }

    private var deviceSection: some View {
        infoSection(title: "DISPOSITIVO & COMPATIBILIDADE") {
            infoRow(label: "Modelo", value: AppInfo.displayMachineName, valueColor: AppTheme.secondaryText, monospaced: true)
            divider
            infoRow(label: "Versão iOS", value: "\(AppInfo.osVersion) (\(AppInfo.osBuild))", valueColor: AppTheme.secondaryText, monospaced: true)
            divider
            infoRow(label: "Compatibilidade Root/PMAP", value: compatibilityText, valueColor: compatibilityColor)
        }
    }

    private var securitySection: some View {
        infoSection(title: "SEGURANÇA & ANTICRACK") {
            infoRow(label: "Proteção Anti-Debugging", value: "NÃO VERIFICADA", valueColor: AppTheme.secondaryText)
            divider
            infoRow(label: "Criptografia Keychain", value: "ATIVA", valueColor: AppTheme.success)
        }
    }

    private var footerNote: some View {
        Text("A chave é armazenada no Keychain. Os estados de segurança só são exibidos como ativos quando existe uma verificação correspondente no aplicativo.")
            .font(.system(size: 12, weight: .medium, design: .default))
            .foregroundStyle(AppTheme.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 2)
    }

    @ViewBuilder
    private func infoSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.system(size: 15, weight: .bold, design: .default))
                .tracking(0.6)
                .foregroundStyle(AppTheme.primaryText)

            VStack(spacing: 0) {
                content()
            }
            .padding(.horizontal, AppTheme.contentCardPadding)
            .padding(.vertical, 4)
            .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .background(AppTheme.cardBackground.opacity(0.72), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(AppTheme.outline, lineWidth: 1.0)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(AppTheme.outlineStrong, lineWidth: 1.05)
            }
            .shadow(color: .clear, radius: 0)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.10))
            .frame(height: 0.7)
    }

    private func infoRow(
        label: String,
        value: String,
        valueColor: Color = AppTheme.primaryText,
        monospaced: Bool = false
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(label)
                .font(.system(size: 15, weight: .medium, design: .default))
                .foregroundStyle(AppTheme.primaryText)
                .lineLimit(1)

            Spacer(minLength: 8)

            Text(value)
                .font(monospaced
                    ? .system(size: 14, weight: .medium, design: .monospaced)
                    : .system(size: 15, weight: .semibold, design: .default)
                )
                .foregroundStyle(valueColor)
                .multilineTextAlignment(.trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(minHeight: 56)
    }

    private func shortIdentifier(_ value: String) -> String {
        guard value.count > 18 else { return value }
        return String(value.prefix(16)) + "…"
    }
}
