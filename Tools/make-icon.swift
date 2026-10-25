// 生成 App 图标（1024×1024，原创）：深蓝底、发光的圆形按钮、白色音符、底部一排频谱
// 用法：swift Tools/make-icon.swift App/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon-1024.png"
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4, space: space,
                    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
// 左上原点
ctx.translateBy(x: 0, y: CGFloat(size))
ctx.scaleBy(x: 1, y: -1)

func color(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

func linear(_ colors: [CGColor], from a: CGPoint, to b: CGPoint) {
    let g = CGGradient(colorsSpace: space, colors: colors as CFArray, locations: nil)!
    ctx.drawLinearGradient(g, start: a, end: b, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
}

let S = CGFloat(size)
// 背景：深蓝渐变（系统会自己切圆角）
linear([color(0x0E2A52), color(0x061227)], from: CGPoint(x: 0, y: 0), to: CGPoint(x: 0, y: S))

// 频谱：底部一排柱子
let bars: [CGFloat] = [0.30, 0.52, 0.72, 0.58, 0.86, 0.66, 0.44, 0.62, 0.80, 0.54, 0.38, 0.26]
let barW: CGFloat = 46, gap: CGFloat = 20
let totalW = CGFloat(bars.count) * barW + CGFloat(bars.count - 1) * gap
let baseY: CGFloat = S - 120
for (i, h) in bars.enumerated() {
    let x = (S - totalW) / 2 + CGFloat(i) * (barW + gap)
    let height = h * 210
    let rect = CGRect(x: x, y: baseY - height, width: barW, height: height)
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: 8, cornerHeight: 8, transform: nil))
    ctx.clip()
    linear([color(0x9FE3FF, 0.55), color(0x1464E6, 0.35)], from: CGPoint(x: 0, y: baseY - 210), to: CGPoint(x: 0, y: baseY))
    ctx.restoreGState()
}

// 圆形按钮：外圈光晕 + 金属边 + 蓝色玻璃面
let center = CGPoint(x: S / 2, y: S * 0.43)
let r: CGFloat = 300
ctx.saveGState()
ctx.setShadow(offset: .zero, blur: 90, color: color(0x3FA9FF, 0.75))
ctx.setFillColor(color(0x3FA9FF))
ctx.fillEllipse(in: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
ctx.restoreGState()
// 金属边
ctx.saveGState()
ctx.addEllipse(in: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
ctx.clip()
linear([color(0xF4F8FD), color(0x8EA3BF)], from: CGPoint(x: 0, y: center.y - r), to: CGPoint(x: 0, y: center.y + r))
ctx.restoreGState()
// 玻璃面
let ri = r - 26
ctx.saveGState()
ctx.addEllipse(in: CGRect(x: center.x - ri, y: center.y - ri, width: ri * 2, height: ri * 2))
ctx.clip()
linear([color(0x5CC4FF), color(0x1464E6), color(0x0B3A8F)], from: CGPoint(x: 0, y: center.y - ri), to: CGPoint(x: 0, y: center.y + ri))
// 上半部分高光
ctx.setFillColor(color(0xFFFFFF, 0.22))
ctx.fillEllipse(in: CGRect(x: center.x - ri * 0.78, y: center.y - ri * 0.96, width: ri * 1.56, height: ri * 0.95))
ctx.restoreGState()

// 白色八分音符
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: 10), blur: 24, color: color(0x02122E, 0.45))
ctx.setFillColor(color(0xFFFFFF))
// 符头（斜椭圆）
ctx.saveGState()
ctx.translateBy(x: center.x - 52, y: center.y + 120)
ctx.rotate(by: -0.42)
ctx.fillEllipse(in: CGRect(x: -86, y: -58, width: 172, height: 116))
ctx.restoreGState()
// 符干
ctx.fill(CGRect(x: center.x + 6, y: center.y - 190, width: 34, height: 320))
// 符尾
let flag = CGMutablePath()
flag.move(to: CGPoint(x: center.x + 6, y: center.y - 190))
flag.addCurve(to: CGPoint(x: center.x + 150, y: center.y - 20),
              control1: CGPoint(x: center.x + 70, y: center.y - 150), control2: CGPoint(x: center.x + 190, y: center.y - 110))
flag.addCurve(to: CGPoint(x: center.x + 40, y: center.y - 110),
              control1: CGPoint(x: center.x + 140, y: center.y - 70), control2: CGPoint(x: center.x + 90, y: center.y - 100))
flag.closeSubpath()
ctx.addPath(flag)
ctx.fillPath()
ctx.restoreGState()

let image = ctx.makeImage()!
let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: out) as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, image, nil)
CGImageDestinationFinalize(dest)
print("已生成 \(out)")
