//
//  OfflineSongCacheManager.swift
//  MyChord Demo
//
//  Created by Chan Hwi Park on 4/10/26.
//

import Foundation
import RealmSwift

final class OfflineSongCacheManager {

    static let shared = OfflineSongCacheManager()

    private init() {}

    private var realm: Realm {
        // swiftlint:disable:next force_try
        try! Realm()
    }

    // MARK: - Save

    func saveAnalyzedSong(
        videoId: String,
        title: String,
        artist: String,
        thumbnailURL: String,
        durationText: String,
        results: [AnalysisChordResult]
    ) {
        let realm = self.realm

        // 이미 존재하면 chords 갱신, 없으면 새로 저장
        if let existing = realm.object(ofType: RealmAnalyzedSong.self, forPrimaryKey: videoId) {
            try? realm.write {
                existing.title = title
                existing.artist = artist
                existing.thumbnailURL = thumbnailURL
                existing.durationText = durationText
                existing.analyzedAt = Date()
                existing.lastViewedAt = Date()
                existing.isOfflineAvailable = true
                existing.chords.removeAll()
                for chord in results {
                    let entry = RealmChordEntry()
                    entry.timeMs = chord.timeMs
                    entry.chord = chord.chord
                    entry.confidence = chord.confidence ?? 0.0
                    existing.chords.append(entry)
                }
            }
        } else {
            let song = RealmAnalyzedSong.from(
                videoId: videoId,
                title: title,
                artist: artist,
                thumbnailURL: thumbnailURL,
                durationText: durationText,
                results: results
            )
            try? realm.write {
                realm.add(song)
            }
        }
    }

    // MARK: - Fetch

    func fetchSong(videoId: String) -> RealmAnalyzedSong? {
        return realm.object(ofType: RealmAnalyzedSong.self, forPrimaryKey: videoId)
    }

    /// lastViewedAt desc 정렬
    /// 사용자가 "가장 최근에 본 곡"을 상단에서 바로 접근할 수 있어야 하므로
    /// analyzedAt보다 lastViewedAt이 더 적절하다.
    /// (같은 곡을 여러 번 열면 analyzedAt은 변하지 않지만 lastViewedAt은 갱신된다)
    func fetchRecentSongs(limit: Int = 50) -> [RealmAnalyzedSong] {
        let results = realm.objects(RealmAnalyzedSong.self)
            .sorted(byKeyPath: "lastViewedAt", ascending: false)
        return Array(results.prefix(limit))
    }

    // MARK: - Query

    func isSongCached(videoId: String) -> Bool {
        return realm.object(ofType: RealmAnalyzedSong.self, forPrimaryKey: videoId) != nil
    }

    // MARK: - Delete

    func deleteSong(videoId: String) {
        let realm = self.realm
        guard let song = realm.object(ofType: RealmAnalyzedSong.self, forPrimaryKey: videoId) else { return }
        try? realm.write {
            realm.delete(song.chords)
            realm.delete(song)
        }
    }

    // MARK: - Touch (lastViewedAt 갱신)

    func touchSong(videoId: String) {
        let realm = self.realm
        guard let song = realm.object(ofType: RealmAnalyzedSong.self, forPrimaryKey: videoId) else { return }
        try? realm.write {
            song.lastViewedAt = Date()
        }
    }
}
