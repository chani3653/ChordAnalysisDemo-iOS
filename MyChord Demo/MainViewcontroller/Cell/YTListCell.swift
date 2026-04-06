//
//  YTListCell.swift
//  MyChord Demo
//
//  Created by Chan Hwi Park on 4/6/26.
//

import UIKit
import Kingfisher

class YTListCell: UITableViewCell {

    @IBOutlet weak var thumbnailImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var artistLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var playtimeLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        thumbnailImageView.kf.cancelDownloadTask()
        thumbnailImageView.image = nil
    }

    func configure(with item: MainViewController.VideoItemViewModel) {
        titleLabel.text = item.searchItem.snippet.title
        artistLabel.text = item.searchItem.snippet.channelTitle
        dateLabel.text = formatDate(item.searchItem.snippet.publishedAt)
        playtimeLabel.text = item.durationText

        if let urlString = item.searchItem.snippet.thumbnails?.high?.url,
           let url = URL(string: urlString) {
            thumbnailImageView.kf.setImage(with: url)
        }
    }

    private func formatDate(_ dateString: String?) -> String {
        guard let dateString else { return "" }
        // "2022-08-05T14:00:07Z" -> "2022-08-05"
        return String(dateString.prefix(10))
    }
}
