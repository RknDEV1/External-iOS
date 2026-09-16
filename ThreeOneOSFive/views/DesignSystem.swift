import SwiftUI
import UIKit

enum AppTheme {
    // Identidade CHZ PRIV: fundo preto, vermelho vivo, branco e cinza.
    static let accent = Color(red: 1.00, green: 0.015, blue: 0.055)
    static let accentBright = Color(red: 1.00, green: 0.16, blue: 0.19)
    static let accentSoft = Color(red: 1.00, green: 0.015, blue: 0.055).opacity(0.16)
    static let outline = accent.opacity(0.58)
    static let outlineStrong = accentBright.opacity(0.86)
    static let pageBackground = Color.black
    static let consoleBackground = Color(red: 0.045, green: 0.018, blue: 0.022)
    static let cardBackground = Color(red: 0.065, green: 0.020, blue: 0.026)
    static let fieldBackground = Color(red: 0.10, green: 0.035, blue: 0.042)
    static let primaryText = Color.white
    static let secondaryText = Color(red: 0.56, green: 0.56, blue: 0.58)
    static let tertiaryText = Color(red: 0.38, green: 0.38, blue: 0.40)
    static let success = Color(red: 0.19, green: 0.82, blue: 0.42)
    static let pageInset: CGFloat = 16
    static let rowIconSize: CGFloat = 17
    static let rowIconFrame: CGFloat = 28
    static let fileRowIconSize: CGFloat = 17
    static let fileRowIconFrame: CGFloat = 30
    static let fileRowHeight: CGFloat = 60
    static let appIconSize: CGFloat = 32
    static let emptyIconSize: CGFloat = 30
    static let selectionIconSize: CGFloat = 18
    static let contentCardCornerRadius: CGFloat = 18
    static let contentCardInset: CGFloat = 16
    static let contentCardPadding: CGFloat = 16
    static let brandFontName = "BurbankBigCondensed-Black"
}

struct CHZPrivWordmark: View {
    var size: CGFloat = 34

    var body: some View {
        VStack(spacing: -size * 0.08) {
            Text("CHZ PRIV")
                .font(.custom(AppTheme.brandFontName, size: size))
                .fontWeight(.black)
                .italic()
                .foregroundStyle(AppTheme.accent)
                .shadow(color: AppTheme.accent.opacity(0.90), radius: 1.5)
                .shadow(color: AppTheme.accent.opacity(0.72), radius: 0, x: 0.55, y: 0)
                .shadow(color: AppTheme.accent.opacity(0.45), radius: 0.45)
            Text("")
                .font(.custom(AppTheme.brandFontName, size: size * 0.94))
                .fontWeight(.black)
                .italic()
                .foregroundStyle(.white)
                .shadow(color: .white.opacity(0.72), radius: 1.2)
                .shadow(color: .white.opacity(0.62), radius: 0, x: 0.55, y: 0)
                .shadow(color: .white.opacity(0.30), radius: 0.45)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("CHZ PRIV")
    }
}

struct AppCardBorder: View {
    var body: some View {
        RoundedRectangle(cornerRadius: AppTheme.contentCardCornerRadius, style: .continuous)
            .strokeBorder(AppTheme.accent.opacity(0.52), lineWidth: 0.7)
            .accessibilityHidden(true)
    }
}

struct AppRowIcon: View {
    let systemName: String
    var tint: Color = AppTheme.accent
    var symbolSize: CGFloat = AppTheme.rowIconSize
    var frameSize: CGFloat = AppTheme.rowIconFrame

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(tint.opacity(0.16))
                .overlay {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(AppTheme.accent.opacity(0.42), lineWidth: 0.6)
                }
            Image(systemName: systemName)
                .font(.system(size: symbolSize, weight: .semibold))
                .foregroundStyle(tint)
        }
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
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.accent)
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
        .background(
            AppTheme.fieldBackground,
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppTheme.accent.opacity(0.38), lineWidth: 0.7)
        }
        .padding(.horizontal, AppTheme.pageInset)
        .padding(.vertical, 8)
        .background(AppTheme.pageBackground)
    }
}

struct AppLogo: View {
    var size: CGFloat = 44

    var body: some View {
        Text("CHZ PRIV")
            .font(.custom(AppTheme.brandFontName, size: size * 0.46))
            .fontWeight(.black)
            .italic()
            .foregroundStyle(.white)
            .frame(width: size, height: size)
        .background(AppTheme.accent)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .stroke(AppTheme.outlineStrong, lineWidth: 1.35)
        }
        .shadow(color: AppTheme.accent.opacity(0.35), radius: 8)
        .accessibilityHidden(true)
    }
}

struct AppThemeModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .preferredColorScheme(.dark)
            .tint(AppTheme.accent)
            .environment(\.font, .system(.body, design: .rounded))
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
