import AmplayerKit

/// 千千静听的五种播放模式（顺序与皮肤里的 mode_* 一致）
enum PlayMode: Int, CaseIterable, Identifiable {
    case single, repeatOne, sequential, loop, random

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .single: "单曲播放"
        case .repeatOne: "单曲循环"
        case .sequential: "顺序播放"
        case .loop: "循环播放"
        case .random: "随机播放"
        }
    }

    var symbol: String {
        switch self {
        case .single: "1.circle"
        case .repeatOne: "repeat.1"
        case .sequential: "arrow.right"
        case .loop: "repeat"
        case .random: "shuffle"
        }
    }

    /// 皮肤里对应的元素名
    var elementName: String {
        ["mode_single", "mode_loop", "mode_slider", "mode_circle", "mode_random"][rawValue]
    }

    var next: PlayMode { PlayMode(rawValue: (rawValue + 1) % 5)! }
}

extension PlayerController {
    var playMode: PlayMode {
        get {
            if shuffle { return .random }
            return switch repeatMode {
            case .single: .single
            case .one: .repeatOne
            case .off: .sequential
            case .all: .loop
            }
        }
        set {
            shuffle = newValue == .random
            repeatMode = switch newValue {
            case .single: .single
            case .repeatOne: .one
            case .sequential: .off
            case .loop, .random: .all
            }
        }
    }
}
