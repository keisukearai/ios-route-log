//
//  LocationRecord.swift
//  ios-route-log (MoveLog)
//
//  位置履歴1件分のデータモデル。SwiftData で端末内に永続化される。
//

import Foundation
import SwiftData

/// 位置履歴1件分のデータモデル
@Model
final class LocationRecord {
    /// 一意識別子
    var id: UUID
    /// 位置情報を取得した日時
    var timestamp: Date
    /// 緯度
    var latitude: Double
    /// 経度
    var longitude: Double
    /// 速度 (m/s)。取得できない場合は 0 に補完して保存される
    var speed: Double
    /// 前回保存地点からの移動距離 (m)。最初の記録は 0
    var distanceFromPrevious: Double
    /// 逆ジオコーディングで得た都道府県＋市区町村（例: "東京都渋谷区"）
    var address: String?

    init(
        id: UUID = UUID(),
        timestamp: Date,
        latitude: Double,
        longitude: Double,
        speed: Double,
        distanceFromPrevious: Double,
        address: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.latitude = latitude
        self.longitude = longitude
        self.speed = speed
        self.distanceFromPrevious = distanceFromPrevious
        self.address = address
    }
}
