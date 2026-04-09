//
//  TabBarViewController.swift
//  MyChord Demo
//
//  Created by Chan Hwi Park on 4/9/26.
//

import UIKit

final class TabBarViewController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()
        configureTabBarAppearance()
        viewControllers = [
            makeMainViewController(),
            makeSettingsViewController()
        ].compactMap { $0 }
        selectedIndex = 0
    }

    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()

        tabBar.standardAppearance = appearance
        if #available(iOS 15.0, *) {
            tabBar.scrollEdgeAppearance = appearance
        }
    }

    private func makeMainViewController() -> UIViewController? {
        let storyboard = UIStoryboard(name: "MainViewController", bundle: nil)
        let vc = storyboard.instantiateInitialViewController()
        vc?.tabBarItem = UITabBarItem(title: "검색", image: UIImage(systemName: "magnifyingglass"), tag: 0)
        return vc
    }

    private func makeSettingsViewController() -> UIViewController? {
        let storyboard = UIStoryboard(name: "SettingsViewController", bundle: nil)
        let vc = storyboard.instantiateInitialViewController()
        vc?.tabBarItem = UITabBarItem(title: "설정", image: UIImage(systemName: "gearshape.fill"), tag: 1)
        return vc
    }
}
