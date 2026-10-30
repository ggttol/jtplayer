import CoreGraphics
import Foundation
import ImageIO

/// 皮肤里的一张图。scale 是“每皮肤像素多少位图像素”：.skn 的 BMP 为 1，内置皮肤按 3 倍绘制
public struct TTImage: @unchecked Sendable {
    public let cgImage: CGImage
    public let scale: CGFloat

    public init(cgImage: CGImage, scale: CGFloat) {
        self.cgImage = cgImage
        self.scale = scale
    }

    /// 皮肤像素尺寸
    public var size: CGSize { CGSize(width: CGFloat(cgImage.width) / scale, height: CGFloat(cgImage.height) / scale) }

    /// 横向等分成 count 帧，取第 index 帧
    public func frame(_ index: Int, of count: Int) -> TTImage {
        guard count > 1 else { return self }
        let w = cgImage.width / count
        guard w > 0, let cropped = cgImage.cropping(to: CGRect(x: min(index, count - 1) * w, y: 0, width: w, height: cgImage.height)) else { return self }
        return TTImage(cgImage: cropped, scale: scale)
    }

    /// 裁出一块（皮肤像素坐标）
    public func crop(_ rect: CGRect) -> TTImage? {
        let px = CGRect(x: rect.minX * scale, y: rect.minY * scale, width: rect.width * scale, height: rect.height * scale).integral
            .intersection(CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
        guard !px.isEmpty, let c = cgImage.cropping(to: px) else { return nil }
        return TTImage(cgImage: c, scale: scale)
    }
}

/// 一套可用的皮肤：布局 + 图片
public final class TTSkin: @unchecked Sendable, Identifiable {
    public let id: String
    public let document: TTSkinDocument
    private let images: [String: TTImage]
    /// 内置皮肤用的调色板（.skn 为 nil）
    public let theme: TTTheme?

    public var name: String { document.name }

    init(id: String, document: TTSkinDocument, images: [String: TTImage], theme: TTTheme? = nil) {
        self.id = id
        self.document = document
        self.images = images
        self.theme = theme
    }

    /// 按 Skin.xml 里写的文件名取图（忽略大小写、目录分隔符）
    public func image(_ name: String?) -> TTImage? {
        guard let name else { return nil }
        let key = Self.key(name)
        if let hit = images[key] { return hit }
        if let base = key.split(separator: "/").last { return images[String(base)] }
        return nil
    }

    static func key(_ name: String) -> String {
        name.replacingOccurrences(of: "\\", with: "/").trimmingCharacters(in: CharacterSet(charactersIn: "/ ")).lowercased()
    }

    // MARK: 加载 .skn

    public enum LoadError: Error, Equatable {
        case missingSkinXML
        case invalid(String)
    }

    /// .skn / .zip 数据
    public static func load(sknData data: Data, id: String) throws -> TTSkin {
        let zip: ZipArchive
        do { zip = try ZipArchive(data: data) } catch { throw LoadError.invalid(String(localized: "不是有效的 .skn（zip）文件")) }
        var files: [String: Data] = [:]
        for entry in zip.entries where !entry.path.hasSuffix("/") {
            guard let d = try? zip.data(for: entry) else { continue }
            files[fixZipName(entry.path)] = d
        }
        return try build(id: id, files: files)
    }

    /// 已解压的皮肤目录
    public static func load(directory: URL, id: String) throws -> TTSkin {
        var files: [String: Data] = [:]
        let root = directory.standardizedFileURL.path
        if let e = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey]) {
            for case let url as URL in e where (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true {
                let rel = String(url.standardizedFileURL.path.dropFirst(root.count))
                files[rel] = try? Data(contentsOf: url)
            }
        }
        return try build(id: id, files: files)
    }

    /// 文件名不是 UTF-8 时 ZipArchive 按 Latin-1 解出来；中文皮肤一般是 GBK，转回来
    static func fixZipName(_ path: String) -> String {
        guard path.unicodeScalars.contains(where: { $0.value > 0x7F && $0.value <= 0xFF }),
              let raw = path.data(using: .isoLatin1) else { return path }
        let gb = CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue))
        return String(data: raw, encoding: String.Encoding(rawValue: gb)) ?? path
    }

    static func build(id: String, files raw: [String: Data]) throws -> TTSkin {
        // 皮肤可能整体放在一个子目录里：以 Skin.xml 所在目录为根
        var files: [String: Data] = [:]
        for (k, v) in raw { files[key(k)] = v }
        guard let skinKey = files.keys.filter({ $0 == "skin.xml" || $0.hasSuffix("/skin.xml") }).min(by: { $0.count < $1.count }),
              let skinData = files[skinKey] else { throw LoadError.missingSkinXML }
        let prefix = String(skinKey.dropLast("skin.xml".count))
        var rooted: [String: Data] = [:]
        for (k, v) in files where k.hasPrefix(prefix) { rooted[String(k.dropFirst(prefix.count))] = v }

        var doc: TTSkinDocument
        do { doc = try TTSkinParser.parseSkin(skinData) } catch { throw LoadError.invalid(String(localized: "Skin.xml 无法解析（只支持 version=\"2\" 的皮肤）")) }
        if doc.name.isEmpty { doc.name = id }
        if let d = rooted["lyric.xml"] { doc.lyricStyle = TTSkinParser.parseLyricStyle(d, base: doc.lyricStyle) }
        if let d = rooted["playlist.xml"] { doc.playlistStyle = TTSkinParser.parsePlaylistStyle(d, base: doc.playlistStyle) }
        if let d = rooted["visual.xml"] { doc.visualStyle = TTSkinParser.parseVisualStyle(d, base: doc.visualStyle) }

        let key = doc.transparentColor ?? TTColor(hex: "#FF00FF")!
        var images: [String: TTImage] = [:]
        for (name, data) in rooted where ["bmp", "png", "jpg", "jpeg", "gif"].contains((name as NSString).pathExtension) {
            if let image = decodeImage(data, transparent: key) { images[name] = TTImage(cgImage: image, scale: 1) }
        }
        guard doc.player.image.flatMap({ images[Self.key($0)] ?? images[String(Self.key($0).split(separator: "/").last ?? "")] }) != nil else {
            throw LoadError.invalid(String(localized: "皮肤缺少主窗口背景图"))
        }
        return TTSkin(id: id, document: doc, images: images)
    }

    /// 解码并把透明色（默认品红）抠成透明；本身带透明通道的 PNG 不处理
    static func decodeImage(_ data: Data, transparent: TTColor) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        // 皮肤图都很小；异常大的图不加载，免得占满内存
        guard image.width <= 4096, image.height <= 4096 else { return nil }
        let hasAlpha = ![.none, .noneSkipFirst, .noneSkipLast].contains(image.alphaInfo)
        let w = image.width, h = image.height
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return image }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        if !hasAlpha, let data = ctx.data {
            let p = data.bindMemory(to: UInt8.self, capacity: w * h * 4)
            let r = UInt8(transparent.r * 255), g = UInt8(transparent.g * 255), b = UInt8(transparent.b * 255)
            for i in 0..<(w * h) where p[i * 4] == r && p[i * 4 + 1] == g && p[i * 4 + 2] == b {
                p[i * 4] = 0; p[i * 4 + 1] = 0; p[i * 4 + 2] = 0; p[i * 4 + 3] = 0
            }
        }
        return ctx.makeImage()
    }

    // MARK: 背景（可拉伸窗口）

    private let backgroundCache = NSCache<NSString, CGImageBox>()

    /// 窗口背景拉伸到 size（皮肤像素）：可拉伸区以外原样，以内拉伸或平铺
    public func background(of window: TTWindow, size: CGSize) -> TTImage? {
        guard let image = image(window.image) else { return nil }
        let base = image.size
        guard let resize = window.resizeRect, size != base else { return image }
        let cacheKey = "\(window.image ?? "")-\(Int(size.width))x\(Int(size.height))" as NSString
        if let hit = backgroundCache.object(forKey: cacheKey) { return TTImage(cgImage: hit.image, scale: image.scale) }
        let s = image.scale
        let pw = Int((size.width * s).rounded()), ph = Int((size.height * s).rounded())
        guard pw > 0, ph > 0, let ctx = CGContext(data: nil, width: pw, height: ph, bitsPerComponent: 8, bytesPerRow: pw * 4,
                                                  space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return image }
        ctx.interpolationQuality = .none
        // CoreGraphics 原点在左下：翻转成左上
        ctx.translateBy(x: 0, y: CGFloat(ph))
        ctx.scaleBy(x: 1, y: -1)
        let xs = [0, resize.x, min(resize.maxX, base.width), base.width]
        let ys = [0, resize.y, min(resize.maxY, base.height), base.height]
        let dx = size.width - base.width, dy = size.height - base.height
        let txs = [0, resize.x, resize.maxX + dx, size.width]
        let tys = [0, resize.y, resize.maxY + dy, size.height]
        for i in 0..<3 {
            for j in 0..<3 {
                let src = CGRect(x: xs[i], y: ys[j], width: xs[i + 1] - xs[i], height: ys[j + 1] - ys[j])
                let dst = CGRect(x: txs[i] * s, y: tys[j] * s, width: (txs[i + 1] - txs[i]) * s, height: (tys[j + 1] - tys[j]) * s)
                guard src.width > 0, src.height > 0, dst.width > 0, dst.height > 0, let piece = image.crop(src) else { continue }
                drawFlipped(piece.cgImage, in: dst, ctx: ctx)
            }
        }
        guard let out = ctx.makeImage() else { return image }
        backgroundCache.setObject(CGImageBox(out), forKey: cacheKey)
        return TTImage(cgImage: out, scale: s)
    }

    private func drawFlipped(_ image: CGImage, in rect: CGRect, ctx: CGContext) {
        ctx.saveGState()
        ctx.translateBy(x: rect.minX, y: rect.maxY)
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(image, in: CGRect(origin: .zero, size: rect.size))
        ctx.restoreGState()
    }
}

final class CGImageBox {
    let image: CGImage
    init(_ image: CGImage) { self.image = image }
}
