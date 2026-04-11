//
//  MainViewController.swift
//  MyChord Demo
//
//  Created by Chan Hwi Park on 4/6/26.
//

import UIKit
import RealmSwift

class MainViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var searchTextField: UITextField!
    @IBOutlet weak var searchButton: UIButton!
    @IBOutlet weak var textViewContainerView: UIView!
    @IBOutlet weak var textViewInnerContainerView: UIView!
    @IBOutlet weak var headerBlurView: UIVisualEffectView!

    // MARK: - Dependencies

    let searchHandler = MainSearchHandler()
    private let analysisFlowController = MainAnalysisFlowController()
    private lazy var analysisLoadingOverlay = AnalysisLoadingOverlayView()
    private lazy var errorOverlay = ErrorOverlayView()

    // MARK: - State

    var isShowingSearchResults = false
    var offlineSongs: [RealmAnalyzedSong] = []
    private var loadMoreTask: Task<Void, Never>?
    private var lastDummySetting = SettingsStore.isDummyDataEnabled
    private let searchAreaHeight: CGFloat = 60
    private var useDummyData: Bool { SettingsStore.isDummyDataEnabled }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setViews()
        lastDummySetting = useDummyData

        if useDummyData {
            isShowingSearchResults = true
            searchHandler.setQuery(DummyYouTubeData.defaultQuery)
            startLoadMore()
        } else {
            reloadOfflineSongs()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        applyDummySettingIfNeeded()

        if !isShowingSearchResults {
            reloadOfflineSongs()
            tableView.reloadData()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if tableView.contentInset.top != searchAreaHeight {
            tableView.contentInset.top = searchAreaHeight
            tableView.scrollIndicatorInsets.top = searchAreaHeight
        }
    }

    // MARK: - View Setup

    private func setViews() {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.contentInset = .zero
        tableView.scrollIndicatorInsets = .zero
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "LoadingIndicatorCell")
        tableView.register(SectionHeaderLabelCell.self, forCellReuseIdentifier: SectionHeaderLabelCell.reuseIdentifier)

        searchTextField.delegate = self
        searchTextField.returnKeyType = .search

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)

        textViewContainerView.layer.cornerRadius = 12
        textViewInnerContainerView.layer.cornerRadius = 10

        headerBlurView.layer.shadowColor = UIColor.black.cgColor
        headerBlurView.layer.shadowOpacity = 0.2
        headerBlurView.layer.shadowOffset = CGSize(width: 0, height: 4)
        headerBlurView.layer.shadowRadius = 8
        headerBlurView.layer.masksToBounds = false
    }

    // MARK: - Actions

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    @IBAction func searchButtonTapped(_ sender: UIButton) {
        performSearch()
    }

    func performSearch() {
        let rawQuery = searchTextField.text ?? ""
        let trimmedQuery = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return }
        searchTextField.resignFirstResponder()

        searchHandler.reset()
        isShowingSearchResults = true
        searchHandler.setQuery(trimmedQuery)
        Task { @MainActor in
            tableView.reloadData()
        }
        startLoadMore()
    }

    // MARK: - Search / Load More

    @MainActor
    func startLoadMore() {
        guard loadMoreTask == nil else { return }
        loadMoreTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.searchHandler.loadMore()
            } catch {
                await MainActor.run { self.showErrorOverlay(error) }
            }
            await MainActor.run {
                self.tableView.reloadData()
                self.loadMoreTask = nil
            }
        }
    }

    // MARK: - Analysis Flow

    func startAnalysisFlow(for item: VideoItemViewModel) {
        analysisFlowController.start(
            for: item,
            stateUpdater: { [weak self] videoID, state in
                self?.updateAnalysisStateInTable(for: videoID, to: state)
            },
            onLoadingState: { [weak self] state in
                guard let self else { return }
                if self.analysisLoadingOverlay.superview == nil {
                    self.analysisLoadingOverlay.show(in: self.view)
                }
                self.analysisLoadingOverlay.update(state: state)
            },
            onSuccess: { [weak self] item, flowResult in
                guard let self else { return }
                self.analysisLoadingOverlay.hide()
                self.saveToOfflineCache(item: item, result: flowResult.analysisResult)
                self.presentPlayer(for: item, timeline: flowResult.timeline)
            },
            onError: { [weak self] item, error in
                guard let self else { return }
                self.analysisLoadingOverlay.hide()
                self.handleAnalysisError(item: item, error: error)
            }
        )
    }

    // MARK: - Offline Playback

    func reloadOfflineSongs() {
        offlineSongs = OfflineSongCacheManager.shared.fetchRecentSongs()
    }

    func startOfflinePlayback(for song: RealmAnalyzedSong) {
        OfflineSongCacheManager.shared.touchSong(videoId: song.videoId)
        presentPlayerFromCache(song)
    }

    // MARK: - Navigation

    @MainActor
    func presentPlayer(for item: VideoItemViewModel, timeline: [ChordTimelineEntry]) {
        let storyboard = UIStoryboard(name: "PlayerStoryboard", bundle: nil)
        let viewController = storyboard.instantiateViewController(withIdentifier: "PlayerViewController")

        if let playerVC = viewController as? PlayerViewController {
            playerVC.videoId = item.videoId
            playerVC.durationText = item.durationText
            playerVC.titleText = item.searchItem.snippet.title
            playerVC.artistText = item.searchItem.snippet.channelTitle
            playerVC.thumbnailURLString = item.searchItem.snippet.thumbnails?.high?.url
                ?? item.searchItem.snippet.thumbnails?.medium?.url
                ?? item.searchItem.snippet.thumbnails?.default?.url
            playerVC.initialChordTimeline = timeline
        }

        if let navigationController {
            navigationController.pushViewController(viewController, animated: true)
        } else {
            viewController.modalPresentationStyle = .fullScreen
            present(viewController, animated: true)
        }
    }

    @MainActor
    func presentPlayerFromCache(_ song: RealmAnalyzedSong) {
        let timeline = song.toChordTimelineEntries()
        let storyboard = UIStoryboard(name: "PlayerStoryboard", bundle: nil)
        let viewController = storyboard.instantiateViewController(withIdentifier: "PlayerViewController")

        if let playerVC = viewController as? PlayerViewController {
            playerVC.videoId = song.videoId
            playerVC.durationText = song.durationText
            playerVC.titleText = song.title
            playerVC.artistText = song.artist
            playerVC.thumbnailURLString = song.thumbnailURL
            playerVC.initialChordTimeline = timeline
        }

        if let navigationController {
            navigationController.pushViewController(viewController, animated: true)
        } else {
            viewController.modalPresentationStyle = .fullScreen
            present(viewController, animated: true)
        }
    }

    // MARK: - Private Helpers

    @MainActor
    private func updateAnalysisStateInTable(for videoID: String, to state: AnalysisAvailabilityState) {
        guard let index = searchHandler.updateAnalysisState(for: videoID, to: state) else { return }
        let currentRowCount = tableView.numberOfRows(inSection: 0)
        if index >= currentRowCount || currentRowCount != searchHandler.videoItems.count {
            tableView.reloadData()
            return
        }
        tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .none)
    }

    private func saveToOfflineCache(item: VideoItemViewModel, result: AnalysisResultResponse) {
        let thumbnailURL = item.searchItem.snippet.thumbnails?.high?.url
            ?? item.searchItem.snippet.thumbnails?.medium?.url
            ?? item.searchItem.snippet.thumbnails?.default?.url
            ?? ""
        OfflineSongCacheManager.shared.saveAnalyzedSong(
            videoId: item.videoId,
            title: item.searchItem.snippet.title ?? "",
            artist: item.searchItem.snippet.channelTitle ?? "",
            thumbnailURL: thumbnailURL,
            durationText: item.durationText,
            results: result.results
        )
    }

    private func handleAnalysisError(item: VideoItemViewModel, error: Error) {
        let cached = OfflineSongCacheManager.shared.fetchSong(videoId: item.videoId)
        if let cached {
            print("[OfflineCache] 오프라인 캐시로 불러왔습니다: \(item.videoId)")
            OfflineSongCacheManager.shared.touchSong(videoId: item.videoId)
            presentPlayerFromCache(cached)
        } else {
            showOfflineUnavailableAlert()
        }
    }

    private func showOfflineUnavailableAlert() {
        let alert = UIAlertController(
            title: "연결 실패",
            message: "서버에 연결할 수 없으며, 이 곡의 오프라인 데이터도 없습니다.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }

    func showErrorOverlay(_ error: Error) {
        errorOverlay.update(message: error.localizedDescription)
        errorOverlay.show(in: view)
    }

    private func applyDummySettingIfNeeded() {
        let currentSetting = useDummyData
        guard currentSetting != lastDummySetting else { return }
        lastDummySetting = currentSetting

        searchHandler.reset()
        isShowingSearchResults = false

        if currentSetting {
            isShowingSearchResults = true
            searchHandler.setQuery(DummyYouTubeData.defaultQuery)
            startLoadMore()
        } else {
            reloadOfflineSongs()
        }

        tableView.reloadData()
    }
}
