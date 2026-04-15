//
//  LocationManager.swift
//  ios-route-log (MoveLog)
//
//  CoreLocation の責務を一手に担うクラス。
//  ViewModel はこのクラスを通じてのみ位置情報を受け取る。
//

import Foundation
import CoreLocation

// MARK: - バックグラウンド位置取得について
//
// iOS でバックグラウンドの位置取得を行うには以下が必要：
//   1. Info.plist の UIBackgroundModes に "location" を追加
//      → Xcode の Signing & Capabilities > Background Modes > "Location updates" にチェック
//   2. CLLocationManager.allowsBackgroundLocationUpdates = true を設定
//   3. 「常に許可 (Always)」の位置情報権限
//
// App Store 審査について：
//   バックグラウンド位置取得は「移動記録」のような明確な用途がある場合は審査通過できる。
//   本アプリは移動ルートの記録が主目的であり、常時監視アプリではない。
//   Info.plist の NSLocationAlwaysAndWhenInUseUsageDescription に
//   用途を明確に記載することが重要。
//
// 電池消費への配慮：
//   - desiredAccuracy を kCLLocationAccuracyHundredMeters に設定（精度と電池のバランス）
//   - distanceFilter で微小な移動によるコールバックを抑制（10m 未満は無視）
//   - 停止中は allowsBackgroundLocationUpdates = false に戻す

/// CoreLocation の責務を担うクラス
///
/// ViewModel から直接 CLLocationManager を操作しないよう、
/// 位置情報の取得・権限管理をこのクラスに集約する。
@Observable
final class LocationManager: NSObject {

    // MARK: - 外部から観察できる状態

    /// 現在の位置情報権限状態
    var authorizationStatus: CLAuthorizationStatus = .notDetermined

    /// 最後に取得した CLLocation
    var currentLocation: CLLocation?

    /// 位置情報取得に失敗したときのエラーメッセージ
    var locationError: String?

    // MARK: - コールバック

    /// 位置情報が更新されたときに ViewModel へ通知するクロージャ
    var onLocationUpdate: ((CLLocation) -> Void)?

    // MARK: - プライベート

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        // 精度は100m程度（バッテリー節約と実用精度のバランス）
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        // 10m 以上移動しないとコールバックしない（頻繁な更新を抑制）
        manager.distanceFilter = 10
        authorizationStatus = manager.authorizationStatus
    }

    // MARK: - 公開メソッド

    /// 位置情報の権限を要求する
    ///
    /// バックグラウンド記録のため "常に許可" を要求する。
    /// ユーザーが "使用中のみ" を選んだ場合、バックグラウンドでの記録は
    /// 保証されないが、フォアグラウンドでは記録できる。
    func requestPermission() {
        manager.requestAlwaysAuthorization()
    }

    /// 位置情報の取得を開始する
    func startUpdating() {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            enableBackgroundUpdatesIfCapable()
            manager.startUpdatingLocation()
        case .notDetermined:
            // まず権限を要求し、付与されたら locationManagerDidChangeAuthorization で再試行
            requestPermission()
        default:
            // denied / restricted はユーザーが設定アプリで変更する必要がある
            break
        }
    }

    /// 位置情報の取得を停止する
    func stopUpdating() {
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
    }

    // MARK: - プライベートメソッド

    private func enableBackgroundUpdatesIfCapable() {
        // UIBackgroundModes に "location" が含まれていない場合に
        // allowsBackgroundLocationUpdates = true を設定すると実行時クラッシュするため
        // ランタイムチェックを行う
        let backgroundModes = Bundle.main.infoDictionary?["UIBackgroundModes"] as? [String] ?? []
        if backgroundModes.contains("location") {
            manager.allowsBackgroundLocationUpdates = true
            manager.pausesLocationUpdatesAutomatically = false
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        // 水平精度チェック
        //   - horizontalAccuracy < 0: 精度不明（無効データ）
        //   - horizontalAccuracy >= 100: 精度が悪すぎる（100m 以上の誤差）
        guard location.horizontalAccuracy >= 0,
              location.horizontalAccuracy < 100 else { return }

        currentLocation = location
        locationError = nil
        onLocationUpdate?(location)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let clError = error as? CLError, clError.code == .locationUnknown {
            // locationUnknown は一時的なエラー。次のコールバックを待てばよい
            return
        }
        locationError = error.localizedDescription
    }
}
