import SwiftUI

/// 一顆頭的外觀。不同難度的對手長得不一樣。
struct FaceStyle: Sendable {
    enum Accessory: Sendable {
        case none
        case cap
        case headband
        case crown
    }

    let skin: Color
    let hair: Color
    let accessory: Accessory
    let name: String

    static let player = FaceStyle(skin: .init(red: 1, green: 0.84, blue: 0.7), hair: .brown, accessory: .none, name: "你")

    static func opponent(for difficulty: Difficulty) -> FaceStyle {
        switch difficulty {
        case .easy:
            FaceStyle(skin: .init(red: 1, green: 0.86, blue: 0.76), hair: .orange, accessory: .cap, name: "猜拳菜鳥")
        case .normal:
            FaceStyle(skin: .init(red: 0.98, green: 0.8, blue: 0.62), hair: .black, accessory: .headband, name: "猜拳老手")
        case .hard:
            FaceStyle(skin: .init(red: 0.82, green: 0.72, blue: 0.95), hair: .purple, accessory: .crown, name: "猜拳之王")
        case .hell:
            FaceStyle(skin: .init(red: 0.95, green: 0.45, blue: 0.38), hair: .init(red: 0.35, green: 0.1, blue: 0.3), accessory: .crown, name: "猜拳惡魔")
        }
    }
}

/// 一顆會做表情的頭。
struct FaceView: View {
    let style: FaceStyle
    let expression: FaceExpression
    let size: CGFloat

    private var mouthCurve: CGFloat {
        switch expression {
        case .neutral: 0.15
        case .happy: 0.9
        case .hurt: -0.8
        case .taunt: 0.55
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(style.skin)
                .overlay(Circle().strokeBorder(.black.opacity(0.18), lineWidth: size * 0.02))

            hair

            VStack(spacing: size * 0.1) {
                HStack(spacing: size * 0.24) {
                    EyeView(expression: expression, size: size * 0.16)
                    EyeView(expression: expression, size: size * 0.16)
                }

                MouthShape(curve: mouthCurve)
                    .stroke(.black.opacity(0.75), style: StrokeStyle(lineWidth: size * 0.04, lineCap: .round))
                    .frame(width: size * 0.34, height: size * 0.16)
            }
            .offset(y: size * 0.1)

            accessory
        }
        .frame(width: size, height: size)
        .animation(.spring(duration: 0.25), value: expression)
    }

    /// 只蓋住頭頂，別壓到眼睛。
    private var hair: some View {
        Circle()
            .trim(from: 0.5, to: 1)
            .fill(style.hair)
            .frame(width: size, height: size)
            .offset(y: -size * 0.26)
            .mask(Circle().frame(width: size, height: size))
    }

    @ViewBuilder
    private var accessory: some View {
        switch style.accessory {
        case .none:
            EmptyView()
        case .cap:
            Capsule()
                .fill(.red)
                .frame(width: size * 0.9, height: size * 0.16)
                .offset(y: -size * 0.34)
        case .headband:
            Capsule()
                .fill(.blue)
                .frame(width: size * 0.94, height: size * 0.12)
                .offset(y: -size * 0.26)
        case .crown:
            CrownShape()
                .fill(.yellow)
                .frame(width: size * 0.56, height: size * 0.28)
                .offset(y: -size * 0.52)
        }
    }
}

/// 嘴巴：curve 為正是微笑，為負是難過。
private struct MouthShape: Shape {
    var curve: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.midY),
            control: CGPoint(x: rect.midX, y: rect.midY + curve * rect.height)
        )
        return path
    }
}

private struct CrownShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.width * 0.25, y: rect.height * 0.45))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.width * 0.75, y: rect.height * 0.45))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct EyeView: View {
    let expression: FaceExpression
    let size: CGFloat

    var body: some View {
        switch expression {
        case .neutral:
            Circle()
                .fill(.black.opacity(0.8))
                .frame(width: size * 0.6, height: size * 0.75)
        case .happy:
            ArcShape()
                .stroke(.black.opacity(0.8), style: StrokeStyle(lineWidth: size * 0.16, lineCap: .round))
                .frame(width: size, height: size * 0.5)
        case .hurt:
            CrossShape()
                .stroke(.black.opacity(0.8), style: StrokeStyle(lineWidth: size * 0.16, lineCap: .round))
                .frame(width: size * 0.8, height: size * 0.8)
        case .taunt:
            ZStack {
                Circle()
                    .fill(.black.opacity(0.8))
                    .frame(width: size * 0.55, height: size * 0.55)
                Capsule()
                    .fill(.black.opacity(0.8))
                    .frame(width: size, height: size * 0.14)
                    .rotationEffect(.degrees(18))
                    .offset(y: -size * 0.5)
            }
        }
    }
}

/// 開心時的「^ ^」眼睛。
private struct ArcShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY),
            control: CGPoint(x: rect.midX, y: rect.minY - rect.height)
        )
        return path
    }
}

/// 被打到時的「XX」眼睛。
private struct CrossShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        return path
    }
}

#Preview {
    VStack(spacing: 24) {
        ForEach(Difficulty.allCases) { difficulty in
            HStack(spacing: 20) {
                FaceView(style: .opponent(for: difficulty), expression: .taunt, size: 72)
                FaceView(style: .player, expression: .happy, size: 72)
                FaceView(style: .player, expression: .hurt, size: 72)
                FaceView(style: .player, expression: .neutral, size: 72)
            }
        }
    }
    .padding()
}
