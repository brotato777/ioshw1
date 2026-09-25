import SwiftUI

/// 結算畫面。整頁不滾動，剋制表會依剩餘空間自動縮放。
struct GameOverView: View {
    let difficulty: Difficulty
    let score: Int
    let highScore: Int
    let isNewRecord: Bool
    /// 只顯示最後一條戰報。
    let lastLog: BattleLogEntry?
    /// 前三難度顯示剋制表，沒有就傳 nil。
    let ruleSet: HandRuleSet?
    let onRetry: () -> Void
    let onMenu: () -> Void

    /// 量到的固定區塊高度，用來換算剋制表能拿到多大。
    /// 字級全部是固定 pt，所以量一次就穩定。
    @State private var fixedHeight: CGFloat = 0

    private let spacing: CGFloat = 12
    private let innerPadding: CGFloat = 20

    var body: some View {
        ZStack {
            Color.crayonInk.opacity(0.6).ignoresSafeArea()

            GeometryReader { geometry in
                VStack(spacing: spacing) {
                    fixedContent
                        .onGeometryChange(for: CGFloat.self) { proxy in
                            proxy.size.height
                        } action: { height in
                            fixedHeight = height
                        }

                    if let ruleSet {
                        RuleChartView(ruleSet: ruleSet, diameter: chartDiameter(in: geometry.size))
                    }
                }
                .padding(innerPadding)
                .frame(maxWidth: 430)
                // 面板只包住內容，再整塊置中，底部才不會留一大片空白。
                .paperPanel(cornerRadius: 28)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(16)
        }
    }

    /// 高度固定的那幾塊：頭像與標題、分數、戰報、按鈕。
    private var fixedContent: some View {
        VStack(spacing: spacing) {
            HStack(spacing: 12) {
                OpponentHeadView(difficulty: difficulty, expression: .taunt, size: 64)

                VStack(alignment: .leading, spacing: 1) {
                    Text("遊戲結束")
                        .font(.crayon(27, weight: .heavy))
                        .foregroundStyle(Color.crayonInk)
                    Text("\(difficulty.title)最高分 \(highScore)")
                        .font(.crayon(12, weight: .semibold))
                        .foregroundStyle(Color.crayonInkSoft)
                }

                Spacer(minLength: 0)
            }

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("本局分數")
                    .font(.crayon(12, weight: .semibold))
                    .foregroundStyle(Color.crayonInkSoft)
                Text("\(score)")
                    .font(.crayon(44, weight: .black))
                    .foregroundStyle(Color.crayonInk)
                    .monospacedDigit()
                if isNewRecord {
                    Text("新紀錄!")
                        .font(.crayon(14, weight: .heavy))
                        .foregroundStyle(.orange)
                }
            }

            if let lastLog {
                // 最後一拳的勝負理由。
                HStack(spacing: 8) {
                    Text(lastLog.isGood ? "✓" : "✕")
                        .font(.crayon(18, weight: .heavy))
                        .foregroundStyle(lastLog.isGood ? .green : .red)
                    Text(lastLog.text)
                        .font(.crayon(15))
                        .foregroundStyle(Color.crayonInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .paperPanel(cornerRadius: 16, fill: Color.crayonTan.opacity(0.28))
            }

            HStack(spacing: 10) {
                Button("再來一局", action: onRetry)
                    .buttonStyle(StickerButtonStyle(
                        fill: difficulty.accent.opacity(0.85),
                        textColor: .white,
                        size: 17
                    ))
                Button("回選單", action: onMenu)
                    .buttonStyle(StickerButtonStyle(size: 17))
            }
        }
    }

    /// 把剩下的高度全部給剋制表，夾在看得清楚與不過大之間。
    private func chartDiameter(in size: CGSize) -> CGFloat {
        let availableHeight = size.height - innerPadding * 2 - fixedHeight - spacing
        let byHeight = availableHeight - RuleChartView.chromeHeight
        let byWidth = size.width - innerPadding * 2 - 36
        return min(max(min(byHeight, byWidth), 130), 300)
    }
}

#Preview {
    GameOverView(
        difficulty: .normal,
        score: 1250,
        highScore: 1250,
        isNewRecord: true,
        lastLog: BattleLogEntry(text: "剪刀 剪爛 布!", isGood: false),
        ruleSet: .rps,
        onRetry: {},
        onMenu: {}
    )
}
