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
