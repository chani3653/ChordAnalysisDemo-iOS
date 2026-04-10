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
    @IBOutlet weak var CloudImg: NSLayoutConstraint!

    private let statusLabel = UILabel()
    private var cloudImgDefaultConstant: CGFloat = 0

    override func awakeFromNib() {
        super.awakeFromNib()
        cloudImgDefaultConstant = CloudImg.constant
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        thumbnailImageView.kf.cancelDownloadTask()
        thumbnailImageView.image = nil
        statusLabel.text = nil
        CloudImg.constant = 0
    }

    func configure(with item: MainViewController.VideoItemViewModel) {
        titleLabel.text = item.searchItem.snippet.title
        artistLabel.text = item.searchItem.snippet.channelTitle
        dateLabel.text = formatDate(item.searchItem.snippet.publishedAt)
        playtimeLabel.text = item.durationText
        statusLabel.text = item.analysisState.statusText

        CloudImg.constant = (item.analysisState == .available) ? cloudImgDefaultConstant : 0

        if let urlString = item.searchItem.snippet.thumbnails?.high?.url,
           let url = URL(string: urlString) {
            thumbnailImageView.kf.setImage(with: url)
        }
    }

    func configureOffline(with song: RealmAnalyzedSong) {
        titleLabel.text = song.title
        artistLabel.text = song.artist
        dateLabel.text = formatRelativeDate(song.lastViewedAt)
        playtimeLabel.text = song.durationText
        statusLabel.text = "분석됨"

        CloudImg.constant = cloudImgDefaultConstant

        if let url = URL(string: song.thumbnailURL) {
            thumbnailImageView.kf.setImage(with: url)
        }
    }

    private func formatDate(_ dateString: String?) -> String {
        guard let dateString else { return "" }
        // "2022-08-05T14:00:07Z" -> "2022-08-05"
        return String(dateString.prefix(10))
    }

    private func formatRelativeDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
