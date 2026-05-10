//
//  ContentView.swift
//  ios-route-log (MoveLog)
//
//  アプリのルートビュー。TabView で3画面を管理する。
//  ViewModel を ModelContext で初期化するのもここで行う。
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(RouteViewModel.self) private var viewModel
    @Environment(LanguageManager.self) private var lm

    @State private var selectedTab = 0
    @State private var historyPath = NavigationPath()

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label(lm.tabHome, systemImage: "house")
                }
                .tag(0)
            HistoryView(navigationPath: $historyPath)
                .tabItem {
                    Label(lm.tabHistory, systemImage: "list.bullet")
                }
                .tag(1)
            SettingsView()
                .tabItem {
                    Label(lm.tabSettings, systemImage: "gear")
                }
                .tag(2)
        }
        .onChange(of: selectedTab) { _, newValue in
            // 履歴タブを押下したら常に日単位一覧へ戻す
            if newValue == 1 {
                historyPath = NavigationPath()
            }
        }
        .onAppear {
            // ModelContext を ViewModel に渡す（起動時の集計復元もここで走る）
            viewModel.configure(modelContext: modelContext)
            // 起動時のロケールを同期
            viewModel.updateLocale(lm.geocodeLocale)
            // 自動開始が有効なら起動時に記録を開始
            if viewModel.autoStartTracking {
                viewModel.startTracking()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                // フォアグラウンド復帰時に自動開始（同セッション中に手動停止した場合はスキップ）
                if viewModel.autoStartTracking, !viewModel.userManuallyStopped {
                    viewModel.startTracking()
                }
            case .background:
                // バックグラウンド移行でフラグをリセット（次回復帰時に自動開始を有効化）
                viewModel.userManuallyStopped = false
            default:
                break
            }
        }
        .onChange(of: lm.language) { _, _ in
            // 言語切替時にロケールを同期し、現在地住所を再ジオコーディング
            viewModel.updateLocale(lm.geocodeLocale)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: LocationRecord.self, inMemory: true)
        .environment(RouteViewModel())
        .environment(LanguageManager())
}
