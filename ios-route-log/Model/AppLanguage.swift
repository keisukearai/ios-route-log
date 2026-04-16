//
//  AppLanguage.swift
//  ios-route-log (MoveLog)
//
//  アプリ内言語設定の選択肢。LanguageManager で管理し UserDefaults に永続化する。
//

import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case japanese = "ja"
    case english  = "en"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .japanese: return "日本語"
        case .english:  return "English"
        }
    }
}
