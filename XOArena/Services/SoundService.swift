//
//  SoundService.swift
//  XOArena
//

import AVFoundation

/// Ultra-quiet cues for paper / graphite feel. Respects mute switch (**`ambient`** session).
@MainActor
final class SoundService {
    static let shared = SoundService()

    /// Prevents audible stacking (**`aiVsAI`**, turbo taps).
    private let minimumCueIntervalSeconds: CFTimeInterval = 0.10

    private var pencilPlayer: AVAudioPlayer?
    private var blockPlayer: AVAudioPlayer?
    private var completionPlayer: AVAudioPlayer?

    private var lastCuePlayTime: CFTimeInterval = 0

    private init() {
        configureAudioSessionIfNeeded()
        preloadAll()
    }

    private func configureAudioSessionIfNeeded() {
        let session = AVAudioSession.sharedInstance()
        do {
            // Mixes politely; honours hardware mute (**no override**).
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {}
    }

    private func preloadAll() {
        pencilPlayer = Self.loadPlayer(resource: "pencil", subdirectory: "Sounds", volume: 0.26)
        blockPlayer = Self.loadPlayer(resource: "block", subdirectory: "Sounds", volume: 0.28)
        completionPlayer = Self.loadPlayer(resource: "completion", subdirectory: "Sounds", volume: 0.32)

        pencilPlayer?.prepareToPlay()
        blockPlayer?.prepareToPlay()
        completionPlayer?.prepareToPlay()
    }

    private static func urlForBundledSound(_ name: String, subdirectory: String?) -> URL? {
        if let sub = subdirectory, let u = Bundle.main.url(forResource: name, withExtension: "wav", subdirectory: sub) {
            return u
        }
        return Bundle.main.url(forResource: name, withExtension: "wav")
    }

    private static func loadPlayer(resource: String, subdirectory: String, volume: Float) -> AVAudioPlayer? {
        guard let url = urlForBundledSound(resource, subdirectory: subdirectory) else {
            return nil
        }
        guard let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
        player.volume = volume
        player.enableRate = false
        player.numberOfLoops = 0
        return player
    }

    /// Valid human or AI slab placement (**not** Learning block‑reward — use **`playBlock()`**).
    func playPencil() {
        playCueStoppingOthers(pencilPlayer, respectsThrottle: true)
    }

    func playBlock() {
        playCueStoppingOthers(blockPlayer, respectsThrottle: true)
    }

    func playCompletion() {
        guard let completionPlayer else { return }
        stopMoveCuePlayers(resetPosition: true)
        completionPlayer.stop()
        completionPlayer.currentTime = 0
        _ = completionPlayer.prepareToPlay()
        completionPlayer.play()
        lastCuePlayTime = CFAbsoluteTimeGetCurrent()
    }

    private func stopMoveCuePlayers(resetPosition: Bool) {
        for player in [pencilPlayer, blockPlayer].compactMap({ $0 }) {
            player.stop()
            if resetPosition { player.currentTime = 0 }
        }
    }

    /// One cue at a time; optional throttle skips rapid‑fire (**AI vs AI**).
    private func playCueStoppingOthers(_ player: AVAudioPlayer?, respectsThrottle: Bool) {
        guard let player else { return }

        let now = CFAbsoluteTimeGetCurrent()
        if respectsThrottle, now - lastCuePlayTime < minimumCueIntervalSeconds {
            return
        }

        completionPlayer?.stop()
        completionPlayer?.currentTime = 0

        stopMoveCuePlayers(resetPosition: true)

        player.currentTime = 0
        _ = player.prepareToPlay()
        player.play()

        lastCuePlayTime = now
    }
}
