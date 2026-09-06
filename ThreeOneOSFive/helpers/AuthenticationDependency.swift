import SwiftUI

@MainActor
final class AuthenticationDependencyState: ObservableObject {
    @Published private(set) var isAvailable = false

    func verify() {
        // O framework de autenticação deve ser vinculado normalmente ao target,
        // incorporado e assinado. A classe só existe quando a dependência foi carregada.
        isAvailable = NSClassFromString("CHZAuthManager") != nil
    }
}

struct MissingAuthenticationDependencyView: View {
    var body: some View {
        ZStack {
            AppTheme.pageBackground.ignoresSafeArea()

            VStack(spacing: 18) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(AppTheme.accent)

                CHZPrivWordmark(size: 30)

                Text("DEPENDÊNCIA AUSENTE")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(AppTheme.primaryText)

                Text("O componente de autenticação CHZ Login não foi carregado. O app não pode continuar sem o framework assinado.")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Instale a versão oficial da IPA com o framework incorporado e assinado.")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.secondaryText.opacity(0.82))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(28)
            .frame(maxWidth: 390)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(AppTheme.outlineStrong, lineWidth: 1.2)
            }
            .padding(24)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Dependência de autenticação ausente")
    }
}
