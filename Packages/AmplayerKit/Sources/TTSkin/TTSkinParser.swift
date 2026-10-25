import Foundation

/// 解析 Skin.xml（version="2"）、Lyric.xml、Playlist.xml、Visual.xml。
/// 旧皮肤多为 GBK 编码，也有 UTF-8（可能带 BOM），两种都认。
public enum TTSkinParser {
    public enum ParseError: Error, Equatable {
        case notXML
        case unsupportedVersion
    }

    /// 简单 DOM：皮肤文件只用到元素和属性
    final class Node {
        let name: String
        let attributes: [String: String]
        var children: [Node] = []

        init(name: String, attributes: [String: String]) {
            self.name = name.lowercased()
            // 属性名不区分大小写
            var attrs: [String: String] = [:]
            for (k, v) in attributes { attrs[k.lowercased()] = v }
            self.attributes = attrs
        }

        subscript(_ key: String) -> String? {
            guard let v = attributes[key.lowercased()]?.trimmingCharacters(in: .whitespaces), !v.isEmpty else { return nil }
            return v
        }
    }

    private final class Builder: NSObject, XMLParserDelegate {
        var root: Node?
        var stack: [Node] = []

        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
            let node = Node(name: elementName, attributes: attributeDict)
            if let parent = stack.last { parent.children.append(node) } else { root = node }
            stack.append(node)
        }

        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
            _ = stack.popLast()
        }
    }

    /// 字节 → 文本：UTF-8（含 BOM）优先，否则按 GB18030（GBK 的超集）
    public static func decodeText(_ data: Data) -> String? {
        var bytes = data
        if bytes.starts(with: [0xEF, 0xBB, 0xBF]) { bytes = bytes.dropFirst(3) }
        if bytes.starts(with: [0xFF, 0xFE]) { return String(data: bytes, encoding: .utf16LittleEndian) }
        if let s = String(data: bytes, encoding: .utf8) { return s }
        let gb = CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue))
        return String(data: bytes, encoding: String.Encoding(rawValue: gb))
    }

    static func parseXML(_ data: Data) -> Node? {
        guard var text = decodeText(data) else { return nil }
        // 已经转成 UTF-8，去掉声明里的 encoding，免得 XMLParser 再按 GBK 解一遍
        if let range = text.range(of: #"encoding\s*=\s*["'][^"']*["']"#, options: .regularExpression) {
            text.removeSubrange(range)
        }
        // 有些皮肤的属性值里出现裸 &
        text = text.replacingOccurrences(of: #"&(?!(amp|lt|gt|quot|apos|#\d+|#x[0-9a-fA-F]+);)"#, with: "&amp;", options: .regularExpression)
        let parser = XMLParser(data: Data(text.utf8))
        let builder = Builder()
        parser.delegate = builder
        parser.shouldResolveExternalEntities = false
        _ = parser.parse()
        return builder.root
    }

    // MARK: Skin.xml

    public static func parseSkin(_ data: Data) throws -> TTSkinDocument {
        guard let root = parseXML(data) else { throw ParseError.notXML }
        guard root["version"].flatMap(Int.init) == 2 else { throw ParseError.unsupportedVersion }
        var doc = TTSkinDocument(name: root["name"] ?? "", author: root["author"] ?? "", url: root["url"] ?? "")
        doc.transparentColor = TTColor(hex: root["transparent_color"])
        for window in root.children {
            switch window.name {
            case "player_window": doc.player = parseWindow(window)
            case "lyric_window": doc.lyric = parseWindow(window)
            case "equalizer_window": doc.equalizer = parseWindow(window)
            case "playlist_window": doc.playlist = parseWindow(window)
            default: break
            }
        }
        return doc
    }

    static func parseWindow(_ node: Node) -> TTWindow {
        var w = TTWindow()
        w.image = node["image"]
        w.position = TTRect(ltrb: node["position"])
        w.resizeRect = TTRect(ltrb: node["resize_rect"])
        w.resizeTile = node["resize_tile"].flatMap(Int.init).map { $0 != 0 } ?? false
        w.bandInterval = node["eq_interval"].flatMap(Double.init).map { CGFloat($0) } ?? 0
        for child in node.children {
            // 同名节点：后面的覆盖前面的（原版写进同一个字段）
            guard let rect = TTRect(ltrb: child["position"]) else { continue }
            var e = TTElement(name: child.name, rect: rect)
            e.image = child["image"]
            e.barImage = child["bar_image"]
            e.fillImage = child["fill_image"]
            e.thumbImage = child["thumb_image"]
            e.vertical = child["vertical"]?.lowercased() == "true"
            switch child["align"]?.lowercased() {
            case let a? where a.contains("right"): e.align = .right
            case let a? where a.contains("center"): e.align = .center
            default: e.align = .left
            }
            e.color = TTColor(hex: child["color"])
            e.background = TTColor(hex: child["bkgnd"])
            e.fontSize = child["font_size"].flatMap(Double.init).map { CGFloat($0) }
            if child.name == "toolbar" { w.toolbarHotImage = child["hot_image"] }
            // 播放列表的选中行图片挂在 playlist 节点上
            if child.name == "playlist", e.image == nil { e.image = child["selected_image"] }
            w.elements[child.name] = e
        }
        return w
    }

    // MARK: 配色文件

    /// LOGFONT 字符串 "-12,0,0,0,400,...,宋体" 的字号（像素）
    static func fontHeight(_ descriptor: String?) -> CGFloat? {
        guard let first = descriptor?.split(separator: ",").first, let v = Double(first.trimmingCharacters(in: .whitespaces)), v != 0 else { return nil }
        return CGFloat(abs(v))
    }

    public static func parseLyricStyle(_ data: Data, base: TTLyricStyle) -> TTLyricStyle {
        guard let node = parseXML(data)?.children.first(where: { $0.name == "lyric" }) else { return base }
        var s = base
        s.text = TTColor(hex: node["textcolor"]) ?? s.text
        s.highlight = TTColor(hex: node["hilightcolor"]) ?? s.highlight
        s.background = TTColor(hex: node["bkgndcolor"]) ?? s.background
        s.fontSize = fontHeight(node["font"]) ?? s.fontSize
        return s
    }

    public static func parsePlaylistStyle(_ data: Data, base: TTPlaylistStyle) -> TTPlaylistStyle {
        guard let node = parseXML(data)?.children.first(where: { $0.name == "playlist" }) else { return base }
        var s = base
        s.text = TTColor(hex: node["color_text"]) ?? s.text
        s.current = TTColor(hex: node["color_hilight"]) ?? s.current
        s.background = TTColor(hex: node["color_bkgnd"]) ?? s.background
        s.background2 = TTColor(hex: node["color_bkgnd2"]) ?? s.background2
        s.number = TTColor(hex: node["color_number"]) ?? s.number
        s.duration = TTColor(hex: node["color_duration"]) ?? s.duration
        s.selection = TTColor(hex: node["color_select"]) ?? s.selection
        s.selectionText = TTColor(hex: node["color_seltext"]) ?? s.selectionText
        s.fontSize = fontHeight(node["font"]) ?? s.fontSize
        return s
    }

    public static func parseVisualStyle(_ data: Data, base: TTVisualStyle) -> TTVisualStyle {
        guard let node = parseXML(data)?.children.first(where: { $0.name == "visual" }) else { return base }
        var s = base
        s.top = TTColor(hex: node["spectrumtopcolor"]) ?? s.top
        s.middle = TTColor(hex: node["spectrummidcolor"]) ?? s.middle
        s.bottom = TTColor(hex: node["spectrumbtmcolor"]) ?? s.bottom
        s.peak = TTColor(hex: node["spectrumpeakcolor"]) ?? s.peak
        if let wide = node["spectrumwide"].flatMap(Double.init) { s.barWidth = max(1, CGFloat(wide) + 1) }
        return s
    }
}
