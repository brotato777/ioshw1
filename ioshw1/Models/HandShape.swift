import SwiftUI

/// 一種拳型。勝負關係完全由 `beats` 這張表決定，程式邏輯不寫死任何 if-else。
struct HandShape: Identifiable, Hashable, Sendable {
    /// 穩定的識別字，`beats` 清單裡存的就是這個值。
    let id: String
    let name: String
    /// 畫面上顯示用的符號。
    let symbol: String
    /// 我打得贏的拳型 id。清單外一律算輸，同 id 算平手。
    let beats: [String]
    /// 戰報字幕用的動詞，例如「布 包住 石頭!」。
    let verb: String
}

/// 玩家拳型與落下物之間的三種關係。
enum HandRelation: Sendable {
    /// 我方打得贏它 → 該接住。
    case playerWins
    /// 它打得贏我 → 該閃開。
    case objectWins
    /// 同拳型 → 忽略。
    case tie

    /// 「勝負相反」道具生效時使用：接與閃對調，平手不變。
    var flipped: HandRelation {
        switch self {
        case .playerWins: .objectWins
        case .objectWins: .playerWins
        case .tie: .tie
        }
    }
}

/// 一組拳型清單。要擴充到 5 種、20 種只需要換這張表。
struct HandRuleSet: Sendable {
    let shapes: [HandShape]

    private let index: [String: HandShape]
    /// 每一對的專屬戰報，key 是「勝方id|敗方id」。
    /// 沒有指定的配對會退回用 `verb` 組出來的句子。
    private let reports: [String: String]

    init(shapes: [HandShape], reports: [String: String] = [:]) {
        self.shapes = shapes
        self.index = Dictionary(uniqueKeysWithValues: shapes.map { ($0.id, $0) })
        self.reports = reports
    }

    func shape(_ id: String) -> HandShape {
        // 所有 id 都來自本表，取不到代表資料表有錯。
        guard let shape = index[id] else {
            preconditionFailure("未知的拳型 id: \(id)")
        }
        return shape
    }

    /// 判定就是一句話：A 打贏 B ⟺ B 在 A 的打贏清單裡。
    func relation(player playerID: String, object objectID: String) -> HandRelation {
        if playerID == objectID { return .tie }
        if shape(playerID).beats.contains(objectID) { return .playerWins }
        return .objectWins
    }

    /// 亂流道具用：順時針轉成清單裡的下一種拳。
    func nextClockwise(after id: String) -> String {
        guard let position = shapes.firstIndex(where: { $0.id == id }) else { return id }
        return shapes[(position + 1) % shapes.count].id
    }

    /// 玩家拳型輪替用：隨機挑一個與現在不同的拳型。
    func randomShape(excluding excludedID: String? = nil) -> String {
        let candidates = shapes.filter { $0.id != excludedID }
        return (candidates.isEmpty ? shapes : candidates).randomElement()!.id
    }

    /// 這個拳型打得贏的所有拳型，用來檢查是否為「絕境拳」。
    func winnableShapes(for playerID: String) -> [String] {
        shape(playerID).beats
    }

    /// 這一對的戰報字幕。把推理變笑點，也讓玩家在遊玩中自然學會關係表。
    func report(winner winnerID: String, loser loserID: String) -> String {
        if let custom = reports["\(winnerID)|\(loserID)"] { return custom }
        let winner = shape(winnerID)
        return "\(winner.name) \(winner.verb) \(shape(loserID).name)!"
    }
}

extension HandRuleSet {
    /// 簡單、普通：經典三拳。
    static let rps = HandRuleSet(shapes: [
        HandShape(id: "rock", name: "石頭", symbol: "✊", beats: ["scissors"], verb: "砸爛"),
        HandShape(id: "paper", name: "布", symbol: "✋", beats: ["rock"], verb: "包住"),
        HandShape(id: "scissors", name: "剪刀", symbol: "✌️", beats: ["paper"], verb: "剪爛"),
    ])

    /// 困難：加入蜥蜴與史巴克的五拳。
    static let rpsls = HandRuleSet(shapes: [
        HandShape(id: "rock", name: "石頭", symbol: "✊", beats: ["scissors", "lizard"], verb: "砸爛"),
        HandShape(id: "paper", name: "布", symbol: "✋", beats: ["rock", "spock"], verb: "包住"),
        HandShape(id: "scissors", name: "剪刀", symbol: "✌️", beats: ["paper", "lizard"], verb: "剪爛"),
        HandShape(id: "lizard", name: "蜥蜴", symbol: "🦎", beats: ["paper", "spock"], verb: "毒倒"),
        HandShape(id: "spock", name: "史巴克", symbol: "🖖", beats: ["rock", "scissors"], verb: "汽化"),
    ])
}
