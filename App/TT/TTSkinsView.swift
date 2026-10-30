import AmplayerKit
import SwiftUI
import UniformTypeIdentifiers

/// 皮肤：内置几套，另可导入千千静听格式的 .skn
struct TTSkinsView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var importing = false

    var body: some View {
        NavigationStack {
            List {
                Section("内置皮肤") {
                    ForEach(app.skins.entries.filter(\.isBuiltIn)) { row($0) }
                }
                let imported = app.skins.entries.filter { !$0.isBuiltIn }
                Section {
                    ForEach(imported) { entry in
                        row(entry)
                            .swipeActions {
                                Button("删除", role: .destructive) { app.skins.delete(entry.id) }
                            }
                    }
                    Button("导入 .skn 皮肤…", systemImage: "square.and.arrow.down") { importing = true }
                } header: {
                    Text("导入的皮肤")
                } footer: {
                    Text("支持千千静听格式的 .skn 皮肤（Skin.xml version=\"2\"），也可以在“文件”App 里用 JTplayer 打开 .skn。皮肤里没有的窗口会用默认皮肤补上。")
                }
            }
            .navigationTitle("皮肤")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
            .fileImporter(isPresented: $importing, allowedContentTypes: [UTType(filenameExtension: "skn") ?? .zip, .zip]) { result in
                guard case let .success(url) = result else { return }
                do {
                    let entry = try app.skins.importSkin(from: url)
                    app.show(String(localized: "已切换到皮肤 \(entry.name)"))
                } catch let error as TTSkin.LoadError {
                    if case let .invalid(message) = error { app.show(message) } else { app.show(String(localized: "皮肤包里没有 Skin.xml")) }
                } catch {
                    app.show(String(localized: "导入失败：\(error.localizedDescription)"))
                }
            }
        }
    }

    private func row(_ entry: TTSkinStore.Entry) -> some View {
        let selected = app.skins.current.id == entry.id
        return Button {
            app.skins.select(entry.id)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                if let skin = app.skins.skin(for: entry.id) {
                    SkinPreview(skin: skin)
                }
                HStack {
                    Text(entry.name).font(.subheadline.weight(.semibold))
                    if !entry.author.isEmpty, !entry.isBuiltIn {
                        Text(entry.author).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if selected { Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.jtAccent) }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("皮肤：\(entry.name)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// 列表里的皮肤预览：直接渲染主控窗口（不响应点击）
private struct SkinPreview: View {
    let skin: TTSkin

    var body: some View {
        GeometryReader { geo in
            let size = skin.image(skin.document.player.image)?.size ?? CGSize(width: 330, height: 136)
            MainPlayerWindow()
                .environment(\.ttSkin, skin)
                .environment(\.ttScale, geo.size.width / size.width)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .aspectRatio(aspect, contentMode: .fit)
    }

    private var aspect: CGFloat {
        let size = skin.image(skin.document.player.image)?.size ?? CGSize(width: 330, height: 136)
        return size.width / max(size.height, 1)
    }
}
