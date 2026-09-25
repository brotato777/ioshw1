import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// 美術素材的命名約定。
///
/// 素材還沒放進 Assets.xcassets 時，每個位置都會自動退回程式繪製／emoji 的版本，
/// 所以可以一個一個補，補到哪裡畫面就換到哪裡。
@MainActor
enum GameArt {

    /// 查過的名字就記下來，落下物每幀都會問，不要每次都去翻 bundle。
    private static var cache: [String: Image?] = [:]

    static func image(_ name: String) -> Image? {
        if let cached = cache[name] { return cached }
        let resolved = exists(name) ? Image(name) : nil
        cache[name] = resolved
        return resolved
    }

    /// 依序試幾個名字，回傳第一個存在的。
    /// 用來讓「每個表情一張」和「整個角色只有一張」兩種素材都能運作。
    static func firstImage(_ names: String...) -> Image? {
        for name in names {
            if let image = image(name) { return image }
        }
        return nil
    }

    private static func exists(_ name: String) -> Bool {
        #if canImport(UIKit)
        UIImage(named: name) != nil
        #elseif canImport(AppKit)
        NSImage(named: name) != nil
        #else
        false
        #endif
    }

    // MARK: - 各部位的名稱

    /// 背景紙紋。
    static var background: Image? { image("bg-paper") }

    /// 拳型圖示，例如 hand-rock、hand-lizard。
    static func hand(_ shapeID: String) -> Image? {
        image("hand-\(shapeID)")
    }

    /// 生命愛心。
    static func heart(filled: Bool) -> Image? {
        image(filled ? "heart-full" : "heart-empty")
    }

    /// 玩家頭像，例如 player-happy。缺某個表情時退回 player-neutral，
    /// 免得同一顆頭在素材與程式繪製之間跳來跳去。
    static func player(_ expression: FaceExpression) -> Image? {
        firstImage("player-\(expression.assetSuffix)", "player", "player-neutral")
    }

    /// 對手頭像，例如 opponent-hard-taunt。
    static func opponent(_ difficulty: Difficulty, _ expression: FaceExpression) -> Image? {
        firstImage(
            "opponent-\(difficulty.rawValue)-\(expression.assetSuffix)",
            "opponent-\(difficulty.rawValue)",
            "opponent-\(difficulty.rawValue)-neutral"
        )
    }
}

extension FaceExpression {
    var assetSuffix: String {
        switch self {
        case .neutral: "neutral"
        case .happy: "happy"
        case .hurt: "hurt"
        case .taunt: "taunt"
        }
    }
}

// MARK: - 素材優先的元件

/// 玩家的頭。
struct PlayerHeadView: View {
    let expression: FaceExpression
    let size: CGFloat

    var body: some View {
        if let artwork = GameArt.player(expression) {
            artwork
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .animation(.spring(duration: 0.25), value: expression)
        } else {
            FaceView(style: .player, expression: expression, size: size)
        }
    }
}

/// 對手的頭。不同難度的人長得不一樣。
struct OpponentHeadView: View {
    let difficulty: Difficulty
    let expression: FaceExpression
    let size: CGFloat

    var body: some View {
        if let artwork = GameArt.opponent(difficulty, expression) {
            artwork
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .animation(.spring(duration: 0.25), value: expression)
        } else {
            FaceView(style: .opponent(for: difficulty), expression: expression, size: size)
        }
    }
}

/// 一個拳型的圖示。
struct HandSymbolView: View {
    let shape: HandShape
    let size: CGFloat

    var body: some View {
        if let artwork = GameArt.hand(shape.id) {
            artwork
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            Text(shape.symbol)
                .font(.system(size: size * 0.82))
        }
    }
}

/// 一顆生命愛心。
struct LifeHeartView: View {
    let isFilled: Bool
    let size: CGFloat

    var body: some View {
        if let artwork = GameArt.heart(filled: isFilled) {
            artwork
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else if let full = GameArt.heart(filled: true) {
            // 只有滿血的素材時，空的那格就用同一顆去色淡化。
            full
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .grayscale(1)
                .opacity(0.3)
        } else {
            Image(systemName: isFilled ? "heart.fill" : "heart")
                .font(.system(size: size * 0.8))
                .foregroundStyle(.red)
        }
    }
}

/// 全畫面背景。素材是再生紙纖維紋理，沒有就退回漸層。
struct GameBackground: View {
    let accent: Color

    var body: some View {
        // 先鋪一層有彈性的 Rectangle 再把圖疊上去並裁掉，
        // 免得 scaledToFill 的溢出尺寸反過來把整個版面撐寬。
        Rectangle()
            .fill(.clear)
            .overlay {
                if let artwork = GameArt.background {
                    artwork
                        .resizable()
                        .scaledToFill()
                } else {
                    LinearGradient(
                        colors: [accent.opacity(0.28), Color(white: 0.96)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }
            .overlay(accent.opacity(0.08))
            .clipped()
            .ignoresSafeArea()
    }
}
