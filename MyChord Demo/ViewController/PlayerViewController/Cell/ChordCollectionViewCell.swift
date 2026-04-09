//
//  ChordCollectionViewCell.swift
//  MyChord Demo
//
//  Created by Chan Hwi Park on 4/6/26.
//

import UIKit

final class ChordCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var chordLabel: UILabel!

    enum Position: Int {
        case center
        case adjacent
        case far
    }

    // ✅ 색상을 미리 캐시 — scrollViewDidScroll 매 프레임마다 객체 생성 방지
    // 🔧 가운데 셀 틴트 alpha → 1.0이면 뒷배경 완전 불투명
    private static let centerTint   = UIColor.white.withAlphaComponent(1.0)
    private static let adjacentTint = UIColor.white.withAlphaComponent(0.9)
    private static let farTint      = UIColor.white.withAlphaComponent(0.6)

    // 🔧 글자색 (가운데 / 인접 / 멀리)
    private static let centerTextColor   = UIColor.black
    private static let adjacentTextColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.8)
    private static let farTextColor      = UIColor(red: 128/255, green: 128/255, blue: 128/255, alpha: 0.6)

    // 🔧 셀 전체 알파 (가운데 / 인접 / 멀리)
    private static let centerAlpha: CGFloat   = 1.0
    private static let adjacentAlpha: CGFloat = 0.6
    private static let farAlpha: CGFloat      = 0.4

    private var whiteTintView: UIView?
    private var currentPosition: Position?  // nil = 아직 설정 안 됨

    override func awakeFromNib() {
        super.awakeFromNib()
        configureAppearance()
        configureLabelOnContentView()
    }

    /// ✅ 셀 재사용 시 transform/alpha를 identity로 리셋.
    /// layout이 즉시 새 값을 적용하지만, 리셋이 없으면
    /// 이전 셀의 transform이 1프레임 노출되어 깜빡임 발생.
    override func prepareForReuse() {
        super.prepareForReuse()
        layer.transform = CATransform3DIdentity
        alpha = 1.0
        currentPosition = nil
        whiteTintView?.backgroundColor = Self.farTint
        chordLabel?.textColor = Self.farTextColor
    }

    func configure(text: String) {
        chordLabel.text = text
        chordLabel.isHidden = false
    }

    func configureAsSpacer() {
        chordLabel.text = nil
        chordLabel.isHidden = true
    }

    /// 위치에 따른 틴트/글자색 전환.
    /// guard로 동일 상태 재적용을 차단 → 불필요한 프로퍼티 변경 = 0
    func updatePosition(_ position: Position) {
        guard position != currentPosition else { return }
        currentPosition = position

        switch position {
        case .center:
            whiteTintView?.backgroundColor = Self.centerTint
            chordLabel?.textColor = Self.centerTextColor
            contentView.alpha = Self.centerAlpha
        case .adjacent:
            whiteTintView?.backgroundColor = Self.adjacentTint
            chordLabel?.textColor = Self.adjacentTextColor
            contentView.alpha = Self.adjacentAlpha
        case .far:
            whiteTintView?.backgroundColor = Self.farTint
            chordLabel?.textColor = Self.farTextColor
            contentView.alpha = Self.farAlpha
        }
    }

    private func configureAppearance() {
        contentView.backgroundColor = .clear
        backgroundColor = .clear

        // ✅ shouldRasterize: blur + cornerRadius + transform3D 조합의
        // GPU 부하를 줄여 프레임 드롭(깜빡임) 방지
        layer.shouldRasterize = true
        layer.rasterizationScale = UIScreen.main.scale

        let blurEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        let blur = UIVisualEffectView(effect: blurEffect)
        blur.translatesAutoresizingMaskIntoConstraints = false
        blur.layer.cornerRadius = 18
        blur.clipsToBounds = true
        contentView.addSubview(blur)
        pinToEdges(blur, in: contentView)

        let whiteTint = UIView()
        whiteTint.translatesAutoresizingMaskIntoConstraints = false
        whiteTint.backgroundColor = Self.farTint
        whiteTint.isUserInteractionEnabled = false
        blur.contentView.addSubview(whiteTint)
        pinToEdges(whiteTint, in: blur.contentView)

        whiteTintView = whiteTint
    }

    private func configureLabelOnContentView() {
        guard let label = chordLabel else { return }

        label.removeFromSuperview()
        contentView.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.textColor = Self.farTextColor

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -8)
        ])
    }

    private func pinToEdges(_ child: UIView, in parent: UIView) {
        NSLayoutConstraint.activate([
            child.leadingAnchor.constraint(equalTo: parent.leadingAnchor),
            child.trailingAnchor.constraint(equalTo: parent.trailingAnchor),
            child.topAnchor.constraint(equalTo: parent.topAnchor),
            child.bottomAnchor.constraint(equalTo: parent.bottomAnchor)
        ])
    }
}
