import AVFoundation

/// 音效播放。
///
/// 接對得分會連續觸發，單一 player 重播會把前一聲切掉，
/// 所以預先建好一小組 player 輪流用，聲音才能疊著響。
@MainActor
final class SoundPlayer {
    static let shared = SoundPlayer()

    private var players: [AVAudioPlayer] = []
    private var nextIndex = 0
    private let voices = 4

    private init() {
        // .ambient：與其他 app 的聲音共存，也尊重使用者的靜音開關。
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        loadScoreSound()
    }

    private func loadScoreSound() {
        guard let url = Bundle.main.url(forResource: "score-coin", withExtension: "mp3") else {
            // 沒有音效檔就安靜地跳過，不要影響遊戲。
            return
        }
        players = (0..<voices).compactMap { _ in
            guard let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
            player.volume = 0.7
            player.prepareToPlay()
            return player
        }
    }

    /// 接對一顆的得分音效。
    func playScore() {
        guard !players.isEmpty else { return }
        let player = players[nextIndex]
        nextIndex = (nextIndex + 1) % players.count
        player.currentTime = 0
        player.play()
    }
}
