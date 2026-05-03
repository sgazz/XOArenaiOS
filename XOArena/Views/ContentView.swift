//
//  ContentView.swift
//  XOArena
//

import SwiftUI

struct ContentView: View {
    @State private var gameViewModel = GameViewModel()
    @State private var showGame = false
    @State private var showPvAISetup = false
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
                        onVsAI: {
                            showPvAISetup = true
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
                    .sheet(isPresented: $showPvAISetup) {
                        PvAISetupSheet { symbol, first in
                            gameViewModel.selectDuration(selectedDuration)
                            gameViewModel.startNewGame(
                                mode: .vsAI,
                                duration: selectedDuration,
                                pvaiHumanMark: symbol.mark,
                                pvaiFirstMover: first
                            )
                            showPvAISetup = false
                            showGame = true
                        }
                        .presentationDetents([.medium])
                        .presentationDragIndicator(.visible)
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
