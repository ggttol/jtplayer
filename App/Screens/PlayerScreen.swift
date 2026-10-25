import AmplayerKit
import SwiftUI
import UniformTypeIdentifiers

/// 主界面：主控窗口在上，均衡器、歌词秀、播放列表依次吸附在下面，按屏宽等比放大
struct PlayerScreen: View {
    @Environment(AppModel.self) private var app
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var app = app
        GeometryReader { geo in
            let skin = app.skin
            let doc = skin.document
            let mainSize = skin.image(doc.player.image)?.size ?? CGSize(width: 330, height: 136)
            // 皮肤缺哪个窗口，就用默认皮肤的那个窗口
            let eqSkin = skin.image(doc.equalizer.image) != nil ? skin : TTSkinStore.fallback
            let lyricSkin = skin.image(doc.lyric.image) != nil ? skin : TTSkinStore.fallback
            let listSkin = skin.image(doc.playlist.image) != nil ? skin : TTSkinStore.fallback
            let eqSize = eqSkin.image(eqSkin.document.equalizer.image)?.size ?? CGSize(width: 330, height: 134)
            // 每个窗口按自己的宽度铺满屏宽：可拉伸的窗口拉到和主窗口一样宽，用主窗口的比例
            let W = geo.size.width
            let mainScale = W / mainSize.width
            let lyricWidth = width(of: lyricSkin.document.lyric, in: lyricSkin, main: skin, mainWidth: mainSize.width)
            let listWidth = width(of: listSkin.document.playlist, in: listSkin, main: skin, mainWidth: mainSize.width)
            let eqScale = W / eqSize.width
            let lower = app.showLyrics || app.showPlaylist
            // 高度放不下（iPad 横屏）时整体缩小
            let fixedHeight = mainSize.height * mainScale + (app.showEqualizer ? eqSize.height * eqScale : 0)
            let fit = min(1, geo.size.height / (fixedHeight + (lower ? 160 : 0)))
            let rest = max(0, geo.size.height - fixedHeight * fit)
            let lyricScale = W / lyricWidth * fit, listScale = W / listWidth * fit
            let lyricPoints = app.showLyrics ? (app.showPlaylist ? max(110, (rest * 0.4).rounded(.down)) : rest) : 0
            let listPoints = app.showPlaylist ? max(110, rest - lyricPoints) : 0
            VStack(spacing: 0) {
                MainPlayerWindow()
                    .environment(\.ttScale, mainScale * fit)
                if app.showEqualizer {
                    EqualizerWindow()
                        .environment(\.ttSkin, eqSkin)
                        .environment(\.ttScale, eqScale * fit)
                }
                if app.showLyrics {
                    LyricWindow(size: windowSize(lyricSkin, lyricSkin.document.lyric, width: lyricWidth, height: lyricPoints / lyricScale))
                        .environment(\.ttSkin, lyricSkin)
                        .environment(\.ttScale, lyricScale)
                }
                if app.showPlaylist {
                    PlaylistWindow(size: windowSize(listSkin, listSkin.document.playlist, width: listWidth, height: listPoints / listScale))
                        .environment(\.ttSkin, listSkin)
                        .environment(\.ttScale, listScale)
                }
                if !lower {
                    ClosedWindowsHint().frame(maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity)
            .environment(\.ttSkin, skin)
        }
        .background(Color.black.ignoresSafeArea())
        .overlay { SideMenuView() }
        .overlay(alignment: .top) { ToastView() }
        .sheet(item: $app.sheet) { sheet in
            switch sheet {
            case .sources: SourcesView()
            case .library: LibraryView()
            case .playlists: LibraryView(initialTab: .playlists)
            case .skins: TTSkinsView()
            case .settings: SettingsView()
            case .effects: SoundEffectsView()
            }
        }
        .fileImporter(isPresented: $app.isImportingFiles, allowedContentTypes: [.audio], allowsMultipleSelection: true) { result in
            if case let .success(urls) = result { app.importAudioFiles(urls, play: true) }
        }
        .onOpenURL { app.open(url: $0) }
        .onChange(of: scenePhase, initial: true) { _, _ in updateAnalyzer() }
        .onChange(of: app.visualizerMode) { _, _ in updateAnalyzer() }
        .onChange(of: app.player.lastError) { _, error in
            if let error { app.show(error) }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden(false)
    }
}

/// 播放列表被关掉后下面的空白处：告诉用户怎么找回窗口
struct ClosedWindowsHint: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        VStack(spacing: 10) {
            Text(app.isMiniMode ? "迷你模式" : "歌词秀和播放列表已关闭").font(.footnote).foregroundStyle(.secondary)
            HStack(spacing: 10) {
                if app.isMiniMode { Button("恢复窗口") { app.toggleMiniMode() } } else {
                Button("播放列表") { app.showPlaylist = true }
                Button("歌词秀") { app.showLyrics = true }
                if !app.showEqualizer { Button("均衡器") { app.showEqualizer = true } }
                }
            }
            .buttonStyle(.bordered)
            .tint(.gray)
            .font(.footnote)
        }
        .frame(maxWidth: .infinity)
    }
}

extension PlayerScreen {
    /// 窗口宽度（皮肤像素）：和主窗口同一套皮肤且可拉伸时与主窗口同宽，否则用窗口自己的宽度
    func width(of window: TTWindow, in skin: TTSkin, main: TTSkin, mainWidth: CGFloat) -> CGFloat {
        if skin === main, window.resizeRect != nil { return mainWidth }
        return max(1, window.baseSize(imageSize: skin.image(window.image)?.size).width)
    }

    /// 可拉伸的窗口拉到和主窗口一样宽、填满给它的高度；不能拉伸的保持原尺寸
    func windowSize(_ skin: TTSkin, _ window: TTWindow, width: CGFloat, height: CGFloat) -> CGSize {
        let base = window.baseSize(imageSize: skin.image(window.image)?.size)
        guard window.resizeRect != nil else { return base }
        return CGSize(width: width, height: max(height, 60))
    }

    /// 频谱只在前台且可视化开着时计算
    func updateAnalyzer() {
        app.player.audio.analyzer.isEnabled = scenePhase == .active && app.visualizerMode != .off
    }
}

struct ToastView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        if let message = app.toast {
            Text(message)
                .font(.footnote)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.default, value: app.toast)
        }
    }
}

/// 曲目信息
struct TrackInfoView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    let track: Track
    @State private var offline = false

    var body: some View {
        NavigationStack {
            Form {
                LabeledContent("标题", value: track.title)
                if let v = track.artist { LabeledContent("艺术家", value: v) }
                if let v = track.album { LabeledContent("专辑", value: v) }
                if let v = track.trackNumber { LabeledContent("音轨", value: "\(v)") }
                if let v = track.duration { LabeledContent("时长", value: TimeFormat.clock(v)) }
                if let v = track.fileSize { LabeledContent("大小", value: ByteCountFormatter.string(fromByteCount: v, countStyle: .file)) }
                LabeledContent("格式", value: track.fileExtension.uppercased())
                LabeledContent("来源", value: app.sources.config(track.sourceID)?.name ?? track.sourceID)
                LabeledContent("路径") { Text(track.path).font(.caption).textSelection(.enabled) }
                LabeledContent("离线", value: offline ? "已下载" : "否")
            }
            .navigationTitle("曲目信息")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
            .task { offline = await app.player.cache.isOffline(track) }
        }
        .presentationDetents([.medium, .large])
    }
}
