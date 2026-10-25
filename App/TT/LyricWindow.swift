import AmplayerKit
import SwiftUI
import UniformTypeIdentifiers

/// 歌词秀窗口：同步歌词逐行滚动，当前行按时间从左到右变色（卡拉 OK 效果）
struct LyricWindow: View {
    @Environment(AppModel.self) private var app
    @Environment(\.ttSkin) private var skin
    @Environment(\.ttScale) private var scale
    /// 窗口尺寸（皮肤像素）
    let size: CGSize

    @State private var importing = false
    @State private var searching = false
    private var player: PlayerController { app.player }

    var body: some View {
        let w = skin.document.lyric
        let base = w.baseSize(imageSize: skin.image(w.image)?.size)
        let style = skin.document.lyricStyle
        let content = w["lyric"].map { w.layout($0.rect, base: base, size: size) } ?? TTRect(x: 6, y: 22, width: size.width - 12, height: size.height - 28)
        ZStack(alignment: .topLeading) {
            TTWindowBackground(window: w, size: size)
            ZStack {
                style.background.color
                lyrics(style)
            }
            .clipped()
            .contextMenu { menu }
            .place(content, scale)
            if let close = w["close"] {
                var e = close
                let _ = e.rect = w.layout(close.rect, base: base, size: size)
                TTButton(element: e, label: "关闭歌词秀") { app.showLyrics = false }
            }
        }
        .frame(width: size.width * scale, height: size.height * scale, alignment: .topLeading)
        .sheet(isPresented: $searching) { LyricsSearchView() }
        .fileImporter(isPresented: $importing, allowedContentTypes: [UTType(filenameExtension: "lrc") ?? .plainText, .plainText]) { result in
            guard case let .success(url) = result else { return }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            if let data = try? Data(contentsOf: url), let text = Lyrics.decode(data), player.setLyrics(text) {
                app.show("已导入歌词")
            } else {
                app.show("不是有效的歌词文件")
            }
        }
    }

    @ViewBuilder
    private func lyrics(_ style: TTLyricStyle) -> some View {
        let fontSize = max(11, style.fontSize) * scale * 0.95
        if let lyrics = player.lyrics, !lyrics.lines.isEmpty {
            if lyrics.isSynced {
                TimelineView(.periodic(from: .now, by: player.audio.state == .playing ? 0.25 : 60)) { _ in
                    LyricLines(lyrics: lyrics, current: lyrics.index(at: player.audio.currentTime), style: style, fontSize: fontSize) { player.seek(to: $0) }
                }
            } else {
                LyricLines(lyrics: lyrics, current: nil, style: style, fontSize: fontSize) { _ in }
            }
        } else {
            VStack(spacing: 6) {
                if player.current == nil || player.audio.state == .stopped {
                    Text(player.current?.displayName ?? "JTplayer")
                        .font(.system(size: fontSize * 1.1, weight: .semibold))
                        .foregroundStyle(style.highlight.color)
                    Text("歌词秀")
                } else if player.lyricsLoading {
                    ProgressView().controlSize(.small).tint(style.highlight.color)
                    Text("正在查找歌词…")
                } else {
                    Text(player.current?.displayName ?? "")
                        .foregroundStyle(style.highlight.color)
                    Text("没有找到歌词，长按可在线搜索或导入 .lrc").opacity(0.7)
                }
            }
            .font(.system(size: fontSize * 0.85))
            .foregroundStyle(style.text.color)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
    }

    @ViewBuilder
    private var menu: some View {
        Button("在线搜索歌词…", systemImage: "magnifyingglass") { searching = true }
            .disabled(player.current == nil)
        Button("从“文件”导入 .lrc", systemImage: "doc.badge.plus") { importing = true }
            .disabled(player.current == nil)
        Button("重新查找歌词", systemImage: "arrow.clockwise") { player.reloadLyrics() }
            .disabled(player.current == nil)
        Button("关闭歌词秀", systemImage: "xmark") { app.showLyrics = false }
    }
}

private struct LyricLines: View {
    let lyrics: Lyrics
    let current: Int?
    let style: TTLyricStyle
    let fontSize: CGFloat
    let onSeek: (TimeInterval) -> Void

    var body: some View {
        GeometryReader { geo in
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: fontSize * 0.55) {
                        ForEach(lyrics.lines) { line in
                            Group {
                                if line.id == current, lyrics.isSynced {
                                    KaraokeLine(lyrics: lyrics, index: line.id, style: style, fontSize: fontSize)
                                } else {
                                    Text(line.text.isEmpty ? "♪" : line.text)
                                        .font(.system(size: fontSize))
                                        .foregroundStyle(style.text.color)
                                }
                            }
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 8)
                            .contentShape(Rectangle())
                            .onTapGesture { if let t = line.time { onSeek(t) } }
                            .id(line.id)
                        }
                    }
                    // 上下留白，第一行和最后一行也能停在中间
                    .padding(.vertical, lyrics.isSynced ? max(8, geo.size.height / 2 - fontSize) : 8)
                }
                .scrollIndicators(.hidden)
                .onAppear { scroll(proxy, animated: false) }
                .onChange(of: current) { _, _ in scroll(proxy, animated: true) }
                .onChange(of: lyrics) { _, _ in scroll(proxy, animated: false) }
            }
        }
    }

    private func scroll(_ proxy: ScrollViewProxy, animated: Bool) {
        guard let current else { return }
        if animated {
            withAnimation(.easeInOut(duration: 0.4)) { proxy.scrollTo(current, anchor: .center) }
        } else {
            proxy.scrollTo(current, anchor: .center)
        }
    }
}

/// 当前行：底色是普通颜色，高亮色按播放进度从左往右盖上去
private struct KaraokeLine: View {
    @Environment(AppModel.self) private var app
    let lyrics: Lyrics
    let index: Int
    let style: TTLyricStyle
    let fontSize: CGFloat

    var body: some View {
        let line = lyrics.lines[index]
        let text = line.text.isEmpty ? "♪" : line.text
        let audio = app.player.audio
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: audio.state != .playing)) { _ in
            let p = progress(at: audio.currentTime)
            Text(text)
                .font(.system(size: fontSize * 1.08, weight: .semibold))
                .foregroundStyle(style.text.color)
                .overlay {
                    GeometryReader { g in
                        Text(text)
                            .font(.system(size: fontSize * 1.08, weight: .semibold))
                            .foregroundStyle(style.highlight.color)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .frame(width: g.size.width, height: g.size.height)
                            .mask(alignment: .leading) { Rectangle().frame(width: g.size.width * p) }
                    }
                }
        }
        .accessibilityLabel(text)
    }

    /// 本行开始到下一行开始之间匀速走完（留一点余量，句末先唱完）
    private func progress(at time: TimeInterval) -> CGFloat {
        guard let start = lyrics.lines[index].time else { return 1 }
        let next = lyrics.lines.dropFirst(index + 1).first { $0.time != nil }?.time
        let duration = max(0.5, ((next ?? start + 5) - start) * 0.92)
        return CGFloat(min(max((time - start) / duration, 0), 1))
    }
}
