import AmplayerKit
import SwiftUI

/// 播放列表窗口：上面一排工具栏（添加、删除、列表、排序、查找、编辑、模式），下面是曲目
struct PlaylistWindow: View {
    @Environment(AppModel.self) private var app
    @Environment(\.ttSkin) private var skin
    @Environment(\.ttScale) private var scale
    /// 窗口尺寸（皮肤像素）
    let size: CGSize

    @State private var isSaving = false
    @State private var playlistName = ""
    @State private var infoTrack: Track?
    @State private var searchText = ""
    @State private var searching = false
    @FocusState private var searchFocused: Bool

    private var player: PlayerController { app.player }

    var body: some View {
        let w = skin.document.playlist
        let base = w.baseSize(imageSize: skin.image(w.image)?.size)
        let style = skin.document.playlistStyle
        let list = w["playlist"].map { w.layout($0.rect, base: base, size: size) } ?? TTRect(x: 6, y: 38, width: size.width - 12, height: size.height - 44)
        let toolbarRect = w["toolbar"].map { w.layout($0.rect, base: base, size: size) } ?? TTRect(x: 6, y: 20, width: size.width - 12, height: 16)
        ZStack(alignment: .topLeading) {
            TTWindowBackground(window: w, size: size)
            toolbar(style).place(toolbarRect, scale)
            VStack(spacing: 0) {
                if searching { searchBar(style) }
                trackList(style)
                    .overlay(alignment: .bottom) { if app.isSelecting { selectionBar } }
                    .overlay { if player.queue.isEmpty { emptyHint(style) } }
            }
            .background(style.background.color)
            .clipped()
            .place(list, scale)
            if let close = w["close"] {
                var e = close
                let _ = e.rect = w.layout(close.rect, base: base, size: size)
                TTButton(element: e, label: "关闭播放列表") { app.showPlaylist = false }
            }
        }
        .frame(width: size.width * scale, height: size.height * scale, alignment: .topLeading)
        .alert("保存播放列表", isPresented: $isSaving) {
            TextField("名称", text: $playlistName)
            Button("保存") {
                do {
                    try app.library.savePlaylist(player.queue.tracks, name: playlistName)
                    app.show("已保存到 文件 › JTplayer › Playlists")
                } catch {
                    app.show("保存失败：\(error.localizedDescription)")
                }
            }
            Button("取消", role: .cancel) {}
        }
        .sheet(item: $infoTrack) { TrackInfoView(track: $0) }
    }

    // MARK: 工具栏

    private func toolbar(_ style: TTPlaylistStyle) -> some View {
        HStack(spacing: 0) {
            toolMenu("添加") {
                Button("从“文件”导入…", systemImage: "folder") { app.isImportingFiles = true }
                Button("从音乐来源添加…", systemImage: "externaldrive.connected.to.line.below") { app.sheet = .sources }
                Button("从曲库添加…", systemImage: "music.note.list") { app.sheet = .library }
            }
            toolMenu("删除") {
                Button("删除所选", systemImage: "minus.circle") { removeSelected() }
                    .disabled(app.selection.isEmpty)
                Button("只保留所选", systemImage: "crop") { cropToSelection() }
                    .disabled(app.selection.isEmpty)
                Button("删除重复的", systemImage: "square.on.square") { removeDuplicates() }
                Button("清空列表", systemImage: "trash", role: .destructive) { player.clear(); app.endSelection() }
            }
            toolMenu("列表") {
                Button("新建列表", systemImage: "doc") { player.clear(); app.endSelection() }
                Button("打开列表…", systemImage: "folder") { app.sheet = .playlists }
                Button("保存列表…", systemImage: "square.and.arrow.down") {
                    playlistName = player.current?.album ?? "我的播放列表"
                    isSaving = true
                }
                .disabled(player.queue.isEmpty)
                Button("曲库（音乐窗）", systemImage: "opticaldisc") { app.sheet = .library }
            }
            toolMenu("排序") {
                Button("按标题") { sort(.title) }
                Button("按艺术家") { sort(.artist) }
                Button("按专辑") { sort(.album) }
                Button("按文件路径") { sort(.path) }
                Divider()
                Button("反转顺序") { player.reverse(); app.endSelection() }
                Button("随机打乱") { player.randomize(); app.endSelection() }
            }
            toolButton("查找") {
                searching.toggle()
                if searching { searchFocused = true } else { searchText = "" }
            }
            toolMenu("编辑") {
                Button(app.isSelecting ? "退出多选" : "多选", systemImage: "checkmark.circle") {
                    if app.isSelecting { app.endSelection() } else { app.isSelecting = true }
                }
                Button("全选") { app.isSelecting = true; app.selection = Set(player.queue.tracks.indices) }
                Button("反选") { app.isSelecting = true; app.selection = Set(player.queue.tracks.indices).subtracting(app.selection) }
                Button("离线下载所选", systemImage: "arrow.down.circle") {
                    makeOffline(app.selection.sorted().map { player.queue.tracks[$0] })
                }
                .disabled(app.selection.isEmpty)
                Button("曲目信息", systemImage: "info.circle") {
                    if let i = app.selection.min() ?? player.queue.currentIndex { infoTrack = player.queue.tracks[i] }
                }
                .disabled(player.queue.isEmpty)
            }
            toolMenu("模式") {
                Picker("播放模式", selection: Binding(get: { player.playMode }, set: { player.playMode = $0; app.show($0.title) })) {
                    ForEach(PlayMode.allCases) { Text($0.title).tag($0) }
                }
            }
        }
        .font(.system(size: 11 * scale * 0.95))
        .foregroundStyle(skin.theme?.titleText.color ?? style.text.color)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func toolMenu<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        Menu(content: content) {
            Text(title).frame(maxWidth: .infinity, maxHeight: .infinity).contentShape(Rectangle())
        }
        .accessibilityLabel(title)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func toolButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).frame(maxWidth: .infinity, maxHeight: .infinity).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private func searchBar(_ style: TTPlaylistStyle) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
            TextField("查找歌曲", text: $searchText)
                .focused($searchFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
            Button { searching = false; searchText = "" } label: { Image(systemName: "xmark.circle.fill") }
                .buttonStyle(.plain)
                .accessibilityLabel("结束查找")
        }
        .font(.system(size: 14))
        .foregroundStyle(style.text.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(style.selection.color.opacity(0.5))
    }

    // MARK: 曲目

    private func matches(_ track: Track) -> Bool {
        let q = searchText.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return true }
        return [track.title, track.artist ?? "", track.album ?? "", track.path].contains { $0.localizedCaseInsensitiveContains(q) }
    }

    private func trackList(_ style: TTPlaylistStyle) -> some View {
        let tracks = player.queue.tracks
        let shown = Array(tracks.enumerated()).filter { matches($0.element) }
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(shown, id: \.offset) { index, track in
                        row(index: index, track: track, style: style).id(index)
                    }
                }
            }
            .scrollIndicators(.visible)
            .onChange(of: player.queue.currentIndex) { _, new in
                if let new, searchText.isEmpty { withAnimation { proxy.scrollTo(new, anchor: .center) } }
            }
            .onAppear { if let c = player.queue.currentIndex { proxy.scrollTo(c, anchor: .center) } }
        }
    }

    private func row(index: Int, track: Track, style: TTPlaylistStyle) -> some View {
        let isCurrent = index == player.queue.currentIndex
        let selected = app.selection.contains(index)
        let fontSize = max(11, style.fontSize) * scale * 0.95
        let textColor = selected ? (style.selectionText ?? style.text) : (isCurrent ? style.current : style.text)
        let rowBackground: Color = selected ? style.selection.color
            : (index % 2 == 1 ? (style.background2?.color ?? .clear) : .clear)
        return HStack(spacing: 6) {
            Text("\(index + 1).")
                .monospacedDigit()
                .foregroundStyle((isCurrent ? style.current : style.number).color)
                .frame(minWidth: fontSize * 1.6, alignment: .trailing)
            Text(track.displayName)
                .foregroundStyle(textColor.color)
                .fontWeight(isCurrent ? .semibold : .regular)
                .lineLimit(1)
            Spacer(minLength: 4)
            if player.loadingTrackID == track.id {
                if let progress = player.loadingProgress {
                    Text(progress).monospacedDigit().foregroundStyle(style.duration.color)
                } else {
                    ProgressView().controlSize(.mini).tint(style.current.color)
                }
            }
            Text(track.duration.map(TimeFormat.clock) ?? "")
                .monospacedDigit()
                .foregroundStyle((isCurrent ? style.current : style.duration).color)
        }
        .font(.system(size: fontSize))
        .padding(.horizontal, 6)
        .frame(height: fontSize * 1.9)
        .background(rowBackground)
        .contentShape(Rectangle())
        .onTapGesture {
            if app.isSelecting {
                if selected { app.selection.remove(index) } else { app.selection.insert(index) }
            } else {
                player.play(index: index)
            }
        }
        .contextMenu {
            Button("播放", systemImage: "play.fill") { player.play(index: index) }
            Button("多选", systemImage: "checkmark.circle") {
                app.isSelecting = true
                app.selection = [index]
            }
            Menu("移动", systemImage: "arrow.up.arrow.down") {
                Button("移到最前", systemImage: "arrow.up.to.line") { player.moveTrack(at: index, to: 0); app.endSelection() }
                    .disabled(index == 0)
                Button("上移", systemImage: "arrow.up") { player.moveTrack(at: index, to: index - 1); app.endSelection() }
                    .disabled(index == 0)
                Button("下移", systemImage: "arrow.down") { player.moveTrack(at: index, to: index + 1); app.endSelection() }
                    .disabled(index == player.queue.tracks.count - 1)
                Button("移到最后", systemImage: "arrow.down.to.line") { player.moveTrack(at: index, to: player.queue.tracks.count - 1); app.endSelection() }
                    .disabled(index == player.queue.tracks.count - 1)
            }
            Button("下一首播放", systemImage: "text.line.first.and.arrowtriangle.forward") {
                let current = player.queue.currentIndex
                player.playNext([track])
                if let c = current {
                    if index > c { player.remove(at: IndexSet([index + 1])) } else if index < c { player.remove(at: IndexSet([index])) }
                }
                app.endSelection()
            }
            .disabled(isCurrent)
            Button("离线下载", systemImage: "arrow.down.circle") { makeOffline([track]) }
            if app.canShowArtist(track), let artist = track.artist {
                Button("查看歌手：\(artist)", systemImage: "music.mic") { app.showArtist(of: track) }
            }
            Button("曲目信息", systemImage: "info.circle") { infoTrack = track }
            Button("从列表删除", systemImage: "trash", role: .destructive) {
                player.remove(at: IndexSet([index]))
                app.endSelection()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(index + 1). \(track.displayName), \(track.duration.map(TimeFormat.clock) ?? "")")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func emptyHint(_ style: TTPlaylistStyle) -> some View {
        VStack(spacing: 8) {
            Text("播放列表是空的")
            Button("打开音乐来源") { app.sheet = .sources }
                .buttonStyle(.bordered)
                .tint(style.current.color)
            Text("也可以点上面的“添加”从“文件”或曲库添加").opacity(0.7)
        }
        .font(.system(size: 13))
        .foregroundStyle(style.text.color)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 12)
    }

    private var selectionBar: some View {
        HStack(spacing: 12) {
            Text("已选 \(app.selection.count) 首").monospacedDigit()
            Spacer()
            Button("全选") { app.selection = Set(player.queue.tracks.indices) }
            Button("删除") { removeSelected() }
                .disabled(app.selection.isEmpty)
            Button("完成") { app.endSelection() }
                .fontWeight(.semibold)
        }
        .font(.system(size: 14))
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.ultraThinMaterial, in: Capsule())
        .padding(6)
    }

    // MARK: 操作

    private func removeSelected() {
        player.remove(at: IndexSet(app.selection))
        app.endSelection()
    }

    private func cropToSelection() {
        let keep = app.selection
        player.remove(at: IndexSet(player.queue.tracks.indices.filter { !keep.contains($0) }))
        app.endSelection()
    }

    private func removeDuplicates() {
        var seen = Set<String>()
        var dupes = IndexSet()
        for (i, t) in player.queue.tracks.enumerated() where !seen.insert(t.id).inserted { dupes.insert(i) }
        player.remove(at: dupes)
        app.endSelection()
        app.show(dupes.isEmpty ? "没有重复的歌曲" : "已删除 \(dupes.count) 首重复的")
    }

    private func sort(_ key: PlayerController.SortKey) {
        player.sort(by: key)
        app.endSelection()
    }

    private func makeOffline(_ tracks: [Track]) {
        let sources = app.sources
        let cache = player.cache
        app.show("开始离线下载 \(tracks.count) 首")
        Task {
            var failed = 0
            for t in tracks {
                guard let source = sources.source(t.sourceID) else { failed += 1; continue }
                do { try await cache.makeOffline(t, source: source) } catch { failed += 1 }
            }
            app.show(failed == 0 ? "离线下载完成" : "\(failed) 首下载失败")
        }
    }
}
