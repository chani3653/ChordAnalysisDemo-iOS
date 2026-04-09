//
//  SettingsStore.swift
//  MyChord Demo
//
//  Created by Chan Hwi Park on 4/9/26.
//

import Foundation

enum SettingsStore {
    private static let dummyDataKey = "settings.dummyDataEnabled"
    private static let backgroundMotionKey = "settings.backgroundMotionEnabled"
    private static let serverConnectionKey = "settings.serverConnectionEnabled"
    private static let loadingDemoKey = "settings.loadingDemoEnabled"

    static var isDummyDataEnabled: Bool {
        get {
            UserDefaults.standard.object(forKey: dummyDataKey) as? Bool ?? true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: dummyDataKey)
        }
    }

    static var isBackgroundMotionEnabled: Bool {
        get {
            UserDefaults.standard.object(forKey: backgroundMotionKey) as? Bool ?? false
        }
        set {
            UserDefaults.standard.set(newValue, forKey: backgroundMotionKey)
        }
    }

    static var isServerConnectionEnabled: Bool {
        get {
            UserDefaults.standard.object(forKey: serverConnectionKey) as? Bool ?? true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: serverConnectionKey)
        }
    }

    static var isLoadingDemoEnabled: Bool {
        get {
            UserDefaults.standard.object(forKey: loadingDemoKey) as? Bool ?? false
        }
        set {
            UserDefaults.standard.set(newValue, forKey: loadingDemoKey)
        }
    }
}
