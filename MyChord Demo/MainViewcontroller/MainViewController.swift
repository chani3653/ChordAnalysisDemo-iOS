//
//  MainViewController.swift
//  MyChord Demo
//
//  Created by Chan Hwi Park on 4/6/26.
//

import UIKit

class MainViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var searchTextField: UITextField!
    @IBOutlet weak var searchButton: UIButton!
    @IBOutlet weak var textViewContainerView: UIView!
    @IBOutlet weak var textViewInnerContainerView: UIView!
    @IBOutlet weak var headerBlurView: UIVisualEffectView!
    
    struct VideoItemViewModel {
        let searchItem: YouTubeSearchItem
        let videoId: String
        let durationText: String
    }

    var videoItems: [VideoItemViewModel] = []
    private var hasSearched = false
    private(set) var isLoadingMore = false
    private var currentQuery: String?
    private var nextPageToken: String?
    private(set) var hasMorePages = true
    private var shortNextPageToken: String?
    private var mediumNextPageToken: String?
    private var shortHasMore = true
    private var mediumHasMore = true
    private let useDummyData = true
    private let searchAreaHeight: CGFloat = 60
    private var dummyItems: [DummyYouTubeData.DummyVideoItem] = []
    private var dummyIndex = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        
        setViews()

        if useDummyData {
            currentQuery = DummyYouTubeData.defaultQuery
            Task {
                await loadMore()
            }
        }
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

    // MARK: - Actions

    @IBAction func searchButtonTapped(_ sender: UIButton) {
        performSearch()
    }

    func performSearch() {
        let rawQuery = searchTextField.text
        let query = (rawQuery?.isEmpty == false) ? rawQuery! : (useDummyData ? DummyYouTubeData.defaultQuery : nil)
        guard let query, !query.isEmpty else { return }
        searchTextField.resignFirstResponder()

        currentQuery = query
        videoItems = []
        shortNextPageToken = nil
        mediumNextPageToken = nil
        shortHasMore = true
        mediumHasMore = true
        hasMorePages = true
        dummyItems = []
        dummyIndex = 0
        updateLoadingFooter()
        tableView.reloadData()

        Task {
            await loadMore()
        }
    }

    func loadMore() async {
        guard let query = currentQuery, !isLoadingMore, hasMorePages else { return }

        if useDummyData {
            await loadMoreDummy(query: query)
            return
        }

        isLoadingMore = true
        updateLoadingFooter()
        tableView.reloadData()

        do {
            // Fetch short(25) and medium(25) in parallel
            async let shortResult: YouTubeSearchResponse? = shortHasMore
                ? try await APIService.shared.searchYouTube(query: query, videoDuration: "short", pageToken: shortNextPageToken)
                : nil
            async let mediumResult: YouTubeSearchResponse? = mediumHasMore
                ? try await APIService.shared.searchYouTube(query: query, videoDuration: "medium", pageToken: mediumNextPageToken)
                : nil

            let shortResponse = try await shortResult
            let mediumResponse = try await mediumResult

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
                    return VideoItemViewModel(searchItem: item, videoId: id, durationText: durationText)
                }
                videoItems.append(contentsOf: newItems)
            }

            hasSearched = true
        } catch {
            shortHasMore = false
            mediumHasMore = false
            showErrorAlert(error)
        }

        isLoadingMore = false
        updateLoadingFooter()
        tableView.reloadData()
    }

    private func loadMoreDummy(query: String) async {
        isLoadingMore = true
        updateLoadingFooter()
        tableView.reloadData()

        if dummyItems.isEmpty {
            dummyItems = DummyYouTubeData.makeItems(query: query, count: DummyYouTubeData.totalCount)
            dummyIndex = 0
        }

        let nextIndex = min(dummyIndex + DummyYouTubeData.pageSize, dummyItems.count)
        if dummyIndex < nextIndex {
            let newItems = dummyItems[dummyIndex..<nextIndex].map {
                VideoItemViewModel(searchItem: $0.searchItem, videoId: $0.videoId, durationText: $0.durationText)
            }
            videoItems.append(contentsOf: newItems)
            dummyIndex = nextIndex
        }

        hasMorePages = dummyIndex < dummyItems.count
        hasSearched = true
        isLoadingMore = false
        updateLoadingFooter()
        tableView.reloadData()
    }

    private func updateLoadingFooter() {
        if isLoadingMore {
            let container = UIView(frame: CGRect(x: 0, y: 0, width: tableView.bounds.width, height: 44))
            let spinner = UIActivityIndicatorView(style: .medium)
            spinner.startAnimating()
            spinner.center = CGPoint(x: container.bounds.midX, y: container.bounds.midY)
            container.addSubview(spinner)
            tableView.tableFooterView = container
        } else {
            tableView.tableFooterView = UIView(frame: .zero)
        }
    }

    private func showErrorAlert(_ error: Error) {
        let alert = UIAlertController(
            title: "오류",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
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

