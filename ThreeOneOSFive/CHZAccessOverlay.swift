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

    private let red = Color(red: 0.92, green: 0.08, blue: 0.10)

    var body: some View {
        ZStack {
            Color.black.opacity(0.76)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: isExpired ? "lock.slash.fill" : "lock.fill")
                    .font(.system(size: 29, weight: .semibold))
                    .foregroundStyle(red)
                    .frame(width: 54, height: 54)
                    .background(Color.black)
                    .overlay(Circle().stroke(red.opacity(0.85), lineWidth: 1.2))

                Text("CHZ PRIV")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .tracking(2.4)
                    .foregroundStyle(.white)

                if isExpired {
                    Text("TEMPO ESGOTADO")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(red)
                    Text("O acesso foi bloqueado. Abra o app novamente para tentar outra vez.")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.68))
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("INSIRA SUA KEY PARA CONTINUAR")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .tracking(0.8)
                        .foregroundStyle(.white.opacity(0.64))

                    SecureField("KEY", text: $key)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 13)
                        .frame(height: 44)
                        .background(Color.black.opacity(0.72))
                        .overlay(
                            RoundedRectangle(cornerRadius: 9)
                                .stroke(red.opacity(0.82), lineWidth: 1)
                        )

                    HStack(spacing: 8) {
                        Image(systemName: "timer")
                        Text("\(remainingSeconds)s")
                    }
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(remainingSeconds <= 5 ? red : .white.opacity(0.7))

                    Button(action: submit) {
                        HStack(spacing: 8) {
                            if isSubmitting {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.78)
                            }
                            Text(isSubmitting ? "VALIDANDO" : "CONTINUAR")
                        }
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .tracking(1.1)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(red.opacity(key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.28 : 0.9))
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                    }
                    .disabled(isSubmitting || key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(red)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 22)
            .padding(.bottom, 20)
            .frame(width: min(340, UIScreen.main.bounds.width - 40))
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(red: 0.025, green: 0.015, blue: 0.018))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(red, lineWidth: 1.35)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 13)
                    .stroke(red.opacity(0.22), lineWidth: 1)
                    .padding(4)
            )
            .shadow(color: red.opacity(0.2), radius: 18, x: 0, y: 8)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Acesso CHZ PRIV")
        }
        .onAppear(perform: startTimer)
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
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
