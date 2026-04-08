//
//  ChordTimelineDemo.swift
//  MyChord Demo
//
//  Created by Chan Hwi Park on 4/6/26.
//

import Foundation

struct ChordTimelineEntry {
    let timeMs: Int
    let chord: String
}

enum ChordTimelineDemo {

    static func makeDemoTimeline(durationSeconds: Double, maxEntries: Int = 80) -> [ChordTimelineEntry] {
        let durationMs = max(1, Int(durationSeconds * 1000))
        let chords = [
            "Cmaj", "Dmaj", "Emaj", "Fmaj", "Gmaj", "Amaj", "Bmaj",
            "Cmin", "Dmin", "Emin", "Fmin", "Gmin", "Amin", "Bmin",
            "C7", "D7", "E7", "F7", "G7", "A7", "B7",
            "Cmaj7", "Dmaj7", "Emaj7", "Fmaj7", "Gmaj7", "Amaj7", "Bmaj7",
            "Csus4", "Dsus4", "Esus4", "Fsus4", "Gsus4", "Asus4", "Bsus4"
        ]

        var entries: [ChordTimelineEntry] = []
        var currentMs = 0
        while currentMs < durationMs && entries.count < maxEntries {
            let chord = chords.randomElement() ?? "Cmaj"
            entries.append(ChordTimelineEntry(timeMs: currentMs, chord: chord))
            let delta = Int.random(in: 700...1500)
            currentMs += delta
        }

        if entries.isEmpty {
            entries.append(ChordTimelineEntry(timeMs: 0, chord: "Cmaj"))
        }

        return entries
    }
}
