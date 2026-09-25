import SwiftUI

enum Difficulty: String, CaseIterable, Identifiable, Sendable {
    case easy
    case normal
    case hard
    case hell

    var id: String { rawValue }

    var title: String {
        switch self {
        case .easy: "簡單"
        case .normal: "普通"
        case .hard: "困難"
        case .hell: "地獄"
        }
    }

    var subtitle: String {
        switch self {
        case .easy: "三拳 · 5 顆心 · 入門"
        case .normal: "三拳 · 3 顆心 · 有道具"
        case .hard: "五拳 · 3 顆心 · 最快"
        case .hell: "十九拳 · 沒有提示 · 用腦"
        }
    }

    var accent: Color {
        switch self {
        case .easy: .green
        case .normal: .orange
        case .hard: .red
        case .hell: .purple
        }
    }

    var config: DifficultyConfig {
        switch self {
        case .easy:
            DifficultyConfig(
                ruleSet: .rps,
                lives: 5,
                fallSpeed: 250,
                spawnInterval: 1.15,
                handSwapInterval: 10,
                powerUpsEnabled: false,
                showsRuleChart: true
            )
        case .normal:
            DifficultyConfig(
                ruleSet: .rps,
                lives: 3,
                fallSpeed: 330,
                spawnInterval: 0.85,
                handSwapInterval: 8,
                powerUpsEnabled: true,
                showsRuleChart: true
            )
        case .hard:
            DifficultyConfig(
                ruleSet: .rpsls,
                lives: 3,
                fallSpeed: 420,
                spawnInterval: 0.7,
                handSwapInterval: 6,
                powerUpsEnabled: true,
                showsRuleChart: true
            )
        case .hell:
            // 起始數值照抄簡單：地獄的難度來自「拳種多 + 沒有提示 = 要動腦推理」，
            // 不是靠手速。遞增速度與困難相同（遞增參數是全難度共用的）。
            DifficultyConfig(
                ruleSet: .hell,
                lives: 5,
                fallSpeed: 250,
                spawnInterval: 1.15,
                handSwapInterval: 10,
                powerUpsEnabled: true,
                showsRuleChart: false
            )
        }
    }
}

/// 一個難度的全部數值參數。難度的差別本質上就是換一組拳型清單 + 換幾個數值。
struct DifficultyConfig: Sendable {
    let ruleSet: HandRuleSet
    let lives: Int
    /// 初始掉落速度（點 / 秒）。
    let fallSpeed: CGFloat
    /// 初始生成間隔（秒）。
    let spawnInterval: Double
    /// 玩家拳型自動輪替的間隔（秒）。
    let handSwapInterval: Double
    let powerUpsEnabled: Bool
    let showsRuleChart: Bool

    // MARK: - 單局內隨時間遞增（不設難度上限）

    /// 每存活這麼多秒套用一次遞增。
    var rampPeriod: Double { 20 }
    /// 每次遞增的掉落速度倍率。無上限，撐越久越快。
    var speedRampFactor: CGFloat { 1.09 }
    /// 每次遞增的生成間隔倍率。無上限，撐越久越密。
    var spawnRampFactor: Double { 0.91 }
    /// 生成間隔的安全下限。這不是難度上限，只是避免每一幀都生成把遊戲壓垮。
    var spawnSafetyFloor: Double { 0.08 }
}
