import AmplayerKit
import SwiftUI

/// 均衡器窗口：开启 / 预设 / 重置，平衡、环绕、前置放大和 10 个频段
struct EqualizerWindow: View {
    @Environment(AppModel.self) private var app
    @Environment(\.ttSkin) private var skin
    @Environment(\.ttScale) private var scale

    private var player: PlayerController { app.player }

    var body: some View {
        let doc = skin.document
        let w = doc.equalizer
        let bg = skin.image(w.image)
        let size = bg?.size ?? w.position?.size ?? CGSize(width: 330, height: 134)
        let eq = player.equalizer
        ZStack(alignment: .topLeading) {
            if let bg { TTImageView(image: bg) }
            TTButton(element: w["close"], label: String(localized: "关闭均衡器")) { app.showEqualizer = false }
            TTButton(element: w["enabled"], selected: eq.enabled, label: eq.enabled ? String(localized: "均衡器：开") : String(localized: "均衡器：关")) {
                var e = player.equalizer
                e.enabled.toggle()
                player.equalizer = e
                app.show(e.enabled ? String(localized: "均衡器已开启") : String(localized: "均衡器已关闭"))
            }
            if let e = w["profile"] { presets(e) }
            TTButton(element: w["reset"], label: String(localized: "重置")) {
                var e = player.equalizer
                e.preamp = 0
                e.bands = Array(repeating: 0, count: 10)
                player.equalizer = e
                player.balance = 0
                app.show(String(localized: "已重置"))
            }
            if let e = w["balance"] {
                TTSlider(element: e, value: Double(player.balance + 1) / 2, snapToCenter: true, label: String(localized: "平衡"),
                         valueText: balanceText) { v, _ in
                    player.balance = Float(v * 2 - 1)
                }
            }
            if let e = w["surround"] {
                TTSlider(element: e, value: surroundValue, label: String(localized: "环绕"), valueText: "\(Int(surroundValue * 100))%") { v, _ in
                    setSurround(v)
                }
            }
            if let e = w["preamp"] {
                TTSlider(element: e, value: Double(eq.preamp + 12) / 24, snapToCenter: true, label: String(localized: "前置放大"),
                         valueText: String(format: "%+.0f dB", eq.preamp)) { v, _ in
                    var s = player.equalizer
                    s.preamp = Float(v * 24 - 12)
                    player.equalizer = s
                }
            }
            ForEach(0..<10, id: \.self) { i in
                if let band = doc.equalizerBand(i), i < eq.bands.count {
                    TTSlider(element: band, value: Double(eq.bands[i] + 12) / 24, snapToCenter: true,
                             label: String(localized: "\(EqualizerSettings.bandLabels[i]) 赫兹"), valueText: String(format: "%+.0f dB", eq.bands[i])) { v, _ in
                        var s = player.equalizer
                        s.bands[i] = Float(v * 24 - 12)
                        if !s.enabled { s.enabled = true }
                        player.equalizer = s
                    }
                }
            }
        }
        .frame(width: size.width * scale, height: size.height * scale, alignment: .topLeading)
    }

    /// “预设”按钮直接打开音效（里面有经典均衡器预设）
    private func presets(_ e: TTElement) -> some View {
        Button { app.sheet = .effects } label: {
            if let image = skin.image(e.image) { TTImageView(image: image.frame(0, of: 4)) } else { Color.clear }
        }
        .buttonStyle(.plain)
        .frame(width: e.rect.width * scale, height: e.rect.height * scale, alignment: .topLeading)
        .hitSlop(5)
        .accessibilityLabel("均衡器预设")
        .offset(x: e.rect.x * scale, y: e.rect.y * scale)
    }

    private var balanceText: String {
        let b = player.balance
        if abs(b) < 0.01 { return String(localized: "居中") }
        return b < 0 ? String(localized: "偏左 \(Int(-b * 100))%") : String(localized: "偏右 \(Int(b * 100))%")
    }

    /// 环绕：用音效里的环绕旋转 + 小房间混响模拟，0…1
    private var surroundValue: Double { Double(min(1, player.effects.surround / 0.6)) }

    private func setSurround(_ v: Double) {
        var e = player.effects
        e.surround = Float(v) * 0.6
        e.surroundSpeed = 0.06
        e.reverbType = .room
        e.reverbMix = Float(v) * 18
        e.presetID = e.isNeutral ? "off" : SoundEffectPreset.custom
        player.effects = e
    }
}
