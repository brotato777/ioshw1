import SwiftUI

/// 一顆落下的拳型物件。道具是「塗」在物件上的一層專屬顏色光暈。
struct FallingObjectView: View {
    let shape: HandShape
    let powerUp: PowerUp?
    let relation: HandRelation
    /// 智慧道具生效時只顯示接／躲標記，平手直接隱形。
    let showsHintOnly: Bool
    /// 讓道具光暈閃爍的相位。
    let pulse: Bool

    private var isHidden: Bool { showsHintOnly && relation == .tie }

    var body: some View {
        Group {
            if showsHintOnly {
                hintBadge
            } else {
                HandSymbolView(shape: shape, size: FallingObject.diameter)
            }
        }
        .frame(width: FallingObject.diameter, height: FallingObject.diameter)
        // 疊兩層陰影讓光暈夠濃；沒有道具時是 clear，等於沒畫。
        .shadow(color: powerUp?.tint ?? .clear, radius: pulse ? 14 : 6)
        .shadow(color: powerUp?.tint ?? .clear, radius: pulse ? 7 : 3)
        .opacity(isHidden ? 0 : 1)
    }

    /// 智慧道具把判讀外包出去，只留一個字。
    private var hintBadge: some View {
        let isCatch = relation == .playerWins
        return ZStack {
            Circle()
                .fill(.white)
                .overlay(Circle().strokeBorder(isCatch ? .green : .red, lineWidth: 4))
            Text(isCatch ? "接" : "躲")
                .font(.system(size: FallingObject.diameter * 0.42, weight: .heavy))
                .foregroundStyle(isCatch ? .green : .red)
        }
    }
}

/// 亂流的變拳線。落下物越過這條線就順時針變成下一種拳，
/// 所以要讓玩家看得到線在哪，上面判讀的答案落到線下會變。
struct TurbulenceLineView: View {
    let width: CGFloat
    /// 跟著道具光暈一起閃，讓人知道這條線是亂流帶來的。
    let pulse: Bool

    private var tint: Color { PowerUp.turbulence.tint }

    var body: some View {
        ZStack {
            DashedLine()
                .stroke(
                    tint,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [14, 9])
                )
                .frame(width: width, height: 4)
                .shadow(color: tint.opacity(0.9), radius: pulse ? 7 : 3)

            Text("過線變拳")
                .font(.crayon(12))
                .foregroundStyle(Color.crayonInk)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .paperPanel(cornerRadius: 10, fill: tint.opacity(0.4))
        }
        .opacity(pulse ? 1 : 0.8)
        .allowsHitTesting(false)
    }
}

private struct DashedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

/// 底部的接盤，上面放著玩家當前的拳。
struct PaddleView: View {
    let shape: HandShape
    let width: CGFloat
    let height: CGFloat
    let isTelegraphing: Bool
    let isInvincible: Bool
    let accent: Color

    var body: some View {
        ZStack {
            Capsule()
                .fill(accent.gradient)
                .overlay(Capsule().strokeBorder(.white.opacity(0.75), lineWidth: 2))
                .shadow(color: .black.opacity(0.25), radius: 4, y: 2)

            HandSymbolView(shape: shape, size: height * 0.92)
        }
        .frame(width: width, height: height)
        .overlay {
            if isTelegraphing {
                // 換拳預告：接盤同時鑲一圈黃邊。
                Capsule()
                    .strokeBorder(.yellow, lineWidth: 3)
                    .shadow(color: .yellow, radius: 6)
            }
        }
        .opacity(isInvincible ? 0.4 : 1)
    }
}
