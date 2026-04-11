//
//  PlayerViewController+CollectionView.swift
//  MyChord Demo
//
//  Created by Chan Hwi Park on 4/6/26.
//

import UIKit

// MARK: - UICollectionViewDataSource

extension PlayerViewController: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return timelineController.chordTimeline.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ChordCollectionViewCell.reuseIdentifier, for: indexPath) as? ChordCollectionViewCell else {
            return UICollectionViewCell()
        }
        cell.configure(text: timelineController.chordTimeline[indexPath.item].chord)
        let position = cellPosition(for: cell.frame, in: collectionView)
        cell.updatePosition(position)
        return cell
    }
}

// MARK: - UICollectionViewDelegateFlowLayout

extension PlayerViewController: UICollectionViewDelegateFlowLayout {

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateVisibleCellCenterStates()
    }
}

// MARK: - Cell Position

extension PlayerViewController {

    func updateVisibleCellCenterStates() {
        let cv = chordCollectionView!
        for cell in cv.visibleCells {
            guard let chordCell = cell as? ChordCollectionViewCell else { continue }
            chordCell.updatePosition(cellPosition(for: cell.frame, in: cv))
        }
    }

    private func cellPosition(for frame: CGRect, in collectionView: UICollectionView) -> ChordCollectionViewCell.Position {
        let centerY = collectionView.contentOffset.y + collectionView.bounds.height / 2
        let distance = abs(frame.midY - centerY)
        let cellHeight = frame.height

        if distance < cellHeight * 0.5 {
            return .center
        } else if distance < cellHeight * 1.5 {
            return .adjacent
        } else {
            return .far
        }
    }
}

private extension ChordCollectionViewCell {

    static let reuseIdentifier = "ChordCollectionViewCell"
}
