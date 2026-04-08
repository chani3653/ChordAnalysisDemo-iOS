//
//  CarouselFlowLayout.swift
//  MyChord Demo
//
//  Created by Chan Hwi Park on 4/8/26.
//

import UIKit

/// 가운데 셀이 크고 양옆 셀이 작아지는 수평 캐러셀 레이아웃.
/// UICollectionViewFlowLayout을 상속하며 외부 라이브러리 없이 동작한다.
///
/// 조절 가능한 프로퍼티:
///   - `sideItemScale`  : 양옆 셀의 최소 스케일 (0.0 ~ 1.0, 기본 0.8)
///   - `sideItemAlpha`  : 양옆 셀의 최소 알파 (0.0 ~ 1.0, 기본 0.6)
///   - `spacing`        : 셀 간 최소 간격 (= minimumLineSpacing 에 반영)
///
/// itemSize, minimumLineSpacing 등은 이 클래스 인스턴스를 만든 뒤
/// 직접 설정하거나 `setup()` 안에서 기본값을 변경하면 된다.
final class CarouselFlowLayout: UICollectionViewFlowLayout {

    // MARK: - 조절 가능한 값

    /// 양옆 셀의 최소 스케일. 1.0이면 스케일 변화 없음.
    var sideItemScale: CGFloat = 0.8

    /// 양옆 셀의 최소 알파. 1.0이면 알파 변화 없음.
    var sideItemAlpha: CGFloat = 0.6

    /// 셀 사이 간격 (minimumLineSpacing 에 매핑)
    var spacing: CGFloat = 20 {
        didSet { minimumLineSpacing = spacing }
    }

    // MARK: - Init

    override init() {
        super.init()
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        scrollDirection = .horizontal
        minimumLineSpacing = spacing
    }

    // MARK: - Content Inset Helper

    /// 첫/마지막 셀도 화면 중앙에 올 수 있도록 contentInset을 설정한다.
    /// collectionView가 레이아웃에 연결된 뒤(viewDidLayoutSubviews 등)에서 호출하면 된다.
    func updateContentInset() {
        guard let cv = collectionView else { return }
        let sideInset = (cv.bounds.width - itemSize.width) / 2
        cv.contentInset = UIEdgeInsets(top: 0, left: sideInset, bottom: 0, right: sideInset)
    }

    // MARK: - Layout Invalidation

    /// 스크롤할 때마다 레이아웃을 다시 계산해서 scale/alpha를 갱신한다.
    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        return true
    }

    // MARK: - Attributes 계산

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        guard let superAttributes = super.layoutAttributesForElements(in: rect),
              let collectionView = collectionView else {
            return nil
        }

        // 원본을 변경하면 내부 캐시와 충돌할 수 있으므로 복사본 사용
        let attributes = superAttributes.compactMap { $0.copy() as? UICollectionViewLayoutAttributes }

        let visibleCenterX = collectionView.contentOffset.x + collectionView.bounds.width / 2

        for attr in attributes {
            let distance = abs(attr.center.x - visibleCenterX)
            // 셀의 중심이 화면 중앙에서 얼마나 떨어져 있는지를 0~1 비율로 환산
            let normalizedDistance = min(distance / collectionView.bounds.width, 1.0)
            let scale = 1.0 - (1.0 - sideItemScale) * normalizedDistance
            let alpha = 1.0 - (1.0 - sideItemAlpha) * normalizedDistance

            attr.transform = CGAffineTransform(scaleX: scale, y: scale)
            attr.alpha = alpha
            // 가운데 셀이 위에 오도록 zIndex 설정
            attr.zIndex = Int((1.0 - normalizedDistance) * 1000)
        }

        return attributes
    }

    // MARK: - 스냅(Snap) 구현

    /// 손을 떼면 가장 가까운 셀의 중심이 화면 중앙으로 스냅된다.
    override func targetContentOffset(
        forProposedContentOffset proposedContentOffset: CGPoint,
        withScrollingVelocity velocity: CGPoint
    ) -> CGPoint {
        guard let cv = collectionView else {
            return super.targetContentOffset(forProposedContentOffset: proposedContentOffset,
                                             withScrollingVelocity: velocity)
        }

        let targetCenterX = proposedContentOffset.x + cv.bounds.width / 2

        // proposedContentOffset 주변 넉넉한 범위의 셀을 탐색
        let searchRect = CGRect(
            x: proposedContentOffset.x - cv.bounds.width,
            y: 0,
            width: cv.bounds.width * 3,
            height: cv.bounds.height
        )

        guard let attributes = super.layoutAttributesForElements(in: searchRect) else {
            return super.targetContentOffset(forProposedContentOffset: proposedContentOffset,
                                             withScrollingVelocity: velocity)
        }

        // 화면 중앙에 가장 가까운 셀 찾기
        var closestAttribute: UICollectionViewLayoutAttributes?
        var closestDistance = CGFloat.greatestFiniteMagnitude

        for attr in attributes {
            let distance = attr.center.x - targetCenterX
            if abs(distance) < abs(closestDistance) {
                closestDistance = distance
                closestAttribute = attr
            }
        }

        guard let snapped = closestAttribute else {
            return super.targetContentOffset(forProposedContentOffset: proposedContentOffset,
                                             withScrollingVelocity: velocity)
        }

        // 스냅 대상 셀의 중심이 화면 중앙에 오도록 오프셋 계산
        let offsetX = snapped.center.x - cv.bounds.width / 2
        return CGPoint(x: offsetX, y: proposedContentOffset.y)
    }
}
