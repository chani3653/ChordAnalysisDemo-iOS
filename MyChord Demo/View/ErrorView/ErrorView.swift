//
//  ErrorView.swift
//  MyChord Demo
//
//  Created by Chan Hwi Park on 4/9/26.
//

import UIKit

final class ErrorOverlayView: UIView {

    private static let overlayTag = 98630

    @IBOutlet private weak var contentView: UIView?
    @IBOutlet private weak var dimView: UIView?
    @IBOutlet private weak var panelView: UIView?
    @IBOutlet private weak var messageTextView: UITextView?
    @IBOutlet private weak var confirmButton: UIButton?

    private var isShowing = false

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
        let targetView = resolveOverlayContainer(from: containerView)
        if let existing = targetView.viewWithTag(Self.overlayTag) as? ErrorOverlayView {
            existing.hide()
        }

        guard !isShowing else { return }
        isShowing = true

        tag = Self.overlayTag
        translatesAutoresizingMaskIntoConstraints = false
        targetView.addSubview(self)
        NSLayoutConstraint.activate([
            leadingAnchor.constraint(equalTo: targetView.leadingAnchor),
            trailingAnchor.constraint(equalTo: targetView.trailingAnchor),
            topAnchor.constraint(equalTo: targetView.topAnchor),
            bottomAnchor.constraint(equalTo: targetView.bottomAnchor)
        ])

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

        UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseIn], animations: { [weak self] in
            self?.alpha = 0
            self?.panelView?.transform = CGAffineTransform(scaleX: 0.98, y: 0.98)
        }) { [weak self] _ in
            self?.panelView?.transform = .identity
            self?.removeFromSuperview()
        }
    }

    @MainActor
    func update(message: String) {
        messageTextView?.text = message
    }

    @IBAction private func confirmButtonTapped(_ sender: UIButton) {
        hide()
    }

    private func loadContentIfNeeded(skipNibLoad: Bool = false) {
        if !skipNibLoad, contentView == nil {
            _ = loadFromNib()
        }
        configureDefaultAppearance()
    }

    private func loadFromNib() -> Bool {
        let loadedObjects = Bundle.main.loadNibNamed("ErrorView", owner: self, options: nil)
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

        messageTextView?.isEditable = false
        messageTextView?.isSelectable = false

        confirmButton?.setTitle("확인", for: .normal)
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
