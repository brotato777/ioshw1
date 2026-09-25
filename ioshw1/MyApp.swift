import SwiftUI

@main struct MyApp: App {
    @State private var highScores = HighScoreStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(highScores)
        }
    }
}
