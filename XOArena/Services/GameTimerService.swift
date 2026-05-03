//
//  GameTimerService.swift
//  XOArena
//

import Combine
import Dispatch
import Foundation

protocol GameTimerControlling: AnyObject {
    func start(
        seconds: Int,
        onTick: @escaping @Sendable (Int) -> Void,
        onFinished: @escaping @Sendable () -> Void
    )
    func stop()
}

/// Single global countdown ticker for a session. One running stream at a time.
final class GameTimerService: GameTimerControlling {
    private var timerCancellable: AnyCancellable?
    private var remainingSeconds: Int = 0

    func start(
        seconds: Int,
        onTick: @escaping @Sendable (Int) -> Void,
        onFinished: @escaping @Sendable () -> Void
    ) {
        stop()

        guard seconds > 0 else {
            onTick(0)
            onFinished()
            return
        }

#if DEBUG
        GameDebugLogger.timerStarted(secondsRemaining: seconds)
#endif

        remainingSeconds = seconds
        timerCancellable = Timer
            .publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.remainingSeconds -= 1
                let next = max(self.remainingSeconds, 0)
                onTick(next)
                if next == 0 {
                    self.stop()
                    onFinished()
                }
            }
    }

    func stop() {
#if DEBUG
        if timerCancellable != nil {
            GameDebugLogger.timerStopped()
        }
#endif
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    deinit {
        stop()
    }
}
