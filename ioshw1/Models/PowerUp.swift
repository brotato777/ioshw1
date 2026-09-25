import SwiftUI

/// 道具。不是獨立物件，而是「塗」在落下拳型物件上的一層顏色／光暈。
/// 道具永不直接扣血，扣血只由拳型關係決定。
enum PowerUp: String, CaseIterable, Identifiable, Sendable {
    case turbulence
    case reversed
    case greed
    case wisdom
    case blackout

    var id: String { rawValue }

    var name: String {
        switch self {
        case .turbulence: "亂流"
        case .reversed: "勝負相反"
        case .greed: "貪婪"
        case .wisdom: "智慧"
        case .blackout: "天黑請閉眼"
        }
    }

    var detail: String {
        switch self {
        case .turbulence: "落下物過中線就換一種拳"
        case .reversed: "該接／該閃全部對調"
        case .greed: "得分 ×2，但落得更快"
        case .wisdom: "直接顯示該接或該躲"
        case .blackout: "下半個畫面黑掉，憑記憶接下去"
        }
    }

    /// 物件上覆的專屬顏色／光暈。
    var tint: Color {
        switch self {
        case .turbulence: .cyan
        case .reversed: .purple
        case .greed: .yellow
        case .wisdom: .mint
        case .blackout: .black
        }
    }

    /// 效果持續時間（秒）。天黑只有短短一下。
    var duration: Double {
        switch self {
        case .turbulence: 7
        case .reversed: 6
        case .greed: 8
        case .wisdom: 6
        case .blackout: 3
        }
    }

    /// 貪婪的得分倍率。
    var scoreMultiplier: Int { self == .greed ? 2 : 1 }

    /// 貪婪額外加快的掉落速度倍率。
    var fallSpeedMultiplier: CGFloat { self == .greed ? 1.35 : 1 }
}

/// 目前生效中的道具。同一時間只保留一個，吃到新的會覆蓋舊的。
struct ActivePowerUp: Sendable {
    let kind: PowerUp
    var remaining: Double

    init(_ kind: PowerUp) {
        self.kind = kind
        self.remaining = kind.duration
    }

    var progress: Double { remaining / kind.duration }
}
