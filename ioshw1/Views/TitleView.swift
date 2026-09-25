import SwiftUI

struct TitleView: View {
    let onStart: (Difficulty) -> Void

    @Environment(HighScoreStore.self) private var highScores
    @State private var showsHowTo = false

    var body: some View {
        ZStack {
            GameBackground(accent: .orange)

            ScrollView {
                VStack(spacing: 22) {
                    VStack(spacing: 6) {
                        Text("猜猜拳")
                            .font(.crayon(54, weight: .black))
                            .foregroundStyle(Color.crayonInk)
                            .shadow(color: .crayonPaper.opacity(0.8), radius: 0, x: 2, y: 2)
                        Text("接住打得贏的、閃開打不贏的")
                            .font(.crayon(15, weight: .semibold))
                            .foregroundStyle(Color.crayonInk.opacity(0.75))
                    }
                    .padding(.top, 30)

                    HStack(spacing: 14) {
                        ForEach(HandRuleSet.rps.shapes) { shape in
                            HandSymbolView(shape: shape, size: 58)
                        }
                    }

                    VStack(spacing: 12) {
                        ForEach(Difficulty.allCases) { difficulty in
                            DifficultyButton(
                                difficulty: difficulty,
                                highScore: highScores.highScore(for: difficulty),
                                action: { onStart(difficulty) }
                            )
                        }
                    }

                    Button("怎麼玩") { showsHowTo = true }
                        .buttonStyle(StickerButtonStyle(size: 17))
                        .padding(.bottom, 30)
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: 480)
                .frame(maxWidth: .infinity)
            }
        }
        .sheet(isPresented: $showsHowTo) {
            HowToPlayView()
        }
    }
}

private struct DifficultyButton: View {
    let difficulty: Difficulty
    let highScore: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                OpponentHeadView(difficulty: difficulty, expression: .neutral, size: 54)

                VStack(alignment: .leading, spacing: 2) {
                    Text(difficulty.title)
                        .font(.crayon(22, weight: .heavy))
                        .foregroundStyle(Color.crayonInk)
                    Text(difficulty.subtitle)
                        .font(.crayon(12, weight: .semibold))
                        .foregroundStyle(Color.crayonInkSoft)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("最高分")
                        .font(.crayon(11, weight: .semibold))
                        .foregroundStyle(Color.crayonInkSoft)
                    Text("\(highScore)")
                        .font(.crayon(19, weight: .heavy))
                        .foregroundStyle(Color.crayonInk)
                        .monospacedDigit()
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            // 奶油底摻一點難度色，維持貼紙質感又分得出難度。
            .paperPanel(cornerRadius: 20, fill: .crayonPaper.mix(with: difficulty.accent, by: 0.32))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(difficulty.title)，最高分 \(highScore)")
    }
}

private struct HowToPlayView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            GameBackground(accent: .orange)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("怎麼玩")
                            .font(.crayon(30, weight: .heavy))
                            .foregroundStyle(Color.crayonInk)
                        Spacer()
                        Button("關閉") { dismiss() }
                            .buttonStyle(StickerButtonStyle(size: 15))
                    }

                    section("操作", "手指按住畫面任意處左右滑動，底下的接盤就會跟著移動。")
                    section("目標", "接住你打得贏的拳、閃開打得贏你的拳。同拳型平手，碰到或漏掉都沒事。")
                    section("會扣血的兩件事", "① 該接的漏掉了　② 該閃的碰到了。扣血後有 0.8 秒無敵並閃爍。")
                    section("你的拳會換", "拳型會定時自動輪替。換拳前 2 秒，接盤上的拳會在「現在」跟「下一個」之間閃爍預告，趁這 2 秒先卡位。")
                    section("計分", "接對 +100，每存活 1 秒 +5。最高分各難度分開記。")
                    section("道具", "道具塗在落下的拳型物件上（一圈發光的顏色）。碰到就同時結算勝負並觸發效果，同時只會有一個效果。")

                    VStack(alignment: .leading, spacing: 10) {
                        Text("道具一覽")
                            .font(.crayon(18))
                            .foregroundStyle(Color.crayonInk)
                        ForEach(PowerUp.allCases) { powerUp in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(powerUp.tint)
                                    .overlay { Circle().strokeBorder(Color.crayonInk.opacity(0.6), lineWidth: 2) }
                                    .frame(width: 20, height: 20)
                                Text(powerUp.name)
                                    .font(.crayon(14))
                                    .foregroundStyle(Color.crayonInk)
                                Text(powerUp.detail)
                                    .font(.crayon(12, weight: .semibold))
                                    .foregroundStyle(Color.crayonInkSoft)
                            }
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .paperPanel()

                    RuleChartView(ruleSet: .rpsls)
                        .frame(maxWidth: .infinity)
                }
                .padding(20)
            }
        }
    }

    private func section(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.crayon(17))
                .foregroundStyle(Color.crayonInk)
            Text(body)
                .font(.crayon(14, weight: .medium))
                .foregroundStyle(Color.crayonInkSoft)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperPanel(cornerRadius: 16)
    }
}

#Preview {
    TitleView(onStart: { _ in })
        .environment(HighScoreStore())
}
