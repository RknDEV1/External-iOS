import SwiftUI
import UIKit

struct CHZAccessOverlay: View {
    @Binding var isAuthorized: Bool
    @Binding var isExpired: Bool

    let onAuthorized: () -> Void
    let onExpired: () -> Void

    @State private var key = ""
    @State private var remainingSeconds = 30
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var timer: Timer?

    private let red = Color(red: 0.94, green: 0.10, blue: 0.12)
    private let panel = Color(red: 0.045, green: 0.035, blue: 0.042)

    var body: some View {
        ZStack {
            Color.black.opacity(0.68)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                lockMark
                    .padding(.top, 24)
                    .padding(.bottom, 14)

                Text("CHZ PRIV")
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .tracking(2.2)
                    .foregroundStyle(.white)

                if isExpired {
                    expiredContent
                } else {
                    accessContent
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 22)
            .frame(width: min(346, UIScreen.main.bounds.width - 36))
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(panel.opacity(0.78))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [red.opacity(0.92), red.opacity(0.28), red.opacity(0.76)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.1
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(.white.opacity(0.07), lineWidth: 1)
                    .padding(4)
            )
            .shadow(color: red.opacity(0.18), radius: 28, x: 0, y: 14)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Acesso CHZ PRIV")
        }
        .onAppear(perform: startTimer)
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }

    private var lockMark: some View {
        ZStack {
            Circle()
                .fill(.thinMaterial)
                .overlay(Circle().fill(Color.black.opacity(0.24)))
                .overlay(Circle().stroke(red.opacity(0.72), lineWidth: 1))
                .frame(width: 58, height: 58)

            Image(systemName: isExpired ? "lock.slash" : "lock")
                .font(.system(size: 25, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(red)
        }
        .accessibilityHidden(true)
    }

    private var accessContent: some View {
        VStack(spacing: 13) {
            Text("INSIRA SUA KEY")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.58))
                .padding(.top, 7)

            HStack(spacing: 10) {
                Image(systemName: "key.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(red.opacity(0.9))

                SecureField("Key de acesso", text: $key)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 14)
            .frame(height: 48)
            .background(Color.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(.white.opacity(0.12), lineWidth: 1)
            )

            HStack(spacing: 6) {
                Image(systemName: "timer")
                Text("\(remainingSeconds)s")
            }
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(remainingSeconds <= 5 ? red : .white.opacity(0.55))

            Button(action: submit) {
                HStack(spacing: 8) {
                    if isSubmitting {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.78)
                    }
                    Text(isSubmitting ? "VALIDANDO" : "CONTINUAR")
                }
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    LinearGradient(
                        colors: [red.opacity(key.isEmpty ? 0.30 : 0.92), red.opacity(key.isEmpty ? 0.18 : 0.68)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                )
            }
            .buttonStyle(.plain)
            .disabled(isSubmitting || key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(red)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, 8)
    }

    private var expiredContent: some View {
        VStack(spacing: 10) {
            Text("TEMPO ESGOTADO")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(1)
                .foregroundStyle(red)
                .padding(.top, 15)

            Text("O acesso foi bloqueado. Abra o app novamente para tentar outra vez.")
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.62))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 4)
    }

    private func startTimer() {
        guard !isAuthorized, !isExpired, timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            guard !isAuthorized, !isExpired else { return }
            if remainingSeconds > 0 {
                remainingSeconds -= 1
            } else {
                timer?.invalidate()
                timer = nil
                isSubmitting = false
                isExpired = true
                onExpired()
            }
        }
    }

    private func submit() {
        guard !isSubmitting, !isExpired else { return }
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { return }

        isSubmitting = true
        errorMessage = nil

        let manager = CHZAuthManager.shared()
        manager.login(withKey: trimmedKey, success: {
            DispatchQueue.main.async {
                timer?.invalidate()
                timer = nil
                isSubmitting = false
                isAuthorized = true
                onAuthorized()
            }
        }, failure: { message in
            DispatchQueue.main.async {
                isSubmitting = false
                errorMessage = message.isEmpty ? "Key inválida ou indisponível." : message
            }
        })
    }
}
