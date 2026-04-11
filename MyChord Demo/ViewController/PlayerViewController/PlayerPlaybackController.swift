//
//  PlayerPlaybackController.swift
//  MyChord Demo
//
//  Created by Chan Hwi Park on 4/6/26.
//

import Foundation
import YouTubePlayerKit

final class PlayerPlaybackController {

    // MARK: - State

    private(set) var isPlaying = false
    private(set) var durationSeconds: Double?
    private var isSeeking = false
    private var playbackTimer: Timer?
    private var lastPlaybackStateCheck: Date?

    private var repeatState: RepeatState = .none
    private var repeatStartSeconds: Double?
    private var repeatEndSeconds: Double?

    private(set) var youTubePlayer: YouTubePlayer?

    enum RepeatState {
        case none
        case startSet
        case endSet
    }

    var currentRepeatState: RepeatState { repeatState }

    // MARK: - Callbacks

    var onPlaybackTimeUpdate: ((Double) -> Void)?
    var onPlayingStateChanged: ((Bool) -> Void)?
    var onDurationResolved: ((Double) -> Void)?

    // MARK: - Setup

    func setupPlayer(videoId: String) -> YouTubePlayer {
        let parameters = YouTubePlayer.Parameters(
            autoPlay: false,
            showControls: false,
            showFullscreenButton: false,
            showCaptions: false,
            restrictRelatedVideosToSameChannel: true
        )
        let player = YouTubePlayer(source: .video(id: videoId), parameters: parameters)
        youTubePlayer = player
        isPlaying = false
        onPlayingStateChanged?(false)
        startPlaybackTimer()
        Task {
            await updateDurationIfNeeded()
        }
        return player
    }

    // MARK: - Play/Pause

    func togglePlayPause() {
        Task {
            guard let youTubePlayer else { return }
            if isPlaying {
                try? await youTubePlayer.pause()
                isPlaying = false
            } else {
                try? await youTubePlayer.play()
                isPlaying = true
            }
            await MainActor.run {
                onPlayingStateChanged?(isPlaying)
            }
        }
    }

    // MARK: - Seek

    func seekBy(secondsDelta: Double) {
        Task {
            guard let youTubePlayer else { return }
            let currentValue = (try? await youTubePlayer.getCurrentTime())?.converted(to: .seconds).value ?? 0
            let durationValue = (try? await youTubePlayer.getDuration())?.converted(to: .seconds).value ?? durationSeconds ?? 0
            let target = max(0, min(currentValue + secondsDelta, durationValue))
            let targetTime = Measurement(value: target, unit: UnitDuration.seconds)
            try? await youTubePlayer.seek(to: targetTime, allowSeekAhead: true)
            await MainActor.run {
                onPlaybackTimeUpdate?(target)
            }
        }
    }

    func seekTo(seconds: Double) {
        Task {
            guard let youTubePlayer else { return }
            let targetTime = Measurement(value: seconds, unit: UnitDuration.seconds)
            try? await youTubePlayer.seek(to: targetTime, allowSeekAhead: true)
        }
    }

    func setIsSeeking(_ value: Bool) {
        isSeeking = value
    }

    // MARK: - Repeat

    func handleRepeatButtonTap() async -> (RepeatState, Double?, Double?) {
        guard let youTubePlayer else { return (repeatState, repeatStartSeconds, repeatEndSeconds) }
        let currentValue = (try? await youTubePlayer.getCurrentTime())?.converted(to: .seconds).value ?? 0

        switch repeatState {
        case .none:
            repeatStartSeconds = currentValue
            repeatEndSeconds = nil
            repeatState = .startSet
        case .startSet:
            repeatEndSeconds = max(currentValue, repeatStartSeconds ?? 0)
            repeatState = .endSet
            if let start = repeatStartSeconds {
                let startTime = Measurement(value: start, unit: UnitDuration.seconds)
                try? await youTubePlayer.seek(to: startTime, allowSeekAhead: true)
                if !isPlaying {
                    try? await youTubePlayer.play()
                    isPlaying = true
                    await MainActor.run { onPlayingStateChanged?(true) }
                }
            }
        case .endSet:
            repeatState = .none
            repeatStartSeconds = nil
            repeatEndSeconds = nil
        }

        return (repeatState, repeatStartSeconds, repeatEndSeconds)
    }

    func resetRepeat() {
        repeatState = .none
        repeatStartSeconds = nil
        repeatEndSeconds = nil
    }

    // MARK: - Timer

    func startPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { [weak self] in
                await self?.updatePlaybackTime()
            }
        }
    }

    func stopPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }

    // MARK: - Private

    private func updateDurationIfNeeded() async {
        guard let youTubePlayer else { return }
        if durationSeconds != nil { return }
        if let duration = try? await youTubePlayer.getDuration() {
            let durationValue = duration.converted(to: .seconds).value
            durationSeconds = durationValue
            await MainActor.run {
                onDurationResolved?(durationValue)
            }
        }
    }

    private func updatePlaybackTime() async {
        guard let youTubePlayer, !isSeeking else { return }
        if durationSeconds == nil {
            await updateDurationIfNeeded()
        }
        await updatePlaybackStateIfNeeded()
        if let currentTime = try? await youTubePlayer.getCurrentTime() {
            let currentValue = currentTime.converted(to: .seconds).value
            await MainActor.run {
                onPlaybackTimeUpdate?(currentValue)
            }
            await enforceRepeatIfNeeded(currentSeconds: currentValue)
        }
    }

    private func updatePlaybackStateIfNeeded() async {
        let now = Date()
        if let last = lastPlaybackStateCheck, now.timeIntervalSince(last) < 0.8 {
            return
        }
        lastPlaybackStateCheck = now

        guard let youTubePlayer else { return }
        if let info = try? await youTubePlayer.getInformation() {
            let playing = info.playerState == .playing
            if playing != isPlaying {
                isPlaying = playing
                await MainActor.run {
                    onPlayingStateChanged?(playing)
                }
            }
        }
    }

    private func enforceRepeatIfNeeded(currentSeconds: Double) async {
        guard repeatState == .endSet,
              let start = repeatStartSeconds,
              let end = repeatEndSeconds else { return }

        if currentSeconds >= end {
            let startTime = Measurement(value: start, unit: UnitDuration.seconds)
            try? await youTubePlayer?.seek(to: startTime, allowSeekAhead: true)
        }
    }
}
