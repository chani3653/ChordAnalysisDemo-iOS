//
//  SettingsViewController.swift
//  MyChord Demo
//
//  Created by Chan Hwi Park on 4/6/26.
//

import UIKit

final class SettingsViewController: UIViewController {

    enum SettingItem: Int, CaseIterable {
        case dummyData
        case backgroundMotion
        case serverConnection
        case loadingDemo

        var title: String {
            switch self {
            case .dummyData:
                return "더미 데이터 사용"
            case .backgroundMotion:
                return "배경 움직임"
            case .serverConnection:
                return "서버 연결"
            case .loadingDemo:
                return "로딩 데모"
            }
        }

        var isOn: Bool {
            switch self {
            case .dummyData:
                return SettingsStore.isDummyDataEnabled
            case .backgroundMotion:
                return SettingsStore.isBackgroundMotionEnabled
            case .serverConnection:
                return SettingsStore.isServerConnectionEnabled
            case .loadingDemo:
                return SettingsStore.isLoadingDemoEnabled
            }
        }

        func setEnabled(_ isOn: Bool) {
            switch self {
            case .dummyData:
                SettingsStore.isDummyDataEnabled = isOn
            case .backgroundMotion:
                SettingsStore.isBackgroundMotionEnabled = isOn
            case .serverConnection:
                SettingsStore.isServerConnectionEnabled = isOn
            case .loadingDemo:
                SettingsStore.isLoadingDemoEnabled = isOn
            }
        }
    }

    private weak var tableView: UITableView?
    private lazy var loadingDemoOverlay = AnalysisLoadingOverlayView()
    private lazy var errorOverlay = ErrorOverlayView()
    private var loadingDemoTask: Task<Void, Never>?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        tableView = findTableView(in: view)
        tableView?.dataSource = self
        tableView?.delegate = self
        tableView?.rowHeight = UITableView.automaticDimension
        tableView?.estimatedRowHeight = 44
    }

    @objc func toggleChanged(_ sender: UISwitch) {
        guard let item = SettingItem(rawValue: sender.tag) else { return }
        item.setEnabled(sender.isOn)

        if item == .loadingDemo, sender.isOn {
            runLoadingDemo()
        }
    }

    private func runLoadingDemo() {
        guard loadingDemoTask == nil else { return }

        loadingDemoTask = Task { [weak self] in
            guard let self else { return }

            await MainActor.run {
                self.loadingDemoOverlay.show(in: self.view)
                self.loadingDemoOverlay.update(state: .checkingCache)
            }

            await sleep(seconds: 0.8)
            await MainActor.run {
                self.loadingDemoOverlay.update(state: .downloading(progress: 10))
            }

            await sleep(seconds: 0.8)
            await MainActor.run {
                self.loadingDemoOverlay.update(state: .downloading(progress: 40))
            }

            await sleep(seconds: 0.8)
            await MainActor.run {
                self.loadingDemoOverlay.update(state: .analyzing(progress: 60))
            }

            await sleep(seconds: 0.8)
            await MainActor.run {
                self.loadingDemoOverlay.update(state: .analyzing(progress: 85))
            }

            await sleep(seconds: 0.8)
            await MainActor.run {
                self.loadingDemoOverlay.update(state: .finalizing)
            }

            await sleep(seconds: 0.6)
            await MainActor.run {
                self.loadingDemoOverlay.update(state: .completed)
            }

            await sleep(seconds: 2.0)
            await MainActor.run {
                self.loadingDemoOverlay.hide()
            }

            await sleep(seconds: 0.8)
            await MainActor.run {
                self.errorOverlay.update(message: "서버 응답이 지연되고 있어요")
                self.errorOverlay.show(in: self.view)
            }

            await MainActor.run {
                SettingsStore.isLoadingDemoEnabled = false
                self.tableView?.reloadData()
                self.loadingDemoTask = nil
            }
        }
    }

    private func sleep(seconds: Double) async {
        let duration = UInt64(seconds * 1_000_000_000)
        try? await Task.sleep(nanoseconds: duration)
    }

    private func findTableView(in rootView: UIView) -> UITableView? {
        if let tableView = rootView as? UITableView {
            return tableView
        }
        for subview in rootView.subviews {
            if let tableView = findTableView(in: subview) {
                return tableView
            }
        }
        return nil
    }
}
