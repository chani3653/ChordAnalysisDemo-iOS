//
//  ChordCollectionViewCell.swift
//  MyChord Demo
//
//  Created by Chan Hwi Park on 4/6/26.
//

import UIKit

final class ChordCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var chordLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        configureAppearance()
    }

    func configure(text: String) {
        chordLabel.text = text
        chordLabel.isHidden = false
        contentView.backgroundColor = .white
    }

    func configureAsSpacer() {
        chordLabel.text = nil
        chordLabel.isHidden = true
        contentView.backgroundColor = .clear
    }

    private func configureAppearance() {
        contentView.layer.cornerRadius = 10
        contentView.layer.masksToBounds = true
    }
}
