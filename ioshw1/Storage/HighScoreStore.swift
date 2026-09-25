import Foundation

/// 各難度各存一筆最高分。
@Observable
final class HighScoreStore {
    private let defaults: UserDefaults
    private var scores: [String: Int]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.scores = Dictionary(
            uniqueKeysWithValues: Difficulty.allCases.map {
                ($0.rawValue, defaults.integer(forKey: Self.key(for: $0)))
            }
        )
    }

    private static func key(for difficulty: Difficulty) -> String {
        "highScore.\(difficulty.rawValue)"
    }

    func highScore(for difficulty: Difficulty) -> Int {
        scores[difficulty.rawValue] ?? 0
    }

    /// 更新紀錄，回傳是否破了紀錄。
    @discardableResult
    func submit(_ score: Int, for difficulty: Difficulty) -> Bool {
        guard score > highScore(for: difficulty) else { return false }
        scores[difficulty.rawValue] = score
        defaults.set(score, forKey: Self.key(for: difficulty))
        return true
    }
}
