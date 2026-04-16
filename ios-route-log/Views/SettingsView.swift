//
//  SettingsView.swift
//  ios-route-log (MoveLog)
//
//  設定画面。取得間隔の変更・位置情報権限の状態確認・設定アプリへの遷移。
//

import SwiftUI
import CoreLocation

struct SettingsView: View {
    @Environment(RouteViewModel.self) private var viewModel

    var body: some View {
        NavigationStack {
            Form {
                intervalSection
                locationPermissionSection
                aboutSection
            }
            .contentMargins(.bottom, 16, for: .scrollContent)
        }
    }

    // MARK: - Sections

    /// 取得間隔選択
    private var intervalSection: some View {
        // @Bindable を使って @Observable の viewModel にバインドする
        // （@Environment で取得した @Observable 型は直接 $ を使えないため）
        Section {
            @Bindable var vm = viewModel
            Picker("取得間隔", selection: $vm.trackingInterval) {
                ForEach(TrackingInterval.allCases) { interval in
                    Text(interval.label).tag(interval)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Text("位置情報の取得間隔")
        } footer: {
            Text("間隔が長いほどバッテリー消費を抑えられます。移動ルートの詳細度は下がります。")
        }
    }

    /// 位置情報権限の状態表示と設定アプリへの遷移
    private var locationPermissionSection: some View {
        Section {
            LabeledContent("権限状態") {
                Text(authorizationLabel)
                    .foregroundStyle(authorizationColor)
                    .fontWeight(.medium)
            }

            // 「常に許可」以外の場合、設定アプリへの誘導を表示
            if viewModel.authorizationStatus != .authorizedAlways {
                Button {
                    openAppSettings()
                } label: {
                    Label("設定アプリで変更する", systemImage: "arrow.up.right.square")
                }
            }
        } header: {
            Text("位置情報")
        } footer: {
            Text("バックグラウンドでの記録には「常に許可」が必要です。「使用中のみ」では、アプリがバックグラウンドになると記録が停止する場合があります。")
        }
    }

    /// アプリについての情報
    private var aboutSection: some View {
        Section("アプリについて") {
            LabeledContent("バージョン", value: appVersion)

            Text("位置情報は端末内にのみ保存され、外部サーバーへ送信されることはありません。本アプリは移動経路の記録を目的として位置情報を利用します。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Helper Properties

    private var authorizationLabel: String {
        switch viewModel.authorizationStatus {
        case .notDetermined:       return "未設定"
        case .restricted:          return "制限あり"
        case .denied:              return "拒否"
        case .authorizedWhenInUse: return "使用中のみ"
        case .authorizedAlways:    return "常に許可"
        @unknown default:          return "不明"
        }
    }

    private var authorizationColor: Color {
        switch viewModel.authorizationStatus {
        case .authorizedAlways:    return .green
        case .authorizedWhenInUse: return .orange
        default:                   return .red
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    // MARK: - Actions

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

#Preview {
    SettingsView()
        .environment(RouteViewModel())
}
