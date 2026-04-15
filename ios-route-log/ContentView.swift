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

    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("ホーム", systemImage: "house")
                }
            HistoryView()
                .tabItem {
                    Label("履歴", systemImage: "list.bullet")
                }
            SettingsView()
                .tabItem {
                    Label("設定", systemImage: "gear")
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
