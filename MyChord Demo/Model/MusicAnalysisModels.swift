//
//  MusicAnalysisModels.swift
//  MyChord Demo
//
//  Created by Chan Hwi Park on 4/6/26.
//

import Foundation

struct VideoAnalysisAvailability: Codable {
    let videoId: String
    let analyzed: Bool

    enum CodingKeys: String, CodingKey {
        case videoId = "video_id"
        case analyzed
    }
}

struct AnalyzeResponse: Codable {
    let cached: Bool?
    let videoId: String
    let video: AnalysisVideoMeta?
    let results: [AnalysisChordResult]?
    let jobId: Int?
    let status: String?
    let progress: Int?
    let reused: Bool?

    enum CodingKeys: String, CodingKey {
        case cached
        case videoId = "video_id"
        case video
        case results
        case jobId = "job_id"
        case status
        case progress
        case reused
    }
}

struct AnalysisJobStatusResponse: Codable {
    let jobId: Int
    let videoId: String
    let status: String
    let progress: Int
    let error: AnalysisErrorResponse?

    enum CodingKeys: String, CodingKey {
        case jobId = "job_id"
        case videoId = "video_id"
        case status
        case progress
        case error
    }
}

struct AnalysisErrorResponse: Codable, Error {
    let code: String
    let message: String
}

struct AnalysisResultResponse: Codable {
    let videoId: String
    let video: AnalysisVideoMeta?
    let results: [AnalysisChordResult]

    enum CodingKeys: String, CodingKey {
        case videoId = "video_id"
        case video
        case results
    }
}

struct AnalysisVideoMeta: Codable {
    let id: Int?
    let videoId: String?
    let title: String?
    let duration: Int?
    let thumbnail: String?
    let analyzed: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case videoId = "video_id"
        case title
        case duration
        case thumbnail
        case analyzed
    }
}

struct AnalysisChordResult: Codable {
    let timeMs: Int
    let chord: String
    let confidence: Double?

    enum CodingKeys: String, CodingKey {
        case timeMs = "time_ms"
        case chord
        case confidence
    }
}

extension Array where Element == AnalysisChordResult {
    func toChordTimelineEntries() -> [ChordTimelineEntry] {
        return map {
            ChordTimelineEntry(timeMs: $0.timeMs, chord: $0.chord, confidence: $0.confidence)
        }
    }
}
