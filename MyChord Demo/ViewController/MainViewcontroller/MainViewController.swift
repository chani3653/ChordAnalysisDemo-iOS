//
//  MainViewController.swift
//  MyChord Demo
//
//  Created by Chan Hwi Park on 4/6/26.
//

import UIKit
import Alamofire

class MainViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var searchTextField: UITextField!
    @IBOutlet weak var searchButton: UIButton!
    @IBOutlet weak var textViewContainerView: UIView!
    @IBOutlet weak var textViewInnerContainerView: UIView!
    @IBOutlet weak var headerBlurView: UIVisualEffectView!

    enum AnalysisAvailabilityState: Equatable {
        case unknown
        case checking
        case available
        case unavailable
        case analyzing(progress: Int?, jobID: Int?)

        var statusText: String {
            switch self {
            case .unknown:
                return "확인 전"
            case .checking:
                return "확인중"
            case .available:
                return "분석됨"
            case .unavailable:
                return "미분석"
            case .analyzing(let progress, _):
                if let progress {
                    return "분석중 \(progress)%"
                }
                return "분석중"
            }
        }
    }

    struct VideoItemViewModel {
        let searchItem: YouTubeSearchItem
        let videoId: String
        let durationText: String
        var analysisState: AnalysisAvailabilityState
    }

    private enum AnalysisFlowError: LocalizedError {
        case missingJob
        case failedStatus(message: String)
        case timeout

        var errorDescription: String? {
            switch self {
            case .missingJob:
                return "분석 요청에 필요한 작업 정보가 없습니다."
            case .failedStatus(let message):
                return message
            case .timeout:
                return "분석이 일정 시간 내에 완료되지 않았습니다."
            }
        }
    }

    typealias LoadingStateHandler = @Sendable (AnalysisLoadingOverlayView.AnalysisLoadingDisplayState) async -> Void

    var videoItems: [VideoItemViewModel] = []
    private var hasSearched = false
    private(set) var isLoadingMore = false
    private var loadMoreTask: Task<Void, Never>?
    private var currentQuery: String?
    private var nextPageToken: String?
    private(set) var hasMorePages = true
    private var shortNextPageToken: String?
    private var mediumNextPageToken: String?
    private var shortHasMore = true
    private var mediumHasMore = true
    private var useDummyData: Bool { SettingsStore.isDummyDataEnabled }
    private let searchAreaHeight: CGFloat = 60
    private var lastDummySetting = SettingsStore.isDummyDataEnabled
    private var dummyItems: [DummyYouTubeData.DummyVideoItem] = []
    private var dummyIndex = 0
    private var checkedVideoIDs: Set<String> = []
    private lazy var analysisLoadingOverlay = AnalysisLoadingOverlayView()
    private lazy var errorOverlay = ErrorOverlayView()
    private var analysisTask: Task<Void, Never>?
    private var activeAnalysisVideoID: String?

    override func viewDidLoad() {
        super.viewDidLoad()

        setViews()
        lastDummySetting = useDummyData

        if useDummyData {
            currentQuery = DummyYouTubeData.defaultQuery
            startLoadMore()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        applyDummySettingIfNeeded()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        if tableView.contentInset.top != searchAreaHeight {
            tableView.contentInset.top = searchAreaHeight
            tableView.scrollIndicatorInsets.top = searchAreaHeight
        }
    }

    private func setViews() {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.contentInset = .zero
        tableView.scrollIndicatorInsets = .zero
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "LoadingIndicatorCell")
        updateLoadingFooter()

        searchTextField.delegate = self
        searchTextField.returnKeyType = .search

        textViewContainerView.layer.cornerRadius = 12
        textViewInnerContainerView.layer.cornerRadius = 10

        headerBlurView.layer.shadowColor = UIColor.black.cgColor
        headerBlurView.layer.shadowOpacity = 0.2
        headerBlurView.layer.shadowOffset = CGSize(width: 0, height: 4)
        headerBlurView.layer.shadowRadius = 8
        headerBlurView.layer.masksToBounds = false
    }

    private func applyDummySettingIfNeeded() {
        let currentSetting = useDummyData
        guard currentSetting != lastDummySetting else { return }
        lastDummySetting = currentSetting

        resetSearchState()
        tableView.reloadData()

        if currentSetting {
            currentQuery = DummyYouTubeData.defaultQuery
            startLoadMore()
        }
    }

    private func resetSearchState() {
        videoItems = []
        shortNextPageToken = nil
        mediumNextPageToken = nil
        shortHasMore = true
        mediumHasMore = true
        hasMorePages = true
        dummyItems = []
        dummyIndex = 0
        checkedVideoIDs.removeAll()
        currentQuery = nil
        hasSearched = false
        isLoadingMore = false
    }

    @MainActor
    func startLoadMore() {
        guard loadMoreTask == nil else { return }
        loadMoreTask = Task { [weak self] in
            guard let self else { return }
            await self.loadMore()
            await MainActor.run {
                self.loadMoreTask = nil
            }
        }
    }

    // MARK: - Actions

    @IBAction func searchButtonTapped(_ sender: UIButton) {
        performSearch()
    }

    func performSearch() {
        let rawQuery = searchTextField.text ?? ""
        let trimmedQuery = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return }
        searchTextField.resignFirstResponder()

        resetSearchState()
        currentQuery = trimmedQuery
        Task { @MainActor in
            tableView.reloadData()
        }

        startLoadMore()
    }

    func loadMore() async {
        guard let query = currentQuery, !isLoadingMore, hasMorePages else { return }

        if useDummyData {
            await loadMoreDummy(query: query)
            return
        }

        isLoadingMore = true
        await MainActor.run {
            tableView.reloadData()
        }

        do {
            // async let + Alamofire 조합은 task 취소 시 메모리 오염을 유발하므로
            // withThrowingTaskGroup으로 short/medium 병렬 요청
            let capturedShortToken = shortNextPageToken
            let capturedMediumToken = mediumNextPageToken

            var shortResponse: YouTubeSearchResponse?
            var mediumResponse: YouTubeSearchResponse?

            try await withThrowingTaskGroup(of: (Bool, YouTubeSearchResponse).self) { group in
                if shortHasMore {
                    group.addTask {
                        let result = try await APIService.shared.searchYouTube(
                            query: query, videoDuration: "short", pageToken: capturedShortToken
                        )
                        return (true, result)
                    }
                }
                if mediumHasMore {
                    group.addTask {
                        let result = try await APIService.shared.searchYouTube(
                            query: query, videoDuration: "medium", pageToken: capturedMediumToken
                        )
                        return (false, result)
                    }
                }
                for try await (isShort, response) in group {
                    if isShort { shortResponse = response }
                    else { mediumResponse = response }
                }
            }

            if let shortResponse {
                shortNextPageToken = shortResponse.nextPageToken
                if shortResponse.nextPageToken == nil { shortHasMore = false }
            }
            if let mediumResponse {
                mediumNextPageToken = mediumResponse.nextPageToken
                if mediumResponse.nextPageToken == nil { mediumHasMore = false }
            }

            var allSearchItems: [YouTubeSearchItem] = []
            if let shortResponse { allSearchItems.append(contentsOf: shortResponse.items) }
            if let mediumResponse { allSearchItems.append(contentsOf: mediumResponse.items) }

            let searchItems = allSearchItems.filter { $0.id.videoIdValue != nil }
            let videoIds = searchItems.compactMap { $0.id.videoIdValue }

            if !videoIds.isEmpty {
                let detailsResponse = try await APIService.shared.fetchVideoDetails(videoIds: videoIds)
                var durationSecondsById: [String: Int] = [:]
                var durationTextById: [String: String] = [:]
                for item in detailsResponse.items {
                    guard let id = item.id else { continue }
                    durationSecondsById[id] = parseDurationToSeconds(item.contentDetails?.duration)
                    durationTextById[id] = formatDuration(item.contentDetails?.duration)
                }

                // Filter: 1min (60s) <= duration <= 7min (420s)
                let newItems = searchItems.compactMap { item -> VideoItemViewModel? in
                    let id = item.id.videoIdValue ?? ""
                    guard let seconds = durationSecondsById[id],
                          seconds >= 60, seconds <= 420 else { return nil }
                    let durationText = durationTextById[id] ?? ""
                    return VideoItemViewModel(
                        searchItem: item,
                        videoId: id,
                        durationText: durationText,
                        analysisState: .checking
                    )
                }
                videoItems.append(contentsOf: newItems)
                Task {
                    await checkAnalysisAvailability(for: newItems.map { $0.videoId })
                }
            }

            hasMorePages = shortHasMore || mediumHasMore
            hasSearched = true
        } catch {
            print("[loadMore] ❌ 오류 발생")
            print("[loadMore] 설명: \(error.localizedDescription)")
            print("[loadMore] 전체 오류: \(error)")
            if let afError = error as? AFError {
                print("[loadMore] AFError: \(afError)")
                if let underlying = afError.underlyingError {
                    print("[loadMore] 내부 오류: \(underlying)")
                }
                if let urlError = afError.underlyingError as? URLError {
                    print("[loadMore] URLError 코드: \(urlError.code.rawValue) - \(urlError.localizedDescription)")
                }
            } else if let urlError = error as? URLError {
                print("[loadMore] URLError 코드: \(urlError.code.rawValue) - \(urlError.localizedDescription)")
            }
            shortHasMore = false
            mediumHasMore = false
            hasMorePages = false
            await MainActor.run { showErrorAlert(error) }
        }

        isLoadingMore = false
        await MainActor.run {
            tableView.reloadData()
        }
    }

    private func loadMoreDummy(query: String) async {
        isLoadingMore = true
//        updateLoadingFooter()
        await MainActor.run {
            tableView.reloadData()
        }

        if dummyItems.isEmpty {
            dummyItems = DummyYouTubeData.makeItems(query: query, count: DummyYouTubeData.totalCount)
            dummyIndex = 0
        }

        let nextIndex = min(dummyIndex + DummyYouTubeData.pageSize, dummyItems.count)
        if dummyIndex < nextIndex {
            let newItems = dummyItems[dummyIndex..<nextIndex].map {
                VideoItemViewModel(
                    searchItem: $0.searchItem,
                    videoId: $0.videoId,
                    durationText: $0.durationText,
                    analysisState: .checking
                )
            }
            videoItems.append(contentsOf: newItems)
            Task {
                await checkAnalysisAvailability(for: newItems.map { $0.videoId })
            }
            dummyIndex = nextIndex
        }

        hasMorePages = dummyIndex < dummyItems.count
        hasSearched = true
        isLoadingMore = false
//        updateLoadingFooter()
        await MainActor.run {
            tableView.reloadData()
        }
    }

    @MainActor
    private func updateAnalysisState(for videoID: String, to state: AnalysisAvailabilityState) {
        guard let index = videoItems.firstIndex(where: { $0.videoId == videoID }) else { return }
        videoItems[index].analysisState = state
        let currentRowCount = tableView.numberOfRows(inSection: 0)
        if index >= currentRowCount || currentRowCount != videoItems.count {
            tableView.reloadData()
            return
        }
        tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .none)
    }

    private func checkAnalysisAvailability(for videoIDs: [String]) async {
        let uniqueIDs = Array(Set(videoIDs)).filter { !checkedVideoIDs.contains($0) }
        guard !uniqueIDs.isEmpty else { return }
        uniqueIDs.forEach { checkedVideoIDs.insert($0) }

        await MainActor.run {
            uniqueIDs.forEach { updateAnalysisState(for: $0, to: .checking) }
        }

        do {
            let results = try await withTimeout(seconds: 5) {
                try await MusicAnalysisAPIService.shared.checkAnalyzed(videoIDs: uniqueIDs)
            }
            await MainActor.run {
                for result in results {
                    let state: AnalysisAvailabilityState = result.analyzed ? .available : .unavailable
                    updateAnalysisState(for: result.videoId, to: state)
                }
            }
        } catch {
            await MainActor.run {
                uniqueIDs.forEach { updateAnalysisState(for: $0, to: .unknown) }
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

    private func makeYouTubeURL(for videoID: String) -> String {
        return "https://www.youtube.com/watch?v=\(videoID)"
    }

    func startAnalysisFlow(for item: VideoItemViewModel) {
        guard analysisTask == nil else { return }

        analysisTask = Task { [weak self] in
            guard let self else { return }

            await MainActor.run {
                self.activeAnalysisVideoID = item.videoId
                self.analysisLoadingOverlay.show(in: self.view)
                self.analysisLoadingOverlay.update(state: .checkingCache)
            }

            do {
                let result = try await self.resolveAnalysisResult(for: item) { state in
                    await MainActor.run {
                        self.analysisLoadingOverlay.update(state: state)
                    }
                }
                let timeline = result.results.toChordTimelineEntries()
                await MainActor.run {
                    self.analysisLoadingOverlay.update(state: .completed)
                    self.analysisLoadingOverlay.hide()
                    self.presentPlayer(for: item, timeline: timeline)
                }
            } catch {
                await MainActor.run {
                    self.analysisLoadingOverlay.hide()
                    self.showErrorAlert(error)
                }
            }

            await MainActor.run {
                self.analysisTask = nil
                self.activeAnalysisVideoID = nil
            }
        }
    }

    func resolveAnalysisResult(
        for item: VideoItemViewModel,
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
                    statusHandler: statusHandler
                )
            }
            fallthrough
        case .unknown, .checking, .unavailable:
            await statusHandler(.checkingCache)
            let response = try await MusicAnalysisAPIService.shared.analyze(youtubeURL: makeYouTubeURL(for: item.videoId))
            return try await handleAnalyzeResponse(
                response,
                videoID: item.videoId,
                statusHandler: statusHandler
            )
        }
    }

    private func handleAnalyzeResponse(
        _ response: AnalyzeResponse,
        videoID: String,
        statusHandler: @escaping LoadingStateHandler
    ) async throws -> AnalysisResultResponse {
        if let results = response.results, !results.isEmpty {
            await MainActor.run {
                updateAnalysisState(for: videoID, to: .available)
            }
            await statusHandler(.finalizing)
            return AnalysisResultResponse(videoId: response.videoId, video: response.video, results: results)
        }

        if response.cached == true {
            await statusHandler(.preparingCached)
            return try await MusicAnalysisAPIService.shared.fetchResult(videoID: response.videoId)
        }

        if let jobID = response.jobId {
            await MainActor.run {
                updateAnalysisState(for: videoID, to: .analyzing(progress: response.progress, jobID: jobID))
            }
            if let status = response.status {
                await statusHandler(displayState(for: status, progress: response.progress))
            } else {
                await statusHandler(.pending)
            }
            return try await pollAnalysisStatus(
                jobID: jobID,
                videoID: response.videoId,
                statusHandler: statusHandler
            )
        }

        throw AnalysisFlowError.missingJob
    }

    func pollAnalysisStatus(
        jobID: Int,
        videoID: String,
        statusHandler: @escaping LoadingStateHandler
    ) async throws -> AnalysisResultResponse {
        let startTime = Date()
        let timeout: TimeInterval = 300
        let interval: UInt64 = 1_000_000_000

        while true {
            let status = try await MusicAnalysisAPIService.shared.fetchStatus(jobID: jobID)
            await statusHandler(displayState(for: status.status, progress: status.progress))

            if status.status == "complete" {
                await MainActor.run {
                    updateAnalysisState(for: videoID, to: .available)
                }
                await statusHandler(.completed)
                return try await MusicAnalysisAPIService.shared.fetchResult(videoID: videoID)
            }

            if status.status == "fail" {
                let message = status.error?.message ?? "분석에 실패했습니다."
                throw AnalysisFlowError.failedStatus(message: message)
            }

            await MainActor.run {
                updateAnalysisState(for: videoID, to: .analyzing(progress: status.progress, jobID: jobID))
            }

            if Date().timeIntervalSince(startTime) > timeout {
                throw AnalysisFlowError.timeout
            }

            try await Task.sleep(nanoseconds: interval)
        }
    }

    @MainActor
    func presentPlayer(for item: VideoItemViewModel, timeline: [ChordTimelineEntry]) {
        let storyboard = UIStoryboard(name: "PlayerStoryboard", bundle: nil)
        let viewController = storyboard.instantiateViewController(withIdentifier: "PlayerViewController")

        if let playerViewController = viewController as? PlayerViewController {
            playerViewController.videoId = item.videoId
            playerViewController.durationText = item.durationText
            playerViewController.titleText = item.searchItem.snippet.title
            playerViewController.artistText = item.searchItem.snippet.channelTitle
            playerViewController.thumbnailURLString = item.searchItem.snippet.thumbnails?.high?.url
                ?? item.searchItem.snippet.thumbnails?.medium?.url
                ?? item.searchItem.snippet.thumbnails?.default?.url
            playerViewController.initialChordTimeline = timeline
        }

        if let navigationController {
            navigationController.pushViewController(viewController, animated: true)
        } else {
            viewController.modalPresentationStyle = .fullScreen
            present(viewController, animated: true)
        }
    }

    @MainActor
    func updateLoadingFooter() {
        tableView.reloadData()
    }

    func showErrorAlert(_ error: Error) {
        errorOverlay.update(message: error.localizedDescription)
        errorOverlay.show(in: view)
    }

    private func displayState(for status: String, progress: Int?) -> AnalysisLoadingOverlayView.AnalysisLoadingDisplayState {
        switch status {
        case "pending":
            return .pending
        case "downloading":
            return .downloading(progress: progress)
        case "analyzing":
            return .analyzing(progress: progress)
        case "complete":
            return .completed
        default:
            return .pending
        }
    }

    private func parseDurationToSeconds(_ duration: String?) -> Int {
        guard let duration, !duration.isEmpty else { return 0 }

        var hours = 0, minutes = 0, seconds = 0
        var currentNumber = ""
        var isTimeSection = false

        for character in duration {
            if character == "T" { isTimeSection = true; continue }
            if character.isNumber { currentNumber.append(character); continue }
            guard isTimeSection, !currentNumber.isEmpty else { continue }
            let value = Int(currentNumber) ?? 0
            switch character {
            case "H": hours = value
            case "M": minutes = value
            case "S": seconds = value
            default: break
            }
            currentNumber = ""
        }
        return hours * 3600 + minutes * 60 + seconds
    }

    private func formatDuration(_ duration: String?) -> String {
        guard let duration, !duration.isEmpty else { return "" }

        var hours = 0
        var minutes = 0
        var seconds = 0
        var currentNumber = ""
        var isTimeSection = false

        for character in duration {
            if character == "T" {
                isTimeSection = true
                continue
            }

            if character.isNumber {
                currentNumber.append(character)
                continue
            }

            guard isTimeSection, !currentNumber.isEmpty else { continue }

            let value = Int(currentNumber) ?? 0
            switch character {
            case "H":
                hours = value
            case "M":
                minutes = value
            case "S":
                seconds = value
            default:
                break
            }
            currentNumber = ""
        }

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}
