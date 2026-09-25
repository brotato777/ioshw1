import SwiftUI

/// 畫面流程：標題 → 遊戲中（含暫停／結束）→ 回標題。
struct ContentView: View {
    @State private var activeDifficulty: Difficulty?

    var body: some View {
        if let difficulty = activeDifficulty {
            GameView(difficulty: difficulty) {
                activeDifficulty = nil
            }
            // 換難度重玩時換掉整個 GameView，確保引擎重新建立。
            .id(difficulty)
        } else {
            TitleView { difficulty in
                activeDifficulty = difficulty
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(HighScoreStore())
}
