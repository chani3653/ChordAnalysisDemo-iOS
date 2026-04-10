//
//  LoadingView.swift
//  MyChord Demo
//
//  Created by Chan Hwi Park on 4/9/26.
//

import UIKit

final class AnalysisLoadingOverlayView: UIView {

    enum AnalysisLoadingDisplayState: Equatable {
        case pending
        case checkingCache
        case preparingCached
        case downloading(progress: Int?)
        case analyzing(progress: Int?)
        case finalizing
        case completed

        var titleText: String {
            switch self {
            case .pending:
                return "분석 준비 중..."
            case .checkingCache:
                return "이미 분석한 곡인지 찾아보는 중..."
            case .preparingCached:
                return "이미 준비된 코드표를 꺼내는 중..."
            case .downloading:
                return "노래를 데리러 가는 중..."
            case .analyzing:
                return "화음을 열심히 해석하는 중..."
            case .finalizing:
                return "코드표를 가지런히 정리하는 중..."
            case .completed:
                return "분석 완료! 곧 플레이어로 이동합니다"
            }
        }

        var progressValue: Int? {
            switch self {
            case .downloading(let progress), .analyzing(let progress):
                return progress
            default:
                return nil
            }
        }
    }

    @IBOutlet private weak var contentView: UIView?
    @IBOutlet private weak var dimView: UIView?
    @IBOutlet private weak var panelView: UIView?
    @IBOutlet private weak var messageLabel: UILabel?
    @IBOutlet private weak var percentLabel: UILabel?
    @IBOutlet private weak var activityIndicator: UIActivityIndicatorView?
    @IBOutlet private weak var progressView: UIProgressView?

    private var isShowing = false
    private var delayHideOnCompletion = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        loadContentIfNeeded()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        loadContentIfNeeded(skipNibLoad: true)
    }

    @MainActor
    func show(in containerView: UIView) {
        guard !isShowing else { return }
        isShowing = true
        delayHideOnCompletion = false

        let targetView = resolveOverlayContainer(from: containerView)

        if superview == nil {
            translatesAutoresizingMaskIntoConstraints = false
            targetView.addSubview(self)
            NSLayoutConstraint.activate([
                leadingAnchor.constraint(equalTo: targetView.leadingAnchor),
                trailingAnchor.constraint(equalTo: targetView.trailingAnchor),
                topAnchor.constraint(equalTo: targetView.topAnchor),
                bottomAnchor.constraint(equalTo: targetView.bottomAnchor)
            ])
        }

        alpha = 0
        panelView?.transform = CGAffineTransform(scaleX: 0.98, y: 0.98)
        layoutIfNeeded()
        UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseOut]) { [weak self] in
            self?.alpha = 1
            self?.panelView?.transform = .identity
        }
    }

    @MainActor
    func hide() {
        guard isShowing else { return }
        isShowing = false

        let delay: TimeInterval = delayHideOnCompletion ? 2.0 : 0.0
        if delay > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.removeFromSuperview()
            }
        } else {
            removeFromSuperview()
        }
    }

    @MainActor
    func update(state: AnalysisLoadingDisplayState) {
        animateMessageChange(to: state.titleText)
        updateProgress(state.progressValue)

        switch state {
        case .pending, .checkingCache, .preparingCached, .finalizing:
            progressView?.isHidden = true
            percentLabel?.isHidden = true
        case .completed:
            delayHideOnCompletion = true
            progressView?.isHidden = false
            percentLabel?.isHidden = false
            updateProgress(100)
        default:
            progressView?.isHidden = false
            percentLabel?.isHidden = false
        }
    }

    @MainActor
    func updateProgress(_ progress: Int?) {
        guard let progress else { return }
        let value = max(0, min(progress, 100))
        progressView?.setProgress(Float(value) / 100.0, animated: true)
        percentLabel?.text = "\(value)%"
    }

    private func animateMessageChange(to newText: String) {
        guard let label = messageLabel else { return }
        if label.text == newText { return }

        UIView.animate(withDuration: 0.35, animations: {
            label.alpha = 0
        }) { _ in
            label.text = newText
            UIView.animate(withDuration: 0.35) {
                label.alpha = 1
            }
        }
    }

    private func loadContentIfNeeded(skipNibLoad: Bool = false) {
        if !skipNibLoad, contentView == nil {
            _ = loadFromNib()
        }
        configureDefaultAppearance()
    }

    private func loadFromNib() -> Bool {
        let loadedObjects = Bundle.main.loadNibNamed("LoadingView", owner: self, options: nil)
        if let contentView {
            attachContentView(contentView)
            return true
        }
        if let view = loadedObjects?.first as? UIView {
            attachContentView(view)
            return true
        }
        return false
    }

    private func attachContentView(_ view: UIView) {
        view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: leadingAnchor),
            view.trailingAnchor.constraint(equalTo: trailingAnchor),
            view.topAnchor.constraint(equalTo: topAnchor),
            view.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        view.insetsLayoutMarginsFromSafeArea = false
        contentView = view
    }

    private func configureDefaultAppearance() {
        dimView?.backgroundColor = UIColor.black.withAlphaComponent(0.1)

        panelView?.layer.cornerRadius = 16
        panelView?.layer.masksToBounds = false
        panelView?.layer.shadowColor = UIColor.black.cgColor
        panelView?.layer.shadowOpacity = 0.25
        panelView?.layer.shadowRadius = 10
        panelView?.layer.shadowOffset = CGSize(width: 0, height: 6)

        messageLabel?.font = messageLabel?.font ?? UIFont.systemFont(ofSize: 20, weight: .semibold)
        messageLabel?.textColor = messageLabel?.textColor ?? .white
        messageLabel?.numberOfLines = messageLabel?.numberOfLines ?? 0

        percentLabel?.font = percentLabel?.font ?? UIFont.systemFont(ofSize: 14, weight: .semibold)
        percentLabel?.textColor = percentLabel?.textColor ?? UIColor.white

        activityIndicator?.color = activityIndicator?.color ?? .white
        activityIndicator?.startAnimating()

        progressView?.setProgress(progressView?.progress ?? 0, animated: false)
    }

    private func resolveOverlayContainer(from view: UIView) -> UIView {
        if let window = view.window {
            return window
        }
        if let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
           let window = windowScene.windows.first(where: { $0.isKeyWindow }) {
            return window
        }
        return view
    }
}
