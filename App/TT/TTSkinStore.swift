import AmplayerKit
import Foundation
import Observation

/// 皮肤列表：内置几套 + 用户导入的 .skn（存在 Application Support/JTplayer/Skins）
@MainActor
@Observable
final class TTSkinStore {
    struct Entry: Identifiable, Hashable {
        var id: String
        var name: String
        var author: String
        var isBuiltIn: Bool
    }

    private(set) var entries: [Entry] = []
    private(set) var current: TTSkin
    private var loaded: [String: TTSkin] = [:]

    private static let selectedKey = "jtplayer.skin"
    nonisolated static let defaultID = TTTheme.all[0].id
    /// 导入的皮肤缺某个窗口（比如没有均衡器）时，用默认皮肤的那个窗口顶上
    nonisolated static let fallback = TTSkin.builtIn(TTTheme.all[0])

    static var folder: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("JTplayer/Skins", isDirectory: true)
    }

    init() {
        current = Self.fallback
        loaded[Self.fallback.id] = Self.fallback
        reloadEntries()
        let saved = UserDefaults.standard.string(forKey: Self.selectedKey) ?? Self.defaultID
        if let skin = skin(for: saved) { current = skin }
    }

    private func reloadEntries() {
        var list = TTTheme.all.map { Entry(id: $0.id, name: $0.name, author: "JTplayer", isBuiltIn: true) }
        let files = (try? FileManager.default.contentsOfDirectory(at: Self.folder, includingPropertiesForKeys: [.creationDateKey])) ?? []
        for url in files.filter({ ["skn", "zip"].contains($0.pathExtension.lowercased()) }).sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let id = "skn:" + url.lastPathComponent
            if let skin = skin(for: id) {
                list.append(Entry(id: id, name: skin.name, author: skin.document.author, isBuiltIn: false))
            }
        }
        entries = list
    }

    func skin(for id: String) -> TTSkin? {
        if let hit = loaded[id] { return hit }
        let skin: TTSkin?
        if id.hasPrefix("skn:") {
            let url = Self.folder.appendingPathComponent(String(id.dropFirst(4)))
            skin = (try? Data(contentsOf: url)).flatMap { try? TTSkin.load(sknData: $0, id: id) }
        } else {
            skin = TTSkin.builtIn(id: id)
        }
        if let skin { loaded[id] = skin }
        return skin
    }

    func select(_ id: String) {
        guard let skin = skin(for: id) else { return }
        current = skin
        UserDefaults.standard.set(id, forKey: Self.selectedKey)
    }

    func next() -> Entry? {
        guard !entries.isEmpty else { return nil }
        let i = entries.firstIndex { $0.id == current.id } ?? -1
        let entry = entries[(i + 1) % entries.count]
        select(entry.id)
        return entry
    }

    /// 导入 .skn：先确认能加载，再复制进皮肤目录并切换过去
    @discardableResult
    func importSkin(from url: URL) throws -> Entry {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url)
        var fileName = url.deletingPathExtension().lastPathComponent + ".skn"
        let fm = FileManager.default
        try fm.createDirectory(at: Self.folder, withIntermediateDirectories: true)
        if fm.fileExists(atPath: Self.folder.appendingPathComponent(fileName).path),
           (try? Data(contentsOf: Self.folder.appendingPathComponent(fileName))) != data {
            fileName = url.deletingPathExtension().lastPathComponent + "-\(UUID().uuidString.prefix(4)).skn"
        }
        let id = "skn:" + fileName
        let skin = try TTSkin.load(sknData: data, id: id)
        try data.write(to: Self.folder.appendingPathComponent(fileName))
        loaded[id] = skin
        reloadEntries()
        select(id)
        return entries.first { $0.id == id } ?? Entry(id: id, name: skin.name, author: skin.document.author, isBuiltIn: false)
    }

    func delete(_ id: String) {
        guard id.hasPrefix("skn:") else { return }
        try? FileManager.default.removeItem(at: Self.folder.appendingPathComponent(String(id.dropFirst(4))))
        loaded[id] = nil
        if current.id == id { select(Self.defaultID) }
        reloadEntries()
    }
}
