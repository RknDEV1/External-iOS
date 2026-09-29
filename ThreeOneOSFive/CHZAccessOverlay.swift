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

    var body: some View {
        ZStack {
            Color.black.opacity(0.62).ignoresSafeArea()

            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.07))
                        .frame(width: 54, height: 54)
                        .overlay(Circle().stroke(AppTheme.primaryText.opacity(0.72), lineWidth: 1))

                    Image(systemName: secondsRemaining == 0 ? "lock.slash" : "lock.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText.opacity(0.95))
                }

                Text("Raki")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .tracking(1.3)
                    .foregroundStyle(.white)

                Text(isRestoringSession ? "Validando sessão neste dispositivo" : "Acesso protegido")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.62))

                SecureField("Insira sua key", text: $key)
                    .focused($isKeyFieldFocused)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled(true)
                    .submitLabel(.go)
                    .onSubmit(submit)
                    .padding(.horizontal, 13)
                    .frame(height: 44)
                    .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(AppTheme.primaryText.opacity(0.56), lineWidth: 1))
                    .foregroundStyle(.white)
                    .disabled(isSubmitting || isRestoringSession || secondsRemaining == 0)

                HStack {
                    Text("Tempo restante")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                    Spacer()
                    Text("00:\(String(format: "%02d", secondsRemaining))")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(secondsRemaining <= 5 ? 1.0 : 0.82))
                }

                Button(action: submit) {
                    ZStack {
                        Text("Continuar").opacity(isSubmitting || isRestoringSession ? 0 : 1)
                        if isSubmitting || isRestoringSession {
                            ProgressView().tint(.white)
                        }
                    }
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(AppTheme.primaryText.opacity(0.82), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .disabled(isSubmitting || isRestoringSession || normalizedKey.isEmpty || secondsRemaining == 0)

                Text(errorMessage ?? " ")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.95))
                    .multilineTextAlignment(.center)
                    .frame(minHeight: 28, alignment: .top)
                    .opacity(errorMessage == nil ? 0 : 1)
            }
            .padding(.horizontal, 22)
            .padding(.top, 22)
            .padding(.bottom, 18)
            .frame(width: min(UIScreen.main.bounds.width - 42, 330))
            .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .background(Color.black.opacity(0.80), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(AppTheme.primaryText.opacity(0.74), lineWidth: 1.2))
            .shadow(color: .clear, radius: 0)
        }
        .onReceive(timer) { _ in tick() }
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
