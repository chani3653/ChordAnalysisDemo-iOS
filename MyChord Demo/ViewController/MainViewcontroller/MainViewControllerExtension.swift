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
        if isShowingSearchResults {
            return videoItems.count + (isLoadingMore && hasMorePages ? 1 : 0)
        } else {
            // Offline mode: header cell + cached songs
            if offlineSongs.isEmpty {
                return 0
            }
            return 1 + offlineSongs.count // 1 for header
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if isShowingSearchResults {
            return searchResultCell(for: indexPath)
        } else {
            return offlineCell(for: indexPath)
        }
    }

    // MARK: - Search Result Cells

    private func searchResultCell(for indexPath: IndexPath) -> UITableViewCell {
        if indexPath.row == videoItems.count {
            let cell = tableView.dequeueReusableCell(withIdentifier: "LoadingIndicatorCell", for: indexPath)
            cell.selectionStyle = .none
            cell.backgroundColor = .clear
            if cell.contentView.viewWithTag(999) == nil {
                let indicator = UIActivityIndicatorView(style: .medium)
                indicator.tag = 999
                indicator.translatesAutoresizingMaskIntoConstraints = false
                cell.contentView.addSubview(indicator)
                NSLayoutConstraint.activate([
                    indicator.centerXAnchor.constraint(equalTo: cell.contentView.centerXAnchor),
                    indicator.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor)
                ])
            }
            (cell.contentView.viewWithTag(999) as? UIActivityIndicatorView)?.startAnimating()
            return cell
        }

        guard let cell = tableView.dequeueReusableCell(withIdentifier: "YTListCell", for: indexPath) as? YTListCell else {
            return UITableViewCell()
        }
        cell.configure(with: videoItems[indexPath.row])
        return cell
    }

    // MARK: - Offline Cells

    private func offlineCell(for indexPath: IndexPath) -> UITableViewCell {
        // Row 0 = header label
        if indexPath.row == 0 {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: SectionHeaderLabelCell.reuseIdentifier, for: indexPath) as? SectionHeaderLabelCell else {
                return UITableViewCell()
            }
            cell.configure(text: "이전곡 분석 목록 (오프라인 사용 가능)")
            return cell
        }

        // Row 1+ = cached songs
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "YTListCell", for: indexPath) as? YTListCell else {
            return UITableViewCell()
        }
        let song = offlineSongs[indexPath.row - 1]
        cell.configureOffline(with: song)
        return cell
    }
}

// MARK: - UITableViewDelegate

extension MainViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if isShowingSearchResults {
            if indexPath.row == videoItems.count { return 56 }
        }
        return UITableView.automaticDimension
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard isShowingSearchResults else { return }
        let offsetY = scrollView.contentOffset.y
        let contentHeight = scrollView.contentSize.height
        let frameHeight = scrollView.frame.size.height

        if contentHeight > 0, offsetY > contentHeight - frameHeight - 200 {
            startLoadMore()
        }
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        guard !isShowingSearchResults, indexPath.row >= 1 else { return false }
        return true
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard !isShowingSearchResults, indexPath.row >= 1 else { return nil }

        let deleteAction = UIContextualAction(style: .destructive, title: "삭제") { [weak self] _, _, completion in
            guard let self else { completion(false); return }
            let songIndex = indexPath.row - 1
            let song = self.offlineSongs[songIndex]
            OfflineSongCacheManager.shared.deleteSong(videoId: song.videoId)
            self.offlineSongs.remove(at: songIndex)

            if self.offlineSongs.isEmpty {
                tableView.reloadData()
            } else {
                tableView.deleteRows(at: [indexPath], with: .automatic)
            }
            completion(true)
        }

        return UISwipeActionsConfiguration(actions: [deleteAction])
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if isShowingSearchResults {
            guard indexPath.row < videoItems.count else { return }
            let item = videoItems[indexPath.row]
            startAnalysisFlow(for: item)
        } else {
            // Offline list: row 0 is header, skip it
            guard indexPath.row >= 1 else { return }
            let song = offlineSongs[indexPath.row - 1]
            startOfflinePlayback(for: song)
        }
    }
}

// MARK: - UITextFieldDelegate

extension MainViewController: UITextFieldDelegate {

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        performSearch()
        return true
    }

    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        // 검색 취소 시 오프라인 목록으로 복귀
        textField.text = ""
        textField.resignFirstResponder()
        isShowingSearchResults = false
        videoItems = []
        reloadOfflineSongs()
        tableView.reloadData()
        return false
    }
}
