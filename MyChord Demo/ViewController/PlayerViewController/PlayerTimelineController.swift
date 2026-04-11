//
//  PlayerTimelineController.swift
//  MyChord Demo
//
//  Created by Chan Hwi Park on 4/6/26.
//

import UIKit

final class PlayerTimelineController {

    private(set) var chordTimeline: [ChordTimelineEntry] = []
    private(set) var currentChordIndex: Int?

    // MARK: - Timeline

    func applyTimeline(_ timeline: [ChordTimelineEntry]) {
        chordTimeline = timeline.sorted { $0.timeMs < $1.timeMs }
        currentChordIndex = nil
    }

    func loadDemoTimelineIfEmpty(durationSeconds: Double) {
        guard chordTimeline.isEmpty else { return }
        let duration = durationSeconds > 0 ? durationSeconds : 180
        applyTimeline(ChordTimelineDemo.makeDemoTimeline(durationSeconds: duration))
    }

    // MARK: - Chord Index Calculation (binary search)

    func chordIndex(for currentMs: Int) -> Int {
        var low = 0
        var high = chordTimeline.count - 1
        var result = 0

        while low <= high {
            let mid = (low + high) / 2
            if chordTimeline[mid].timeMs <= currentMs {
                result = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        return result
    }

    /// Returns the new index if it changed, nil otherwise.
    func updateCurrentIndex(for currentSeconds: Double) -> Int? {
        guard !chordTimeline.isEmpty else { return nil }
        let currentMs = Int(currentSeconds * 1000)
        let index = chordIndex(for: currentMs)
        guard index != currentChordIndex else { return nil }
        currentChordIndex = index
        return index
    }

    // MARK: - Time Formatting

    static func formatTime(seconds: Double) -> String {
        let totalSeconds = max(0, Int(seconds))
        let minutes = totalSeconds / 60
        let secondsPart = totalSeconds % 60
        return String(format: "%d:%02d", minutes, secondsPart)
    }
}
