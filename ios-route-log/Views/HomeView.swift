//
//  HomeView.swift
//  ios-route-log (MoveLog)
//
//  ホーム画面。記録状態・現在位置・移動統計を表示し、
//  記録の開始・停止を行う。
//

import SwiftUI
import CoreLocation

struct HomeView: View {
    @Environment(RouteViewModel.self) private var viewModel

    var body: some View {
        NavigationStack {
            List {
                recordingStatusSection
                currentLocationSection
                movementStatsSection
                controlSection
            }
            .navigationTitle("MoveLog")
            .listStyle(.insetGrouped)
        }
    }

    // MARK: - Sections

    /// 記録状態・インターバル・エラー表示
    private var recordingStatusSection: some View {
        Section("記録状態") {
            HStack(spacing: 10) {
                // 録中インジケーター
                Circle()
                    .fill(viewModel.isTracking ? Color.green : Color.gray)
                    .frame(width: 10, height: 10)
                Text(viewModel.isTracking ? "記録中" : "停止中")
                    .fontWeight(.medium)
                Spacer()
                Text(viewModel.trackingInterval.label + "ごとに記録")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // エラーがある場合のみ表示
            if let error = viewModel.locationError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    /// 現在の緯度・経度・最終取得時刻
    private var currentLocationSection: some View {
        Section("現在の位置情報") {
            if let location = viewModel.currentLocation {
                LabeledContent("緯度", value: String(format: "%.6f°", location.coordinate.latitude))
                LabeledContent("経度", value: String(format: "%.6f°", location.coordinate.longitude))
            } else {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("位置情報を取得中...")
                        .foregroundStyle(.secondary)
                }
            }

            if let updated = viewModel.lastUpdated {
                LabeledContent("最終取得", value: updated.formatted(date: .abbreviated, time: .shortened))
            }
        }
    }

    /// 累計距離・現在速度・平均速度
    private var movementStatsSection: some View {
        Section("移動統計") {
            LabeledContent("累計移動距離", value: formatDistance(viewModel.totalDistance))
            LabeledContent("現在速度",     value: formatSpeed(viewModel.currentSpeed))
            LabeledContent("平均速度",     value: formatSpeed(viewModel.averageSpeed))
        }
    }

    /// 記録開始・停止ボタン
    private var controlSection: some View {
        Section {
            Button(action: toggleTracking) {
                HStack {
                    Spacer()
                    if viewModel.isTracking {
                        Label("記録を停止する", systemImage: "stop.circle.fill")
                            .foregroundStyle(.red)
                    } else {
                        Label("記録を開始する", systemImage: "play.circle.fill")
                            .foregroundStyle(.blue)
                    }
                    Spacer()
                }
                .font(.headline)
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
        } footer: {
            if viewModel.authorizationStatus == .denied || viewModel.authorizationStatus == .restricted {
                Text("位置情報の権限が必要です。設定画面から許可してください。")
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Actions

    private func toggleTracking() {
        if viewModel.isTracking {
            viewModel.stopTracking()
        } else {
            viewModel.startTracking()
        }
    }
}

#Preview {
    HomeView()
        .environment(RouteViewModel())
}
