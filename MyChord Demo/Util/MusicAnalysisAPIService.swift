//
//  MusicAnalysisAPIService.swift
//  MyChord Demo
//
//  Created by Chan Hwi Park on 4/6/26.
//

import Foundation
import Alamofire

final class MusicAnalysisAPIService {

    static let shared = MusicAnalysisAPIService()

    enum ConnectionError: LocalizedError {
        case disabled

        var errorDescription: String? {
            switch self {
            case .disabled:
                return "서버 연결이 꺼져 있습니다. 설정에서 켜주세요."
            }
        }
    }

    private enum API {
        static let baseURL = "http://192.168.0.12:3000"
        static let check = "/videos/check"
        static let analyze = "/analyze"
        static let status = "/status"
        static let result = "/result"
    }

    private init() {}

    func checkAnalyzed(videoIDs: [String]) async throws -> [VideoAnalysisAvailability] {
        try ensureConnectionEnabled()
        let url = API.baseURL + API.check
        let parameters: Parameters = ["video_ids": videoIDs]
        return try await NetworkManager.shared.post(url, parameters: parameters)
    }

    func analyze(youtubeURL: String) async throws -> AnalyzeResponse {
        try ensureConnectionEnabled()
        let url = API.baseURL + API.analyze
        let parameters: Parameters = ["youtube_url": youtubeURL]
        return try await NetworkManager.shared.post(url, parameters: parameters)
    }

    func fetchStatus(jobID: Int) async throws -> AnalysisJobStatusResponse {
        try ensureConnectionEnabled()
        let url = API.baseURL + API.status + "/\(jobID)"
        return try await NetworkManager.shared.get(url)
    }

    func fetchResult(videoID: String) async throws -> AnalysisResultResponse {
        try ensureConnectionEnabled()
        let url = API.baseURL + API.result + "/\(videoID)"
        return try await NetworkManager.shared.get(url)
    }

    private func ensureConnectionEnabled() throws {
        guard SettingsStore.isServerConnectionEnabled else {
            throw ConnectionError.disabled
        }
    }
}
