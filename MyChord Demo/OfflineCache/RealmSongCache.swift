//
//  RealmSongCache.swift
//  MyChord Demo
//
//  Created by Chan Hwi Park on 4/10/26.
//

import Foundation
import RealmSwift

// MARK: - Realm Models

class RealmChordEntry: Object {
    @Persisted var timeMs: Int = 0
    @Persisted var chord: String = ""
    @Persisted var confidence: Double = 0.0
}

class RealmAnalyzedSong: Object {
    @Persisted(primaryKey: true) var videoId: String = ""
    @Persisted var title: String = ""
    @Persisted var artist: String = ""
    @Persisted var thumbnailURL: String = ""
    @Persisted var durationText: String = ""
    @Persisted var youtubeURL: String = ""
    @Persisted var analyzedAt: Date = Date()
    @Persisted var lastViewedAt: Date = Date()
    @Persisted var isOfflineAvailable: Bool = true
    @Persisted var chords: List<RealmChordEntry>
}

// MARK: - Mappers: Server -> Realm

extension RealmAnalyzedSong {

    static func from(
        videoId: String,
        title: String,
        artist: String,
        thumbnailURL: String,
        durationText: String,
        results: [AnalysisChordResult]
    ) -> RealmAnalyzedSong {
        let song = RealmAnalyzedSong()
        song.videoId = videoId
        song.title = title
        song.artist = artist
        song.thumbnailURL = thumbnailURL
        song.durationText = durationText
        song.youtubeURL = "https://www.youtube.com/watch?v=\(videoId)"
        song.analyzedAt = Date()
        song.lastViewedAt = Date()
        song.isOfflineAvailable = true

        for chord in results {
            let entry = RealmChordEntry()
            entry.timeMs = chord.timeMs
            entry.chord = chord.chord
            entry.confidence = chord.confidence ?? 0.0
            song.chords.append(entry)
        }

        return song
    }
}

// MARK: - Mappers: Realm -> App Models

extension RealmAnalyzedSong {

    func toChordTimelineEntries() -> [ChordTimelineEntry] {
        return chords.map {
            ChordTimelineEntry(
                timeMs: $0.timeMs,
                chord: $0.chord,
                confidence: $0.confidence
            )
        }
    }
}
