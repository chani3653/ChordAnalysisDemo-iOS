//
//  SettingsToggleCell.swift
//  MyChord Demo
//
//  Created by Chan Hwi Park on 4/9/26.
//

import UIKit

final class SettingsToggleCell: UITableViewCell {

    private enum Constants {
        static let targetToggleHeight: CGFloat = 22
    }

    private var didApplyToggleScale = false

    private var toggleSwitch: UISwitch? {
        return findToggle(in: contentView)
    }

    private var titleLabel: UILabel? {
        return findLabel(in: contentView)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        applyToggleScaleIfNeeded()
    }

    func configure(title: String, isOn: Bool, tag: Int, target: Any?, action: Selector) {
        titleLabel?.text = title

        if let toggleSwitch {
            toggleSwitch.removeTarget(nil, action: nil, for: .valueChanged)
            toggleSwitch.isOn = isOn
            toggleSwitch.tag = tag
            toggleSwitch.addTarget(target, action: action, for: .valueChanged)
        }

        selectionStyle = .none
    }

    private func applyToggleScaleIfNeeded() {
        guard !didApplyToggleScale, let toggleSwitch else { return }

        let originalHeight = toggleSwitch.bounds.height
        guard originalHeight > 0 else { return }

        let scale = Constants.targetToggleHeight / originalHeight
        toggleSwitch.transform = CGAffineTransform(scaleX: scale, y: scale)
        didApplyToggleScale = true
    }

    private func findToggle(in rootView: UIView) -> UISwitch? {
        if let toggle = rootView as? UISwitch {
            return toggle
        }
        for subview in rootView.subviews {
            if let toggle = findToggle(in: subview) {
                return toggle
            }
        }
        return nil
    }

    private func findLabel(in rootView: UIView) -> UILabel? {
        if let label = rootView as? UILabel {
            return label
        }
        for subview in rootView.subviews {
            if let label = findLabel(in: subview) {
                return label
            }
        }
        return nil
    }
}
