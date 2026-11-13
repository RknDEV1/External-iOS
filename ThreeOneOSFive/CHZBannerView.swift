import SwiftUI
import ImageIO
import UIKit

enum CHZBannerCatalog {
    static let names = (1...7).map { "chz-banner-\($0)" }
}

struct CHZAnimatedBanner: View {
    @AppStorage("chz.banner.index") private var selectedIndex = 0

    var body: some View {
        Group {
            if let image = animatedImage(named: CHZBannerCatalog.names[safe: selectedIndex] ?? CHZBannerCatalog.names[0]) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(colors: [AppTheme.cardBackground, AppTheme.accent.opacity(0.28)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .overlay { Image(systemName: "sparkles.tv.fill").font(.system(size: 34, weight: .bold)).foregroundStyle(AppTheme.accentBright) }
            }
        }
        .frame(height: 118)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.contentCardCornerRadius, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: AppTheme.contentCardCornerRadius, style: .continuous).stroke(AppTheme.outlineStrong, lineWidth: 1) }
        .clipped()
        .accessibilityLabel("Banner animado")
    }

    private func animatedImage(named name: String) -> UIImage? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "gif"),
              let data = try? Data(contentsOf: url),
              let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let count = CGImageSourceGetCount(source)
        guard count > 0 else { return nil }
        var frames: [UIImage] = []
        var duration: Double = 0
        for index in 0..<count {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, index, nil) else { continue }
            frames.append(UIImage(cgImage: cgImage))
            let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any]
            let gif = properties?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
            let delay = (gif?[kCGImagePropertyGIFUnclampedDelayTime] as? Double) ?? (gif?[kCGImagePropertyGIFDelayTime] as? Double) ?? 0.08
            duration += max(delay, 0.04)
        }
        return frames.count > 1 ? UIImage.animatedImage(with: frames, duration: duration) : frames.first
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
