import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import TTSkin

struct TTSkinTests {
    static let sampleXML = """
    <?xml version="1.0" encoding="GB2312"?>
    <skin version="2" name="测试皮肤" author="某人" transparent_color="#ff00ff">
    <player_window image="Player.bmp">
        <play      position=" 24, 90, 43,109" image="1 button.bmp"/>
        <play      position=" 30, 90, 49,109" image="1 button.bmp"/>
        <info      position="  4, 26,107, 41" align="right" bkgnd="#e6c8ff" color="#1464e6" font_size="16"/>
        <volume    position=" 90, 90,131,109" bar_image="2 passive.bmp" fill_image="2 full.bmp" thumb_image="thumb.bmp" vertical="false"/>
        <broken    position=",,,"/>
    </player_window>
    <lyric_window position="0,112,177,223" resize_rect="21,43,156,87" image="lyrics.bmp">
        <close    position="156,  2,175, 21" image="1 button.bmp"/>
        <lyric    position="  2, 24,175,109"/>
    </lyric_window>
    <equalizer_window image="eq.bmp" eq_interval="5">
        <eqfactor position="60, 40, 69, 100" vertical="true"/>
    </equalizer_window>
    </skin>
    """

    @Test func parsesGBKSkinXML() throws {
        let gbk = CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue))
        let data = try #require(Self.sampleXML.data(using: String.Encoding(rawValue: gbk)))
        let doc = try TTSkinParser.parseSkin(data)
        #expect(doc.name == "测试皮肤")
        #expect(doc.author == "某人")
        #expect(doc.transparentColor == TTColor(hex: "#ff00ff"))
        #expect(doc.player.image == "Player.bmp")
        // 同名节点：后面的覆盖前面的
        #expect(doc.player["play"]?.rect == TTRect(x: 30, y: 90, width: 20, height: 20))
        let info = try #require(doc.player["info"])
        #expect(info.align == .right)
        #expect(info.color == TTColor(hex: "#1464e6"))
        #expect(info.fontSize == 16)
        #expect(doc.player["volume"]?.thumbImage == "thumb.bmp")
        #expect(doc.player["broken"] == nil)
        #expect(doc.lyric.resizeRect == TTRect(x: 21, y: 43, width: 136, height: 45))
        // 频段按 宽 + 间距 平移
        #expect(doc.equalizerBand(0)?.rect.x == 60)
        #expect(doc.equalizer.bandInterval == 5)
        #expect(doc.equalizerBand(3)?.rect.x == CGFloat(102), "\(String(describing: doc.equalizerBand(3)))")
    }

    @Test func rejectsOldVersion() {
        #expect(throws: TTSkinParser.ParseError.unsupportedVersion) {
            try TTSkinParser.parseSkin(Data(#"<skin version="1"><player_window/></skin>"#.utf8))
        }
    }

    @Test func parsesColorFiles() {
        let lyric = TTSkinParser.parseLyricStyle(Data("""
        <?xml version="1.0" encoding="UTF-8"?>
        <ttplayer_lyric><Lyric Font="-15,0,0,0,400,0,0,0,0,3,2,4,34,宋体" TextColor="#ffff80" HilightColor="#1464e6" BkgndColor="#000000"/></ttplayer_lyric>
        """.utf8), base: TTSkinDocument.defaultLyricStyle)
        #expect(lyric.text == TTColor(hex: "#ffff80"))
        #expect(lyric.highlight == TTColor(hex: "#1464e6"))
        #expect(lyric.fontSize == 15)
        let list = TTSkinParser.parsePlaylistStyle(Data(##"<ttplayer_playlist><PlayList Color_Text="#112233" Color_Hilight="#445566" Color_Bkgnd2="#000001"/></ttplayer_playlist>"##.utf8),
                                                  base: TTSkinDocument.defaultPlaylistStyle)
        #expect(list.text == TTColor(hex: "#112233"))
        #expect(list.current == TTColor(hex: "#445566"))
        #expect(list.background2 == TTColor(hex: "#000001"))
        #expect(list.background == TTSkinDocument.defaultPlaylistStyle.background)
    }

    @Test func resizableLayoutAnchorsElements() {
        var w = TTWindow()
        w.resizeRect = TTRect(x: 20, y: 20, width: 60, height: 60)
        let base = CGSize(width: 100, height: 100), size = CGSize(width: 150, height: 130)
        // 右上角的关闭按钮跟着右边走
        #expect(w.layout(TTRect(x: 85, y: 2, width: 12, height: 12), base: base, size: size) == TTRect(x: 135, y: 2, width: 12, height: 12))
        // 横跨可拉伸区的内容区跟着变大
        #expect(w.layout(TTRect(x: 2, y: 16, width: 96, height: 80), base: base, size: size) == TTRect(x: 2, y: 16, width: 146, height: 110))
        // 左上的标题不动
        #expect(w.layout(TTRect(x: 2, y: 2, width: 10, height: 10), base: base, size: size) == TTRect(x: 2, y: 2, width: 10, height: 10))
    }

    /// 生成一张 BMP：左上角一个品红像素
    static func bmp(width: Int, height: Int) -> Data {
        let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        ctx.setFillColor(CGColor(srgbRed: 0.2, green: 0.4, blue: 0.6, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        ctx.setFillColor(CGColor(srgbRed: 1, green: 0, blue: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: height - 1, width: 1, height: 1))
        let out = NSMutableData()
        let dest = CGImageDestinationCreateWithData(out, "com.microsoft.bmp" as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
        CGImageDestinationFinalize(dest)
        return out as Data
    }

    @Test func loadsPackageFromSubfolderAndKeysTransparentColor() throws {
        let xml = Data(#"<skin version="2" name="Pack"><player_window image="main.bmp"><play position="0,0,9,9" image="Btn.BMP"/></player_window></skin>"#.utf8)
        let skin = try TTSkin.build(id: "x", files: [
            "Pack/Skin.xml": xml,
            "Pack/main.bmp": Self.bmp(width: 40, height: 20),
            "Pack/btn.bmp": Self.bmp(width: 40, height: 10),
            "Pack/Lyric.xml": Data(##"<ttplayer_lyric><Lyric TextColor="#010203"/></ttplayer_lyric>"##.utf8),
        ])
        #expect(skin.name == "Pack")
        #expect(skin.document.lyricStyle.text == TTColor(hex: "#010203"))
        let main = try #require(skin.image("main.bmp"))
        #expect(main.size == CGSize(width: 40, height: 20))
        // 文件名大小写不同也能找到；按钮四帧
        let button = try #require(skin.image("Btn.BMP"))
        #expect(button.frame(2, of: 4).size == CGSize(width: 10, height: 10))
        // 品红变透明
        let ctx = CGContext(data: nil, width: 40, height: 20, bitsPerComponent: 8, bytesPerRow: 160,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(main.cgImage, in: CGRect(x: 0, y: 0, width: 40, height: 20))
        let p = ctx.data!.bindMemory(to: UInt8.self, capacity: 40 * 20 * 4)
        #expect(p[3] == 0, "左上角品红应透明")
        #expect(p[4 * 5 + 3] == 255)
    }

    @Test func missingSkinXMLFails() {
        #expect(throws: TTSkin.LoadError.missingSkinXML) { try TTSkin.build(id: "x", files: ["a.bmp": Data()]) }
    }

    @Test func builtInSkinsHaveEveryImage() throws {
        for theme in TTTheme.all {
            let skin = TTSkin.builtIn(theme)
            for name in BuiltInLayout.imageNames {
                #expect(skin.image(name) != nil, "\(theme.name) 缺 \(name)")
            }
            let doc = skin.document
            #expect(skin.image(doc.player.image)?.size == BuiltInLayout.mainSize)
            // 按钮图是四帧，每帧和元素一样大
            for name in ["play", "prev", "minimode", "lyric", "mode_loop"] {
                let e = try #require(doc.player[name])
                let frame = try #require(skin.image(e.image)).frame(0, of: 4)
                #expect(abs(frame.size.width - e.rect.width) < 0.01 && abs(frame.size.height - e.rect.height) < 0.01, "\(name) \(frame.size) vs \(e.rect)")
            }
            // 第 10 个频段还在窗口里
            let last = try #require(doc.equalizerBand(9))
            #expect(last.rect.maxX <= BuiltInLayout.eqSize.width - 8)
            // 拉伸后的背景尺寸正确
            let bg = try #require(skin.background(of: doc.playlist, size: CGSize(width: 330, height: 400)))
            #expect(bg.size == CGSize(width: 330, height: 400))
        }
    }

    /// 本地放了真实 .skn（Fixtures/local，不入库）时逐个加载
    @Test func loadsLocalSkins() throws {
        let dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/local")
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil))?.filter { $0.pathExtension.lowercased() == "skn" } ?? []
        for url in files {
            let skin = try TTSkin.load(sknData: Data(contentsOf: url), id: url.lastPathComponent)
            #expect(skin.image(skin.document.player.image) != nil, "\(url.lastPathComponent) 主窗口背景")
            for (name, e) in skin.document.player.elements where e.image != nil {
                #expect(skin.image(e.image) != nil, "\(url.lastPathComponent) 缺 \(name) 的图 \(e.image ?? "")")
            }
        }
    }

    @Test func fixesGBKZipNames() {
        let gbk = CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue))
        let raw = "播放.bmp".data(using: String.Encoding(rawValue: gbk))!
        let latin = String(data: raw, encoding: .isoLatin1)!
        #expect(TTSkin.fixZipName(latin) == "播放.bmp")
        #expect(TTSkin.fixZipName("play.bmp") == "play.bmp")
    }
}
