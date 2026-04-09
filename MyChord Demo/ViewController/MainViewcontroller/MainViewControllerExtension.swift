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
        return videoItems.count + (isLoadingMore && hasMorePages ? 1 : 0)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // 마지막 행이 로딩 인디케이터 셀인 경우
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
}

// MARK: - UITableViewDelegate

extension MainViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.row == videoItems.count { return 56 }
        return UITableView.automaticDimension
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offsetY = scrollView.contentOffset.y
        let contentHeight = scrollView.contentSize.height
        let frameHeight = scrollView.frame.size.height

        if contentHeight > 0, offsetY > contentHeight - frameHeight - 200 {
            startLoadMore()
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.section == 0, indexPath.row < videoItems.count else { return }
        tableView.deselectRow(at: indexPath, animated: true)

        let item = videoItems[indexPath.row]
        startAnalysisFlow(for: item)
    }
}

// MARK: - UITextFieldDelegate

extension MainViewController: UITextFieldDelegate {

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        performSearch()
        return true
    }
}
