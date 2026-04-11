//
//  MainAnalysisFlowController.swift
//  MyChord Demo
//
//  Created by Chan Hwi Park on 4/6/26.
//

import Foundation

final class MainAnalysisFlowController {

    typealias LoadingStateHandler = @Sendable (AnalysisLoadingOverlayView.AnalysisLoadingDisplayState) async -> Void
    typealias AnalysisStateUpdater = @MainActor (String, AnalysisAvailabilityState) -> Void

    private var analysisTask: Task<Void, Never>?
    private(set) var activeAnalysisVideoID: String?

    var isRunning: Bool { analysisTask != nil }

    struct AnalysisFlowResult {
        let analysisResult: AnalysisResultResponse
        let timeline: [ChordTimelineEntry]
    }

    // MARK: - Start Analysis

    func start(
        for item: VideoItemViewModel,
        stateUpdater: @escaping AnalysisStateUpdater,
        onLoadingState: @escaping @MainActor (AnalysisLoadingOverlayView.AnalysisLoadingDisplayState) -> Void,
        onSuccess: @escaping @MainActor (VideoItemViewModel, AnalysisFlowResult) -> Void,
        onError: @escaping @MainActor (VideoItemViewModel, Error) -> Void
    ) {
        guard analysisTask == nil else { return }

        analysisTask = Task { [weak self] in
            guard let self else { return }

            await MainActor.run {
                self.activeAnalysisVideoID = item.videoId
                onLoadingState(.checkingCache)
            }

            do {
                let result = try await self.resolveAnalysisResult(
                    for: item,
                    stateUpdater: stateUpdater
                ) { state in
                    await MainActor.run {
                        onLoadingState(state)
                    }
                }
                let timeline = result.results.toChordTimelineEntries()
                let flowResult = AnalysisFlowResult(analysisResult: result, timeline: timeline)

                await MainActor.run {
                    onLoadingState(.completed)
                    onSuccess(item, flowResult)
                }
            } catch {
                await MainActor.run {
                    onError(item, error)
                }
            }

            await MainActor.run {
                self.analysisTask = nil
                self.activeAnalysisVideoID = nil
            }
        }
    }

    func cancel() {
        analysisTask?.cancel()
        analysisTask = nil
        activeAnalysisVideoID = nil
    }

    // MARK: - Resolve Analysis

    private func resolveAnalysisResult(
        for item: VideoItemViewModel,
        stateUpdater: @escaping AnalysisStateUpdater,
        statusHandler: @escaping LoadingStateHandler
    ) async throws -> AnalysisResultResponse {
        switch item.analysisState {
        case .available:
            await statusHandler(.preparingCached)
            return try await MusicAnalysisAPIService.shared.fetchResult(videoID: item.videoId)
        case .analyzing(_, let jobID):
            await statusHandler(.analyzing(progress: nil))
            if let jobID {
                return try await pollAnalysisStatus(
                    jobID: jobID,
                    videoID: item.videoId,
                    stateUpdater: stateUpdater,
                    statusHandler: statusHandler
                )
            }
            fallthrough
        case .unknown, .checking, .unavailable:
            await statusHandler(.checkingCache)
            let youtubeURL = "https://www.youtube.com/watch?v=\(item.videoId)"
            let response = try await MusicAnalysisAPIService.shared.analyze(youtubeURL: youtubeURL)
            return try await handleAnalyzeResponse(
                response,
                videoID: item.videoId,
                stateUpdater: stateUpdater,
                statusHandler: statusHandler
            )
        }
    }

    private func handleAnalyzeResponse(
        _ response: AnalyzeResponse,
        videoID: String,
        stateUpdater: @escaping AnalysisStateUpdater,
        statusHandler: @escaping LoadingStateHandler
    ) async throws -> AnalysisResultResponse {
        if let results = response.results, !results.isEmpty {
            await MainActor.run { stateUpdater(videoID, .available) }
            await statusHandler(.finalizing)
            return AnalysisResultResponse(videoId: response.videoId, video: response.video, results: results)
        }

        if response.cached == true {
            await statusHandler(.preparingCached)
            return try await MusicAnalysisAPIService.shared.fetchResult(videoID: response.videoId)
        }

        if let jobID = response.jobId {
            await MainActor.run {
                stateUpdater(videoID, .analyzing(progress: response.progress, jobID: jobID))
            }
            if let status = response.status {
                await statusHandler(AnalysisDisplayStateMapper.displayState(for: status, progress: response.progress))
            } else {
                await statusHandler(.pending)
            }
            return try await pollAnalysisStatus(
                jobID: jobID,
                videoID: response.videoId,
                stateUpdater: stateUpdater,
                statusHandler: statusHandler
            )
        }

        throw AnalysisFlowError.missingJob
    }

    // MARK: - Polling

    private func pollAnalysisStatus(
        jobID: Int,
        videoID: String,
        stateUpdater: @escaping AnalysisStateUpdater,
        statusHandler: @escaping LoadingStateHandler
    ) async throws -> AnalysisResultResponse {
        let startTime = Date()
        let timeout: TimeInterval = 300
        let interval: UInt64 = 1_000_000_000

        while true {
            let status = try await MusicAnalysisAPIService.shared.fetchStatus(jobID: jobID)
            await statusHandler(AnalysisDisplayStateMapper.displayState(for: status.status, progress: status.progress))

            if status.status == "complete" {
                await MainActor.run { stateUpdater(videoID, .available) }
                await statusHandler(.completed)
                return try await MusicAnalysisAPIService.shared.fetchResult(videoID: videoID)
            }

            if status.status == "fail" {
                let message = status.error?.message ?? "분석에 실패했습니다."
                throw AnalysisFlowError.failedStatus(message: message)
            }

            await MainActor.run {
                stateUpdater(videoID, .analyzing(progress: status.progress, jobID: jobID))
            }

            if Date().timeIntervalSince(startTime) > timeout {
                throw AnalysisFlowError.timeout
            }

            try await Task.sleep(nanoseconds: interval)
        }
    }
}
