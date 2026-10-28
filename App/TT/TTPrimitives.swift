import AmplayerKit
import SwiftUI

extension Color {
    /// JTplayer 的强调色：和默认皮肤一致的蓝
    static let jtAccent = Color(red: 0.24, green: 0.56, blue: 0.98)
}
import UIKit

// 皮肤坐标系：位置都用皮肤像素表示，乘以 ttScale 得到屏幕点。

private struct TTScaleKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1
}

private struct TTSkinKey: EnvironmentKey {
    static let defaultValue: TTSkin = TTSkinStore.fallback
}

extension EnvironmentValues {
    var ttScale: CGFloat {
        get { self[TTScaleKey.self] }
        set { self[TTScaleKey.self] = newValue }
    }

    var ttSkin: TTSkin {
        get { self[TTSkinKey.self] }
        set { self[TTSkinKey.self] = newValue }
    }
}

extension TTColor {
    var color: Color { Color(.sRGB, red: r, green: g, blue: b, opacity: a) }
}

extension View {
    /// 放到皮肤矩形里（ZStack 左上对齐时用）
    func place(_ rect: TTRect, _ scale: CGFloat) -> some View {
        frame(width: rect.width * scale, height: rect.height * scale, alignment: .topLeading)
            .offset(x: rect.x * scale, y: rect.y * scale)
    }

    /// 点击区域比实际图形大一圈，小按钮也好点
    func hitSlop(_ points: CGFloat) -> some View {
        padding(points).contentShape(Rectangle()).padding(-points)
    }
}

/// 皮肤里的一张图，按皮肤像素尺寸放大
struct TTImageView: View {
    @Environment(\.ttScale) private var scale
    let image: TTImage

    var body: some View {
        let size = image.size
        Image(decorative: image.cgImage, scale: 1)
            .resizable()
            // 内置皮肤按 3 倍绘制，缩小时用平滑；.skn 的 BMP 放大不到 2 倍时最近邻会粗细不均，也用平滑
            .interpolation(image.scale > 1 || scale < 2 ? .medium : .none)
            .frame(width: size.width * scale, height: size.height * scale)
    }
}

enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func tick() { UISelectionFeedbackGenerator().selectionChanged() }
}

/// 四帧按钮：普通 / 悬停 / 按下(选中) / 禁用
struct TTButton: View {
    @Environment(\.ttSkin) private var skin
    @Environment(\.ttScale) private var scale
    let element: TTElement?
    var selected = false
    var disabled = false
    let label: String
    let action: () -> Void

    var body: some View {
        if let element {
            Button {
                Haptics.tap()
                action()
            } label: { EmptyView() }
                .buttonStyle(TTButtonStyle(image: skin.image(element.image), size: element.rect.size, selected: selected, disabled: disabled, scale: scale))
                .disabled(disabled)
                .accessibilityLabel(label)
                .accessibilityAddTraits(selected ? .isSelected : [])
                .place(element.rect, scale)
        }
    }
}

struct TTButtonStyle: ButtonStyle {
    let image: TTImage?
    let size: CGSize
    let selected: Bool
    let disabled: Bool
    let scale: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        let frame = disabled ? 3 : (configuration.isPressed || selected ? 2 : 0)
        ZStack(alignment: .topLeading) {
            Color.clear
            if let image { TTImageView(image: image.frame(frame, of: 4)) }
        }
        .frame(width: size.width * scale, height: size.height * scale, alignment: .topLeading)
        .hitSlop(5)
    }
}

/// 滑块：底图、已填充部分、滑块（四帧）。横向时填充到滑块中心；竖向时从滑块中心填到底
struct TTSlider: View {
    @Environment(\.ttSkin) private var skin
    @Environment(\.ttScale) private var scale
    let element: TTElement
    /// 0...1
    let value: Double
    var showThumb = true
    /// 中间（0.5）附近吸附
    var snapToCenter = false
    let label: String
    var valueText: String = ""
    let onChange: (Double, _ ended: Bool) -> Void

    @State private var dragging: Double?

    var body: some View {
        let r = element.rect
        let v = min(max(dragging ?? value, 0), 1)
        let bar = skin.image(element.barImage)
        let fill = skin.image(element.fillImage)
        let thumbImage = showThumb ? skin.image(element.thumbImage) : nil
        let thumbSize = thumbImage.map { $0.frame(0, of: 4).size } ?? .zero
        let vertical = element.vertical
        let travel = vertical ? r.height - thumbSize.height : r.width - thumbSize.width
        let thumbPos = vertical ? travel * (1 - v) : travel * v
        ZStack(alignment: .topLeading) {
            Color.clear
            if let bar {
                TTImageView(image: bar)
                    .offset(x: (r.width - bar.size.width) / 2 * scale, y: (r.height - bar.size.height) / 2 * scale)
            }
            if let fill {
                let fx = (r.width - fill.size.width) / 2, fy = (r.height - fill.size.height) / 2
                if vertical {
                    let edge = thumbImage == nil ? r.height * (1 - v) : thumbPos + thumbSize.height / 2
                    let sy = min(max(edge - fy, 0), fill.size.height)
                    TTImageView(image: fill)
                        .mask(alignment: .bottom) { Rectangle().frame(height: (fill.size.height - sy) * scale) }
                        .offset(x: fx * scale, y: fy * scale)
                } else {
                    let edge = thumbImage == nil ? r.width * v : thumbPos + thumbSize.width / 2
                    let w = min(max(edge - fx, 0), fill.size.width)
                    TTImageView(image: fill)
                        .mask(alignment: .leading) { Rectangle().frame(width: w * scale) }
                        .offset(x: fx * scale, y: fy * scale)
                }
            }
            if let thumbImage {
                TTImageView(image: thumbImage.frame(dragging != nil ? 2 : 0, of: 4))
                    .offset(x: (vertical ? (r.width - thumbSize.width) / 2 : thumbPos) * scale,
                            y: (vertical ? thumbPos : (r.height - thumbSize.height) / 2) * scale)
            }
        }
        .frame(width: r.width * scale, height: r.height * scale, alignment: .topLeading)
        .padding(vertical ? EdgeInsets(top: 4, leading: 6, bottom: 4, trailing: 6) : EdgeInsets(top: 8, leading: 4, bottom: 8, trailing: 4))
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { g in
                    let raw = vertical
                        ? 1 - ((g.location.y - 4) / scale - thumbSize.height / 2) / max(travel, 1)
                        : ((g.location.x - 4) / scale - thumbSize.width / 2) / max(travel, 1)
                    var nv = min(max(raw, 0), 1)
                    if snapToCenter, abs(nv - 0.5) < 0.04 { nv = 0.5 }
                    if snapToCenter, let old = dragging, (old - 0.5).sign != (nv - 0.5).sign || (nv == 0.5 && old != 0.5) { Haptics.tick() }
                    dragging = nv
                    onChange(nv, false)
                }
                .onEnded { _ in
                    if let d = dragging { onChange(d, true) }
                    dragging = nil
                }
        )
        .padding(vertical ? EdgeInsets(top: -4, leading: -6, bottom: -4, trailing: -6) : EdgeInsets(top: -8, leading: -4, bottom: -8, trailing: -4))
        .offset(x: r.x * scale, y: r.y * scale)
        .accessibilityElement()
        .accessibilityLabel(label)
        .accessibilityValue(valueText)
        .accessibilityAdjustableAction { direction in
            let step = 0.05
            let nv = min(max(value + (direction == .increment ? step : -step), 0), 1)
            onChange(nv, true)
        }
    }
}

/// 文字区（歌曲信息、声道、状态），可选滚动
struct TTTextView: View {
    @Environment(\.ttScale) private var scale
    let element: TTElement
    let text: String
    var scroll = false
    /// 只有在播放时才滚动（停着时一直重画很耗电）
    var active = true
    let fallbackColor: TTColor

    var body: some View {
        let r = element.rect
        // font_size 是 LOGFONT 的 lfHeight（字符格高度，像素），字号约为它的 0.85
        let px = (element.fontSize ?? 12) * 0.85
        let font = UIFont.systemFont(ofSize: px * scale)
        let width = (text as NSString).size(withAttributes: [.font: font]).width
        let needsScroll = scroll && width > r.width * scale
        ZStack(alignment: needsScroll ? .leading : alignment) {
            if let bg = element.background { bg.color }
            if needsScroll {
                Marquee(text: text, textWidth: width, font: font, active: active)
                    .frame(width: r.width * scale, alignment: .leading)
            } else {
                Text(text).font(Font(font)).lineLimit(1).minimumScaleFactor(0.7)
            }
        }
        .foregroundStyle((element.color ?? fallbackColor).color)
        .frame(width: r.width * scale, height: r.height * scale, alignment: alignment)
        .clipped()
        .offset(x: r.x * scale, y: r.y * scale)
        .allowsHitTesting(false)
    }

    private var alignment: Alignment {
        switch element.align {
        case .left: .leading
        case .center: .center
        case .right: .trailing
        }
    }
}

private struct Marquee: View {
    let text: String
    let textWidth: CGFloat
    let font: UIFont
    let active: Bool

    var body: some View {
        let gap = font.pointSize * 3
        let cycle = textWidth + gap
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: !active)) { context in
            let speed = font.pointSize * 2.2
            // 不滚动时从头显示，不要停在半截
            let offset = active ? (context.date.timeIntervalSinceReferenceDate * speed).truncatingRemainder(dividingBy: cycle) : 0
            HStack(spacing: gap) {
                Text(text).fixedSize()
                Text(text).fixedSize()
            }
            .font(Font(font))
            .fixedSize()
            .offset(x: -offset)
        }
    }
}

/// LED 时间：led 图片横向 12 格（0-9、冒号、减号）
struct TTLEDView: View {
    @Environment(\.ttSkin) private var skin
    @Environment(\.ttScale) private var scale
    let element: TTElement
    let text: String
    let fallbackColor: TTColor
    var opacity: Double = 1
    var onTap: (() -> Void)?

    var body: some View {
        let r = element.rect
        Group {
            if let image = skin.image(element.image), image.cgImage.width >= 12 {
                HStack(spacing: 0) {
                    ForEach(Array(text.enumerated()), id: \.offset) { _, ch in
                        let index: Int? = ch == ":" ? 10 : ch == "-" ? 11 : ch.wholeNumberValue
                        if let index { TTImageView(image: image.frame(index, of: 12)) }
                    }
                }
            } else {
                Text(text).font(.system(size: r.height * 0.8 * scale, weight: .medium, design: .rounded).monospacedDigit())
                    .foregroundStyle((element.color ?? fallbackColor).color)
            }
        }
        .opacity(opacity)
        .frame(width: r.width * scale, height: r.height * scale, alignment: element.align == .left ? .topLeading : .topTrailing)
        // 点按区域必须在 offset 之前设置，否则会留在窗口左上角
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
        .offset(x: r.x * scale, y: r.y * scale)
    }
}

/// 可拉伸窗口（歌词、播放列表）的背景
struct TTWindowBackground: View {
    @Environment(\.ttSkin) private var skin
    let window: TTWindow
    let size: CGSize

    var body: some View {
        if let bg = skin.background(of: window, size: size) {
            TTImageView(image: bg)
        }
    }
}
