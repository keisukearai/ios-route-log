//
//  RouteViewModel.swift
//  ios-route-log (MoveLog)
//
//  移動記録の業務ロジックを管理する ViewModel。
//  LocationManager から位置情報を受け取り、SwiftData へ保存する。
//  集計値（累計距離・平均速度など）もここで算出・管理する。
//

import Foundation
import CoreLocation
import SwiftData

/// 移動記録アプリのメイン ViewModel
///
/// - 記録の開始・停止
/// - 指定インターバルでの位置情報保存
/// - 表示用データ（累計距離・速度・平均速度）の管理
/// - SwiftData への保存
@Observable
final class RouteViewModel {

    // MARK: - 記録状態（ホーム画面の表示に使う）

    /// 現在記録中かどうか
    var isTracking: Bool = false

    /// ユーザーが選択した保存インターバル
    var trackingInterval: TrackingInterval = .thirtyMinutes

    // MARK: - 表示用データ

    /// 最後に受信した位置情報
    var currentLocation: CLLocation?

    /// 現在地の住所（都道府県＋市区町村）
    var currentAddress: String?

    /// 最後に位置情報を受信した時刻
    var lastUpdated: Date?

    /// 現在の速度 (m/s)。CLLocation.speed が負値の場合は 0
    var currentSpeed: Double = 0

    /// 保存済みレコードの平均速度 (m/s)
    var averageSpeed: Double = 0

    /// 保存済みレコードの累計移動距離 (m)
    var totalDistance: Double = 0

    // MARK: - 依存オブジェクト

    /// 位置情報取得を担う LocationManager
    let locationManager: LocationManager

    // MARK: - プライベート変数

    private var modelContext: ModelContext?

    /// 前回保存した CLLocation（次回の距離計算に使う）
    private var lastSavedLocation: CLLocation?

    /// 前回保存した時刻（インターバル判定に使う）
    private var lastSaveTime: Date?

    /// 保存済みレコード数（平均速度の計算に使う）
    private var savedRecordCount: Int = 0

    /// 保存済みレコードの速度合計（平均速度の計算に使う）
    private var totalSpeedSum: Double = 0

    /// 逆ジオコーディング用
    private let geocoder = CLGeocoder()
    /// 前回ジオコーディングした座標（500m 未満の移動では再取得しない）
    private var lastGeocodedLocation: CLLocation?

    // MARK: - 初期化

    init(locationManager: LocationManager = LocationManager()) {
        self.locationManager = locationManager
        setupLocationCallback()
    }

    // MARK: - セットアップ

    /// ModelContext を注入する。アプリ起動時に ContentView から呼ぶ
    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadSummaryFromStorage()
    }

    private func setupLocationCallback() {
        locationManager.onLocationUpdate = { [weak self] location in
            self?.handleLocationUpdate(location)
        }
    }

    // MARK: - 記録の開始・停止

    func startTracking() {
        guard !isTracking else { return }
        isTracking = true
        // 開始直後に1件保存できるよう lastSaveTime をリセット
        lastSaveTime = nil
        locationManager.startUpdating()
    }

    func stopTracking() {
        guard isTracking else { return }
        isTracking = false
        locationManager.stopUpdating()
    }

    // MARK: - 位置情報の処理

    private func handleLocationUpdate(_ location: CLLocation) {
        // 現在地・最終取得時刻・現在速度を常に最新にする（表示用）
        currentLocation = location
        lastUpdated = location.timestamp
        // speed が負値（GPS が速度を取得できなかった）場合は 0 に補完
        currentSpeed = max(0, location.speed)

        // 現在地の住所を逆ジオコーディング（500m 未満の移動では再取得しない）
        reverseGeocodeForDisplay(location)

        // 記録中でない場合は保存しない
        guard isTracking else { return }

        // インターバルがまだ経過していない場合はスキップ
        if let lastTime = lastSaveTime,
           Date().timeIntervalSince(lastTime) < trackingInterval.seconds {
            return
        }

        saveLocationRecord(location)
    }

    /// 表示用住所の逆ジオコーディング（前回から 500m 以上移動した場合のみ実行）
    private func reverseGeocodeForDisplay(_ location: CLLocation) {
        if let last = lastGeocodedLocation, location.distance(from: last) < 500 { return }
        lastGeocodedLocation = location

        geocoder.cancelGeocode()
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            guard let self, let placemark = placemarks?.first else { return }
            self.currentAddress = Self.formatAddress(placemark)
        }
    }

    /// CLPlacemark から都道府県＋市区町村を組み立てる
    private static func formatAddress(_ placemark: CLPlacemark) -> String {
        let prefecture = placemark.administrativeArea ?? ""
        let city = placemark.locality ?? placemark.subAdministrativeArea ?? ""
        return "\(prefecture)\(city)"
    }

    private func saveLocationRecord(_ location: CLLocation) {
        guard let context = modelContext else { return }

        // 前回保存地点からの距離を CLLocation.distance(from:) で算出
        let distance: Double
        if let previous = lastSavedLocation {
            distance = location.distance(from: previous)
        } else {
            // 最初の記録は距離 0
            distance = 0
        }

        // speed が負値の場合は 0 に補完
        let speed = max(0, location.speed)

        let record = LocationRecord(
            timestamp: location.timestamp,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            speed: speed,
            distanceFromPrevious: distance,
            address: currentAddress
        )

        context.insert(record)

        // 集計値をインクリメンタルに更新（全件再集計より効率的）
        totalDistance    += distance
        savedRecordCount += 1
        totalSpeedSum    += speed
        averageSpeed      = totalSpeedSum / Double(savedRecordCount)

        lastSavedLocation = location
        lastSaveTime      = Date()
    }

    // MARK: - 起動時の集計値復元

    /// アプリ起動時に保存済みレコードから集計値を復元する
    private func loadSummaryFromStorage() {
        guard let context = modelContext else { return }

        let descriptor = FetchDescriptor<LocationRecord>(
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        guard let records = try? context.fetch(descriptor), !records.isEmpty else { return }

        totalDistance    = records.reduce(0) { $0 + $1.distanceFromPrevious }
        savedRecordCount = records.count
        totalSpeedSum    = records.reduce(0) { $0 + $1.speed }
        averageSpeed     = savedRecordCount > 0 ? totalSpeedSum / Double(savedRecordCount) : 0
        lastUpdated      = records.last?.timestamp
    }

    // MARK: - Computed Properties

    /// 位置情報の権限状態（LocationManager から転送）
    var authorizationStatus: CLAuthorizationStatus {
        locationManager.authorizationStatus
    }

    /// 位置情報エラーメッセージ（LocationManager から転送）
    var locationError: String? {
        locationManager.locationError
    }
}
