//
//  SettingsView.swift
//  ios-route-log (MoveLog)
//
//  設定画面。取得間隔の変更・言語切替・位置情報権限の状態確認・設定アプリへの遷移。
//

import SwiftUI
import CoreLocation

struct SettingsView: View {
    @Environment(RouteViewModel.self) private var viewModel
    @Environment(LanguageManager.self) private var languageManager

    var body: some View {
        NavigationStack {
            Form {
                languageSection
                intervalSection
                locationPermissionSection
                aboutSection
            }
            .contentMargins(.bottom, 16, for: .scrollContent)
        }
    }

    // MARK: - Sections

    /// 言語切替
    private var languageSection: some View {
        @Bindable var lm = languageManager
        return Section(lm.languageSectionTitle) {
            Picker(lm.languageSectionTitle, selection: $lm.language) {
                ForEach(AppLanguage.allCases) { lang in
                    Text(lang.displayName).tag(lang)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    /// 取得間隔選択
    private var intervalSection: some View {
        // @Bindable を使って @Observable の viewModel にバインドする
        // （@Environment で取得した @Observable 型は直接 $ を使えないため）
        let lm = languageManager
        return Section {
            @Bindable var vm = viewModel
            Picker(lm.trackingIntervalPickerLabel, selection: $vm.trackingInterval) {
                ForEach(TrackingInterval.allCases) { interval in
                    Text(interval.localizedLabel(for: lm.language)).tag(interval)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Text(lm.locationTrackingIntervalHeader)
        } footer: {
            Text(lm.intervalFooter)
        }
    }

    /// 位置情報権限の状態表示と設定アプリへの遷移
    private var locationPermissionSection: some View {
        let lm = languageManager
        return Section {
            LabeledContent(lm.permissionStatus) {
                Text(lm.authorizationLabel(for: viewModel.authorizationStatus))
                    .foregroundStyle(authorizationColor)
                    .fontWeight(.medium)
            }

            // 「常に許可」以外の場合、設定アプリへの誘導を表示
            if viewModel.authorizationStatus != .authorizedAlways {
                Button {
                    openAppSettings()
                } label: {
                    Label(lm.openSettingsApp, systemImage: "arrow.up.right.square")
                }
            }
        } header: {
            Text(lm.locationSectionTitle)
        } footer: {
            Text(lm.locationPermFooter)
        }
    }

    /// アプリについての情報
    private var aboutSection: some View {
        let lm = languageManager
        return Section(lm.aboutSectionTitle) {
            LabeledContent(lm.versionLabel, value: appVersion)

            Text(lm.privacyNote)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Helper Properties

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
        .environment(LanguageManager())
}
