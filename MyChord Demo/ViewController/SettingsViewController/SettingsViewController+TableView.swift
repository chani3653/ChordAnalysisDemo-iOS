//
//  SettingsViewController+TableView.swift
//  MyChord Demo
//
//  Created by Chan Hwi Park on 4/9/26.
//

import UIKit

extension SettingsViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return SettingItem.allCases.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SettingsToggleCell", for: indexPath)
        if let item = SettingItem(rawValue: indexPath.row) {
            if let toggleCell = cell as? SettingsToggleCell {
                toggleCell.configure(
                    title: item.title,
                    isOn: item.isOn,
                    tag: indexPath.row,
                    target: self,
                    action: #selector(toggleChanged(_:))
                )
            }
        }
        return cell
    }
}

extension SettingsViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
