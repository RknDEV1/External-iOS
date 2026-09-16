import SwiftUI
import UIKit

struct CHZAccessOverlay: View {
    @Binding var isPresented: Bool
    @State private var key = ""
    @State private var secondsRemaining = 30
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color.black.opacity(0.62).ignoresSafeArea()
            VStack(spacing: 16) {
                ZStack {
                    Circle().fill(Color.white.opacity(0.07)).frame(width: 54, height: 54)
                        .overlay(Circle().stroke(Color.red.opacity(0.72), lineWidth: 1))
                    Image(systemName: secondsRemaining == 0 ? "lock.slash" : "lock.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Color.red.opacity(0.95))
                }
                Text("CHZ PRIV").font(.system(size: 18, weight: .bold, design: .rounded)).tracking(1.3).foregroundStyle(.white)
                Text("Acesso protegido").font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.62))
                SecureField("Insira sua key", text: $key)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled(true)
                    .padding(.horizontal, 13).frame(height: 44)
                    .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(Color.red.opacity(0.56), lineWidth: 1))
                    .foregroundStyle(.white)
                HStack {
                    Text("Tempo restante").font(.system(size: 11, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.55))
                    Spacer()
                    Text("00:\(String(format: "%02d", secondsRemaining))").font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundStyle(secondsRemaining <= 5 ? .red : .white.opacity(0.82))
                }
                Button(action: submit) {
                    Group { if isSubmitting { ProgressView().tint(.white) } else { Text("Continuar") } }
                        .font(.system(size: 14, weight: .bold, design: .rounded)).frame(maxWidth: .infinity).frame(height: 42)
                }
                .buttonStyle(.plain).foregroundStyle(.white)
                .background(Color.red.opacity(0.82), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .disabled(isSubmitting || key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || secondsRemaining == 0)
                if let errorMessage {
                    Text(errorMessage).font(.system(size: 11, weight: .medium, design: .rounded)).foregroundStyle(.red.opacity(0.95)).multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 22).padding(.top, 22).padding(.bottom, 18)
            .frame(width: min(UIScreen.main.bounds.width - 42, 330))
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .background(Color.black.opacity(0.80), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.red.opacity(0.74), lineWidth: 1.2))
            .shadow(color: .red.opacity(0.20), radius: 22, y: 10)
        }
        .onReceive(timer) { _ in tick() }
    }

    private func tick() {
        guard isPresented, secondsRemaining > 0 else { return }
        secondsRemaining -= 1
        if secondsRemaining == 0 {
            errorMessage = "Tempo expirado. Valide sua key para continuar."
        }
    }

    private func submit() {
        guard secondsRemaining > 0, !isSubmitting else { return }
        isSubmitting = true
        errorMessage = nil
        let normalizedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        CHZAuthManager.shared().login(withKey: normalizedKey, success: {
            DispatchQueue.main.async {
                isSubmitting = false
                isPresented = false
                NotificationCenter.default.post(name: Notification.Name("CHZLoginDidAuthenticateNotification"), object: nil)
            }
        }, failure: { message in
            DispatchQueue.main.async {
                isSubmitting = false
                errorMessage = message
            }
        })
    }
}
