//
//  LanguageManager.swift
//  ios-route-log (MoveLog)
//
//  アプリ内言語を管理する @Observable クラス。
//  言語設定は UserDefaults に保存され、次回起動時も維持される。
//  全 View から @Environment(LanguageManager.self) で参照し、
//  このクラスのプロパティを通じてローカライズ済み文字列を取得する。
//

import Foundation
import CoreLocation

@Observable
final class LanguageManager {

    var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: "appLanguage") }
    }

    init() {
        let raw = UserDefaults.standard.string(forKey: "appLanguage") ?? "ja"
        language = AppLanguage(rawValue: raw) ?? .japanese
    }

    // MARK: - Private Helper

    private func s(_ japanese: String, _ english: String) -> String {
        language == .japanese ? japanese : english
    }
}

// MARK: - Tab Labels

extension LanguageManager {
    var tabHome: String     { s("ホーム", "Home") }
    var tabHistory: String  { s("履歴", "History") }
    var tabSettings: String { s("設定", "Settings") }
}

// MARK: - HomeView

extension LanguageManager {
    var recordingStatusSection: String { s("記録状態", "Recording Status") }
    var recordingLabel: String         { s("記録中", "Recording") }
    var stoppedLabel: String           { s("停止中", "Stopped") }

    func trackingIntervalDisplay(_ interval: TrackingInterval) -> String {
        switch language {
        case .japanese: return "\(interval.localizedLabel(for: .japanese))ごとに記録"
        case .english:  return "Every \(interval.localizedLabel(for: .english))"
        }
    }

    var currentLocationSection: String { s("現在の位置情報", "Current Location") }
    var addressLabel: String           { s("住所", "Address") }
    var latitudeLabel: String          { s("緯度", "Latitude") }
    var longitudeLabel: String         { s("経度", "Longitude") }
    var fetchingLocation: String       { s("位置情報を取得中...", "Fetching location...") }
    var lastUpdatedLabel: String       { s("最終取得", "Last Updated") }
    var movementStatsSection: String   { s("移動統計", "Movement Stats") }
    var statsTodayLabel: String        { s("当日", "Today") }
    var statsYesterdayLabel: String    { s("前日", "Yesterday") }
    var statsAllTimeLabel: String      { s("全期間", "All Time") }
    var totalDistanceLabel: String     { s("累計移動距離", "Total Distance") }
    var currentSpeedLabel: String      { s("現在速度", "Current Speed") }
    var averageSpeedLabel: String      { s("平均速度", "Average Speed") }
    var stopRecording: String          { s("記録を停止する", "Stop Recording") }
    var startRecording: String         { s("記録を開始する", "Start Recording") }
    var locationPermRequired: String   { s("位置情報の権限が必要です。設定画面から許可してください。",
                                           "Location permission is required. Please allow it in Settings.") }
}

// MARK: - HistoryView

extension LanguageManager {
    var noRecordsTitle: String       { s("記録なし", "No Records") }
    var noRecordsDescription: String { s("ホーム画面から記録を開始すると\n位置履歴が表示されます",
                                         "Start recording from Home\nto view location history") }

    var filterOneWeek:  String { s("1週間", "1 Week") }
    var filterTwoWeeks: String { s("2週間", "2 Weeks") }
    var filterOneMonth: String { s("1ヶ月", "1 Month") }
    var filterAll:      String { s("全期間", "All") }

    func recordCount(_ n: Int) -> String {
        language == .japanese ? "\(n)件" : (n == 1 ? "1 record" : "\(n) records")
    }

    /// 日付行ビューで使う DateFormatter（言語に応じて切替）
    /// ジオコーダーに渡すロケール
    var geocodeLocale: Locale {
        language == .japanese ? Locale(identifier: "ja_JP") : Locale(identifier: "en_US")
    }

    var dayDateFormatter: DateFormatter {
        let f = DateFormatter()
        switch language {
        case .japanese:
            f.locale = Locale(identifier: "ja_JP")
            f.dateFormat = "yyyy年M月d日(E)"
        case .english:
            f.locale = Locale(identifier: "en_US")
            f.dateFormat = "EEE, MMM d, yyyy"
        }
        return f
    }
}

// MARK: - DayNote

extension LanguageManager {
    var dayNoteAdd: String         { s("メモを追加...", "Add a note...") }
    var dayNoteEdit: String        { s("メモを編集", "Edit Note") }
    var dayNotePlaceholder: String { s("この日のメモを入力", "Enter a note for this day") }
    var dayNoteSave: String        { s("保存", "Save") }
}

// MARK: - SettingsView

extension LanguageManager {
    var trackingIntervalPickerLabel: String { s("取得間隔", "Tracking Interval") }
    var locationTrackingIntervalHeader: String { s("位置情報の取得間隔", "Location Tracking Interval") }
    var intervalFooter: String { s("間隔が長いほどバッテリー消費を抑えられます。移動ルートの詳細度は下がります。",
                                   "Longer intervals save battery but reduce route detail.") }
    var permissionStatus: String   { s("権限状態", "Permission Status") }
    var openSettingsApp: String    { s("設定アプリで変更する", "Open Settings App") }
    var locationSectionTitle: String { s("位置情報", "Location") }
    var locationPermFooter: String { s("バックグラウンドでの記録には「常に許可」が必要です。「使用中のみ」では、アプリがバックグラウンドになると記録が停止する場合があります。",
                                       "\"Always\" permission is required for background recording. With \"When In Use\", recording may stop when the app goes to the background.") }
    var aboutSectionTitle: String  { s("アプリについて", "About") }
    var versionLabel: String       { s("バージョン", "Version") }
    var privacyNote: String        { s("位置情報は端末内にのみ保存され、外部サーバーへ送信されることはありません。本アプリは移動経路の記録を目的として位置情報を利用します。",
                                       "Location data is stored only on your device and is never sent to external servers. This app uses location data solely for recording travel routes.") }
    var languageSectionTitle: String { s("言語", "Language") }

    // MARK: - Auto Start

    var autoStartSectionTitle: String { s("自動開始", "Auto Start") }
    var autoStartLabel: String        { s("起動時・復帰時に自動で開始する", "Start automatically on launch or foreground") }
    var autoStartFooter: String       { s("アプリ起動時またはフォアグラウンド復帰時に、記録を自動で開始します。同じセッション中に手動で停止した場合は、他のアプリに切り替えるまで再開しません。",
                                         "Recording starts automatically when the app launches or returns to the foreground. If stopped manually within the same session, it will not restart until you switch to another app.") }

    // MARK: - Premium / Paywall

    var premiumSectionTitle: String     { s("プレミアム", "Premium") }
    var premiumStatusLabel: String      { s("プラン", "Plan") }
    var premiumStatusFree: String       { s("無料", "Free") }
    var premiumStatusPremium: String    { s("プレミアム", "Premium") }
    var upgradeButton: String           { s("アップグレード", "Upgrade") }
    var restoreButton: String           { s("購入を復元", "Restore Purchase") }
    var premiumSectionFooter: String    { s("プレミアムプランでは5分・10分・15分・30分の短い間隔を使用できます。",
                                           "Premium plan allows shorter intervals: 5, 10, 15, and 30 minutes.") }

    var paywallNavTitle: String  { s("プレミアムプラン", "Premium Plan") }
    var paywallTitle: String     { s("プレミアムプラン", "Premium Plan") }
    var paywallSubtitle: String  { s("短いインターバルで\nより詳細なルートを記録",
                                     "Record more detailed routes\nwith shorter intervals") }
    var featureShortInterval: String { s("5・10・15・30分の短い取得間隔", "Short intervals: 5, 10, 15, 30 min") }
    var featureDetailedRoute: String { s("より精密な移動ルートの記録", "More detailed route tracking") }
    var cancelButton: String     { s("キャンセル", "Cancel") }
    var errorTitle: String       { s("エラー", "Error") }
    var okButton: String         { s("OK", "OK") }
    var purchaseButtonLoading: String { s("読み込み中...", "Loading...") }

    func purchaseButtonWithPrice(_ price: String) -> String {
        s("\(price) で購入", "Buy for \(price)")
    }

    var intervalLockedHint: String { s("プレミアムプランが必要です", "Requires Premium plan") }

    #if DEBUG
    var testModeSectionTitle: String { s("デバッグ", "Debug") }
    var testModeLabel: String        { s("テストモード（全インターバル解放）", "Test Mode (all intervals unlocked)") }
    #endif

    func authorizationLabel(for status: CLAuthorizationStatus) -> String {
        switch status {
        case .notDetermined:       return s("未設定", "Not Set")
        case .restricted:          return s("制限あり", "Restricted")
        case .denied:              return s("拒否", "Denied")
        case .authorizedWhenInUse: return s("使用中のみ", "When In Use")
        case .authorizedAlways:    return s("常に許可", "Always")
        @unknown default:          return s("不明", "Unknown")
        }
    }
}
