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
    @Environment(LanguageManager.self) private var lm

    var body: some View {
        NavigationStack {
            List {
                recordingStatusSection
                currentLocationSection
                movementStatsSection
                controlSection
            }
            .listStyle(.insetGrouped)
            .font(.subheadline)
            .padding(.bottom, 15)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }

    // MARK: - Sections

    /// 記録状態・インターバル・エラー表示
    private var recordingStatusSection: some View {
        Section(lm.recordingStatusSection) {
            HStack(spacing: 10) {
                // 録中インジケーター
                Circle()
                    .fill(viewModel.isTracking ? Color.green : Color.gray)
                    .frame(width: 10, height: 10)
                Text(viewModel.isTracking ? lm.recordingLabel : lm.stoppedLabel)
                    .fontWeight(.medium)
                Spacer()
                Text(lm.trackingIntervalDisplay(viewModel.trackingInterval))
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

    /// 現在の緯度・経度・住所・最終取得時刻
    private var currentLocationSection: some View {
        Section(lm.currentLocationSection) {
            if let location = viewModel.currentLocation {
                if let address = viewModel.currentAddress {
                    LabeledContent(lm.addressLabel, value: address)
                }
                LabeledContent(lm.latitudeLabel,  value: String(format: "%.6f°", location.coordinate.latitude))
                LabeledContent(lm.longitudeLabel, value: String(format: "%.6f°", location.coordinate.longitude))
            } else {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(lm.fetchingLocation)
                        .foregroundStyle(.secondary)
                }
            }

            if let updated = viewModel.lastUpdated {
                LabeledContent(lm.lastUpdatedLabel, value: updated.formatted(date: .abbreviated, time: .shortened))
            }
        }
    }

    /// 累計距離・現在速度・平均速度
    private var movementStatsSection: some View {
        Section(lm.movementStatsSection) {
            LabeledContent(lm.totalDistanceLabel, value: formatDistance(viewModel.totalDistance))
            LabeledContent(lm.currentSpeedLabel,  value: formatSpeed(viewModel.currentSpeed))
            LabeledContent(lm.averageSpeedLabel,  value: formatSpeed(viewModel.averageSpeed))
        }
    }

    /// 記録開始・停止ボタン
    private var controlSection: some View {
        Section {
            Button(action: toggleTracking) {
                HStack {
                    Spacer()
                    if viewModel.isTracking {
                        Label(lm.stopRecording, systemImage: "stop.circle.fill")
                            .foregroundStyle(.red)
                    } else {
                        Label(lm.startRecording, systemImage: "play.circle.fill")
                            .foregroundStyle(.blue)
                    }
                    Spacer()
                }
                .font(.subheadline)
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
        } footer: {
            if viewModel.authorizationStatus == .denied || viewModel.authorizationStatus == .restricted {
                Text(lm.locationPermRequired)
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
        .environment(LanguageManager())
}
