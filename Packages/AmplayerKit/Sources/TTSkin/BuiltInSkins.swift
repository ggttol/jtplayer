import CoreGraphics
import CoreText
import Foundation

/// 内置皮肤的调色板。布局写成标准的 Skin.xml（和导入的 .skn 走同一套解析和渲染），图片用代码按 3 倍绘制。
public struct TTTheme: Sendable, Equatable, Identifiable {
    public var id: String
    public var name: String
    public var frameTop: TTColor, frameBottom: TTColor, frameBorder: TTColor, frameHighlight: TTColor, titleText: TTColor
    public var panelTop: TTColor, panelBottom: TTColor, panelBorder: TTColor, lcdText: TTColor, lcdDim: TTColor
    public var accent: TTColor, accent2: TTColor
    public var buttonTop: TTColor, buttonBottom: TTColor, buttonBorder: TTColor, glyph: TTColor, glyphActive: TTColor

    init(id: String, name: String, frame: (String, String, String), highlight: Double, title: String,
         panel: (String, String, String), lcd: (String, String), accent: (String, String),
         button: (String, String, String), glyph: (String, String)) {
        func c(_ s: String) -> TTColor { TTColor(hex: s)! }
        self.id = id
        self.name = name
        frameTop = c(frame.0); frameBottom = c(frame.1); frameBorder = c(frame.2)
        frameHighlight = TTColor.white.opacity(highlight)
        titleText = c(title)
        panelTop = c(panel.0); panelBottom = c(panel.1); panelBorder = c(panel.2)
        lcdText = c(lcd.0); lcdDim = c(lcd.1)
        self.accent = c(accent.0); accent2 = c(accent.1)
        buttonTop = c(button.0); buttonBottom = c(button.1); buttonBorder = c(button.2)
        self.glyph = c(glyph.0); glyphActive = c(glyph.1)
    }

    public static let all: [TTTheme] = [
        TTTheme(id: "jt-blue", name: "静听蓝", frame: ("#E8EEF6", "#A9BBD3", "#5A6F8E"), highlight: 0.75, title: "#1D3557",
                panel: ("#0A1A33", "#12305A", "#061024"), lcd: ("#9FE3FF", "#4F7FAE"), accent: ("#3FA9FF", "#9FE3FF"),
                button: ("#FDFEFF", "#BCCBE0", "#6B7F9E"), glyph: ("#2A4466", "#1478E0")),
        TTTheme(id: "jt-black", name: "炫酷黑", frame: ("#3A3D44", "#15171B", "#000000"), highlight: 0.14, title: "#E6E6E6",
                panel: ("#050607", "#101318", "#000000"), lcd: ("#FFB547", "#8A6A3A"), accent: ("#FF8A1F", "#FFD08A"),
                button: ("#4A4E57", "#22252B", "#0A0B0D"), glyph: ("#D9D9D9", "#FF9A3C")),
        TTTheme(id: "jt-pink", name: "樱花粉", frame: ("#FFF0F5", "#F2B8CC", "#B9708A"), highlight: 0.8, title: "#7A2E4A",
                panel: ("#3A1424", "#5A1F38", "#220A14"), lcd: ("#FFD1E3", "#B66A8A"), accent: ("#FF6FA5", "#FFD1E3"),
                button: ("#FFFFFF", "#F5C9D8", "#C4859D"), glyph: ("#8A3456", "#E8437F")),
        TTTheme(id: "jt-green", name: "翡翠绿", frame: ("#EEF7EE", "#AFCFB4", "#557A5C"), highlight: 0.8, title: "#1F4D2A",
                panel: ("#08200F", "#12381C", "#03110A"), lcd: ("#A8FFB8", "#4E9A61"), accent: ("#39D46A", "#A8FFB8"),
                button: ("#FFFFFF", "#C3DCC6", "#6E9475"), glyph: ("#285C35", "#1FA34A")),
        TTTheme(id: "jt-silver", name: "金属银", frame: ("#F4F4F4", "#B8BCC2", "#6E737A"), highlight: 0.85, title: "#2B2F36",
                panel: ("#1B1E22", "#2C3137", "#0D0F11"), lcd: ("#E8F1FF", "#7D8794"), accent: ("#8FB8FF", "#E8F1FF"),
                button: ("#FFFFFF", "#C9CDD3", "#80858C"), glyph: ("#3B4048", "#2F6FD6")),
    ]

    var lyricStyle: TTLyricStyle {
        TTLyricStyle(text: lcdDim.mixed(with: panelTop, 0.15), highlight: accent2.mixed(with: .white, 0.35), background: panelTop.mixed(with: .black, 0.35), fontSize: 15)
    }

    var playlistStyle: TTPlaylistStyle {
        TTPlaylistStyle(text: lcdText.mixed(with: .white, 0.2).mixed(with: panelTop, 0.15), current: accent2.mixed(with: .white, 0.2),
                        background: panelTop.mixed(with: .black, 0.2), background2: panelTop.mixed(with: .black, 0.05),
                        number: lcdDim, duration: lcdDim, selection: accent.opacity(0.35), selectionText: .white, fontSize: 12)
    }

    var visualStyle: TTVisualStyle {
        TTVisualStyle(top: .white, middle: accent2, bottom: accent, peak: .white, barWidth: 2)
    }
}

public extension TTSkin {
    static let builtInScale: CGFloat = 3

    /// 内置皮肤
    static func builtIn(_ theme: TTTheme) -> TTSkin {
        var doc = try! TTSkinParser.parseSkin(Data(BuiltInLayout.skinXML(name: theme.name).utf8))
        doc.author = "JTplayer"
        doc.lyricStyle = theme.lyricStyle
        doc.playlistStyle = theme.playlistStyle
        doc.visualStyle = theme.visualStyle
        let painter = BuiltInPainter(theme: theme, scale: builtInScale)
        var images: [String: TTImage] = [:]
        for name in BuiltInLayout.imageNames {
            if let img = painter.image(name) { images[name] = TTImage(cgImage: img, scale: builtInScale) }
        }
        return TTSkin(id: theme.id, document: doc, images: images, theme: theme)
    }

    static func builtIn(id: String) -> TTSkin? {
        TTTheme.all.first { $0.id == id }.map(builtIn)
    }
}

/// 内置皮肤的布局（Skin.xml 格式，坐标含右下边界）
enum BuiltInLayout {
    static let mainSize = CGSize(width: 330, height: 136)
    static let lyricSize = CGSize(width: 330, height: 150)
    static let eqSize = CGSize(width: 330, height: 134)
    static let playlistSize = CGSize(width: 330, height: 220)

    static let imageNames = [
        "player.png", "lyric.png", "equalizer.png", "playlist.png",
        "minimize.png", "minimode.png", "exit.png", "close.png",
        "prev.png", "play.png", "pause.png", "stop.png", "next.png", "open.png", "mute.png", "browser.png",
        "lrc.png", "eq.png", "pl.png", "led.png",
        "mode_single.png", "mode_circle.png", "mode_slider.png", "mode_loop.png", "mode_random.png",
        "progress_bar.png", "progress_fill.png", "progress_thumb.png",
        "volume_bar.png", "volume_fill.png", "volume_thumb.png",
        "eq_enabled.png", "eq_profile.png", "eq_reset.png",
        "balance_bar.png", "balance_fill.png", "surround_bar.png", "surround_fill.png", "h_thumb.png",
        "band_bar.png", "band_fill.png", "band_thumb.png",
    ]

    static func skinXML(name: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <skin version="2" name="\(name)" author="JTplayer" transparent_color="#ff00ff">
        <player_window image="player.png">
            <icon      position="  6,  4, 19, 17"/>
            <minimize  position="270,  4,285, 17" image="minimize.png"/>
            <minimode  position="290,  4,305, 17" image="minimode.png"/>
            <exit      position="310,  4,325, 17" image="exit.png"/>
            <visual    position=" 12, 26, 95, 75"/>
            <info      position="102, 25,318, 40" align="left" font_size="14"/>
            <stereo    position="102, 44,215, 56" align="left" font_size="11"/>
            <status    position="102, 60,158, 72" align="left" font_size="11"/>
            <mode_single position="162, 60,187, 71" image="mode_single.png"/>
            <mode_circle position="162, 60,187, 71" image="mode_circle.png"/>
            <mode_slider position="162, 60,187, 71" image="mode_slider.png"/>
            <mode_loop   position="162, 60,187, 71" image="mode_loop.png"/>
            <mode_random position="162, 60,187, 71" image="mode_random.png"/>
            <led       position="222, 41,318, 60" align="right" image="led.png"/>
            <lyric     position="248, 65,269, 75" image="lrc.png"/>
            <equalizer position="272, 65,293, 75" image="eq.png"/>
            <playlist  position="296, 65,317, 75" image="pl.png"/>
            <progress  position="  8, 84,321, 93" bar_image="progress_bar.png" fill_image="progress_fill.png" thumb_image="progress_thumb.png"/>
            <prev      position=" 12,100, 39,127" image="prev.png"/>
            <play      position=" 46,100, 73,127" image="play.png"/>
            <pause     position=" 46,100, 73,127" image="pause.png"/>
            <stop      position=" 80,100,107,127" image="stop.png"/>
            <next      position="114,100,141,127" image="next.png"/>
            <open      position="148,100,175,127" image="open.png"/>
            <mute      position="192,106,207,121" image="mute.png"/>
            <volume    position="212,109,287,118" bar_image="volume_bar.png" fill_image="volume_fill.png" thumb_image="volume_thumb.png"/>
            <browser   position="296,103,321,124" image="browser.png"/>
        </player_window>
        <lyric_window image="lyric.png" resize_rect="100,24,300,130">
            <close     position="312,  4,325, 15" image="close.png"/>
            <lyric     position="  6, 22,323,143"/>
        </lyric_window>
        <equalizer_window image="equalizer.png" eq_interval="13">
            <close     position="312,  4,325, 15" image="close.png"/>
            <enabled   position=" 10, 22, 47, 35" image="eq_enabled.png"/>
            <profile   position=" 52, 22, 89, 35" image="eq_profile.png"/>
            <reset     position=" 94, 22,131, 35" image="eq_reset.png"/>
            <balance   position="176, 25,245, 32" bar_image="balance_bar.png" fill_image="balance_fill.png" thumb_image="h_thumb.png"/>
            <surround  position="282, 25,321, 32" bar_image="surround_bar.png" fill_image="surround_fill.png" thumb_image="h_thumb.png"/>
            <preamp    position=" 14, 46, 27,117" vertical="true" bar_image="band_bar.png" fill_image="band_fill.png" thumb_image="band_thumb.png"/>
            <eqfactor  position=" 62, 46, 75,117" vertical="true" bar_image="band_bar.png" fill_image="band_fill.png" thumb_image="band_thumb.png"/>
        </equalizer_window>
        <playlist_window image="playlist.png" resize_rect="100,40,300,200">
            <close     position="312,  4,325, 15" image="close.png"/>
            <toolbar   position="  6, 20,323, 35"/>
            <playlist  position="  6, 38,323,213"/>
        </playlist_window>
        </skin>
        """
    }
}

/// 用 CoreGraphics 画内置皮肤的各张图（坐标为皮肤像素、左上原点）
struct BuiltInPainter {
    let theme: TTTheme
    let scale: CGFloat

    typealias Ctx = CGContext

    func canvas(_ w: CGFloat, _ h: CGFloat, _ draw: (Ctx) -> Void) -> CGImage? {
        let pw = Int((w * scale).rounded()), ph = Int((h * scale).rounded())
        guard let ctx = CGContext(data: nil, width: pw, height: ph, bitsPerComponent: 8, bytesPerRow: pw * 4,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.translateBy(x: 0, y: CGFloat(ph))
        ctx.scaleBy(x: scale, y: -scale)
        draw(ctx)
        return ctx.makeImage()
    }

    /// 横向四帧：普通、悬停、按下/选中、禁用
    func frames(_ w: CGFloat, _ h: CGFloat, _ draw: (Ctx, CGRect, Int) -> Void) -> CGImage? {
        canvas(w * 4, h) { ctx in
            for i in 0..<4 {
                ctx.saveGState()
                if i == 3 { ctx.setAlpha(0.4) }
                draw(ctx, CGRect(x: CGFloat(i) * w, y: 0, width: w, height: h), i)
                ctx.restoreGState()
            }
        }
    }

    func image(_ name: String) -> CGImage? {
        let t = theme
        switch name {
        case "player.png": return mainBackground()
        case "lyric.png": return windowBackground(BuiltInLayout.lyricSize, title: "歌词秀", panel: CGRect(x: 6, y: 22, width: 318, height: 122), fill: t.lyricStyle.background)
        case "playlist.png":
            return windowBackground(BuiltInLayout.playlistSize, title: "播放列表", panel: CGRect(x: 6, y: 38, width: 318, height: 176), fill: t.playlistStyle.background) { ctx in
                roundRect(ctx, CGRect(x: 6, y: 20, width: 318, height: 16), 3, fill: t.frameBottom.mixed(with: .black, 0.08), stroke: t.frameBorder.opacity(0.5))
            }
        case "equalizer.png": return equalizerBackground()
        case "minimize.png": return titleButton { ctx, r in line(ctx, CGPoint(x: r.minX + 4.5, y: r.midY + 2), CGPoint(x: r.maxX - 4.5, y: r.midY + 2), 1.6) }
        case "minimode.png": return titleButton { ctx, r in ctx.stroke(r.insetBy(dx: 4.5, dy: 4), width: 1.3) }
        case "exit.png", "close.png":
            let size = name == "exit.png" ? CGSize(width: 16, height: 14) : CGSize(width: 14, height: 12)
            return titleButton(size) { ctx, r in
                let d: CGFloat = name == "exit.png" ? 4.5 : 4
                line(ctx, CGPoint(x: r.minX + d, y: r.minY + d - 0.5), CGPoint(x: r.maxX - d, y: r.maxY - d + 0.5), 1.5)
                line(ctx, CGPoint(x: r.maxX - d, y: r.minY + d - 0.5), CGPoint(x: r.minX + d, y: r.maxY - d + 0.5), 1.5)
            }
        case "prev.png": return roundButton { ctx, r, c in
            ctx.setFillColor(c.cgColor)
            ctx.fill(CGRect(x: r.midX - 6, y: r.midY - 5, width: 2, height: 10))
            triangle(ctx, CGPoint(x: r.midX - 4, y: r.midY), pointingLeft: true, size: 10)
            triangle(ctx, CGPoint(x: r.midX + 2, y: r.midY), pointingLeft: true, size: 10)
        }
        case "next.png": return roundButton { ctx, r, c in
            ctx.setFillColor(c.cgColor)
            triangle(ctx, CGPoint(x: r.midX - 7, y: r.midY), pointingLeft: false, size: 10)
            triangle(ctx, CGPoint(x: r.midX - 1, y: r.midY), pointingLeft: false, size: 10)
            ctx.fill(CGRect(x: r.midX + 4, y: r.midY - 5, width: 2, height: 10))
        }
        case "play.png": return roundButton(accentGlyph: true) { ctx, r, c in
            ctx.setFillColor(c.cgColor)
            triangle(ctx, CGPoint(x: r.midX - 3.5, y: r.midY), pointingLeft: false, size: 12)
        }
        case "pause.png": return roundButton(accentGlyph: true) { ctx, r, c in
            ctx.setFillColor(c.cgColor)
            ctx.fill(CGRect(x: r.midX - 4.5, y: r.midY - 5.5, width: 3, height: 11))
            ctx.fill(CGRect(x: r.midX + 1.5, y: r.midY - 5.5, width: 3, height: 11))
        }
        case "stop.png": return roundButton { ctx, r, c in
            ctx.setFillColor(c.cgColor)
            ctx.addPath(CGPath(roundedRect: CGRect(x: r.midX - 4.5, y: r.midY - 4.5, width: 9, height: 9), cornerWidth: 1.5, cornerHeight: 1.5, transform: nil))
            ctx.fillPath()
        }
        case "open.png": return roundButton { ctx, r, c in
            ctx.setFillColor(c.cgColor)
            let p = CGMutablePath()
            p.move(to: CGPoint(x: r.midX, y: r.midY - 6))
            p.addLine(to: CGPoint(x: r.midX + 6, y: r.midY + 1))
            p.addLine(to: CGPoint(x: r.midX - 6, y: r.midY + 1))
            p.closeSubpath()
            ctx.addPath(p); ctx.fillPath()
            ctx.fill(CGRect(x: r.midX - 6, y: r.midY + 3, width: 12, height: 2.5))
        }
        case "mute.png": return smallRoundButton(CGSize(width: 16, height: 16)) { ctx, r, c in
            ctx.setFillColor(c.cgColor)
            let p = CGMutablePath()
            p.move(to: CGPoint(x: r.minX + 3.5, y: r.midY - 2))
            p.addLine(to: CGPoint(x: r.minX + 6, y: r.midY - 2))
            p.addLine(to: CGPoint(x: r.minX + 9, y: r.midY - 5))
            p.addLine(to: CGPoint(x: r.minX + 9, y: r.midY + 5))
            p.addLine(to: CGPoint(x: r.minX + 6, y: r.midY + 2))
            p.addLine(to: CGPoint(x: r.minX + 3.5, y: r.midY + 2))
            p.closeSubpath()
            ctx.addPath(p); ctx.fillPath()
            ctx.setStrokeColor(c.cgColor); ctx.setLineWidth(1.1)
            ctx.addArc(center: CGPoint(x: r.minX + 9, y: r.midY), radius: 3.5, startAngle: -.pi / 3.5, endAngle: .pi / 3.5, clockwise: false)
            ctx.strokePath()
        }
        case "browser.png": return smallRoundButton(CGSize(width: 26, height: 22)) { ctx, r, c in
            // 音乐窗：一个小“光盘”
            ctx.setStrokeColor(c.cgColor); ctx.setLineWidth(1.3)
            ctx.strokeEllipse(in: CGRect(x: r.midX - 6, y: r.midY - 6, width: 12, height: 12))
            ctx.setFillColor(c.cgColor)
            ctx.fillEllipse(in: CGRect(x: r.midX - 1.6, y: r.midY - 1.6, width: 3.2, height: 3.2))
        }
        case "lrc.png": return pill("LRC", CGSize(width: 22, height: 11))
        case "eq.png": return pill("EQ", CGSize(width: 22, height: 11))
        case "pl.png": return pill("PL", CGSize(width: 22, height: 11))
        case "mode_single.png": return pill("单曲", CGSize(width: 26, height: 12), chinese: true)
        case "mode_circle.png": return pill("循环", CGSize(width: 26, height: 12), chinese: true)
        case "mode_slider.png": return pill("顺序", CGSize(width: 26, height: 12), chinese: true)
        case "mode_loop.png": return pill("单循", CGSize(width: 26, height: 12), chinese: true)
        case "mode_random.png": return pill("随机", CGSize(width: 26, height: 12), chinese: true)
        case "led.png": return led()
        case "progress_bar.png": return groove(CGSize(width: 314, height: 10), thickness: 4, filled: false)
        case "progress_fill.png": return groove(CGSize(width: 314, height: 10), thickness: 4, filled: true)
        case "progress_thumb.png": return knob(CGSize(width: 12, height: 12))
        case "volume_bar.png": return groove(CGSize(width: 76, height: 10), thickness: 4, filled: false)
        case "volume_fill.png": return groove(CGSize(width: 76, height: 10), thickness: 4, filled: true)
        case "volume_thumb.png": return knob(CGSize(width: 10, height: 10))
        case "eq_enabled.png": return textButton("开启", CGSize(width: 38, height: 14))
        case "eq_profile.png": return textButton("预设", CGSize(width: 38, height: 14))
        case "eq_reset.png": return textButton("重置", CGSize(width: 38, height: 14))
        case "balance_bar.png": return groove(CGSize(width: 70, height: 8), thickness: 3, filled: false, centerTick: true)
        case "balance_fill.png": return groove(CGSize(width: 70, height: 8), thickness: 3, filled: true)
        case "surround_bar.png": return groove(CGSize(width: 40, height: 8), thickness: 3, filled: false)
        case "surround_fill.png": return groove(CGSize(width: 40, height: 8), thickness: 3, filled: true)
        case "h_thumb.png": return knob(CGSize(width: 8, height: 10), square: true)
        case "band_bar.png": return vgroove(CGSize(width: 14, height: 72), filled: false)
        case "band_fill.png": return vgroove(CGSize(width: 14, height: 72), filled: true)
        case "band_thumb.png": return knob(CGSize(width: 14, height: 8), square: true)
        default: return nil
        }
    }

    // MARK: 窗口背景

    private func frame(_ ctx: Ctx, _ size: CGSize) {
        let t = theme
        let r = CGRect(origin: .zero, size: size).insetBy(dx: 0.5, dy: 0.5)
        let path = CGPath(roundedRect: r, cornerWidth: 6, cornerHeight: 6, transform: nil)
        ctx.saveGState()
        ctx.addPath(path); ctx.clip()
        gradient(ctx, r, t.frameTop, t.frameBottom)
        ctx.restoreGState()
        // 顶部高光
        ctx.saveGState()
        ctx.addPath(CGPath(roundedRect: r.insetBy(dx: 1, dy: 1), cornerWidth: 5, cornerHeight: 5, transform: nil))
        ctx.setStrokeColor(t.frameHighlight.cgColor); ctx.setLineWidth(1)
        ctx.strokePath()
        ctx.restoreGState()
        ctx.addPath(path)
        ctx.setStrokeColor(t.frameBorder.cgColor); ctx.setLineWidth(1)
        ctx.strokePath()
    }

    private func panel(_ ctx: Ctx, _ rect: CGRect, radius: CGFloat = 4, fill: TTColor? = nil) {
        let t = theme
        let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
        ctx.saveGState()
        ctx.addPath(path); ctx.clip()
        if let fill { ctx.setFillColor(fill.cgColor); ctx.fill(rect) } else { gradient(ctx, rect, t.panelTop, t.panelBottom) }
        // 玻璃反光
        if fill == nil {
            ctx.setFillColor(TTColor.white.opacity(0.05).cgColor)
            ctx.fill(CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height * 0.45))
        }
        ctx.restoreGState()
        ctx.addPath(path)
        ctx.setStrokeColor(t.panelBorder.cgColor); ctx.setLineWidth(1)
        ctx.strokePath()
        ctx.addPath(CGPath(roundedRect: rect.insetBy(dx: -1, dy: -1), cornerWidth: radius + 1, cornerHeight: radius + 1, transform: nil))
        ctx.setStrokeColor(t.frameHighlight.opacity(t.frameHighlight.a * 0.6).cgColor)
        ctx.strokePath()
    }

    private func title(_ ctx: Ctx, _ text: String, x: CGFloat, y: CGFloat, size: CGFloat = 9) {
        drawText(ctx, text, at: CGPoint(x: x, y: y), size: size, color: theme.titleText, bold: true)
    }

    private func appIcon(_ ctx: Ctx, _ r: CGRect) {
        // 圆形图标里一个八分音符
        let t = theme
        ctx.saveGState()
        ctx.addEllipse(in: r); ctx.clip()
        gradient(ctx, r, t.accent2, t.accent)
        ctx.restoreGState()
        ctx.setStrokeColor(t.frameBorder.cgColor); ctx.setLineWidth(0.8)
        ctx.strokeEllipse(in: r)
        ctx.setFillColor(TTColor.white.cgColor)
        ctx.fillEllipse(in: CGRect(x: r.minX + 3.5, y: r.maxY - 6.5, width: 4, height: 3.2))
        ctx.fill(CGRect(x: r.minX + 6.6, y: r.minY + 3.2, width: 1.1, height: 7.5))
        ctx.fill(CGRect(x: r.minX + 6.6, y: r.minY + 3.2, width: 3.5, height: 1.4))
    }

    private func mainBackground() -> CGImage? {
        let s = BuiltInLayout.mainSize
        return canvas(s.width, s.height) { ctx in
            frame(ctx, s)
            appIcon(ctx, CGRect(x: 6, y: 4, width: 14, height: 14))
            title(ctx, "JTplayer", x: 24, y: 5, size: 9.5)
            panel(ctx, CGRect(x: 8, y: 22, width: 315, height: 58))
            // 可视化和信息区之间的分隔
            ctx.setStrokeColor(theme.lcdDim.opacity(0.35).cgColor); ctx.setLineWidth(0.6)
            ctx.move(to: CGPoint(x: 98.5, y: 27)); ctx.addLine(to: CGPoint(x: 98.5, y: 75)); ctx.strokePath()
            // 底部一条浅槽托住播放按钮
            roundRect(ctx, CGRect(x: 8, y: 97, width: 171, height: 34), 17, fill: theme.frameBottom.mixed(with: .black, 0.06), stroke: theme.frameBorder.opacity(0.35))
        }
    }

    private func windowBackground(_ s: CGSize, title text: String, panel rect: CGRect, fill: TTColor, extra: ((Ctx) -> Void)? = nil) -> CGImage? {
        canvas(s.width, s.height) { ctx in
            frame(ctx, s)
            appIcon(ctx, CGRect(x: 6, y: 3, width: 13, height: 13))
            title(ctx, text, x: 23, y: 3.5)
            extra?(ctx)
            panel(ctx, rect, radius: 3, fill: fill)
        }
    }

    private func equalizerBackground() -> CGImage? {
        let s = BuiltInLayout.eqSize
        let t = theme
        return canvas(s.width, s.height) { ctx in
            frame(ctx, s)
            appIcon(ctx, CGRect(x: 6, y: 3, width: 13, height: 13))
            title(ctx, "均衡器", x: 23, y: 3.5)
            drawText(ctx, "平衡", at: CGPoint(x: 150, y: 23), size: 8, color: t.titleText)
            drawText(ctx, "环绕", at: CGPoint(x: 256, y: 23), size: 8, color: t.titleText)
            panel(ctx, CGRect(x: 8, y: 40, width: 315, height: 90))
            let freqs = ["31", "62", "125", "250", "500", "1K", "2K", "4K", "8K", "16K"]
            for (i, f) in freqs.enumerated() {
                let x = 62 + CGFloat(i) * 26 + 7
                drawText(ctx, f, at: CGPoint(x: x, y: 119), size: 6.5, color: t.lcdDim, align: .center)
            }
            drawText(ctx, "前置", at: CGPoint(x: 21, y: 119), size: 6.5, color: t.lcdDim, align: .center)
            for (label, y) in [("+12", 46.0), ("0", 78.0), ("-12", 110.0)] {
                drawText(ctx, label, at: CGPoint(x: 56, y: y), size: 6, color: t.lcdDim, align: .right)
            }
            // 0 dB 参考线
            ctx.setStrokeColor(t.lcdDim.opacity(0.35).cgColor); ctx.setLineWidth(0.5)
            ctx.setLineDash(phase: 0, lengths: [1.5, 1.5])
            ctx.move(to: CGPoint(x: 58, y: 81.5)); ctx.addLine(to: CGPoint(x: 314, y: 81.5)); ctx.strokePath()
            ctx.setLineDash(phase: 0, lengths: [])
            ctx.move(to: CGPoint(x: 37.5, y: 46)); ctx.addLine(to: CGPoint(x: 37.5, y: 117)); ctx.strokePath()
        }
    }

    // MARK: 控件

    private func roundButton(accentGlyph: Bool = false, _ glyph: @escaping (Ctx, CGRect, TTColor) -> Void) -> CGImage? {
        let t = theme
        return frames(28, 28) { ctx, cell, state in
            let r = cell.insetBy(dx: 1, dy: 1)
            ctx.saveGState()
            ctx.addEllipse(in: r); ctx.clip()
            switch state {
            case 1: gradient(ctx, r, t.buttonTop.mixed(with: .white, 0.4), t.buttonBottom.mixed(with: .white, 0.25))
            case 2: gradient(ctx, r, t.buttonBottom.mixed(with: .black, 0.12), t.buttonTop.mixed(with: .black, 0.04))
            default: gradient(ctx, r, t.buttonTop, t.buttonBottom)
            }
            // 上半部分高光
            if state != 2 {
                ctx.setFillColor(TTColor.white.opacity(0.22).cgColor)
                ctx.fillEllipse(in: CGRect(x: r.minX + 3, y: r.minY + 1.5, width: r.width - 6, height: r.height * 0.45))
            }
            ctx.restoreGState()
            ctx.setStrokeColor(t.buttonBorder.cgColor); ctx.setLineWidth(1)
            ctx.strokeEllipse(in: r)
            let color = state == 2 || accentGlyph ? t.glyphActive : t.glyph
            glyph(ctx, cell.offsetBy(dx: 0, dy: state == 2 ? 0.5 : 0), color)
        }
    }

    private func smallRoundButton(_ size: CGSize, _ glyph: @escaping (Ctx, CGRect, TTColor) -> Void) -> CGImage? {
        let t = theme
        return frames(size.width, size.height) { ctx, cell, state in
            let r = cell.insetBy(dx: 0.75, dy: 0.75)
            let path = CGPath(roundedRect: r, cornerWidth: min(r.height / 2, 5), cornerHeight: min(r.height / 2, 5), transform: nil)
            ctx.saveGState()
            ctx.addPath(path); ctx.clip()
            switch state {
            case 1: gradient(ctx, r, t.buttonTop.mixed(with: .white, 0.4), t.buttonBottom.mixed(with: .white, 0.25))
            case 2: gradient(ctx, r, t.buttonBottom.mixed(with: .black, 0.12), t.buttonTop)
            default: gradient(ctx, r, t.buttonTop, t.buttonBottom)
            }
            ctx.restoreGState()
            ctx.addPath(path)
            ctx.setStrokeColor(t.buttonBorder.cgColor); ctx.setLineWidth(0.8)
            ctx.strokePath()
            glyph(ctx, cell, state == 2 ? t.glyphActive : t.glyph)
        }
    }

    private func titleButton(_ size: CGSize = CGSize(width: 16, height: 14), _ glyph: @escaping (Ctx, CGRect) -> Void) -> CGImage? {
        smallRoundButton(size) { ctx, r, c in
            ctx.setStrokeColor(c.cgColor)
            glyph(ctx, r)
        }
    }

    /// 显示屏里的小开关（LRC / EQ / PL / 播放模式），选中时点亮
    private func pill(_ text: String, _ size: CGSize, chinese: Bool = false) -> CGImage? {
        let t = theme
        return frames(size.width, size.height) { ctx, cell, state in
            let r = cell.insetBy(dx: 0.5, dy: 0.5)
            let lit = state == 2
            roundRect(ctx, r, 2.5, fill: lit ? t.accent.opacity(0.3) : (state == 1 ? t.lcdDim.opacity(0.15) : nil),
                      stroke: lit ? t.accent : t.lcdDim.opacity(0.7))
            drawText(ctx, text, at: CGPoint(x: r.midX, y: r.minY + (chinese ? 1.6 : 1.2)), size: chinese ? 7.5 : 7,
                     color: lit ? t.lcdText : t.lcdDim, bold: !chinese, align: .center)
        }
    }

    private func textButton(_ text: String, _ size: CGSize) -> CGImage? {
        let t = theme
        return frames(size.width, size.height) { ctx, cell, state in
            let r = cell.insetBy(dx: 0.5, dy: 0.5)
            let path = CGPath(roundedRect: r, cornerWidth: 3, cornerHeight: 3, transform: nil)
            ctx.saveGState()
            ctx.addPath(path); ctx.clip()
            switch state {
            case 1: gradient(ctx, r, t.buttonTop.mixed(with: .white, 0.4), t.buttonBottom.mixed(with: .white, 0.25))
            case 2: gradient(ctx, r, t.accent.mixed(with: .white, 0.25), t.accent.mixed(with: .black, 0.1))
            default: gradient(ctx, r, t.buttonTop, t.buttonBottom)
            }
            ctx.restoreGState()
            ctx.addPath(path)
            ctx.setStrokeColor((state == 2 ? t.accent.mixed(with: .black, 0.3) : t.buttonBorder).cgColor); ctx.setLineWidth(0.8)
            ctx.strokePath()
            drawText(ctx, text, at: CGPoint(x: r.midX, y: r.minY + 2), size: 8, color: state == 2 ? .white : t.glyph, align: .center)
        }
    }

    /// LED 数字：0-9、冒号、减号，共 12 格
    private func led() -> CGImage? {
        let t = theme
        let w: CGFloat = 11, h: CGFloat = 20
        let glyphs = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", ":", "-"]
        return canvas(w * 12, h) { ctx in
            for (i, g) in glyphs.enumerated() {
                ctx.saveGState()
                ctx.setShadow(offset: .zero, blur: 2.5, color: t.accent.opacity(0.8).cgColor)
                drawText(ctx, g, at: CGPoint(x: CGFloat(i) * w + w / 2, y: g == ":" ? 0.5 : 0.5), size: 18, color: t.lcdText, bold: false, align: .center, monospacedDigits: true)
                ctx.restoreGState()
            }
        }
    }

    private func groove(_ size: CGSize, thickness: CGFloat, filled: Bool, centerTick: Bool = false) -> CGImage? {
        let t = theme
        return canvas(size.width, size.height) { ctx in
            let r = CGRect(x: 0.5, y: (size.height - thickness) / 2, width: size.width - 1, height: thickness)
            let path = CGPath(roundedRect: r, cornerWidth: thickness / 2, cornerHeight: thickness / 2, transform: nil)
            if filled {
                ctx.saveGState()
                ctx.addPath(path); ctx.clip()
                gradient(ctx, r, t.accent2, t.accent)
                ctx.restoreGState()
            } else {
                ctx.addPath(path)
                ctx.setFillColor(t.panelTop.mixed(with: .black, 0.2).cgColor)
                ctx.fillPath()
                ctx.addPath(path)
                ctx.setStrokeColor(t.frameBorder.opacity(0.7).cgColor); ctx.setLineWidth(0.6)
                ctx.strokePath()
                if centerTick {
                    ctx.setFillColor(t.frameBorder.cgColor)
                    ctx.fill(CGRect(x: size.width / 2 - 0.4, y: 0, width: 0.8, height: size.height))
                }
            }
        }
    }

    private func vgroove(_ size: CGSize, filled: Bool) -> CGImage? {
        let t = theme
        return canvas(size.width, size.height) { ctx in
            let r = CGRect(x: (size.width - 4) / 2, y: 0.5, width: 4, height: size.height - 1)
            let path = CGPath(roundedRect: r, cornerWidth: 2, cornerHeight: 2, transform: nil)
            if filled {
                ctx.saveGState()
                ctx.addPath(path); ctx.clip()
                gradient(ctx, r, t.accent2, t.accent)
                ctx.restoreGState()
            } else {
                ctx.addPath(path)
                ctx.setFillColor(TTColor.black.opacity(0.55).cgColor)
                ctx.fillPath()
                ctx.addPath(path)
                ctx.setStrokeColor(t.lcdDim.opacity(0.5).cgColor); ctx.setLineWidth(0.5)
                ctx.strokePath()
            }
        }
    }

    private func knob(_ size: CGSize, square: Bool = false) -> CGImage? {
        let t = theme
        return frames(size.width, size.height) { ctx, cell, state in
            let r = cell.insetBy(dx: 0.6, dy: 0.6)
            let path = square ? CGPath(roundedRect: r, cornerWidth: 2, cornerHeight: 2, transform: nil) : CGPath(ellipseIn: r, transform: nil)
            ctx.saveGState()
            ctx.addPath(path); ctx.clip()
            if state == 2 { gradient(ctx, r, t.accent2, t.accent) } else { gradient(ctx, r, t.buttonTop.mixed(with: .white, state == 1 ? 0.4 : 0), t.buttonBottom) }
            ctx.restoreGState()
            ctx.addPath(path)
            ctx.setStrokeColor(t.buttonBorder.cgColor); ctx.setLineWidth(0.7)
            ctx.strokePath()
            if square {
                ctx.setFillColor(t.glyph.opacity(0.6).cgColor)
                if r.width > r.height { ctx.fill(CGRect(x: r.minX + 3, y: r.midY - 0.35, width: r.width - 6, height: 0.7)) }
                else { ctx.fill(CGRect(x: r.midX - 0.35, y: r.minY + 2.5, width: 0.7, height: r.height - 5)) }
            }
        }
    }

    // MARK: 绘图工具

    private func gradient(_ ctx: Ctx, _ r: CGRect, _ top: TTColor, _ bottom: TTColor) {
        guard let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [top.cgColor, bottom.cgColor] as CFArray, locations: [0, 1]) else { return }
        ctx.drawLinearGradient(g, start: CGPoint(x: r.midX, y: r.minY), end: CGPoint(x: r.midX, y: r.maxY), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    }

    private func roundRect(_ ctx: Ctx, _ r: CGRect, _ radius: CGFloat, fill: TTColor?, stroke: TTColor?) {
        let path = CGPath(roundedRect: r, cornerWidth: radius, cornerHeight: radius, transform: nil)
        if let fill { ctx.addPath(path); ctx.setFillColor(fill.cgColor); ctx.fillPath() }
        if let stroke { ctx.addPath(path); ctx.setStrokeColor(stroke.cgColor); ctx.setLineWidth(0.8); ctx.strokePath() }
    }

    private func line(_ ctx: Ctx, _ a: CGPoint, _ b: CGPoint, _ width: CGFloat) {
        ctx.setLineWidth(width); ctx.setLineCap(.round)
        ctx.move(to: a); ctx.addLine(to: b); ctx.strokePath()
    }

    private func triangle(_ ctx: Ctx, _ origin: CGPoint, pointingLeft: Bool, size: CGFloat) {
        let w = size * 0.85, h = size
        let p = CGMutablePath()
        if pointingLeft {
            p.move(to: CGPoint(x: origin.x, y: origin.y))
            p.addLine(to: CGPoint(x: origin.x + w, y: origin.y - h / 2))
            p.addLine(to: CGPoint(x: origin.x + w, y: origin.y + h / 2))
        } else {
            p.move(to: CGPoint(x: origin.x, y: origin.y - h / 2))
            p.addLine(to: CGPoint(x: origin.x + w, y: origin.y))
            p.addLine(to: CGPoint(x: origin.x, y: origin.y + h / 2))
        }
        p.closeSubpath()
        ctx.addPath(p); ctx.fillPath()
    }

    enum TextAlign { case left, center, right }

    /// 在左上原点、y 向下的坐标系里画一行字（point 为文字框左上角 / 顶部中点 / 右上角）
    private func drawText(_ ctx: Ctx, _ text: String, at point: CGPoint, size: CGFloat, color: TTColor, bold: Bool = false, align: TextAlign = .left, monospacedDigits: Bool = false) {
        var font = CTFontCreateUIFontForLanguage(bold ? .emphasizedSystem : .system, size, "zh-Hans" as CFString)
            ?? CTFontCreateWithName("PingFangSC-Regular" as CFString, size, nil)
        if monospacedDigits {
            let desc = CTFontDescriptorCreateCopyWithFeature(CTFontCopyFontDescriptor(font), kNumberSpacingType as CFNumber, kMonospacedNumbersSelector as CFNumber)
            font = CTFontCreateWithFontDescriptor(desc, size, nil)
        }
        let attrs: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color.cgColor,
        ]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attrs))
        let width = CTLineGetTypographicBounds(line, nil, nil, nil)
        let ascent = CTFontGetAscent(font)
        let x: CGFloat = switch align {
        case .left: point.x
        case .center: point.x - CGFloat(width) / 2
        case .right: point.x - CGFloat(width)
        }
        ctx.saveGState()
        ctx.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
        ctx.textPosition = CGPoint(x: x, y: point.y + ascent)
        CTLineDraw(line, ctx)
        ctx.restoreGState()
    }
}
