//
//  PlayerViewController.swift
//  MyChord Demo
//
//  Created by Chan Hwi Park on 4/6/26.
//

import UIKit
import YouTubePlayerKit
import Kingfisher

class PlayerViewController: UIViewController {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var artistLabel: UILabel!
    @IBOutlet weak var totalTimeLabel: UILabel!
    @IBOutlet weak var nowTimeLabel: UILabel!
    @IBOutlet weak var timeSlider: UISlider!
    @IBOutlet weak var playPauseButton: UIButton!
    @IBOutlet weak var backwardButton: UIButton!
    @IBOutlet weak var forwardButton: UIButton!
    @IBOutlet weak var backButton: UIButton!
    @IBOutlet weak var playerContainerView: UIView!
    @IBOutlet weak var backgroundImageView: UIImageView!
    @IBOutlet weak var repeatButton: UIButton!
    @IBOutlet weak var repeatALabel: UILabel!
    @IBOutlet weak var repeatBarLabel: UILabel!
    @IBOutlet weak var repeatBLabel: UILabel!
    @IBOutlet weak var contorolPannelView: UIView!
    @IBOutlet weak var chordCollectionView: UICollectionView!

    // MARK: - Input Properties

    var videoId: String?
    var durationText: String?
    var titleText: String?
    var artistText: String?
    var thumbnailURLString: String?
    var initialChordTimeline: [ChordTimelineEntry] = []

    // MARK: - Dependencies

    let playbackController = PlayerPlaybackController()
    let timelineController = PlayerTimelineController()

    private var youTubePlayerHostingView: YouTubePlayerHostingView?
    let chordCellSideInset: CGFloat = 40
    let chordCellHeight: CGFloat = 100
    private var carouselLayout: CarouselFlowLayout?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        titleLabel.text = titleText
        artistLabel.text = artistText
        totalTimeLabel.text = durationText
        nowTimeLabel.text = "0:00"
        timeSlider.value = 0
        updatePlayPauseButton()
        applyThumbnail()
        updateBackButtonColor()
        updateRepeatUI(active: false, isStartActive: false, isEndActive: false)

        configureChordCollectionView()
        bindPlaybackController()

        if !initialChordTimeline.isEmpty {
            timelineController.applyTimeline(initialChordTimeline)
            chordCollectionView.reloadData()
            scrollToChordIndex(0)
        } else {
            timelineController.loadDemoTimelineIfEmpty(durationSeconds: 180)
            chordCollectionView.reloadData()
            scrollToChordIndex(0)
        }

        setupYouTubePlayer()
        updateChordLayout()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        playbackController.stopPlaybackTimer()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        applyControlPanelShadow()
        updateChordLayout()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: nil) { [weak self] _ in
            self?.updateChordLayout()
        }
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    // MARK: - Actions

    @IBAction func backButtonTapped(_ sender: UIButton) {
        dismiss(animated: true)
    }

    @IBAction func playPauseTapped(_ sender: UIButton) {
        playbackController.togglePlayPause()
    }

    @IBAction func backwardTapped(_ sender: UIButton) {
        playbackController.seekBy(secondsDelta: -10)
    }

    @IBAction func forwardTapped(_ sender: UIButton) {
        playbackController.seekBy(secondsDelta: 10)
    }

    @IBAction func sliderTouchDown(_ sender: UISlider) {
        playbackController.setIsSeeking(true)
    }

    @IBAction func sliderValueChanged(_ sender: UISlider) {
        nowTimeLabel.text = PlayerTimelineController.formatTime(seconds: Double(sender.value))
    }

    @IBAction func sliderTouchUp(_ sender: UISlider) {
        playbackController.setIsSeeking(false)
        playbackController.seekTo(seconds: Double(sender.value))
    }

    @IBAction func repeatButtonTapped(_ sender: UIButton) {
        Task {
            let (state, _, _) = await playbackController.handleRepeatButtonTap()
            switch state {
            case .none:
                updateRepeatUI(active: false, isStartActive: false, isEndActive: false)
            case .startSet:
                updateRepeatUI(active: true, isStartActive: true, isEndActive: false)
            case .endSet:
                updateRepeatUI(active: true, isStartActive: true, isEndActive: true)
            }
        }
    }

    @IBAction func seekToStartTapped(_ sender: UIButton) {
        playbackController.resetRepeat()
        updateRepeatUI(active: false, isStartActive: false, isEndActive: false)
        playbackController.seekTo(seconds: 0)
        nowTimeLabel.text = "0:00"
        timeSlider.value = 0
    }

    // MARK: - Binding

    private func bindPlaybackController() {
        playbackController.onPlaybackTimeUpdate = { [weak self] currentSeconds in
            guard let self else { return }
            self.nowTimeLabel.text = PlayerTimelineController.formatTime(seconds: currentSeconds)
            self.timeSlider.value = Float(currentSeconds)
            self.updateChordScroll(currentSeconds: currentSeconds)
        }

        playbackController.onPlayingStateChanged = { [weak self] _ in
            self?.updatePlayPauseButton()
        }

        playbackController.onDurationResolved = { [weak self] durationValue in
            guard let self else { return }
            self.timeSlider.minimumValue = 0
            self.timeSlider.maximumValue = Float(durationValue)
            if self.totalTimeLabel.text?.isEmpty != false {
                self.totalTimeLabel.text = PlayerTimelineController.formatTime(seconds: durationValue)
            }
            if self.timelineController.chordTimeline.isEmpty && self.initialChordTimeline.isEmpty {
                self.timelineController.applyTimeline(ChordTimelineDemo.makeDemoTimeline(durationSeconds: durationValue))
                self.chordCollectionView.reloadData()
                self.scrollToChordIndex(0)
            }
        }
    }

    // MARK: - YouTube Player Setup

    private func setupYouTubePlayer() {
        guard let videoId, !videoId.isEmpty else { return }

        let player = playbackController.setupPlayer(videoId: videoId)
        let hostingView = YouTubePlayerHostingView(player: player)
        playerContainerView.addSubview(hostingView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: playerContainerView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: playerContainerView.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: playerContainerView.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: playerContainerView.bottomAnchor)
        ])
        youTubePlayerHostingView = hostingView
    }

    // MARK: - Collection View

    private func configureChordCollectionView() {
        chordCollectionView.dataSource = self
        chordCollectionView.delegate = self
        chordCollectionView.decelerationRate = .fast
        chordCollectionView.showsVerticalScrollIndicator = false
    }

    private func updateChordLayout() {
        let cvWidth = chordCollectionView.bounds.width
        let cvHeight = chordCollectionView.bounds.height
        guard cvWidth > 0, cvHeight > 0 else { return }

        let itemWidth = max(0, cvWidth - chordCellSideInset * 2)
        let itemHeight = chordCellHeight
        let lineSpacing: CGFloat = -10

        if carouselLayout == nil {
            let layout = CarouselFlowLayout()
            layout.centerItemScale = 1.15
            layout.sideItemScale = 0.8
            layout.sideItemAlpha = 0.6
            layout.spacing = lineSpacing
            layout.itemSize = CGSize(width: itemWidth, height: itemHeight)
            chordCollectionView.setCollectionViewLayout(layout, animated: false)
            carouselLayout = layout
            layout.updateContentInset()
            chordCollectionView.reloadData()
        } else if let layout = carouselLayout {
            let newSize = CGSize(width: itemWidth, height: itemHeight)
            if layout.itemSize != newSize || layout.spacing != lineSpacing {
                layout.spacing = lineSpacing
                layout.itemSize = newSize
                layout.updateContentInset()
                layout.invalidateLayout()
            }
        }
    }

    private func updateChordScroll(currentSeconds: Double) {
        guard let index = timelineController.updateCurrentIndex(for: currentSeconds) else { return }
        let indexPath = IndexPath(item: index, section: 0)
        DispatchQueue.main.async { [weak self] in
            self?.chordCollectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: true)
        }
    }

    func scrollToChordIndex(_ index: Int) {
        guard !timelineController.chordTimeline.isEmpty else { return }
        let targetIndex = max(0, min(index, timelineController.chordTimeline.count - 1))
        let indexPath = IndexPath(item: targetIndex, section: 0)
        chordCollectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: false)
    }

    // MARK: - UI Helpers

    private func updatePlayPauseButton() {
        let imageName = playbackController.isPlaying ? "pause.fill" : "play.fill"
        playPauseButton.setImage(UIImage(systemName: imageName), for: .normal)
        chordCollectionView.isScrollEnabled = !playbackController.isPlaying
    }

    private func updateBackButtonColor() {
        let isLight = preferredStatusBarStyle == .lightContent
        backButton.tintColor = isLight ? .white : .black
    }

    private func applyControlPanelShadow() {
        contorolPannelView.layer.shadowColor = UIColor.white.cgColor
        contorolPannelView.layer.shadowOpacity = 1
        contorolPannelView.layer.shadowRadius = 15
        contorolPannelView.layer.shadowOffset = CGSize(width: 0, height: -35)
        contorolPannelView.layer.masksToBounds = false
        let expandedBounds = contorolPannelView.bounds.insetBy(dx: -45, dy: -10)
        contorolPannelView.layer.shadowPath = UIBezierPath(rect: expandedBounds).cgPath
    }

    private func updateRepeatUI(active: Bool, isStartActive: Bool, isEndActive: Bool) {
        let activeColor = UIColor.systemGreen
        let inactiveColor = UIColor.black

        repeatButton.tintColor = active ? activeColor : inactiveColor
        repeatALabel.textColor = isStartActive ? activeColor : inactiveColor
        repeatBarLabel.textColor = isStartActive ? activeColor : inactiveColor
        repeatBLabel.textColor = isEndActive ? activeColor : inactiveColor
    }

    private func applyThumbnail() {
        backgroundImageView.isHidden = SettingsStore.isBackgroundMotionEnabled
        backgroundImageView.contentMode = .scaleAspectFill
        backgroundImageView.clipsToBounds = true
        guard let urlString = thumbnailURLString, let url = URL(string: urlString) else { return }
        backgroundImageView.kf.setImage(with: url)
    }
}
