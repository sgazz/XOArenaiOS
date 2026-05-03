//
//  WatchHaptics.swift
//  XOArenaWatch
//

#if os(watchOS)
import WatchKit
#endif

enum WatchHaptics {
    static func move() {
        #if os(watchOS)
        WKInterfaceDevice.current().play(.click)
        #endif
    }

    static func boardWin(forHuman: Bool) {
        #if os(watchOS)
        WKInterfaceDevice.current().play(forHuman ? .success : .failure)
        #endif
    }

    static func drawBoard() {
        #if os(watchOS)
        WKInterfaceDevice.current().play(.directionUp)
        #endif
    }

    static func matchEnd() {
        #if os(watchOS)
        WKInterfaceDevice.current().play(.notification)
        #endif
    }

    static func invalid() {
        #if os(watchOS)
        WKInterfaceDevice.current().play(.directionDown)
        #endif
    }
}
