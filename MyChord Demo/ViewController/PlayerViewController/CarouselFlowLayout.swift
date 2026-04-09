//
//  CarouselFlowLayout.swift
//  MyChord Demo
//
//  Created by Chan Hwi Park on 4/8/26.
//

import UIKit

/// 가운데 셀이 크고 위아래 셀이 작아지는 세로 캐러셀 레이아웃.
///
/// 깜빡임 방지를 위한 핵심 설계:
///   1. layoutAttributesForElements / layoutAttributesForItem 모두에서 copy() 후 transform 적용
///   2. shouldInvalidateLayout = true 이지만, collectionView.reloadData()는 최소화
///   3. transform은 오직 layout에서만 관리 — 셀은 건드리지 않음
final class CarouselFlowLayout: UICollectionViewFlowLayout {

    // MARK: - 조절 가능한 값

    /// 가운데 셀의 스케일 (1.0보다 크면 강조)
    var centerItemScale: CGFloat = 1.15

    /// 가장 먼 셀의 최소 스케일
    var sideItemScale: CGFloat = 0.8

    /// 가장 먼 셀의 최소 알파
    var sideItemAlpha: CGFloat = 0.6

    /// X축 회전 최대 각도(라디안). 0이면 기울기 없음.
    var maxTiltAngle: CGFloat = .pi / 6

    /// 셀 사이 간격 (= minimumLineSpacing)
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
        scrollDirection = .vertical
        minimumLineSpacing = spacing
    }

    // MARK: - Content Inset

    /// 첫/마지막 셀도 화면 중앙에 올 수 있도록 contentInset 설정.
    func updateContentInset() {
        guard let cv = collectionView else { return }
        let inset = (cv.bounds.height - itemSize.height) / 2
        cv.contentInset = UIEdgeInsets(top: inset, left: 0, bottom: inset, right: 0)
    }

    // MARK: - Invalidation

    /// 스크롤할 때마다 transform/alpha를 재계산해야 하므로 항상 true.
    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        return true
    }

    // MARK: - Attributes 계산 (핵심)

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        guard let superAttributes = super.layoutAttributesForElements(in: rect) else {
            return nil
        }
        // ✅ 반드시 copy() — 원본 캐시를 오염시키면 깜빡임 발생
        return superAttributes.compactMap { original in
            guard let attr = original.copy() as? UICollectionViewLayoutAttributes else { return nil }
            applyTransform(to: attr)
            return attr
        }
    }

    /// ✅ 개별 아이템 요청에도 transform을 적용해야 깜빡임이 없다.
    /// 이 메서드를 빠뜨리면 insertItems/deleteItems/scrollToItem 시
    /// transform이 없는 원본 attributes가 한 프레임 노출된다.
    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard let original = super.layoutAttributesForItem(at: indexPath),
              let attr = original.copy() as? UICollectionViewLayoutAttributes else {
            return nil
        }
        applyTransform(to: attr)
        return attr
    }

    /// 공통 transform/alpha/zIndex 계산
    private func applyTransform(to attr: UICollectionViewLayoutAttributes) {
        guard let cv = collectionView else { return }

        let visibleCenterY = cv.contentOffset.y + cv.bounds.height / 2
        let signedDistance = attr.center.y - visibleCenterY
        let absDistance = abs(signedDistance)
        let normalizedDistance = min(absDistance / cv.bounds.height, 1.0)

        // 스케일: center → centerItemScale, 가장자리 → sideItemScale
        let scale = centerItemScale - (centerItemScale - sideItemScale) * normalizedDistance
        // 알파
        let alpha = 1.0 - (1.0 - sideItemAlpha) * normalizedDistance
        // 3D 기울기 (위쪽 셀 앞으로, 아래쪽 셀 뒤로)
        let tiltAngle = signedDistance / cv.bounds.height * maxTiltAngle
        let clampedTilt = max(-maxTiltAngle, min(maxTiltAngle, tiltAngle))

        var t = CATransform3DIdentity
        t.m34 = -1.0 / 500
        t = CATransform3DRotate(t, clampedTilt, 1, 0, 0)
        t = CATransform3DScale(t, scale, scale, 1)

        attr.transform3D = t
        attr.alpha = alpha
        // 가운데 셀이 위에 그려지도록
        attr.zIndex = Int((1.0 - normalizedDistance) * 1000)
    }

    // MARK: - 스냅

    override func targetContentOffset(
        forProposedContentOffset proposedContentOffset: CGPoint,
        withScrollingVelocity velocity: CGPoint
    ) -> CGPoint {
        guard let cv = collectionView else {
            return super.targetContentOffset(forProposedContentOffset: proposedContentOffset,
                                             withScrollingVelocity: velocity)
        }

        let targetCenterY = proposedContentOffset.y + cv.bounds.height / 2

        let searchRect = CGRect(
            x: 0,
            y: proposedContentOffset.y - cv.bounds.height,
            width: cv.bounds.width,
            height: cv.bounds.height * 3
        )

        guard let attributes = super.layoutAttributesForElements(in: searchRect) else {
            return super.targetContentOffset(forProposedContentOffset: proposedContentOffset,
                                             withScrollingVelocity: velocity)
        }

        var closestAttr: UICollectionViewLayoutAttributes?
        var closestDist = CGFloat.greatestFiniteMagnitude

        for attr in attributes {
            let dist = attr.center.y - targetCenterY
            if abs(dist) < abs(closestDist) {
                closestDist = dist
                closestAttr = attr
            }
        }

        guard let snapped = closestAttr else {
            return super.targetContentOffset(forProposedContentOffset: proposedContentOffset,
                                             withScrollingVelocity: velocity)
        }

        return CGPoint(x: proposedContentOffset.x,
                       y: snapped.center.y - cv.bounds.height / 2)
    }
}
