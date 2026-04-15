//
//  ios_route_logApp.swift
//  ios-route-log (MoveLog)
//
//  アプリのエントリーポイント。
//  - SwiftData の ModelContainer をセットアップ
//  - RouteViewModel を環境に注入して全画面で共有
//

import SwiftUI
import SwiftData

@main
struct ios_route_logApp: App {
    /// アプリ全体で共有する ViewModel。@State で保持しないと環境注入が安定しない
    @State private var viewModel = RouteViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                // SwiftData の ModelContainer を設定（端末内に永続化）
                .modelContainer(for: LocationRecord.self)
                // RouteViewModel を環境に注入（全 View から @Environment で参照可能）
                .environment(viewModel)
        }
    }
}
