import SwiftUI
import UIKit

enum AppTheme {
    // Raki monochrome interface using the native iOS system typeface.
    static let accent = Color.white
    static let accentBright = Color.white
    static let accentSoft = Color.white.opacity(0.12)
    static let outline = Color.white.opacity(0.08)
    static let outlineStrong = Color.white.opacity(0.14)
    static let pageBackground = Color.black
    static let consoleBackground = Color(red: 0.075, green: 0.075, blue: 0.085)
    static let cardBackground = Color(red: 0.11, green: 0.11, blue: 0.12)
    static let fieldBackground = Color(red: 0.14, green: 0.14, blue: 0.15)
    static let primaryText = Color.white
    static let secondaryText = Color(red: 0.62, green: 0.62, blue: 0.65)
    static let tertiaryText = Color(red: 0.48, green: 0.48, blue: 0.51)
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
    static let contentCardCornerRadius: CGFloat = 20
    static let contentCardInset: CGFloat = 16
    static let contentCardPadding: CGFloat = 16
    static let brandFontName = "SF Pro"
}

struct CHZPrivWordmark: View {
    var size: CGFloat = 34

    var body: some View {
        Text("Raki")
            .font(.system(size: size, weight: .bold, design: .default))
            .foregroundStyle(AppTheme.accentBright)
            .accessibilityLabel("Raki")
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
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(tint.opacity(0.16))
                .overlay {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(AppTheme.outlineStrong, lineWidth: 0.6)
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
                .font(.system(size: 14, weight: .semibold, design: .default))
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
            .font(.system(size: size * 0.48, weight: .semibold))
            .foregroundStyle(AppTheme.accentBright)
            .frame(width: size, height: size)
            .background(AppTheme.fieldBackground)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                    .stroke(AppTheme.outlineStrong, lineWidth: 1.0)
            }
            .accessibilityHidden(true)
    }
}

struct AppThemeModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .preferredColorScheme(.dark)
            .tint(AppTheme.accent)
            .environment(\.font, .system(.body, design: .default))
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
