import SwiftUI
import UIKit

struct CHZAccessOverlay: View {
    @Binding var isPresented: Bool
    let isRestoringSession: Bool
    let onAuthenticated: () -> Void

    @State private var key = ""
    @State private var secondsRemaining = 30
    @State private var isSubmitting = false
    @State private var didCompleteAuthentication = false
    @State private var errorMessage: String?
    @FocusState private var isKeyFieldFocused: Bool

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private var isBusy: Bool { isSubmitting || isRestoringSession }
    private var isDisabled: Bool { isBusy || normalizedKey.isEmpty || secondsRemaining == 0 }
    private var timerProgress: Double {
        min(max(Double(secondsRemaining) / 30.0, 0), 1)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.78)
                .ignoresSafeArea()
                .onTapGesture { isKeyFieldFocused = false }

            GeometryReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    loginCard
                        .frame(maxWidth: 360)
                        .frame(minHeight: proxy.size.height - 32)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onReceive(timer) { _ in tick() }
    }

    private var loginCard: some View {
        VStack(spacing: 0) {
            header

            Rectangle()
                .fill(AppTheme.outline.opacity(0.34))
                .frame(height: 1)
                .padding(.top, 22)

            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(isRestoringSession ? "RESTAURANDO SESSÃO" : "AUTENTICAÇÃO LOCAL")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .tracking(1.1)
                        .foregroundStyle(AppTheme.accentBright)

                    Text(isRestoringSession
                         ? "Verificando uma sessão salva neste dispositivo."
                         : "Insira sua key para liberar o acesso ao painel.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(AppTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                keyField
                timerStatus

                if let errorMessage, !errorMessage.isEmpty {
                    errorBox(errorMessage)
                }

                submitButton
            }
            .padding(.top, 22)
            .padding(.horizontal, 22)
            .padding(.bottom, 22)

            footer
        }
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppTheme.cardBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    AppTheme.accentBright.opacity(0.82),
                                    AppTheme.outline.opacity(0.42),
                                    AppTheme.primaryText.opacity(0.20)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
                .shadow(color: AppTheme.accent.opacity(0.18), radius: 28, y: 14)
        }
    }

    private var header: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.16))
                    .frame(width: 76, height: 76)
                    .overlay {
                        Circle()
                            .stroke(AppTheme.accentBright.opacity(0.46), lineWidth: 1)
                    }

                Image("CHZPrivLogoFinal")
                    .resizable()
                    .scaledToFit()
                    .padding(12)
                    .frame(width: 68, height: 68)
                    .clipShape(Circle())
            }

            VStack(spacing: 5) {
                Text("CHZ PRIV")
                    .font(.system(size: 21, weight: .black, design: .monospaced))
                    .tracking(1.8)
                    .foregroundStyle(AppTheme.primaryText)

                HStack(spacing: 6) {
                    Circle()
                        .fill(isRestoringSession ? AppTheme.accentBright : AppTheme.success)
                        .frame(width: 6, height: 6)
                    Text(isRestoringSession ? "VALIDANDO DISPOSITIVO" : "ACESSO PROTEGIDO")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(0.7)
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }
        }
        .padding(.top, 24)
    }

    private var keyField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CHAVE DE ACESSO")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(AppTheme.secondaryText)

            HStack(spacing: 11) {
                Image(systemName: isKeyFieldFocused ? "key.fill" : "key")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isKeyFieldFocused ? AppTheme.accentBright : AppTheme.secondaryText)
                    .frame(width: 20)

                SecureField("Insira sua key", text: $key)
                    .focused($isKeyFieldFocused)
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled(true)
                    .submitLabel(.go)
                    .onSubmit(submit)
                    .foregroundStyle(AppTheme.primaryText)
                    .disabled(isDisabled)

                if !key.isEmpty && !isBusy {
                    Button {
                        key = ""
                        isKeyFieldFocused = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(AppTheme.tertiaryText)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Limpar key")
                }
            }
            .padding(.horizontal, 13)
            .frame(height: 52)
            .background(AppTheme.fieldBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        isKeyFieldFocused ? AppTheme.accentBright : AppTheme.outline,
                        lineWidth: isKeyFieldFocused ? 1.25 : 0.8
                    )
            }
            .shadow(color: isKeyFieldFocused ? AppTheme.accent.opacity(0.16) : .clear, radius: 12)
            .animation(.easeOut(duration: 0.16), value: isKeyFieldFocused)
        }
    }

    private var timerStatus: some View {
        VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("JANELA DE VALIDAÇÃO")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(0.65)
                    .foregroundStyle(AppTheme.secondaryText)

                Spacer()

                Text(secondsRemaining == 0 ? "EXPIRADA" : "00:\(String(format: "%02d", secondsRemaining))")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(secondsRemaining <= 5 ? AppTheme.accentBright : AppTheme.primaryText)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppTheme.primaryText.opacity(0.10))
                    Capsule()
                        .fill(secondsRemaining <= 5 ? AppTheme.accentBright : AppTheme.accent)
                        .frame(width: proxy.size.width * timerProgress)
                }
            }
            .frame(height: 4)
        }
    }

    private func errorBox(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.accentBright)

            Text(message)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(AppTheme.primaryText)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.accent.opacity(0.11), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppTheme.accent.opacity(0.38), lineWidth: 0.8)
        }
    }

    private var submitButton: some View {
        Button(action: submit) {
            HStack(spacing: 9) {
                if isBusy {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                } else {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                }

                Text(isRestoringSession ? "VALIDANDO…" : isSubmitting ? "CONECTANDO…" : "CONTINUAR")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .tracking(0.75)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isDisabled ? AppTheme.primaryText.opacity(0.18) : AppTheme.accent)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isDisabled ? AppTheme.primaryText.opacity(0.12) : AppTheme.accentBright.opacity(0.76), lineWidth: 0.8)
        }
        .shadow(color: isDisabled ? .clear : AppTheme.accent.opacity(0.24), radius: 12, y: 6)
        .disabled(isDisabled)
        .animation(.easeOut(duration: 0.16), value: isDisabled)
    }

    private var footer: some View {
        HStack(spacing: 7) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 11, weight: .semibold))
            Text("SESSÃO LOCAL • DADOS PROTEGIDOS")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(0.45)
        }
        .foregroundStyle(AppTheme.tertiaryText)
        .padding(.bottom, 16)
    }

    private var normalizedKey: String {
        key.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func tick() {
        guard isPresented, !isRestoringSession, !didCompleteAuthentication, secondsRemaining > 0 else { return }
        secondsRemaining -= 1
        if secondsRemaining == 0 {
            isKeyFieldFocused = false
            errorMessage = "Tempo expirado. Valide sua key para continuar."
        }
    }

    private func submit() {
        guard secondsRemaining > 0, !isSubmitting, !isRestoringSession, !didCompleteAuthentication, !normalizedKey.isEmpty else { return }
        isKeyFieldFocused = false
        isSubmitting = true
        errorMessage = nil
        let submittedKey = normalizedKey

        CHZAuthManager.shared().login(withKey: submittedKey, success: {
            DispatchQueue.main.async {
                guard !didCompleteAuthentication else { return }
                didCompleteAuthentication = true
                isSubmitting = false
                NotificationCenter.default.post(
                    name: Notification.Name("CHZLoginDidAuthenticateNotification"),
                    object: nil
                )
                withAnimation(.easeOut(duration: 0.18)) {
                    onAuthenticated()
                }
            }
        }, failure: { message in
            DispatchQueue.main.async {
                guard !didCompleteAuthentication else { return }
                isSubmitting = false
                errorMessage = message
            }
        })
    }
}
