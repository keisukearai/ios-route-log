//
//  TrackingInterval.swift
//  ios-route-log (MoveLog)
//
//  位置情報を保存する間隔の選択肢。ユーザーが設定画面で変更できる。
//

import Foundation

/// 位置情報の保存間隔
///
/// - 取得自体は CLLocationManager が連続して行う
/// - この値は「何分経過したら次の1件を保存するか」の閾値として使う
/// - 間隔が長いほど電池消費が抑えられ、蓄積データ量も減る
enum TrackingInterval: Int, CaseIterable, Identifiable {
    case fifteenMinutes = 15
    case thirtyMinutes  = 30
    case oneHour        = 60

    var id: Int { rawValue }

    /// 秒単位のインターバル
    var seconds: TimeInterval { TimeInterval(rawValue * 60) }

    /// 設定画面・ホーム画面に表示するラベル
    var label: String {
        switch self {
        case .fifteenMinutes: return "15分"
        case .thirtyMinutes:  return "30分"
        case .oneHour:        return "1時間"
        }
    }
}
