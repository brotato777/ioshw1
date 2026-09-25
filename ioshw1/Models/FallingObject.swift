import SwiftUI

/// 一顆從上方落下的拳型物件。
struct FallingObject: Identifiable, Sendable {
    let id = UUID()
    /// 目前顯示的拳型；亂流生效時會在中線被改寫。
    var shapeID: String
    /// 中心點座標（點），原點在場地左上角。
    var position: CGPoint
    /// 這顆的基礎掉落速度（點 / 秒）。
    var speed: CGFloat
    /// 塗在這顆上面的道具，沒有就是 nil。
    var powerUp: PowerUp?
    /// 亂流只在越過中線的那一刻觸發一次。
    var didCrossMidline = false
    /// 已經結算過（接到或飛出畫面）就不再判定。
    var isResolved = false

    static let diameter: CGFloat = 64
    var radius: CGFloat { Self.diameter / 2 }
}

/// 結算後閃在畫面上的一行戰報字幕。
struct BattleLogEntry: Identifiable, Sendable {
    let id = UUID()
    let text: String
    let isGood: Bool
}
