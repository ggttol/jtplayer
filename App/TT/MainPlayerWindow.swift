import AmplayerKit
import SwiftUI

/// 主控窗口：背景图 + Skin.xml 里定义的各个元素
struct MainPlayerWindow: View {
    @Environment(AppModel.self) private var app
    @Environment(\.ttSkin) private var skin
    @Environment(\.ttScale) private var scale

    private var player: PlayerController { app.player }

    var body: some View {
        let w = skin.document.player
        let bg = skin.image(w.image)
        let size = bg?.size ?? CGSize(width: 330, height: 136)
        let lcd = skin.theme?.lcdText ?? skin.document.visualStyle.middle
        let playing = player.audio.state == .playing
        ZStack(alignment: .topLeading) {
            if let bg { TTImageView(image: bg) }

            // 左上角图标：打开总控菜单
            menuButton(w["icon"]?.rect ?? TTRect(x: 0, y: 0, width: 24, height: 20))

            if let e = w["visual"] {
                TTVisualizer(element: e).place(e.rect, scale)
            }
            if let e = w["info"] {
                TTTextView(element: e, text: infoText, scroll: true, active: playing, fallbackColor: lcd)
            }
            if let e = w["stereo"] {
                TTTextView(element: e, text: formatText, fallbackColor: lcd)
            }
            if let e = w["status"] {
                TTTextView(element: e, text: statusText, fallbackColor: lcd)
            }
            if let e = w["led"] {
                TimeLED(element: e, fallbackColor: lcd)
            }

            windowButtons(w)
            transport(w)
            modeButton(w)

            if let e = w["progress"] { ProgressSlider(element: e) }
            if let e = w["volume"] {
                TTSlider(element: e, value: Double(player.volume), label: "音量", valueText: "\(Int(player.volume * 100))%") { v, _ in
                    player.volume = Float(v)
                    app.mutedVolume = nil
                }
            }
        }
        .frame(width: size.width * scale, height: size.height * scale, alignment: .topLeading)
    }

    private func menuButton(_ rect: TTRect) -> some View {
        Color.clear
            .contentShape(Rectangle())
            .hitSlop(6)
            .onTapGesture { Haptics.tap(); app.showSideMenu = true }
            .accessibilityLabel("菜单")
            .accessibilityAddTraits(.isButton)
            .place(rect, scale)
    }

    @ViewBuilder
    private func windowButtons(_ w: TTWindow) -> some View {
        TTButton(element: w["minimize"], label: app.isMiniMode ? "恢复窗口" : "迷你模式") { app.toggleMiniMode() }
        TTButton(element: w["minimode"], selected: app.isMiniMode, label: app.isMiniMode ? "恢复窗口" : "迷你模式") { app.toggleMiniMode() }
        TTButton(element: w["exit"], label: "停止播放") { player.stop() }
        TTButton(element: w["lyric"], selected: app.showLyrics, label: "歌词秀") { app.showLyrics.toggle() }
        TTButton(element: w["equalizer"], selected: app.showEqualizer, label: "均衡器") { app.showEqualizer.toggle() }
        TTButton(element: w["playlist"], selected: app.showPlaylist, label: "播放列表") { app.showPlaylist.toggle() }
        TTButton(element: w["browser"], label: "音乐窗（曲库）") { app.sheet = .library }
        TTButton(element: w["set"], label: "设置") { app.sheet = .settings }
        TTButton(element: w["open"], label: "打开文件") { app.isImportingFiles = true }
        TTButton(element: w["mute"], selected: app.mutedVolume != nil, label: app.mutedVolume != nil ? "取消静音" : "静音") { app.toggleMute() }
    }

    @ViewBuilder
    private func transport(_ w: TTWindow) -> some View {
        TTButton(element: w["prev"], label: "上一首") { player.previous() }
        TTButton(element: w["next"], label: "下一首") { player.next() }
        TTButton(element: w["stop"], label: "停止") { player.stop() }
        // 播放和暂停通常放在同一个位置：播放时显示暂停
        let playing = player.audio.state == .playing
        if let pause = w["pause"], playing {
            TTButton(element: pause, label: "暂停") { player.pause() }
        } else if let play = w["play"] {
            TTButton(element: play, label: playing ? "暂停" : "播放") {
                if playing { player.pause() } else { player.play() }
            }
        }
    }

    /// 播放模式：五个 mode_* 元素只显示当前模式那一个，点按切换到下一个
    @ViewBuilder
    private func modeButton(_ w: TTWindow) -> some View {
        let mode = player.playMode
        if let e = w[mode.elementName] {
            TTButton(element: e, label: "播放模式：\(mode.title)") {
                player.playMode = mode.next
                app.show(player.playMode.title)
            }
        }
    }

    private var infoText: String {
        if let error = player.lastError { return error }
        guard let track = player.current else { return "JTplayer · 点左上角图标打开菜单添加音乐" }
        let prefix = player.isLoading ? "[缓冲中\(player.loadingProgress.map { " " + $0 } ?? "")] " : ""
        return prefix + track.displayName
    }

    private var formatText: String {
        guard let info = player.audio.info, player.current != nil else { return "" }
        let channels = info.channels >= 2 ? "立体声" : "单声道"
        return "\(info.bitrate)kbps \(Int((info.sampleRate / 1000).rounded()))kHz \(channels)"
    }

    private var statusText: String {
        if player.isLoading { return "缓冲" }
        return switch player.audio.state {
        case .playing: "播放"
        case .paused: "暂停"
        default: "停止"
        }
    }
}

/// LED 时间：点按切换已播放 / 剩余；暂停时闪烁
private struct TimeLED: View {
    @Environment(AppModel.self) private var app
    let element: TTElement
    let fallbackColor: TTColor

    var body: some View {
        let audio = app.player.audio
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let duration = audio.info?.duration ?? 0
            let remaining = app.showRemainingTime && duration > 0
            let t = Int(remaining ? max(0, duration - audio.currentTime) : audio.currentTime)
            let text = (remaining ? "-" : "") + String(format: "%02d:%02d", min(99, t / 60), t % 60)
            let blinkOff = audio.state == .paused && Int(context.date.timeIntervalSinceReferenceDate * 2) % 2 == 0
            TTLEDView(element: element, text: audio.state == .stopped ? "00:00" : text, fallbackColor: fallbackColor,
                      opacity: blinkOff ? 0.25 : 1) { app.showRemainingTime.toggle() }
        }
        .accessibilityElement()
        .accessibilityIdentifier("time")
        .accessibilityLabel("播放时间")
        .accessibilityValue(accessibilityState)
    }

    private var accessibilityState: String {
        let player = app.player
        let state = player.isLoading ? "缓冲中" : (player.audio.state == .playing ? "播放中" : (player.audio.state == .paused ? "已暂停" : "已停止"))
        return "\(state) \(TimeFormat.clock(player.audio.currentTime)) \(player.current?.title ?? "")"
    }
}

/// 进度条：拖动时只移动滑块，松手后跳转
private struct ProgressSlider: View {
    @Environment(AppModel.self) private var app
    let element: TTElement

    var body: some View {
        let audio = app.player.audio
        TimelineView(.periodic(from: .now, by: audio.state == .playing ? 0.5 : 60)) { _ in
            let duration = audio.info?.duration ?? 0
            let value = duration > 0 ? audio.currentTime / duration : 0
            TTSlider(element: element, value: value, showThumb: audio.info != nil, label: "进度",
                     valueText: "\(TimeFormat.clock(audio.currentTime)) / \(TimeFormat.clock(duration))") { v, ended in
                if ended, duration > 0 { app.player.seek(to: v * duration) }
            }
        }
    }
}

/// 频谱 / 示波器，颜色来自 Visual.xml
struct TTVisualizer: View {
    @Environment(AppModel.self) private var app
    @Environment(\.ttSkin) private var skin
    @Environment(\.ttScale) private var scale
    let element: TTElement

    @State private var peaks: [Double] = []

    var body: some View {
        let mode = app.visualizerMode
        let style = skin.document.visualStyle
        let playing = app.player.audio.state == .playing
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: mode == .off || !playing)) { timeline in
            Canvas { ctx, size in
                guard mode != .off, playing else { return }
                let snapshot = app.player.audio.analyzer.snapshot()
                let s = scale
                if mode == .spectrum {
                    let barW = style.barWidth
                    let count = max(1, Int(size.width / s / (barW + 1)))
                    let gradient = Gradient(stops: [
                        .init(color: style.bottom.color, location: 0),
                        .init(color: style.middle.color, location: 0.55),
                        .init(color: style.top.color, location: 1),
                    ])
                    let shading = GraphicsContext.Shading.linearGradient(gradient, startPoint: CGPoint(x: 0, y: size.height), endPoint: .zero)
                    var bars = Path()
                    for i in 0..<count {
                        let lo = i * 75 / count, hi = max(lo + 1, (i + 1) * 75 / count)
                        let level = Double(snapshot.spectrum[lo..<min(75, hi)].max() ?? 0)
                        let h = (level * Double(size.height)).rounded()
                        bars.addRect(CGRect(x: CGFloat(i) * (barW + 1) * s, y: size.height - h, width: barW * s, height: h))
                        if i < peaks.count, peaks[i] > 0.02 {
                            let y = size.height - peaks[i] * size.height
                            ctx.fill(Path(CGRect(x: CGFloat(i) * (barW + 1) * s, y: y - s, width: barW * s, height: s)), with: .color(style.peak.color))
                        }
                    }
                    ctx.fill(bars, with: shading)
                } else {
                    var path = Path()
                    let n = snapshot.waveform.count
                    for (i, v) in snapshot.waveform.enumerated() {
                        let p = CGPoint(x: size.width * CGFloat(i) / CGFloat(max(1, n - 1)), y: size.height / 2 - CGFloat(v) * size.height / 2)
                        if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
                    }
                    ctx.stroke(path, with: .color(style.middle.color), lineWidth: max(1, s))
                }
                _ = timeline.date
            }
            .onChange(of: timeline.date) { updatePeaks(width: element.rect.width, barWidth: style.barWidth) }
        }
        .contentShape(Rectangle())
        .onTapGesture { cycle() }
        .accessibilityLabel("可视化，点按切换")
    }

    private func updatePeaks(width: CGFloat, barWidth: CGFloat) {
        guard app.visualizerMode == .spectrum else { return }
        let count = max(1, Int(width / (barWidth + 1)))
        if peaks.count != count { peaks = Array(repeating: 0, count: count) }
        let spectrum = app.player.audio.analyzer.snapshot().spectrum
        for i in 0..<count {
            let lo = i * 75 / count, hi = max(lo + 1, (i + 1) * 75 / count)
            let level = Double(spectrum[lo..<min(75, hi)].max() ?? 0)
            peaks[i] = level >= peaks[i] ? level : max(0, peaks[i] - 0.015)
        }
    }

    private func cycle() {
        app.visualizerMode = switch app.visualizerMode {
        case .spectrum: .oscilloscope
        case .oscilloscope: .off
        case .off: .spectrum
        }
    }
}
