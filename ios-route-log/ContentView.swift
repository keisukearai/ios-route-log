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

    @State private var selectedTab = 0
    @State private var historyPath = NavigationPath()

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("ホーム", systemImage: "house")
                }
                .tag(0)
            HistoryView(navigationPath: $historyPath)
                .tabItem {
                    Label("履歴", systemImage: "list.bullet")
                }
                .tag(1)
            SettingsView()
                .tabItem {
                    Label("設定", systemImage: "gear")
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
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: LocationRecord.self, inMemory: true)
        .environment(RouteViewModel())
}
