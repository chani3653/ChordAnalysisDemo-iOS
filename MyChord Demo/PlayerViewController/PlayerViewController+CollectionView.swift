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
        return chordTimeline.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ChordCollectionViewCell.reuseIdentifier, for: indexPath) as? ChordCollectionViewCell else {
            return UICollectionViewCell()
        }
        cell.configure(text: chordTimeline[indexPath.item].chord)
        return cell
    }
}

// MARK: - UICollectionViewDelegateFlowLayout

extension PlayerViewController: UICollectionViewDelegateFlowLayout { }

private extension ChordCollectionViewCell {

    static let reuseIdentifier = "ChordCollectionViewCell"
}
