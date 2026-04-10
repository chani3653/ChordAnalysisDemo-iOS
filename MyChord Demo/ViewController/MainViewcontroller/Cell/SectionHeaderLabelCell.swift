//
//  SectionHeaderLabelCell.swift
//  MyChord Demo
//
//  Created by Chan Hwi Park on 4/10/26.
//

import UIKit

class SectionHeaderLabelCell: UITableViewCell {

    static let reuseIdentifier = "SectionHeaderLabelCell"

    private let headerLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.addSubview(headerLabel)
        NSLayoutConstraint.activate([
            headerLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            headerLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            headerLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            headerLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(text: String) {
        headerLabel.text = text
    }
}
