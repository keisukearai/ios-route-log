//
//  HistoryView.swift
//  ios-route-log (MoveLog)
//
//  位置履歴一覧画面。1日単位で集計し、詳細から取得間隔単位の一覧を表示する。
//

import SwiftUI
import SwiftData

// MARK: - 1日分の集計データ

struct DaySummary: Identifiable {
    var id: Date { date }
    /// その日の開始時刻（00:00:00）
    let date: Date
    /// その日の LocationRecord 一覧（新しい順）
    let records: [LocationRecord]

    /// 記録件数
    var count: Int { records.count }

    /// 累計移動距離 (m)
    var totalDistance: Double { records.reduce(0) { $0 + $1.distanceFromPrevious } }

    /// 平均速度 (m/s)
    var averageSpeed: Double {
        guard count > 0 else { return 0 }
        return records.reduce(0) { $0 + $1.speed } / Double(count)
    }

    /// その日の最初の記録時刻
    var startTime: Date? { records.last?.timestamp }   // records は降順

    /// その日の最後の記録時刻
    var endTime: Date? { records.first?.timestamp }    // records は降順
}

// MARK: - 履歴一覧（日単位）

struct HistoryView: View {
    @Binding var navigationPath: NavigationPath

    @Query(sort: \LocationRecord.timestamp, order: .reverse)
    private var records: [LocationRecord]

    @Environment(\.modelContext) private var modelContext

    private var daySummaries: [DaySummary] {
        let calendar = Calendar.current
        // startOfDay をキーにしてグループ化
        var grouped: [Date: [LocationRecord]] = [:]
        for record in records {
            let day = calendar.startOfDay(for: record.timestamp)
            grouped[day, default: []].append(record)
        }
        // 日付の降順で返す
        return grouped
            .map { DaySummary(date: $0.key, records: $0.value) }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if records.isEmpty {
                    ContentUnavailableView(
                        "記録なし",
                        systemImage: "location.slash",
                        description: Text("ホーム画面から記録を開始すると\n位置履歴が表示されます")
                    )
                } else {
                    List {
                        ForEach(daySummaries) { summary in
                            NavigationLink(value: summary.date) {
                                DaySummaryRowView(summary: summary)
                            }
                        }
                        .onDelete(perform: deleteDays)
                    }
                    .listStyle(.insetGrouped)
                    .contentMargins(.bottom, 16, for: .scrollContent)
                }
            }
            .navigationDestination(for: Date.self) { date in
                DayDetailView(date: date)
            }
        }
    }

    private func deleteDays(at offsets: IndexSet) {
        for index in offsets {
            let summary = daySummaries[index]
            for record in summary.records {
                modelContext.delete(record)
            }
        }
    }
}

// MARK: - 日単位の行ビュー

struct DaySummaryRowView: View {
    let summary: DaySummary

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy年M月d日(E)"
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 日付
            Text(Self.dateFormatter.string(from: summary.date))
                .font(.headline)

            // 時間帯
            if let start = summary.startTime, let end = summary.endTime {
                Text("\(Self.timeFormatter.string(from: start)) 〜 \(Self.timeFormatter.string(from: end))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // 集計情報
            HStack(spacing: 16) {
                Label("\(summary.count)件", systemImage: "mappin.circle")
                Label(formatDistance(summary.totalDistance), systemImage: "arrow.right")
                Label(formatSpeed(summary.averageSpeed), systemImage: "speedometer")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - 日別詳細（取得間隔単位）

struct DayDetailView: View {
    @Query private var records: [LocationRecord]
    @Environment(\.modelContext) private var modelContext

    let date: Date

    init(date: Date) {
        self.date = date
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        _records = Query(
            filter: #Predicate<LocationRecord> { record in
                record.timestamp >= start && record.timestamp < end
            },
            sort: \LocationRecord.timestamp,
            order: .reverse
        )
    }

    var body: some View {
        List {
            ForEach(records) { record in
                HistoryRowView(record: record)
            }
            .onDelete(perform: deleteRecords)
        }
        .listStyle(.insetGrouped)
        .padding(.bottom, 50)
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private func deleteRecords(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(records[index])
        }
    }
}

// MARK: - 取得間隔単位の行ビュー

struct HistoryRowView: View {
    let record: LocationRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            // 住所（都道府県＋市区町村）＋取得時刻
            HStack(alignment: .firstTextBaseline) {
                if let address = record.address, !address.isEmpty {
                    Label(address, systemImage: "location.fill")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                } else {
                    Label(
                        String(format: "%.6f, %.6f", record.latitude, record.longitude),
                        systemImage: "location.fill"
                    )
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                }
                Spacer()
                Text(record.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // 緯度・経度（住所がある場合のみ）
            if let address = record.address, !address.isEmpty {
                Label {
                    Text(String(format: "%.6f, %.6f", record.latitude, record.longitude))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                } icon: {
                    Image(systemName: "location.fill")
                        .font(.subheadline)
                        .opacity(0)
                }
            }

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
    @Previewable @State var path = NavigationPath()
    HistoryView(navigationPath: $path)
        .modelContainer(for: LocationRecord.self, inMemory: true)
}
