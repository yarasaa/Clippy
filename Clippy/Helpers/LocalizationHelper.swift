//
//  LocalizationHelper.swift
//  Clippy
//
//  Created by Mehmet Akbaba on 20.09.2025.
//


import Foundation

func L(_ key: String, settings: SettingsManager) -> String {
    let languageCode = settings.appLanguage

    if languageCode == "system" || languageCode == "tr" {
        return NSLocalizedString(key, comment: "")
    }

    guard let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"), let bundle = Bundle(path: path) else { return key }
    return NSLocalizedString(key, tableName: nil, bundle: bundle, comment: "")
}
