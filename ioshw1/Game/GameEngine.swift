import SwiftUI

extension Duration {
    /// 把 Duration 換成秒，給遊戲迴圈算 delta time 用。
    var seconds: Double {
        Double(components.seconds) + Double(components.attoseconds) * 1e-18
    }
}

enum GamePhase: Sendable {
    case playing
    case paused
    case gameOver
}

/// 角色臉上的表情。
enum FaceExpression: Sendable {
    case neutral
    case happy
    case hurt
    case taunt
}

@MainActor
@Observable
final class GameEngine {

    // MARK: - 設定

    let difficulty: Difficulty
    let config: DifficultyConfig

    // MARK: - 場地

    /// 由 GameView 的 GeometryReader 填入。
    var fieldSize: CGSize = .zero
    var paddleX: CGFloat = 0
    let paddleWidth: CGFloat = 110
    /// 接盤做得夠高，讓拳型貼紙放得進去，視覺上的接觸面才跟判定範圍一致。
    let paddleHeight: CGFloat = 46

    /// 接盤中心線離場地底部的距離。
    private let paddleBottomInset: CGFloat = 62
    var paddleY: CGFloat { max(0, fieldSize.height - paddleBottomInset) }

    // MARK: - 狀態

    var phase: GamePhase = .playing
    var objects: [FallingObject] = []
    var lives: Int
    var score: Int = 0
    var elapsed: Double = 0

    /// 玩家當前拳型。
    var playerHandID: String
    /// 換拳後會變成的拳型，預告閃爍就是在閃這顆。
    var nextHandID: String
    private var handSwapRemaining: Double
    private var blinkClock: Double = 0

    var activePowerUp: ActivePowerUp?
    var powerUpToast: String?
    private var toastRemaining: Double = 0

    private(set) var invincibleRemaining: Double = 0
    var isInvincible: Bool { invincibleRemaining > 0 }
    /// 無敵幀期間讓角色閃爍。
    var invincibleBlinkOn: Bool { Int(invincibleRemaining * 12) % 2 == 0 }

    /// 只保留最後一條戰報，而且只在結算畫面出現，遊戲中不顯示。
    var lastLog: BattleLogEntry?

    var playerExpression: FaceExpression = .neutral
    var opponentExpression: FaceExpression = .neutral
    private var playerExpressionRemaining: Double = 0
    private var opponentExpressionRemaining: Double = 0

    var didBeatHighScore = false

    // MARK: - 內部計時

    private var spawnCountdown: Double
    private var survivalAccumulator: Double = 0
    private var timeSinceCatchableSpawn: Double = 0
    private var loopTask: Task<Void, Never>?
    private let laneCount = 5

    // MARK: - 預告

    /// 換拳前 2 秒開始閃爍預告。
    private let telegraphLead: Double = 2

    /// 智慧生效中與結束後這段時間內都不換拳。
    /// 判讀剛被還回來就馬上換拳，玩家根本反應不過來。
    private let wisdomSwapGrace: Double = 1
    private var handSwapFreezeRemaining: Double = 0

    /// 智慧結束前這段時間開始閃回真正的拳型，讓玩家先接手判讀。
    private let wisdomFadeLead: Double = 1.8
    /// 最後這段時間完全不再顯示標記，讓玩家在效果消失前就已經在自己判讀。
    private let wisdomHandoverLead: Double = 0.5

    var isTelegraphing: Bool {
        handSwapFreezeRemaining <= 0 && handSwapRemaining <= telegraphLead
    }

    /// 接盤上實際畫出來的拳型：預告期間在目前與下一個之間交替。
    var displayedHandID: String {
        guard isTelegraphing else { return playerHandID }
        return Int(blinkClock * 4) % 2 == 0 ? playerHandID : nextHandID
    }

    // MARK: - 亂流

    var isTurbulent: Bool { activePowerUp?.kind == .turbulence }

    /// 亂流的變拳線。畫面上畫的線與實際變拳的判定都讀這個值，兩邊不會對不上。
    var turbulenceLineY: CGFloat { fieldSize.height / 2 }

    /// 智慧道具是不是快結束了。
    var isWisdomEnding: Bool {
        guard let active = activePowerUp, active.kind == .wisdom else { return false }
        return active.remaining <= wisdomFadeLead
    }

    /// 此刻是否要把落下物換成接／躲標記。
    ///
    /// 智慧快結束時先與真正的落下物交替閃爍當預告，
    /// 最後 `wisdomHandoverLead` 秒直接把判讀完整交還，不要在正要消失的瞬間還在閃。
    var showsWisdomHints: Bool {
        guard let active = activePowerUp, active.kind == .wisdom else { return false }
        guard active.remaining <= wisdomFadeLead else { return true }
        guard active.remaining > wisdomHandoverLead else { return false }
        return Int(active.remaining / 0.3) % 2 == 1
    }

    var handSwapProgress: Double {
        1 - (handSwapRemaining / config.handSwapInterval)
    }

    // MARK: - 建立

    init(difficulty: Difficulty) {
        self.difficulty = difficulty
        let config = difficulty.config
        self.config = config
        self.lives = config.lives
        self.spawnCountdown = config.spawnInterval
        self.handSwapRemaining = config.handSwapInterval
        let first = config.ruleSet.shapes.randomElement()!.id
        self.playerHandID = first
        self.nextHandID = config.ruleSet.randomShape(excluding: first)
    }

    // MARK: - 難度遞增

    /// 每存活 `rampPeriod` 秒套用一次遞增，而且不設難度上限：撐得越久就越難，沒有天花板。
    private var rampSteps: Double { (elapsed / config.rampPeriod).rounded(.down) }

    private var speedMultiplier: CGFloat {
        pow(config.speedRampFactor, CGFloat(rampSteps))
    }

    private var currentSpawnInterval: Double {
        // 只夾一個安全下限，避免每一幀都生成把遊戲壓垮；這不是難度上限。
        max(config.spawnInterval * pow(config.spawnRampFactor, rampSteps), config.spawnSafetyFloor)
    }

    /// 貪婪生效時整體掉落速度加快。
    private var powerUpSpeedFactor: CGFloat {
        activePowerUp?.kind.fallSpeedMultiplier ?? 1
    }

    private var scoreMultiplier: Int {
        activePowerUp?.kind.scoreMultiplier ?? 1
    }

    // MARK: - 勝負判定

    /// 忽略道具的原始關係。
    func baseRelation(forShape shapeID: String) -> HandRelation {
        config.ruleSet.relation(player: playerHandID, object: shapeID)
    }

    /// 「勝負相反」生效時接與閃對調。
    func effectiveRelation(forShape shapeID: String) -> HandRelation {
        let relation = baseRelation(forShape: shapeID)
        return activePowerUp?.kind == .reversed ? relation.flipped : relation
    }

    func effectiveRelation(for object: FallingObject) -> HandRelation {
        effectiveRelation(forShape: object.shapeID)
    }

    /// 這局玩家現在是不是拿到一張打不贏任何東西的「絕境拳」。
    var isDeadEndHand: Bool {
        config.ruleSet.winnableShapes(for: playerHandID).isEmpty
    }

    // MARK: - 迴圈

    func start() {
        guard loopTask == nil else { return }
        loopTask = Task { @MainActor [weak self] in
            var last = ContinuousClock.now
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(16))
                guard let self else { return }
                let now = ContinuousClock.now
                let delta = last.duration(to: now).seconds
                last = now
                guard self.phase == .playing else { continue }
                // 夾住 delta，避免切回前景時一次跳一大段。
                self.tick(delta: min(delta, 1.0 / 20))
            }
        }
    }

    func stop() {
        loopTask?.cancel()
        loopTask = nil
    }

    func pause() {
        guard phase == .playing else { return }
        phase = .paused
    }

    func resume() {
        guard phase == .paused else { return }
        phase = .playing
    }

    private func tick(delta: Double) {
        elapsed += delta
        blinkClock += delta

        advanceTimers(delta: delta)
        advanceScoreForSurvival(delta: delta)
        advanceHandSwap(delta: delta)
        moveObjects(delta: delta)
        resolveCollisions()
        objects.removeAll { $0.isResolved }

        // 結算可能讓生命歸零，這局結束後就不要再生成了。
        guard phase == .playing else { return }

        spawnCountdown -= delta
        if spawnCountdown <= 0 {
            spawnCountdown = currentSpawnInterval
            spawnObject()
        }
        timeSinceCatchableSpawn += delta
    }

    private func advanceTimers(delta: Double) {
        if invincibleRemaining > 0 { invincibleRemaining -= delta }

        if var active = activePowerUp {
            active.remaining -= delta
            activePowerUp = active.remaining > 0 ? active : nil
        }

        advanceHandSwapFreeze(delta: delta)

        if toastRemaining > 0 {
            toastRemaining -= delta
            if toastRemaining <= 0 { powerUpToast = nil }
        }

        if playerExpressionRemaining > 0 {
            playerExpressionRemaining -= delta
            if playerExpressionRemaining <= 0 { playerExpression = .neutral }
        }

        if opponentExpressionRemaining > 0 {
            opponentExpressionRemaining -= delta
            if opponentExpressionRemaining <= 0 { opponentExpression = .neutral }
        }
    }

    /// 存活每秒 +5。
    private func advanceScoreForSurvival(delta: Double) {
        survivalAccumulator += delta
        while survivalAccumulator >= 1 {
            survivalAccumulator -= 1
            score += 5 * scoreMultiplier
        }
    }

    /// 智慧生效期間把換拳倒數整個凍住，結束後再多給 `wisdomSwapGrace` 秒才解凍。
    private func advanceHandSwapFreeze(delta: Double) {
        if activePowerUp?.kind == .wisdom {
            handSwapFreezeRemaining = wisdomSwapGrace
            return
        }

        guard handSwapFreezeRemaining > 0 else { return }
        handSwapFreezeRemaining -= delta
        guard handSwapFreezeRemaining <= 0 else { return }

        handSwapFreezeRemaining = 0
        // 解凍的瞬間至少留滿一次預告時間，不要一解除就立刻換拳。
        handSwapRemaining = max(handSwapRemaining, telegraphLead)
    }

    private func advanceHandSwap(delta: Double) {
        guard handSwapFreezeRemaining <= 0 else { return }

        handSwapRemaining -= delta
        guard handSwapRemaining <= 0 else { return }
        // 換拳瞬間全場「接／閃」關係一次翻新。
        playerHandID = nextHandID
        nextHandID = config.ruleSet.randomShape(excluding: playerHandID)
        handSwapRemaining = config.handSwapInterval
        blinkClock = 0
    }

    private func moveObjects(delta: Double) {
        let turbulent = isTurbulent

        for index in objects.indices {
            objects[index].position.y += objects[index].speed * powerUpSpeedFactor * CGFloat(delta)

            // 亂流：越過變拳線時順時針變成下一種拳。
            if turbulent, !objects[index].didCrossMidline, objects[index].position.y >= turbulenceLineY {
                objects[index].didCrossMidline = true
                objects[index].shapeID = config.ruleSet.nextClockwise(after: objects[index].shapeID)
            }
        }
    }

    // MARK: - 碰撞與結算

    private func resolveCollisions() {
        guard fieldSize.height > 0 else { return }
        let catchBandHalf: CGFloat = 32

        // 先標記再結算：結算可能會結束遊戲並清空 objects，不能邊走邊改。
        var caught: [FallingObject] = []
        var missed: [FallingObject] = []

        for index in objects.indices where !objects[index].isResolved {
            let object = objects[index]

            let withinBand = abs(object.position.y - paddleY) <= catchBandHalf
            let withinPaddle = abs(object.position.x - paddleX) <= (paddleWidth / 2 + object.radius * 0.6)

            if withinBand && withinPaddle {
                objects[index].isResolved = true
                caught.append(object)
            } else if object.position.y - object.radius > fieldSize.height {
                objects[index].isResolved = true
                missed.append(object)
            }
        }

        for object in caught where phase == .playing {
            resolveCatch(object)
        }
        for object in missed where phase == .playing {
            resolveMiss(object)
        }
    }

    /// 碰到接盤：同時結算拳型勝負 + 觸發道具效果。
    private func resolveCatch(_ object: FallingObject) {
        switch effectiveRelation(for: object) {
        case .playerWins:
            score += 100 * scoreMultiplier
            SoundPlayer.shared.playScore()
            recordLog(winnerID: playerHandID, loserID: object.shapeID, isGood: true)
            setPlayerExpression(.happy)
            setOpponentExpression(.hurt)
        case .objectWins:
            recordLog(winnerID: object.shapeID, loserID: playerHandID, isGood: false)
            applyDamage()
        case .tie:
            break
        }

        // 道具永不直接扣血，且不論勝負都會觸發。
        if let powerUp = object.powerUp {
            activate(powerUp)
        }
    }

    private func resolveMiss(_ object: FallingObject) {
        switch effectiveRelation(for: object) {
        case .playerWins:
            // 該接的漏接了。
            recordLog(text: "漏接 \(name(object.shapeID))!白白放走一分", isGood: false)
            applyDamage()
        case .objectWins, .tie:
            break
        }
    }

    private func applyDamage() {
        guard !isInvincible else { return }
        lives -= 1
        invincibleRemaining = 0.8
        setPlayerExpression(.hurt)
        setOpponentExpression(.taunt)

        if lives <= 0 {
            lives = 0
            endGame()
        }
    }

    private func activate(_ powerUp: PowerUp) {
        // 同一時間只保留一個效果，吃到新的覆蓋舊的。
        activePowerUp = ActivePowerUp(powerUp)
        powerUpToast = powerUp.name
        toastRemaining = 1.8
    }

    private func endGame() {
        phase = .gameOver
        objects.removeAll()
        stop()
    }

    // MARK: - 生成

    private func spawnObject() {
        guard fieldSize.width > 0 else { return }

        let catchables = objects.filter {
            !$0.isResolved && effectiveRelation(for: $0) == .playerWins
        }

        // 別讓長時間沒有任何可接物件（除非玩家正卡在絕境拳）。
        let needsCatchable = catchables.isEmpty
            && timeSinceCatchableSpawn > 2.5
            && !catchableShapes.isEmpty

        let shapeID = needsCatchable
            ? catchableShapes.randomElement()!
            : config.ruleSet.shapes.randomElement()!.id

        let relation = effectiveRelation(forShape: shapeID)

        // 不要把「該閃的」丟在唯一能接的物件正上方，否則接盤只有一個 → 變必扣血。
        var lanes = Array(0..<laneCount)
        if relation == .objectWins, catchables.count == 1 {
            let blocked = Set(catchables.map { lane(forX: $0.position.x) })
            lanes.removeAll { blocked.contains($0) }
        }
        let chosenLane = lanes.randomElement() ?? Int.random(in: 0..<laneCount)

        var object = FallingObject(
            shapeID: shapeID,
            position: CGPoint(x: x(forLane: chosenLane), y: -FallingObject.diameter),
            speed: config.fallSpeed * speedMultiplier
        )

        // 道具只塗在「該接」的物件上，避免負面效果跟扣血情境重疊。
        if config.powerUpsEnabled, relation == .playerWins, Double.random(in: 0..<1) < 0.16 {
            object.powerUp = PowerUp.allCases.randomElement()
        }

        if relation == .playerWins { timeSinceCatchableSpawn = 0 }
        objects.append(object)
    }

    /// 目前拳型打得贏的拳型（含勝負相反的影響）。
    private var catchableShapes: [String] {
        config.ruleSet.shapes.map(\.id).filter { effectiveRelation(forShape: $0) == .playerWins }
    }

    private var laneWidth: CGFloat {
        let usable = max(fieldSize.width - FallingObject.diameter, 1)
        return usable / CGFloat(laneCount)
    }

    private func x(forLane lane: Int) -> CGFloat {
        let base = FallingObject.diameter / 2 + laneWidth * (CGFloat(lane) + 0.5)
        let jitter = CGFloat.random(in: -laneWidth / 4...laneWidth / 4)
        return min(max(base + jitter, FallingObject.diameter / 2), fieldSize.width - FallingObject.diameter / 2)
    }

    private func lane(forX x: CGFloat) -> Int {
        let raw = (x - FallingObject.diameter / 2) / laneWidth
        return min(max(Int(raw), 0), laneCount - 1)
    }

    // MARK: - 操作

    /// 手指按住畫面任意處左右滑動，接盤跟著移動。
    func movePaddle(to x: CGFloat) {
        let half = paddleWidth / 2
        paddleX = min(max(x, half), max(fieldSize.width - half, half))
    }

    func updateFieldSize(_ size: CGSize) {
        let isFirstLayout = fieldSize == .zero
        fieldSize = size
        if isFirstLayout {
            paddleX = size.width / 2
        } else {
            movePaddle(to: paddleX)
        }
    }

    // MARK: - 戰報字幕

    private func name(_ shapeID: String) -> String {
        config.ruleSet.shape(shapeID).name
    }

    /// 記下這次結算的理由，留到結算畫面當作最後一條戰報。
    private func recordLog(winnerID: String, loserID: String, isGood: Bool) {
        recordLog(text: config.ruleSet.report(winner: winnerID, loser: loserID), isGood: isGood)
    }

    private func recordLog(text: String, isGood: Bool) {
        lastLog = BattleLogEntry(text: text, isGood: isGood)
    }

    // MARK: - 表情

    private func setPlayerExpression(_ expression: FaceExpression) {
        playerExpression = expression
        playerExpressionRemaining = 0.7
    }

    private func setOpponentExpression(_ expression: FaceExpression) {
        opponentExpression = expression
        opponentExpressionRemaining = 0.7
    }
}
