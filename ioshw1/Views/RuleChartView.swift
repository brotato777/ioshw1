import SwiftUI

/// 圖形化剋制表：拳型排成一圈，箭頭一律從「打贏的」指向「被打贏的」。
/// 節點與箭頭全部從拳型資料表長出來，換表就換圖。
struct RuleChartView: View {
    let ruleSet: HandRuleSet
    /// 玩家當前拳型。有指定時會把「該接」染綠、「該閃」染紅。
    var highlightedID: String?
    var diameter: CGFloat = 264

    /// 標題、圖例與邊距合計佔掉的高度。
    /// 想把圖塞進固定高度時，用「可用高度 − 這個值」就是能給的直徑。
    static let chromeHeight: CGFloat = 104

    private var nodeSize: CGFloat { diameter * 0.23 }
    private var ringRadius: CGFloat { diameter / 2 - nodeSize / 2 - 4 }

    var body: some View {
        VStack(spacing: 12) {
            Text("剋制表")
                .font(.crayon(20))
                .foregroundStyle(Color.crayonInk)

            ZStack {
                Canvas { context, _ in
                    // 先畫沒被標記的，再畫標記過的，重點箭頭才不會被蓋住。
                    for arrow in arrows.sorted(by: { $0.role.depth < $1.role.depth }) {
                        draw(arrow, in: &context)
                    }
                }

                ForEach(Array(ruleSet.shapes.enumerated()), id: \.element.id) { index, shape in
                    node(for: shape)
                        .position(position(at: index))
                }
            }
            .frame(width: diameter, height: diameter)

            if highlightedID != nil {
                HStack(spacing: 18) {
                    legend(color: .green, text: "接住")
                    legend(color: .red, text: "閃開")
                }
            }
        }
        .padding(18)
        .paperPanel()
    }

    // MARK: - 節點

    @ViewBuilder
    private func node(for shape: HandShape) -> some View {
        ZStack {
            if shape.id == highlightedID {
                // 你現在出的拳。
                Circle()
                    .fill(Color.orange.opacity(0.22))
                    .overlay { Circle().strokeBorder(.orange, lineWidth: 3) }
                    .frame(width: nodeSize * 1.3, height: nodeSize * 1.3)
            }
            HandSymbolView(shape: shape, size: nodeSize)
        }
    }

    private func legend(color: Color, text: String) -> some View {
        HStack(spacing: 5) {
            Text("→")
                .font(.crayon(20, weight: .heavy))
                .foregroundStyle(color)
            Text(text)
                .font(.crayon(14, weight: .semibold))
                .foregroundStyle(Color.crayonInkSoft)
        }
    }

    // MARK: - 幾何

    private func position(at index: Int) -> CGPoint {
        let count = max(ruleSet.shapes.count, 1)
        // 從正上方開始順時針排。
        let angle = -Double.pi / 2 + 2 * Double.pi * Double(index) / Double(count)
        return CGPoint(
            x: diameter / 2 + ringRadius * cos(angle),
            y: diameter / 2 + ringRadius * sin(angle)
        )
    }

    // MARK: - 箭頭

    private enum ArrowRole {
        /// 你打得贏它 → 該接。
        case youCatch
        /// 它打得贏你 → 該閃。
        case youDodge
        /// 與你當前的拳無關。
        case plain

        var depth: Int {
            switch self {
            case .plain: 0
            case .youDodge: 1
            case .youCatch: 2
            }
        }

        var color: Color {
            switch self {
            case .youCatch: .green
            case .youDodge: .red
            case .plain: Color.crayonInk.opacity(0.42)
            }
        }

        var lineWidth: CGFloat {
            self == .plain ? 3 : 4.5
        }
    }

    private struct Arrow {
        let from: CGPoint
        let to: CGPoint
        let role: ArrowRole
    }

    private var arrows: [Arrow] {
        var result: [Arrow] = []
        for (index, shape) in ruleSet.shapes.enumerated() {
            for beatenID in shape.beats {
                guard let targetIndex = ruleSet.shapes.firstIndex(where: { $0.id == beatenID }) else { continue }
                result.append(
                    Arrow(
                        from: position(at: index),
                        to: position(at: targetIndex),
                        role: role(winner: shape.id, loser: beatenID)
                    )
                )
            }
        }
        return result
    }

    private func role(winner: String, loser: String) -> ArrowRole {
        guard let highlightedID else { return .plain }
        if winner == highlightedID { return .youCatch }
        if loser == highlightedID { return .youDodge }
        return .plain
    }

    private func draw(_ arrow: Arrow, in context: inout GraphicsContext) {
        let dx = arrow.to.x - arrow.from.x
        let dy = arrow.to.y - arrow.from.y
        let length = max(sqrt(dx * dx + dy * dy), 0.001)
        let ux = dx / length
        let uy = dy / length

        // 兩端都讓開節點，箭頭才不會壓在貼紙上。
        let gap = nodeSize / 2 + 8
        let start = CGPoint(x: arrow.from.x + ux * gap, y: arrow.from.y + uy * gap)
        let end = CGPoint(x: arrow.to.x - ux * (gap + 4), y: arrow.to.y - uy * (gap + 4))

        var path = Path()
        path.move(to: start)
        path.addLine(to: end)

        // 箭頭尖：從終點往回開兩撇。
        let headLength: CGFloat = 13
        let spread = 0.42
        let base = atan2(uy, ux) + .pi
        for sign in [-1.0, 1.0] {
            let angle = base + sign * spread
            path.move(to: end)
            path.addLine(to: CGPoint(x: end.x + cos(angle) * headLength, y: end.y + sin(angle) * headLength))
        }

        context.stroke(
            path,
            with: .color(arrow.role.color),
            style: StrokeStyle(lineWidth: arrow.role.lineWidth, lineCap: .round, lineJoin: .round)
        )
    }
}

#Preview {
    ZStack {
        GameBackground(accent: .orange)
        ScrollView {
            VStack(spacing: 20) {
                RuleChartView(ruleSet: .rps, highlightedID: "paper")
                RuleChartView(ruleSet: .rpsls, highlightedID: "lizard")
                RuleChartView(ruleSet: .rpsls)
            }
            .padding()
        }
    }
}
