//
//  ContentView.swift
//  XOArena
//

import SwiftUI

struct ContentView: View {
    @State private var gameViewModel = GameViewModel()
    @State private var showGame = false
    @State private var selectedDuration: GameDuration = .oneMinute
    @StateObject private var themeManager = SGThemeManager()

    /// Mirrors **`@AppStorage("showIntro")`** for first-frame routing (see **`ContentView.readInitialShowSplash()`**).
    @State private var showSplash: Bool

    private var tintColor: Color {
        XOTheme.tokens(for: themeManager.mode).accentSubtle
    }

    init() {
        _showSplash = State(initialValue: Self.readInitialShowSplash())
    }

    private static func readInitialShowSplash() -> Bool {
        let key = "showIntro"
        if UserDefaults.standard.object(forKey: key) == nil { return true }
        return UserDefaults.standard.bool(forKey: key)
    }

    var body: some View {
        Group {
            if showSplash {
                IntroView {
                    showSplash = false
                }
                .transition(.opacity)
            } else {
                NavigationStack {
                    MainMenuView(
                        selectedDuration: $selectedDuration,
                        aiDifficulty: Binding(
                            get: { gameViewModel.aiDifficulty },
                            set: { gameViewModel.aiDifficulty = $0 }
                        ),
                        menuPlayModeBias: gameViewModel.gameMode,
                        onPractice: { duration in
                            gameViewModel.selectDuration(duration)
                            gameViewModel.startNewGame(mode: .soloFocus, duration: duration)
                            showGame = true
                        },
                        onVsAI: { duration in
                            gameViewModel.selectDuration(duration)
                            gameViewModel.startNewGame(mode: .vsAI, duration: duration)
                            showGame = true
                        },
                        onLearning: { duration in
                            gameViewModel.selectDuration(duration)
                            gameViewModel.startNewGame(mode: .learning, duration: duration)
                            showGame = true
                        },
                        onLocalDuel: { duration in
                            gameViewModel.selectDuration(duration)
                            gameViewModel.startNewGame(mode: .localDuel, duration: duration)
                            showGame = true
                        },
                        onAiVsAITest: { duration in
#if DEBUG
                            gameViewModel.selectDuration(duration)
                            gameViewModel.startNewGame(mode: .aiVsAI, duration: duration)
                            showGame = true
#else
                            _ = duration
#endif
                        }
                    )
                    .navigationDestination(isPresented: $showGame) {
                        GameView(viewModel: gameViewModel)
                    }
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.26), value: showSplash)
        .environment(\.sgThemeMode, themeManager.mode)
        .environmentObject(themeManager)
        .tint(tintColor)
        .sgToolbarStyle()
    }
}

#Preview {
    ContentView()
}
