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
    
    var videoId: String?
    var durationText: String?
    var titleText: String?
    var artistText: String?
    var thumbnailURLString: String?

    private var youTubePlayer: YouTubePlayer?
    private var youTubePlayerHostingView: YouTubePlayerHostingView?
    private var playbackTimer: Timer?
    private var isSeeking = false
    private var isPlaying = false
    private var durationSeconds: Double?
    private var lastPlaybackStateCheck: Date?
    private var repeatState: RepeatState = .none
    private var repeatStartSeconds: Double?
    private var repeatEndSeconds: Double?

    private enum RepeatState {
        case none
        case startSet
        case endSet
    }

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

        setupYouTubePlayer()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopPlaybackTimer()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        applyControlPanelShadow()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    @IBAction func backButtonTapped(_ sender: UIButton) {
        dismiss(animated: true)
    }

    @IBAction func playPauseTapped(_ sender: UIButton) {
        Task {
            guard let youTubePlayer else { return }
            if isPlaying {
                try? await youTubePlayer.pause()
                isPlaying = false
            } else {
                try? await youTubePlayer.play()
                isPlaying = true
            }
            updatePlayPauseButton()
        }
    }

    @IBAction func backwardTapped(_ sender: UIButton) {
        seekBy(secondsDelta: -10)
    }

    @IBAction func forwardTapped(_ sender: UIButton) {
        seekBy(secondsDelta: 10)
    }

    @IBAction func sliderTouchDown(_ sender: UISlider) {
        isSeeking = true
    }

    @IBAction func sliderValueChanged(_ sender: UISlider) {
        nowTimeLabel.text = formatTime(seconds: Double(sender.value))
    }

    @IBAction func sliderTouchUp(_ sender: UISlider) {
        isSeeking = false
        seekTo(seconds: Double(sender.value))
    }

    @IBAction func repeatButtonTapped(_ sender: UIButton) {
        Task {
            await handleRepeatButtonTap()
        }
    }

    @IBAction func seekToStartTapped(_ sender: UIButton) {
        repeatState = .none
        repeatStartSeconds = nil
        repeatEndSeconds = nil
        updateRepeatUI(active: false, isStartActive: false, isEndActive: false)

        seekTo(seconds: 0)
        nowTimeLabel.text = "0:00"
        timeSlider.value = 0
    }

    private func setupYouTubePlayer() {
        guard let videoId, !videoId.isEmpty else { return }

        let parameters = YouTubePlayer.Parameters(
            autoPlay: false,
            showControls: false,
            showFullscreenButton: false,
            showCaptions: false,
            restrictRelatedVideosToSameChannel: true
        )
        let player = YouTubePlayer(source: .video(id: videoId), parameters: parameters)
        let hostingView = YouTubePlayerHostingView(player: player)
        playerContainerView.addSubview(hostingView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: playerContainerView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: playerContainerView.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: playerContainerView.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: playerContainerView.bottomAnchor)
        ])

        youTubePlayer = player
        youTubePlayerHostingView = hostingView
        isPlaying = false
        updatePlayPauseButton()
        startPlaybackTimer()
        Task {
            await updateDurationIfNeeded()
        }
    }

    private func updatePlayPauseButton() {
        let imageName = isPlaying ? "pause.fill" : "play.fill"
        let image = UIImage(systemName: imageName)
        playPauseButton.setImage(image, for: .normal)
    }

    private func updatePlaybackStateIfNeeded() async {
        let now = Date()
        if let last = lastPlaybackStateCheck, now.timeIntervalSince(last) < 0.8 {
            return
        }
        lastPlaybackStateCheck = now

        guard let youTubePlayer else { return }
        if let info = try? await youTubePlayer.getInformation() {
            let playing = info.playerState == .playing
            if playing != isPlaying {
                isPlaying = playing
                updatePlayPauseButton()
            }
        }
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

    private func handleRepeatButtonTap() async {
        guard let youTubePlayer else { return }
        let currentValue = (try? await youTubePlayer.getCurrentTime())?.converted(to: .seconds).value ?? 0

        switch repeatState {
        case .none:
            repeatStartSeconds = currentValue
            repeatEndSeconds = nil
            repeatState = .startSet
            updateRepeatUI(active: true, isStartActive: true, isEndActive: false)
        case .startSet:
            repeatEndSeconds = max(currentValue, repeatStartSeconds ?? 0)
            repeatState = .endSet
            updateRepeatUI(active: true, isStartActive: true, isEndActive: true)
            if let start = repeatStartSeconds {
                let startTime = Measurement(value: start, unit: UnitDuration.seconds)
                try? await youTubePlayer.seek(to: startTime, allowSeekAhead: true)
                if !isPlaying {
                    try? await youTubePlayer.play()
                    isPlaying = true
                    updatePlayPauseButton()
                }
            }
        case .endSet:
            repeatState = .none
            repeatStartSeconds = nil
            repeatEndSeconds = nil
            updateRepeatUI(active: false, isStartActive: false, isEndActive: false)
        }
    }

    private func enforceRepeatIfNeeded(currentSeconds: Double) async {
        guard repeatState == .endSet,
              let start = repeatStartSeconds,
              let end = repeatEndSeconds else { return }

        if currentSeconds >= end {
            let startTime = Measurement(value: start, unit: UnitDuration.seconds)
            try? await youTubePlayer?.seek(to: startTime, allowSeekAhead: true)
        }
    }

    private func applyThumbnail() {
        backgroundImageView.contentMode = .scaleAspectFill
        backgroundImageView.clipsToBounds = true
        guard let urlString = thumbnailURLString, let url = URL(string: urlString) else { return }
        backgroundImageView.kf.setImage(with: url)
    }

    private func startPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { [weak self] in
                await self?.updatePlaybackTime()
            }
        }
    }

    private func stopPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }

    private func updateDurationIfNeeded() async {
        guard let youTubePlayer else { return }
        if durationSeconds != nil { return }
        if let duration = try? await youTubePlayer.getDuration() {
            let durationValue = duration.converted(to: .seconds).value
            durationSeconds = durationValue
            timeSlider.minimumValue = 0
            timeSlider.maximumValue = Float(durationValue)
            if totalTimeLabel.text?.isEmpty != false {
                totalTimeLabel.text = formatTime(seconds: durationValue)
            }
        }
    }

    private func updatePlaybackTime() async {
        guard let youTubePlayer, !isSeeking else { return }
        if durationSeconds == nil {
            await updateDurationIfNeeded()
        }
        await updatePlaybackStateIfNeeded()
        if let currentTime = try? await youTubePlayer.getCurrentTime() {
            let currentValue = currentTime.converted(to: .seconds).value
            nowTimeLabel.text = formatTime(seconds: currentValue)
            timeSlider.value = Float(currentValue)
            await enforceRepeatIfNeeded(currentSeconds: currentValue)
        }
    }

    private func seekBy(secondsDelta: Double) {
        Task {
            guard let youTubePlayer else { return }
            let currentValue = (try? await youTubePlayer.getCurrentTime())?.converted(to: .seconds).value ?? 0
            let durationValue = (try? await youTubePlayer.getDuration())?.converted(to: .seconds).value ?? durationSeconds ?? 0
            let target = max(0, min(currentValue + secondsDelta, durationValue))
            let targetTime = Measurement(value: target, unit: UnitDuration.seconds)
            try? await youTubePlayer.seek(to: targetTime, allowSeekAhead: true)
            nowTimeLabel.text = formatTime(seconds: target)
            timeSlider.value = Float(target)
        }
    }

    private func seekTo(seconds: Double) {
        Task {
            guard let youTubePlayer else { return }
            let targetTime = Measurement(value: seconds, unit: UnitDuration.seconds)
            try? await youTubePlayer.seek(to: targetTime, allowSeekAhead: true)
        }
    }

    private func formatTime(seconds: Double) -> String {
        let totalSeconds = max(0, Int(seconds))
        let minutes = totalSeconds / 60
        let secondsPart = totalSeconds % 60
        return String(format: "%d:%02d", minutes, secondsPart)
    }
}

