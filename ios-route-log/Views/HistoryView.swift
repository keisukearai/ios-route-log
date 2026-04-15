//
//  HistoryView.swift
//  ios-route-log (MoveLog)
//
//  位置履歴一覧画面。SwiftData の @Query で自動的にリストを更新する。
//

import SwiftUI
import SwiftData

struct HistoryView: View {
    // 新しい順（降順）で全レコードを取得
    @Query(sort: \LocationRecord.timestamp, order: .reverse)
    private var records: [LocationRecord]

    var body: some View {
        NavigationStack {
            Group {
                if records.isEmpty {
                    // 記録がない場合のプレースホルダー
                    ContentUnavailableView(
                        "記録なし",
                        systemImage: "location.slash",
                        description: Text("ホーム画面から記録を開始すると\n位置履歴が表示されます")
                    )
                } else {
                    List(records) { record in
                        HistoryRowView(record: record)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("位置履歴 (\(records.count)件)")
        }
    }
}

// MARK: - Row View

/// 位置履歴1件分の行ビュー
struct HistoryRowView: View {
    let record: LocationRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            // 取得日時
            Text(record.timestamp.formatted(date: .abbreviated, time: .standard))
                .font(.caption)
                .foregroundStyle(.secondary)

            // 緯度・経度
            Label(
                String(format: "%.6f, %.6f", record.latitude, record.longitude),
                systemImage: "location.fill"
            )
            .font(.subheadline)
            .foregroundStyle(.primary)

            // 速度・前地点からの距離
            HStack(spacing: 16) {
                Label(formatSpeed(record.speed), systemImage: "speedometer")
                Label(formatDistance(record.distanceFromPrevious), systemImage: "arrow.right")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    HistoryView()
        .modelContainer(for: LocationRecord.self, inMemory: true)
}
