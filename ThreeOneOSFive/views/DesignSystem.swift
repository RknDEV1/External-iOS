import SwiftUI
import UIKit

enum AppTheme {
    // Raki: interface monocromática, plana e discreta.
    static let accent = Color.white
    static let accentBright = Color.white
    static let accentSoft = Color.white.opacity(0.12)
    static let outline = Color.white.opacity(0.14)
    static let outlineStrong = Color.white.opacity(0.24)
    static let pageBackground = Color.black
    static let consoleBackground = Color.black
    static let cardBackground = Color.white.opacity(0.08)
    static let fieldBackground = Color.white.opacity(0.12)
    static let primaryText = Color.white
    static let secondaryText = Color.white.opacity(0.72)
    static let tertiaryText = Color.white.opacity(0.52)
    static let success = Color.white
    static let pageInset: CGFloat = 16
    static let rowIconSize: CGFloat = 17
    static let rowIconFrame: CGFloat = 28
    static let fileRowIconSize: CGFloat = 17
    static let fileRowIconFrame: CGFloat = 30
    static let fileRowHeight: CGFloat = 60
    static let appIconSize: CGFloat = 32
    static let emptyIconSize: CGFloat = 30
    static let selectionIconSize: CGFloat = 18
    static let contentCardCornerRadius: CGFloat = 14
    static let contentCardInset: CGFloat = 14
    static let contentCardPadding: CGFloat = 14
    static let brandFontName = "SF Mono"
}

struct CHZPrivWordmark: View {
    var size: CGFloat = 34

    var body: some View {
        Text("3105")
            .font(.system(size: size, weight: .semibold, design: .monospaced))
           .foregroundStyle(AppTheme.primaryText)
            .accessibilityLabel("3105")
    }
}

struct AppCardBorder: View {
    var body: some View {
        RoundedRectangle(cornerRadius: AppTheme.contentCardCornerRadius, style: .continuous)
            .strokeBorder(AppTheme.outlineStrong, lineWidth: 0.7)
            .accessibilityHidden(true)
    }
}

struct AppRowIcon: View {
    let systemName: String
    var tint: Color = AppTheme.accent
    var symbolSize: CGFloat = AppTheme.rowIconSize
    var frameSize: CGFloat = AppTheme.rowIconFrame

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: symbolSize, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: frameSize, height: frameSize)
            .accessibilityHidden(true)
    }
}

struct AppSearchField: View {
    @Binding var text: String
    let prompt: String
    let clearLabel: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.secondaryText)
                .accessibilityHidden(true)

            TextField(prompt, text: $text)
                .font(.body)
               .foregroundStyle(AppTheme.primaryText)
                .tint(AppTheme.accent)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)

            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.secondaryText)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(clearLabel)
            }
        }
        .padding(.horizontal, 11)
        .frame(minHeight: 38)
        .background(AppTheme.fieldBackground, in: RoundedRectangle(cornerRadius: 0, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 0, style: .continuous)
                .stroke(AppTheme.outlineStrong, lineWidth: 0.7)
        }
        .padding(.horizontal, AppTheme.pageInset)
        .padding(.vertical, 8)
        .background(AppTheme.pageBackground)
    }
}

struct AppLogo: View {
    var size: CGFloat = 44

    var body: some View {
        Image(systemName: "shippingbox.fill")
            .font(.system(size: size * 0.44, weight: .medium))
           .foregroundStyle(AppTheme.primaryText)
            .frame(width: size, height: size)
            .background(AppTheme.fieldBackground, in: RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
            .accessibilityHidden(true)
    }
}

struct AppThemeModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .preferredColorScheme(.dark)
            .tint(AppTheme.accent)
            .environment(\.font, .system(.body, design: .monospaced))
           .foregroundStyle(AppTheme.primaryText)
            .scrollContentBackground(.hidden)
            .background(AppTheme.pageBackground.ignoresSafeArea())
    }
}

extension View {
    func appTheme() -> some View {
        modifier(AppThemeModifier())
    }
}
