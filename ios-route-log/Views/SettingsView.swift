//
//  SettingsView.swift
//  ios-route-log (MoveLog)
//
//  設定画面。取得間隔の変更・言語切替・位置情報権限の状態確認・設定アプリへの遷移。
//  プレミアム課金状態の表示と購入・復元も行う。
//

import SwiftUI
import CoreLocation

struct SettingsView: View {
    @Environment(RouteViewModel.self) private var viewModel
    @Environment(LanguageManager.self) private var languageManager
    @Environment(PurchaseService.self) private var purchaseService

    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            Form {
                languageSection
                intervalSection
                locationPermissionSection
                premiumSection
                aboutSection
                #if DEBUG
                debugSection
                #endif
            }
            .font(.subheadline)
            .padding(.bottom, 15)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
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
        let lm = languageManager
        return Section {
            @Bindable var vm = viewModel
            VStack(alignment: .leading, spacing: 8) {
                // セグメントピッカー（全選択肢を表示）
                Picker(lm.trackingIntervalPickerLabel, selection: $vm.trackingInterval) {
                    ForEach(TrackingInterval.allCases) { interval in
                        Text(interval.localizedLabel(for: lm.language)).tag(interval)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: vm.trackingInterval) { _, newValue in
                    // 無課金ユーザーが有料インターバルを選択しようとした場合
                    if !purchaseService.canUseAllIntervals && !newValue.isFreeAvailable {
                        vm.trackingInterval = .oneHour
                        showPaywall = true
                    }
                }

                // 無課金の場合はロックのヒントを表示
                if !purchaseService.canUseAllIntervals {
                    Label(lm.intervalLockedHint, systemImage: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text(lm.locationTrackingIntervalHeader)
        } footer: {
            Text(lm.intervalFooter)
        }
    }

    /// プレミアムプランの状態と購入ボタン
    private var premiumSection: some View {
        let lm = languageManager
        return Section {
            LabeledContent(lm.premiumStatusLabel) {
                if purchaseService.isPremium {
                    Label(lm.premiumStatusPremium, systemImage: "crown.fill")
                        .font(.body)
                        .foregroundStyle(.yellow)
                        .fontWeight(.medium)
                } else {
                    Text(lm.premiumStatusFree)
                        .foregroundStyle(.secondary)
                }
            }

            if !purchaseService.isPremium {
                Button {
                    showPaywall = true
                } label: {
                    Label(lm.upgradeButton, systemImage: "crown")
                        .font(.body)
                        .foregroundStyle(Color.accentColor)
                }

                Button(lm.restoreButton) {
                    Task {
                        try? await purchaseService.restore()
                    }
                }
                .foregroundStyle(.secondary)
            }
        } header: {
            Text(lm.premiumSectionTitle)
        } footer: {
            if !purchaseService.isPremium {
                Text(lm.premiumSectionFooter)
            }
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

    #if DEBUG
    /// デバッグ専用: テストモード切替
    private var debugSection: some View {
        @Bindable var ps = purchaseService
        return Section {
            Toggle(languageManager.testModeLabel, isOn: Binding(
                get: { purchaseService.isTestMode },
                set: { purchaseService.isTestMode = $0 }
            ))
        } header: {
            Text(languageManager.testModeSectionTitle)
        }
    }
    #endif

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
        .environment(PurchaseService())
}
