//
//  WatchHaptics.swift
//  XOArenaWatch — quiet “tick” layer (WKHapticType, no symbolic `.light` in SDK → **`.click`**).
//

#if os(watchOS)
import WatchKit
#endif

enum WatchHaptics {
    /// General tap (**play / cancel / intro** …) — **`click`** (~light tick).
    static func tapLight() {
        #if os(watchOS)
        print("[XOArenaWatch] HAPTIC_TAP")
        WKInterfaceDevice.current().play(.click)
        #endif
    }

    /// AI čini potez — isti kao tap, uz kratak pomak (**~30 ms**) da sleže prirodno uz UI.
    static func aiMoveLightDelayed() {
        #if os(watchOS)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
            print("[XOArenaWatch] HAPTIC_AI_MOVE")
            WKInterfaceDevice.current().play(.click)
        }
        #endif
    }

    /// Jedan slab +1 ili nerešeno (**bez duplog** kad ide preview/scroll traka).
    static func slabOutcomeTick() {
        #if os(watchOS)
        WKInterfaceDevice.current().play(.click)
        #endif
    }

    /// Nelegalan potez — mekši od starog **`directionDown`**.
    static func invalid() {
        #if os(watchOS)
        WKInterfaceDevice.current().play(.click)
        #endif
    }

    /// Kraj utakmice (**jedan** puls na End ekranu): pobeda **`success`**, ostalo **`click`**.
    static func matchOutcome(isHumanAhead: Bool, isTie: Bool) {
        #if os(watchOS)
        if isTie {
            print("[XOArenaWatch] HAPTIC_END_SOFT")
            WKInterfaceDevice.current().play(.click)
        } else if isHumanAhead {
            print("[XOArenaWatch] HAPTIC_END_WIN")
            WKInterfaceDevice.current().play(.success)
        } else {
            print("[XOArenaWatch] HAPTIC_END_SOFT")
            WKInterfaceDevice.current().play(.click)
        }
        #endif
    }

    static func userMoveLight() { tapLight() }
}
