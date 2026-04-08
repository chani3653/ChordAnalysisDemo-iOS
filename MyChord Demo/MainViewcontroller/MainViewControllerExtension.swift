//
//  MainViewController+TableView.swift
//  MyChord Demo
//
//  Created by Chan Hwi Park on 4/6/26.
//

import UIKit

// MARK: - UITableViewDataSource

extension MainViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return videoItems.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "YTListCell", for: indexPath) as? YTListCell else {
            return UITableViewCell()
        }
        cell.configure(with: videoItems[indexPath.row])
        return cell
    }
}

// MARK: - UITableViewDelegate

extension MainViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offsetY = scrollView.contentOffset.y
        let contentHeight = scrollView.contentSize.height
        let frameHeight = scrollView.frame.size.height

        if contentHeight > 0, offsetY > contentHeight - frameHeight - 200 {
            Task {
                await loadMore()
            }
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.section == 0 else { return }
        tableView.deselectRow(at: indexPath, animated: true)

        let storyboard = UIStoryboard(name: "PlayerStoryboard", bundle: nil)
        let viewController = storyboard.instantiateViewController(withIdentifier: "PlayerViewController")

        if let playerViewController = viewController as? PlayerViewController {
            let item = videoItems[indexPath.row]
            playerViewController.videoId = item.videoId
            playerViewController.durationText = item.durationText
            playerViewController.titleText = item.searchItem.snippet.title
            playerViewController.artistText = item.searchItem.snippet.channelTitle
            playerViewController.thumbnailURLString = item.searchItem.snippet.thumbnails?.high?.url
                ?? item.searchItem.snippet.thumbnails?.medium?.url
                ?? item.searchItem.snippet.thumbnails?.default?.url
        }

        viewController.modalPresentationStyle = .fullScreen
        present(viewController, animated: true)
    }
}

// MARK: - UITextFieldDelegate

extension MainViewController: UITextFieldDelegate {

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        performSearch()
        return true
    }
}
