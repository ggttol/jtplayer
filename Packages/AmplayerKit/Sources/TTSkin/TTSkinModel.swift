import CoreGraphics
import Foundation

/// 千千静听式皮肤（.skn）的数据模型。坐标单位是皮肤像素，矩形按 Skin.xml 的 “左,上,右,下”（含右下边界）。
public struct TTRect: Equatable, Sendable {
    public var x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat

    public init(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        self.x = x; self.y = y; self.width = width; self.height = height
    }

    /// "l, t, r, b"；缺项或格式不对返回 nil
    public init?(ltrb text: String?) {
        guard let text else { return nil }
        let parts = text.split(separator: ",", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count >= 4, let l = Double(parts[0]), let t = Double(parts[1]), let r = Double(parts[2]), let b = Double(parts[3]) else { return nil }
        guard r >= l, b >= t else { return nil }
        self.init(x: l, y: t, width: r - l + 1, height: b - t + 1)
    }

    public var cgRect: CGRect { CGRect(x: x, y: y, width: width, height: height) }
    public var maxX: CGFloat { x + width }
    public var maxY: CGFloat { y + height }
    public var size: CGSize { CGSize(width: width, height: height) }
}

/// RGB 颜色（"#rrggbb"）
public struct TTColor: Equatable, Sendable {
    public var r: Double, g: Double, b: Double, a: Double

    public init(r: Double, g: Double, b: Double, a: Double = 1) {
        self.r = r; self.g = g; self.b = b; self.a = a
    }

    public init?(hex: String?) {
        guard var s = hex?.trimmingCharacters(in: .whitespaces), !s.isEmpty else { return nil }
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        self.init(r: Double((v >> 16) & 0xFF) / 255, g: Double((v >> 8) & 0xFF) / 255, b: Double(v & 0xFF) / 255)
    }

    public var cgColor: CGColor { CGColor(srgbRed: r, green: g, blue: b, alpha: a) }

    public func mixed(with other: TTColor, _ t: Double) -> TTColor {
        TTColor(r: r + (other.r - r) * t, g: g + (other.g - g) * t, b: b + (other.b - b) * t, a: a + (other.a - a) * t)
    }

    public func opacity(_ alpha: Double) -> TTColor { TTColor(r: r, g: g, b: b, a: alpha) }

    public static let white = TTColor(r: 1, g: 1, b: 1)
    public static let black = TTColor(r: 0, g: 0, b: 0)
}

public enum TTAlign: Sendable, Equatable {
    case left, center, right
}

/// 窗口里的一个元素：按钮、滑块、文字区等
public struct TTElement: Equatable, Sendable {
    public var name: String
    public var rect: TTRect
    /// 按钮：横向四帧（普通、悬停、按下/选中、禁用）
    public var image: String?
    /// 滑块：底图、填充、滑块（横向四帧）
    public var barImage: String?
    public var fillImage: String?
    public var thumbImage: String?
    public var vertical = false
    public var align: TTAlign = .left
    public var color: TTColor?
    public var background: TTColor?
    public var fontSize: CGFloat?

    public init(name: String, rect: TTRect) {
        self.name = name
        self.rect = rect
    }
}

/// 一个窗口：背景图 + 元素。resizeRect 内的部分可拉伸（播放列表、歌词窗口）
public struct TTWindow: Equatable, Sendable {
    public var image: String?
    public var position: TTRect?
    public var resizeRect: TTRect?
    public var resizeTile = false
    /// 均衡器频段间距
    public var bandInterval: CGFloat = 0
    public var elements: [String: TTElement] = [:]
    /// 播放列表工具栏
    public var toolbarHotImage: String?

    public init() {}

    public subscript(name: String) -> TTElement? { elements[name] }
}

public struct TTLyricStyle: Equatable, Sendable {
    public var text: TTColor
    public var highlight: TTColor
    public var background: TTColor
    public var fontSize: CGFloat

    public init(text: TTColor, highlight: TTColor, background: TTColor, fontSize: CGFloat) {
        self.text = text; self.highlight = highlight; self.background = background; self.fontSize = fontSize
    }
}

public struct TTPlaylistStyle: Equatable, Sendable {
    public var text: TTColor
    public var current: TTColor
    public var background: TTColor
    public var background2: TTColor?
    public var number: TTColor
    public var duration: TTColor
    public var selection: TTColor
    public var selectionText: TTColor?
    public var fontSize: CGFloat

    public init(text: TTColor, current: TTColor, background: TTColor, background2: TTColor? = nil, number: TTColor, duration: TTColor,
                selection: TTColor, selectionText: TTColor? = nil, fontSize: CGFloat) {
        self.text = text; self.current = current; self.background = background; self.background2 = background2
        self.number = number; self.duration = duration; self.selection = selection; self.selectionText = selectionText; self.fontSize = fontSize
    }
}

public struct TTVisualStyle: Equatable, Sendable {
    public var top: TTColor
    public var middle: TTColor
    public var bottom: TTColor
    public var peak: TTColor
    /// 频谱条宽度（皮肤像素）
    public var barWidth: CGFloat

    public init(top: TTColor, middle: TTColor, bottom: TTColor, peak: TTColor, barWidth: CGFloat) {
        self.top = top; self.middle = middle; self.bottom = bottom; self.peak = peak; self.barWidth = barWidth
    }
}

/// Skin.xml + 附带的配色文件
public struct TTSkinDocument: Equatable, Sendable {
    public var name: String
    public var author: String
    public var url: String
    public var transparentColor: TTColor?
    public var player = TTWindow()
    public var lyric = TTWindow()
    public var equalizer = TTWindow()
    public var playlist = TTWindow()
    public var lyricStyle: TTLyricStyle
    public var playlistStyle: TTPlaylistStyle
    public var visualStyle: TTVisualStyle

    public init(name: String = "", author: String = "", url: String = "") {
        self.name = name
        self.author = author
        self.url = url
        lyricStyle = TTSkinDocument.defaultLyricStyle
        playlistStyle = TTSkinDocument.defaultPlaylistStyle
        visualStyle = TTSkinDocument.defaultVisualStyle
    }

    public static let defaultLyricStyle = TTLyricStyle(
        text: TTColor(hex: "#7C93B0")!, highlight: TTColor(hex: "#58C8FF")!, background: .black, fontSize: 14)
    public static let defaultPlaylistStyle = TTPlaylistStyle(
        text: TTColor(hex: "#C8D6E8")!, current: TTColor(hex: "#4FC3FF")!, background: TTColor(hex: "#0B1626")!,
        number: TTColor(hex: "#6F86A3")!, duration: TTColor(hex: "#6F86A3")!, selection: TTColor(hex: "#1F4F86")!, fontSize: 12)
    public static let defaultVisualStyle = TTVisualStyle(
        top: TTColor(hex: "#FFFFFF")!, middle: TTColor(hex: "#58C8FF")!, bottom: TTColor(hex: "#1464E6")!, peak: TTColor(hex: "#FFFFFF")!, barWidth: 2)

    /// 均衡器的 10 个频段：模板 eqfactor 依次平移（原版步长是 右-左+间距，比含边界的宽度少 1）
    public func equalizerBand(_ index: Int) -> TTElement? {
        guard var band = equalizer["eqfactor"] else { return nil }
        band.rect.x += CGFloat(index) * (band.rect.width - 1 + equalizer.bandInterval)
        band.name = "eqfactor\(index)"
        return band
    }
}

// MARK: 可拉伸窗口的布局

public extension TTWindow {
    /// 背景图原始尺寸（皮肤像素）；没有背景图时用 position
    func baseSize(imageSize: CGSize?) -> CGSize {
        if let imageSize { return imageSize }
        if let position { return position.size }
        return .zero
    }

    /// 窗口拉伸到 size 后元素的位置：在可拉伸区右/下方的元素跟着平移，跨过可拉伸区的元素跟着变宽/变高
    func layout(_ rect: TTRect, base: CGSize, size: CGSize) -> TTRect {
        guard let resize = resizeRect else { return rect }
        let dx = size.width - base.width, dy = size.height - base.height
        var r = rect
        if rect.x >= resize.maxX { r.x += dx } else if rect.maxX >= resize.maxX && rect.x <= resize.x + resize.width / 2 { r.width += dx }
        if rect.y >= resize.maxY { r.y += dy } else if rect.maxY >= resize.maxY && rect.y <= resize.y + resize.height / 2 { r.height += dy }
        r.width = max(1, r.width)
        r.height = max(1, r.height)
        return r
    }
}
