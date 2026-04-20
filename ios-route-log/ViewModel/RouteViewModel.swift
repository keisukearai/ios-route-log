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
    var trackingInterval: TrackingInterval = TrackingInterval(rawValue: UserDefaults.standard.integer(forKey: "trackingInterval")) ?? .oneHour {
        didSet { UserDefaults.standard.set(trackingInterval.rawValue, forKey: "trackingInterval") }
    }

    // MARK: - 表示用データ

    /// 最後に受信した位置情報
    var currentLocation: CLLocation?

    /// 現在地の住所（都道府県＋市区町村）
    var currentAddress: String?

    /// 最後に位置情報を受信した時刻
    var lastUpdated: Date?

    /// 現在の速度 (m/s)。CLLocation.speed が負値の場合は 0
    var currentSpeed: Double = 0

    /// 保存済みレコードの平均速度 (m/s)。distance > 0 のレコードのみ対象
    var averageSpeed: Double = 0

    /// 保存済みレコードの累計移動距離 (m)
    var totalDistance: Double = 0

    /// 当日の累計移動距離 (m)
    var todayDistance: Double = 0

    /// 当日の平均速度 (m/s)。distance > 0 のレコードのみ対象
    var todayAverageSpeed: Double = 0

    /// 前日の累計移動距離 (m)
    var yesterdayDistance: Double = 0

    /// 前日の平均速度 (m/s)。distance > 0 のレコードのみ対象
    var yesterdayAverageSpeed: Double = 0

    // MARK: - 依存オブジェクト

    /// 位置情報取得を担う LocationManager
    let locationManager: LocationManager

    // MARK: - プライベート変数

    private var modelContext: ModelContext?

    /// 前回保存した CLLocation（次回の距離計算に使う）
    private var lastSavedLocation: CLLocation?

    /// 前回保存したレコードの distanceFromPrevious（連続 0 スキップ判定に使う）
    private var lastSavedDistance: Double?

    /// 前回保存した時刻（インターバル判定に使う）
    private var lastSaveTime: Date?

    /// 全期間: 記録された総時間 (秒)
    private var allTimeSeconds: Double = 0

    /// 当日: 記録された総時間 (秒)
    private var todaySeconds: Double = 0

    /// 前日: 記録された総時間 (秒)
    private var yesterdaySeconds: Double = 0

    /// 逆ジオコーディング用（表示）
    private let geocoder = CLGeocoder()
    /// 前回ジオコーディングした座標（500m 未満の移動では再取得しない）
    private var lastGeocodedLocation: CLLocation?

    /// 逆ジオコーディング用（レコード保存専用）
    private let recordGeocoder = CLGeocoder()

    /// ジオコーダーに渡すロケール（言語設定と連動）
    var preferredLocale: Locale = Locale(identifier: "ja_JP")

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

    /// 言語が切り替わったときに呼ぶ。ロケールを更新し現在地を再ジオコーディングする
    func updateLocale(_ locale: Locale) {
        preferredLocale = locale
        lastGeocodedLocation = nil   // キャッシュ無効化 → 次の呼び出しで再取得
        if let location = currentLocation {
            reverseGeocodeForDisplay(location)
        }
    }

    /// 表示用住所の逆ジオコーディング（前回から 500m 以上移動した場合のみ実行）
    private func reverseGeocodeForDisplay(_ location: CLLocation) {
        if let last = lastGeocodedLocation, location.distance(from: last) < 500 { return }
        lastGeocodedLocation = location

        geocoder.cancelGeocode()
        geocoder.reverseGeocodeLocation(location, preferredLocale: preferredLocale) { [weak self] placemarks, _ in
            guard let self, let placemark = placemarks?.first else { return }
            self.currentAddress = Self.formatAddress(placemark, locale: self.preferredLocale)
        }
    }

    /// CLPlacemark から表示用住所文字列を組み立てる
    ///
    /// - 日本語: "東京都渋谷区"（都道府県＋市区町村を連結）
    /// - 英語:   "Shibuya, Tokyo"（市区町村, 都道府県）
    private static func formatAddress(_ placemark: CLPlacemark, locale: Locale) -> String {
        let prefecture = placemark.administrativeArea ?? ""
        let city = placemark.locality ?? placemark.subAdministrativeArea ?? ""
        if locale.language.languageCode?.identifier == "ja" {
            return "\(prefecture)\(city)"
        } else {
            return [city, prefecture].filter { !$0.isEmpty }.joined(separator: ", ")
        }
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

        // 前回も今回も distance == 0 なら保存をスキップ（停止中の重複レコードを抑制）
        if distance == 0, let prev = lastSavedDistance, prev == 0 {
            lastSaveTime = Date()
            return
        }

        // speed が負値の場合は 0 に補完
        let speed = max(0, location.speed)

        let record = LocationRecord(
            timestamp: location.timestamp,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            speed: speed,
            distanceFromPrevious: distance,
            address: nil,
            intervalMinutes: trackingInterval.rawValue
        )

        context.insert(record)

        // レコード専用ジオコーダーで住所を非同期取得し、保存後に更新
        let locale = preferredLocale
        recordGeocoder.reverseGeocodeLocation(location, preferredLocale: locale) { [weak self] placemarks, _ in
            guard self != nil, let placemark = placemarks?.first else { return }
            record.address = Self.formatAddress(placemark, locale: locale)
        }

        // 集計値をインクリメンタルに更新（全件再集計より効率的）
        let intervalSeconds = Double(trackingInterval.rawValue * 60)
        totalDistance += distance
        allTimeSeconds += intervalSeconds
        averageSpeed = allTimeSeconds > 0 ? totalDistance / allTimeSeconds : 0

        // 当日分の集計
        if Calendar.current.isDateInToday(location.timestamp) {
            todayDistance += distance
            todaySeconds += intervalSeconds
            todayAverageSpeed = todaySeconds > 0 ? todayDistance / todaySeconds : 0
        }

        // 全期間合計をUserDefaultsに永続化（次回起動時の全件フェッチを不要にする）
        UserDefaults.standard.set(totalDistance, forKey: "totalDistance")
        UserDefaults.standard.set(allTimeSeconds, forKey: "allTimeSeconds")

        lastSavedLocation  = location
        lastSavedDistance  = distance
        lastSaveTime       = Date()
    }

    // MARK: - 起動時の集計値復元

    /// アプリ起動時に保存済みレコードから集計値を復元する
    private func loadSummaryFromStorage() {
        guard let context = modelContext else { return }

        let cal = Calendar.current
        let todayStart     = cal.startOfDay(for: Date())
        let yesterdayStart = cal.date(byAdding: .day, value: -1, to: todayStart)!

        // 全期間合計: UserDefaultsから読む。未保存（初回/移行時）は全件フェッチして計算
        if UserDefaults.standard.object(forKey: "totalDistance") != nil {
            totalDistance  = UserDefaults.standard.double(forKey: "totalDistance")
            allTimeSeconds = UserDefaults.standard.double(forKey: "allTimeSeconds")
            averageSpeed   = allTimeSeconds > 0 ? totalDistance / allTimeSeconds : 0
        } else {
            let allDesc = FetchDescriptor<LocationRecord>()
            if let allRecords = try? context.fetch(allDesc), !allRecords.isEmpty {
                totalDistance  = allRecords.reduce(0) { $0 + $1.distanceFromPrevious }
                allTimeSeconds = allRecords.reduce(0.0) { $0 + Double(($1.intervalMinutes ?? 0) * 60) }
                averageSpeed   = allTimeSeconds > 0 ? totalDistance / allTimeSeconds : 0
                UserDefaults.standard.set(totalDistance, forKey: "totalDistance")
                UserDefaults.standard.set(allTimeSeconds, forKey: "allTimeSeconds")
            }
        }

        // 当日・前日: 日付フィルタで絞ってフェッチ（SQLのWHEREで絞るので少量）
        let recentPredicate = #Predicate<LocationRecord> { $0.timestamp >= yesterdayStart }
        let recentDescriptor = FetchDescriptor<LocationRecord>(
            predicate: recentPredicate,
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        guard let recentRecords = try? context.fetch(recentDescriptor) else { return }

        let todayRecs     = recentRecords.filter { $0.timestamp >= todayStart }
        let yesterdayRecs = recentRecords.filter { $0.timestamp >= yesterdayStart && $0.timestamp < todayStart }

        todayDistance     = todayRecs.reduce(0) { $0 + $1.distanceFromPrevious }
        todaySeconds      = todayRecs.reduce(0.0) { $0 + Double(($1.intervalMinutes ?? 0) * 60) }
        todayAverageSpeed = todaySeconds > 0 ? todayDistance / todaySeconds : 0

        yesterdayDistance     = yesterdayRecs.reduce(0) { $0 + $1.distanceFromPrevious }
        yesterdaySeconds      = yesterdayRecs.reduce(0.0) { $0 + Double(($1.intervalMinutes ?? 0) * 60) }
        yesterdayAverageSpeed = yesterdaySeconds > 0 ? yesterdayDistance / yesterdaySeconds : 0

        // 最終更新日時: 最新1件だけ取得
        var lastDesc = FetchDescriptor<LocationRecord>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        lastDesc.fetchLimit = 1
        lastUpdated = (try? context.fetch(lastDesc))?.first?.timestamp
    }

    // MARK: - 間隔変更時の即時保存

    /// 取得間隔が変更されたときに呼ぶ。記録中かつ現在地がある場合のみ即座に1件保存する
    func saveCurrentLocationOnIntervalChange() {
        guard isTracking, let location = currentLocation else { return }
        // 間隔変更時は distance == 0 によるスキップを無効化するためリセット
        lastSavedDistance = nil
        saveLocationRecord(location)
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
