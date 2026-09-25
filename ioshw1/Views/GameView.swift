import SwiftUI

struct GameView: View {
    let difficulty: Difficulty
    let onExit: () -> Void

    @Environment(HighScoreStore.self) private var highScores
    @Environment(\.scenePhase) private var scenePhase

    @State private var engine: GameEngine
    @State private var showsRuleChart = false

    init(difficulty: Difficulty, onExit: @escaping () -> Void) {
        self.difficulty = difficulty
        self.onExit = onExit
        _engine = State(initialValue: GameEngine(difficulty: difficulty))
    }

    private var opponentStyle: FaceStyle { .opponent(for: difficulty) }
    private var isBlackout: Bool { engine.activePowerUp?.kind == .blackout }
    /// 智慧生效中顯示接／躲標記；快結束時會閃回真正的落下物。
    private var showsHintOnly: Bool { engine.showsWisdomHints }
    private var pulse: Bool { Int(engine.elapsed * 5) % 2 == 0 }

    var body: some View {
        ZStack {
            GameBackground(accent: difficulty.accent)

            VStack(spacing: 0) {
                // 上下各壓一條奶油色紙條，讓小字在棕色紙紋上讀得清楚，
                // 也把中間的落球區框出來。
                VStack(spacing: 0) {
                    hudBar
                    opponentBar
                }
                .background(Color.crayonPaper.opacity(0.8))
                .overlay(alignment: .bottom) { edgeLine }

                field

                playerBar
                    .background(Color.crayonPaper.opacity(0.8))
                    .overlay(alignment: .top) { edgeLine }
            }

            if showsRuleChart, engine.config.showsRuleChart {
                chartOverlay
            }

            if engine.phase == .paused {
                pauseOverlay
            }

            if engine.phase == .gameOver {
                GameOverView(
                    difficulty: difficulty,
                    score: engine.score,
                    highScore: highScores.highScore(for: difficulty),
                    isNewRecord: engine.didBeatHighScore,
                    lastLog: engine.lastLog,
                    ruleSet: engine.config.showsRuleChart ? engine.config.ruleSet : nil,
                    onRetry: restart,
                    onMenu: onExit
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: engine.phase)
        .onAppear { engine.start() }
        .onDisappear { engine.stop() }
        .onChange(of: engine.phase) { _, phase in
            guard phase == .gameOver else { return }
            engine.didBeatHighScore = highScores.submit(engine.score, for: difficulty)
        }
        .onChange(of: scenePhase) { _, phase in
            // 切到背景自動暫停，回來不會被偷扣血。
            if phase != .active { engine.pause() }
        }
    }

    // MARK: - HUD

    /// 紙條與落球區之間的蠟筆分隔線。
    private var edgeLine: some View {
        Rectangle()
            .fill(Color.crayonInk.opacity(0.28))
            .frame(height: 2)
    }

    private var hudBar: some View {
        HStack(spacing: 10) {
            CrayonIconButton(systemName: "pause.fill", label: "暫停") {
                engine.pause()
            }
            .disabled(engine.phase != .playing)

            HStack(spacing: 2) {
                ForEach(0..<engine.config.lives, id: \.self) { index in
                    LifeHeartView(isFilled: index < engine.lives, size: 28)
                }
            }
            .accessibilityLabel("剩餘生命 \(engine.lives)")

            Spacer()

            VStack(alignment: .trailing, spacing: 0) {
                Text("\(engine.score)")
                    .font(.crayon(22, weight: .heavy))
                    .foregroundStyle(Color.crayonInk)
                    .monospacedDigit()
                Text("最高 \(highScores.highScore(for: difficulty))")
                    .font(.crayon(11, weight: .semibold))
                    .foregroundStyle(Color.crayonInkSoft)
            }

            if engine.config.showsRuleChart {
                CrayonIconButton(systemName: "arrow.triangle.2.circlepath", label: "剋制表") {
                    showsRuleChart.toggle()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var opponentBar: some View {
        HStack(spacing: 12) {
            OpponentHeadView(
                difficulty: difficulty,
                expression: engine.opponentExpression,
                size: 68
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(opponentStyle.name)
                    .font(.crayon(16))
                    .foregroundStyle(Color.crayonInk)
                Text("\(difficulty.title) · \(engine.config.ruleSet.shapes.count) 拳")
                    .font(.crayon(12, weight: .semibold))
                    .foregroundStyle(Color.crayonInkSoft)
            }

            Spacer()

            powerUpBadge
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
    }

    @ViewBuilder
    private var powerUpBadge: some View {
        if let active = engine.activePowerUp {
            VStack(alignment: .trailing, spacing: 4) {
                Text(active.kind.name)
                    .font(.crayon(13))
                    .foregroundStyle(Color.crayonInk)
                CrayonBar(value: active.progress, tint: active.kind.tint, width: 74, height: 11)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .paperPanel(cornerRadius: 14, fill: active.kind.tint.opacity(0.22))
        }
    }

    // MARK: - 場地

    private var field: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                // 留空讓底下的紙紋透出來；contentShape 負責接手勢。
                Color.clear

                if engine.isTurbulent {
                    // 畫在落下物底下，物件才會從線上面壓過去。
                    TurbulenceLineView(width: geometry.size.width, pulse: pulse)
                        .position(x: geometry.size.width / 2, y: engine.turbulenceLineY)
                }

                ForEach(engine.objects) { object in
                    FallingObjectView(
                        shape: engine.config.ruleSet.shape(object.shapeID),
                        powerUp: object.powerUp,
                        relation: engine.effectiveRelation(for: object),
                        showsHintOnly: showsHintOnly,
                        pulse: pulse
                    )
                    .position(object.position)
                }

                PaddleView(
                    shape: engine.config.ruleSet.shape(engine.displayedHandID),
                    width: engine.paddleWidth,
                    height: engine.paddleHeight,
                    isTelegraphing: engine.isTelegraphing,
                    isInvincible: engine.isInvincible && engine.invincibleBlinkOn,
                    accent: difficulty.accent
                )
                .position(x: engine.paddleX, y: engine.paddleY)

            }
            .clipped()
            .overlay(alignment: .bottom) {
                if isBlackout {
                    // 天黑請閉眼：下半個畫面黑掉，落下物會沉進黑暗裡，
                    // 最後一段要靠記憶跟感覺接。
                    ZStack {
                        Color.black
                        Text("天黑請閉眼")
                            .font(.crayon(20))
                            .foregroundStyle(.white.opacity(0.35))
                    }
                    .frame(height: geometry.size.height / 2)
                }
            }
            .overlay(alignment: .top) {
                if let toast = engine.powerUpToast {
                    Text(toast)
                        .font(.crayon(22, weight: .heavy))
                        .foregroundStyle(Color.crayonInk)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 10)
                        .paperPanel(cornerRadius: 26)
                        .padding(.top, 18)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.easeOut(duration: 0.2), value: engine.powerUpToast)
            .contentShape(.rect)
            // 手指按住畫面任意處左右滑動，接盤跟著移動。
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { engine.movePaddle(to: $0.location.x) }
            )
            .onAppear { engine.updateFieldSize(geometry.size) }
            .onChange(of: geometry.size) { _, size in engine.updateFieldSize(size) }
        }
    }

    // MARK: - 玩家

    private var playerBar: some View {
        HStack(spacing: 12) {
            PlayerHeadView(expression: engine.playerExpression, size: 64)

            VStack(alignment: .leading, spacing: 2) {
                Text("你的拳")
                    .font(.crayon(12, weight: .semibold))
                    .foregroundStyle(Color.crayonInkSoft)
                HStack(spacing: 6) {
                    Text(engine.config.ruleSet.shape(engine.playerHandID).name)
                        .font(.crayon(17))
                        .foregroundStyle(Color.crayonInk)
                    if engine.isTelegraphing {
                        Text("→")
                            .font(.crayon(15, weight: .heavy))
                            .foregroundStyle(.orange)
                        Text(engine.config.ruleSet.shape(engine.nextHandID).name)
                            .font(.crayon(17))
                            .foregroundStyle(.orange)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(engine.isTelegraphing ? "即將換拳!" : "下次換拳")
                    .font(.crayon(12, weight: .semibold))
                    .foregroundStyle(engine.isTelegraphing ? .orange : Color.crayonInkSoft)
                CrayonBar(
                    value: engine.handSwapProgress,
                    tint: engine.isTelegraphing ? .orange : difficulty.accent
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 4)
    }

    // MARK: - 疊層

    private var chartOverlay: some View {
        ZStack {
            Color.crayonInk.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { showsRuleChart = false }

            RuleChartView(ruleSet: engine.config.ruleSet, highlightedID: engine.playerHandID)
        }
    }

    private var pauseOverlay: some View {
        ZStack {
            Color.crayonInk.opacity(0.55).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    Text("暫停")
                        .font(.crayon(38, weight: .heavy))
                        .foregroundStyle(Color.crayonPaper)

                    if engine.config.showsRuleChart {
                        RuleChartView(ruleSet: engine.config.ruleSet, highlightedID: engine.playerHandID)
                    }

                    VStack(spacing: 12) {
                        Button("繼續") { engine.resume() }
                            .buttonStyle(StickerButtonStyle(fill: difficulty.accent.opacity(0.85), textColor: .white))
                        Button("重新開始", action: restart)
                            .buttonStyle(StickerButtonStyle())
                        Button("回選單", action: onExit)
                            .buttonStyle(StickerButtonStyle())
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func restart() {
        let size = engine.fieldSize
        engine.stop()
        let fresh = GameEngine(difficulty: difficulty)
        fresh.updateFieldSize(size)
        engine = fresh
        fresh.start()
    }
}

#Preview {
    GameView(difficulty: .normal, onExit: {})
        .environment(HighScoreStore())
}
