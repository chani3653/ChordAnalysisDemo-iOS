//
//  MainSearchHandler.swift
//  MyChord Demo
//
//  Created by Chan Hwi Park on 4/6/26.
//

import Foundation

final class MainSearchHandler {

    private(set) var videoItems: [VideoItemViewModel] = []
    private(set) var isLoadingMore = false
    private(set) var hasMorePages = true
    private(set) var hasSearched = false

    private var currentQuery: String?
    private var nextPageToken: String?
    private var checkedVideoIDs: Set<String> = []

    private var useDummyData: Bool { SettingsStore.isDummyDataEnabled }

    // MARK: - Public

    var currentSearchQuery: String? { currentQuery }

    func reset() {
        videoItems = []
        nextPageToken = nil
        hasMorePages = true
        checkedVideoIDs.removeAll()
        currentQuery = nil
        hasSearched = false
        isLoadingMore = false
    }

    func setQuery(_ query: String) {
        currentQuery = query
    }

    func updateAnalysisState(for videoID: String, to state: AnalysisAvailabilityState) -> Int? {
        guard let index = videoItems.firstIndex(where: { $0.videoId == videoID }) else { return nil }
        videoItems[index].analysisState = state
        return index
    }

    // MARK: - Load More

    func loadMore() async throws {
        guard let query = currentQuery, !isLoadingMore, hasMorePages else { return }

        if useDummyData {
            loadMoreDummy(query: query)
            return
        }

        isLoadingMore = true

        do {
            let response = try await APIService.shared.searchYouTube(
                query: query, pageToken: nextPageToken
            )

            nextPageToken = response.nextPageToken
            if response.nextPageToken == nil { hasMorePages = false }

            let searchItems = response.items.filter { $0.id.videoIdValue != nil }
            let videoIds = searchItems.compactMap { $0.id.videoIdValue }

            if !videoIds.isEmpty {
                let detailsResponse = try await APIService.shared.fetchVideoDetails(videoIds: videoIds)
                var durationSecondsById: [String: Int] = [:]
                var durationTextById: [String: String] = [:]
                for item in detailsResponse.items {
                    guard let id = item.id else { continue }
                    durationSecondsById[id] = YouTubeDurationParser.parseToSeconds(item.contentDetails?.duration)
                    durationTextById[id] = YouTubeDurationParser.format(item.contentDetails?.duration)
                }

                let newItems = searchItems.compactMap { item -> VideoItemViewModel? in
                    let id = item.id.videoIdValue ?? ""
                    guard let seconds = durationSecondsById[id],
                          seconds >= 60, seconds < 420 else { return nil }
                    let durationText = durationTextById[id] ?? ""
                    return VideoItemViewModel(
                        searchItem: item,
                        videoId: id,
                        durationText: durationText,
                        analysisState: .checking
                    )
                }
                videoItems.append(contentsOf: newItems)

                let newVideoIDs = newItems.map { $0.videoId }
                Task {
                    await checkAnalysisAvailability(for: newVideoIDs)
                }
            }

            hasSearched = true
            isLoadingMore = false
        } catch {
            isLoadingMore = false
            hasMorePages = false
            throw error
        }
    }

    private func loadMoreDummy(query: String) {
        isLoadingMore = true

        let dummyItems = DummyYouTubeData.makeItems(query: query, count: DummyYouTubeData.demoVideos.count)
        let newItems = dummyItems.map {
            VideoItemViewModel(
                searchItem: $0.searchItem,
                videoId: $0.videoId,
                durationText: $0.durationText,
                analysisState: .checking
            )
        }
        videoItems.append(contentsOf: newItems)

        let newVideoIDs = newItems.map { $0.videoId }
        Task {
            await checkAnalysisAvailability(for: newVideoIDs)
        }

        hasMorePages = false
        hasSearched = true
        isLoadingMore = false
    }

    // MARK: - Analysis Availability Check

    private func checkAnalysisAvailability(for videoIDs: [String]) async {
        let uniqueIDs = Array(Set(videoIDs)).filter { !checkedVideoIDs.contains($0) }
        guard !uniqueIDs.isEmpty else { return }
        uniqueIDs.forEach { checkedVideoIDs.insert($0) }

        for id in uniqueIDs {
            _ = updateAnalysisState(for: id, to: .checking)
        }

        do {
            let results = try await withTimeout(seconds: 5) {
                try await MusicAnalysisAPIService.shared.checkAnalyzed(videoIDs: uniqueIDs)
            }
            for result in results {
                let state: AnalysisAvailabilityState = result.analyzed ? .available : .unavailable
                _ = updateAnalysisState(for: result.videoId, to: state)
            }
        } catch {
            for id in uniqueIDs {
                _ = updateAnalysisState(for: id, to: .unknown)
            }
        }
    }

    private func withTimeout<T>(
        seconds: Double,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                let duration = UInt64(seconds * 1_000_000_000)
                try await Task.sleep(nanoseconds: duration)
                throw AnalysisFlowError.timeout
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}
