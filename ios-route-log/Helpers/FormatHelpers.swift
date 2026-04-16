//
//  FormatHelpers.swift
//  ios-route-log (MoveLog)
//
//  表示用フォーマット関数。全 View から共有して使う。
//

import Foundation

/// 距離 (m) を人間が読みやすい文字列に変換する
///
/// - 10m 未満: "0 m"（誤差範囲として丸める）
/// - 1,000m 未満: "xxx m"
/// - 1,000m 以上: "x.xx km"
func formatDistance(_ meters: Double) -> String {
    if meters < 10 {
        return "0 m"
    } else if meters < 1000 {
        return String(format: "%.0f m", meters)
    } else {
        return String(format: "%.2f km", meters / 1000)
    }
}

/// 速度 (m/s) を km/h 表記の文字列に変換する
func formatSpeed(_ mps: Double) -> String {
    let kmh = mps * 3.6
    return String(format: "%.1f km/h", kmh)
}
