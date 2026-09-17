from pathlib import Path
import re
import sys

root = Path(sys.argv[1]).resolve()
project = root / 'ThreeOneOSFive.xcodeproj/project.pbxproj'
text = project.read_text(encoding='utf-8')
text = '\n'.join(line for line in text.splitlines() if 'ChzLogin' not in line) + '\n'
project.write_text(text, encoding='utf-8')

header = root / 'ThreeOneOSFive/ThreeOneOSFive-Bridging-Header.h'
header.write_text('''#import "exploit/bad_query.h"
#import "exploit/mcm_bridge.h"
#import "kexploit/kexploit_opa334.h"
#import "kexploit/sandbox_escape.h"
#import "kexploit/kutils.h"
#import "helpers/AppIconHelper.h"
#import "helpers/DisplayIdentity.h"
''', encoding='utf-8')

app = root / 'ThreeOneOSFive/App.swift'
source = app.read_text(encoding='utf-8')
pattern = r'    private func refreshAuthenticationState\(\) \{.*?\n    \}\n\n    private func didAuthenticate\(\)'
replacement = '''    private func refreshAuthenticationState() {
        // Test-only build: no external authentication framework is embedded.
        didAuthenticate()
    }

    private func didAuthenticate()'''
source, count = re.subn(pattern, replacement, source, count=1, flags=re.S)
if count != 1:
    raise SystemExit('authentication entry point not found')
app.write_text(source, encoding='utf-8')

overlay = root / 'ThreeOneOSFive/CHZAccessOverlay.swift'
overlay.write_text('''import SwiftUI
import UIKit

struct CHZAccessOverlay: View {
    @Binding var isPresented: Bool
    let isRestoringSession: Bool
    let onAuthenticated: () -> Void
    @State private var key = ""
    @State private var secondsRemaining = 30
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color.black.opacity(0.62).ignoresSafeArea()
            VStack(spacing: 14) {
                Image(systemName: "lock.fill").font(.system(size: 24, weight: .semibold)).foregroundStyle(.red)
                Text("TESTE SEM FRAMEWORK").font(.system(size: 16, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Text("Modo local de validação").font(.caption).foregroundStyle(.white.opacity(0.65))
                SecureField("Insira uma key de teste", text: $key)
                    .textInputAutocapitalization(.characters).autocorrectionDisabled(true)
                    .padding(12).background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
                Button("Continuar") {
                    guard !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                    onAuthenticated()
                }
                .frame(maxWidth: .infinity).frame(height: 42).foregroundStyle(.white)
                .background(Color.red.opacity(0.82), in: RoundedRectangle(cornerRadius: 12))
                Text("Tempo restante: 00:\(String(format: "%02d", secondsRemaining))")
                    .font(.caption.monospaced()).foregroundStyle(.white.opacity(0.65))
            }
            .padding(22).frame(width: min(UIScreen.main.bounds.width - 42, 330))
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.red.opacity(0.7), lineWidth: 1.2))
        }
        .onReceive(timer) { _ in if secondsRemaining > 0 { secondsRemaining -= 1 } }
    }
}
''', encoding='utf-8')

for path in [project, header, app, overlay]:
    print(path)
