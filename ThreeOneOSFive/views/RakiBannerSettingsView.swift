import SwiftUI
import AVFoundation
import UIKit

struct RakiBannerSettingsView: View {
    @AppStorage("raki.banner.index") private var selectedIndex = 0
    @AppStorage("raki.banner.enabled") private var isEnabled = true
    @Environment(\.scenePhase) private var scenePhase

    private let banners = (1...7).map { "raki-banner-\($0)" }

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                if let name = banners[safe: selectedIndex], let url = Bundle.main.url(forResource: name, withExtension: "mp4") {
                    RakiLoopingVideoView(url: url, isPlaying: isEnabled && scenePhase == .active)
                        .frame(maxWidth: .infinity)
                        .frame(height: 168)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(alignment: .bottomLeading) {
                            Text("Raki · Fundo \(selectedIndex + 1)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(.black.opacity(0.58), in: Capsule())
                                .padding(10)
                        }
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("Fundo indisponível")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                        .frame(maxWidth: .infinity)
                        .frame(height: 168)
                }

                Toggle("Fundo animado: \(isEnabled ? "ligado" : "desligado")", isOn: $isEnabled)
                    .tint(AppTheme.accent)

                Text("Escolha o fundo exibido no Raki. Os vídeos são locais e ficam em reprodução contínua.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(Array(banners.enumerated()), id: \.offset) { index, name in
                        Button {
                            selectedIndex = index
                            isEnabled = true
                        } label: {
                            RakiBannerChoice(
                                name: name,
                                index: index,
                                isSelected: index == selectedIndex,
                                isPlaying: isEnabled && scenePhase == .active
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Selecionar fundo \(index + 1)")
                    }
                }
            }
            .padding(.vertical, 4)
        } header: {
            Label("Fundos animados", systemImage: "play.rectangle.fill")
        } footer: {
            Text("A animação reinicia automaticamente ao voltar ao app ou retornar para esta tela.")
        }
    }
}

private struct RakiBannerChoice: View {
    let name: String
    let index: Int
    let isSelected: Bool
    let isPlaying: Bool

    var body: some View {
        VStack(spacing: 6) {
            if let url = Bundle.main.url(forResource: name, withExtension: "mp4") {
                RakiLoopingVideoView(url: url, isPlaying: isPlaying)
                    .frame(height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.secondary.opacity(0.12))
                    .frame(height: 64)
            }
            HStack(spacing: 4) {
                Text("Fundo \(index + 1)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.primary)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.accent)
                }
            }
        }
        .padding(5)
        .background(
            isSelected ? AppTheme.accent.opacity(0.14) : Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isSelected ? AppTheme.accent : Color.clear, lineWidth: 1.5)
        }
    }
}

private struct RakiLoopingVideoView: UIViewRepresentable {
    let url: URL
    let isPlaying: Bool

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.configure(url: url)
        view.setPlaying(isPlaying)
        return view
    }

    func updateUIView(_ view: PlayerView, context: Context) {
        view.configure(url: url)
        view.setPlaying(isPlaying)
    }

    static func dismantleUIView(_ view: PlayerView, coordinator: ()) {
        view.stop()
    }
}

private final class PlayerView: UIView {
    private var player: AVPlayer?
    private var endObserver: NSObjectProtocol?
    private var appActiveObserver: NSObjectProtocol?
    private var currentURL: URL?

    override class var layerClass: AnyClass { AVPlayerLayer.self }

    private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    func configure(url: URL) {
        guard currentURL != url else { return }
        stop()
        currentURL = url
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        player.isMuted = true
        player.actionAtItemEnd = .none
        self.player = player
        playerLayer.player = player
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.restartAndPlay()
        }
        appActiveObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.restartAndPlay()
        }
    }

    func setPlaying(_ shouldPlay: Bool) {
        guard let player else { return }
        if shouldPlay {
            player.isMuted = true
            if player.timeControlStatus != .playing {
                player.play()
            }
        } else {
            player.pause()
        }
    }

    func restartAndPlay() {
        guard let player else { return }
        player.seek(to: .zero) { [weak self] _ in
            self?.player?.play()
        }
    }

    func stop() {
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        if let appActiveObserver { NotificationCenter.default.removeObserver(appActiveObserver) }
        endObserver = nil
        appActiveObserver = nil
        player?.pause()
        playerLayer.player = nil
        player = nil
        currentURL = nil
    }

    deinit { stop() }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
