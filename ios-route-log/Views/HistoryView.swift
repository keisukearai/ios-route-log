//
//  HistoryView.swift
//  ios-route-log (MoveLog)
//
//  位置履歴一覧画面。1日単位で集計し、詳細から取得間隔単位の一覧を表示する。
//

import SwiftUI
import SwiftData
import MapKit

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

    /// 平均速度 (m/s) = 総移動距離 ÷ 総記録時間
    var averageSpeed: Double {
        let totalSeconds = records.reduce(0.0) { $0 + Double(($1.intervalMinutes ?? 0) * 60) }
        guard totalSeconds > 0 else { return 0 }
        return totalDistance / totalSeconds
    }

    /// その日の最初の記録時刻
    var startTime: Date? { records.last?.timestamp }   // records は降順

    /// その日の最後の記録時刻
    var endTime: Date? { records.first?.timestamp }    // records は降順
}

// MARK: - 履歴一覧（日単位）

// MARK: - フィルター期間

enum HistoryFilter: Int, CaseIterable, Identifiable {
    case oneWeek = 7
    case twoWeeks = 14
    case oneMonth = 30
    case all = 0

    var id: Int { rawValue }

    func label(for lm: LanguageManager) -> String {
        switch self {
        case .oneWeek:  return lm.filterOneWeek
        case .twoWeeks: return lm.filterTwoWeeks
        case .oneMonth: return lm.filterOneMonth
        case .all:      return lm.filterAll
        }
    }
}

struct HistoryView: View {
    @Binding var navigationPath: NavigationPath

    @Query(sort: \LocationRecord.timestamp, order: .reverse)
    private var records: [LocationRecord]

    @Query private var dayNotes: [DayNote]

    @Environment(\.modelContext) private var modelContext
    @Environment(LanguageManager.self) private var lm

    @State private var filter: HistoryFilter = .oneWeek

    private var allDaySummaries: [DaySummary] {
        let calendar = Calendar.current
        var grouped: [Date: [LocationRecord]] = [:]
        for record in records {
            let day = calendar.startOfDay(for: record.timestamp)
            grouped[day, default: []].append(record)
        }
        return grouped
            .map { DaySummary(date: $0.key, records: $0.value) }
            .sorted { $0.date > $1.date }
    }

    private var filteredDaySummaries: [DaySummary] {
        guard filter != .all else { return allDaySummaries }
        let cutoff = Calendar.current.startOfDay(
            for: Calendar.current.date(byAdding: .day, value: -(filter.rawValue - 1), to: Date())!
        )
        return allDaySummaries.filter { $0.date >= cutoff }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if records.isEmpty {
                    ContentUnavailableView(
                        lm.noRecordsTitle,
                        systemImage: "location.slash",
                        description: Text(lm.noRecordsDescription)
                    )
                } else {
                    List {
                        ForEach(filteredDaySummaries) { summary in
                            let note = dayNotes.first { $0.date == summary.date }?.note
                            NavigationLink(value: summary.date) {
                                DaySummaryRowView(summary: summary, note: note)
                            }
                        }
                        .onDelete(perform: deleteDays)
                    }
                    .listStyle(.insetGrouped)
                    .padding(.bottom, 15)
                    .safeAreaInset(edge: .top, spacing: 0) {
                        Picker("", selection: $filter) {
                            ForEach(HistoryFilter.allCases) { f in
                                Text(f.label(for: lm)).tag(f)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(.bar)
                    }
                }
            }
            .navigationDestination(for: Date.self) { date in
                DayDetailView(date: date)
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }

    private func deleteDays(at offsets: IndexSet) {
        for index in offsets {
            let summary = filteredDaySummaries[index]
            for record in summary.records {
                modelContext.delete(record)
            }
        }
    }
}

// MARK: - 日単位の行ビュー

struct DaySummaryRowView: View {
    let summary: DaySummary
    var note: String? = nil
    @Environment(LanguageManager.self) private var lm

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 日付（言語に応じてフォーマット切替）
            Text(lm.dayDateFormatter.string(from: summary.date))
                .font(.headline)

            // 時間帯
            if let start = summary.startTime, let end = summary.endTime {
                Text("\(Self.timeFormatter.string(from: start)) 〜 \(Self.timeFormatter.string(from: end))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // 集計情報
            HStack(spacing: 16) {
                Label(lm.recordCount(summary.count), systemImage: "mappin.circle")
                Label(formatDistance(summary.totalDistance), systemImage: "arrow.right")
                Label(formatSpeed(summary.averageSpeed), systemImage: "speedometer")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if let note, !note.isEmpty {
                Label(note, systemImage: "note.text")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
    }
}

// MARK: - 日別詳細（取得間隔単位）

struct DayDetailView: View {
    @Query private var records: [LocationRecord]
    @Query private var dayNotes: [DayNote]
    @Environment(\.modelContext) private var modelContext
    @Environment(LanguageManager.self) private var lm
    @State private var selectedTab = 0
    @State private var showingNoteSheet = false

    let date: Date

    private var currentNote: DayNote? { dayNotes.first }

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
        _dayNotes = Query(
            filter: #Predicate<DayNote> { $0.date == start }
        )
    }

    var body: some View {
        Group {
            if selectedTab == 0 {
                HourlyDetailView(date: date, records: records)
            } else if selectedTab == 1 {
                List {
                    Section {
                        ForEach(Array(records.enumerated()), id: \.element.id) { index, record in
                            let prevRecord = index + 1 < records.count ? records[index + 1] : nil
                            HistoryRowView(record: record, previousRecord: prevRecord)
                        }
                        .onDelete(perform: deleteRecords)
                    } header: {
                        Text(lm.dayDateFormatter.string(from: date))
                            .font(.caption)
                    }
                }
                .listStyle(.insetGrouped)
                .padding(.bottom, 15)
            } else {
                RouteMapView(records: records)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            Button {
                showingNoteSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "note.text")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                    Text(currentNote?.note ?? lm.dayNoteAdd)
                        .font(.subheadline)
                        .foregroundStyle(currentNote != nil ? .primary : .tertiary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "pencil")
                        .foregroundStyle(.tertiary)
                        .font(.caption)
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(.bar)
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showingNoteSheet) {
            NoteEditSheet(date: date, existingNote: currentNote)
        }
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("", selection: $selectedTab) {
                    Image(systemName: "clock").tag(0)
                    Image(systemName: "list.bullet").tag(1)
                    Image(systemName: "map").tag(2)
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
            }
        }
    }

    private func deleteRecords(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(records[index])
        }
    }
}

// MARK: - メモ編集シート

struct NoteEditSheet: View {
    let date: Date
    let existingNote: DayNote?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(LanguageManager.self) private var lm

    @State private var text: String

    init(date: Date, existingNote: DayNote?) {
        self.date = date
        self.existingNote = existingNote
        _text = State(initialValue: existingNote?.note ?? "")
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                TextField(lm.dayNotePlaceholder, text: $text, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                Spacer()
            }
            .navigationTitle(lm.dayNoteEdit)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(lm.cancelButton) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(lm.dayNoteSave) {
                        save()
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.height(200)])
    }

    private func save() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let existing = existingNote {
            if trimmed.isEmpty {
                modelContext.delete(existing)
            } else {
                existing.note = trimmed
            }
        } else if !trimmed.isEmpty {
            let note = DayNote(date: Calendar.current.startOfDay(for: date), note: trimmed)
            modelContext.insert(note)
        }
    }
}

// MARK: - 1時間単位サマリ表示

struct HourlyDetailView: View {
    let date: Date
    let records: [LocationRecord]  // 降順

    @Environment(LanguageManager.self) private var lm

    private struct HourlySummary: Identifiable {
        var id: Date { hourStart }
        let hourStart: Date
        let totalDistance: Double
        let averageSpeed: Double
        let recordCount: Int
        let startTime: Date
        let endTime: Date
    }

    private var hourlySummaries: [HourlySummary] {
        let calendar = Calendar.current
        var grouped: [Date: [LocationRecord]] = [:]
        for record in records {
            let hourStart = calendar.dateInterval(of: .hour, for: record.timestamp)!.start
            grouped[hourStart, default: []].append(record)
        }
        return grouped.compactMap { hourStart, hourRecords -> HourlySummary? in
            guard !hourRecords.isEmpty else { return nil }
            let sorted = hourRecords.sorted { $0.timestamp < $1.timestamp }
            let totalDistance = hourRecords.reduce(0.0) { $0 + $1.distanceFromPrevious }
            let totalSeconds = hourRecords.reduce(0.0) { $0 + Double(($1.intervalMinutes ?? 0) * 60) }
            let avgSpeed = totalSeconds > 0 ? totalDistance / totalSeconds : 0
            return HourlySummary(
                hourStart: hourStart,
                totalDistance: totalDistance,
                averageSpeed: avgSpeed,
                recordCount: hourRecords.count,
                startTime: sorted.first!.timestamp,
                endTime: sorted.last!.timestamp
            )
        }
        .sorted { $0.hourStart > $1.hourStart }
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    var body: some View {
        List {
            Section {
                ForEach(hourlySummaries) { summary in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        let hour = Calendar.current.component(.hour, from: summary.hourStart)
                        Text("\(hour):00")
                            .font(.headline)
                        Spacer()
                        Text("\(Self.timeFormatter.string(from: summary.startTime)) 〜 \(Self.timeFormatter.string(from: summary.endTime))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 16) {
                        Label(formatDistance(summary.totalDistance), systemImage: "arrow.right")
                        Label(formatSpeed(summary.averageSpeed), systemImage: "speedometer")
                        Label("\(summary.recordCount)件", systemImage: "mappin.circle")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
                .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                }
            } header: {
                Text(lm.dayDateFormatter.string(from: date))
                    .font(.caption)
            }
        }
        .listStyle(.insetGrouped)
        .padding(.bottom, 15)
    }
}

// MARK: - 軌跡地図

struct RouteMapView: View {
    let records: [LocationRecord]

    private var chronological: [LocationRecord] { records.reversed() }

    private var coordinates: [CLLocationCoordinate2D] {
        chronological.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }

    var body: some View {
        if chronological.isEmpty {
            ContentUnavailableView("記録なし", systemImage: "map")
        } else {
            Map(initialPosition: .automatic) {
                if coordinates.count >= 2 {
                    MapPolyline(coordinates: coordinates)
                        .stroke(.blue, lineWidth: 3)
                }
                if let first = chronological.first {
                    Annotation("出発", coordinate: CLLocationCoordinate2D(latitude: first.latitude, longitude: first.longitude)) {
                        Image(systemName: "figure.walk")
                            .padding(5)
                            .background(.green)
                            .foregroundStyle(.white)
                            .clipShape(Circle())
                    }
                }
                if chronological.count > 1, let last = chronological.last {
                    Annotation("到着", coordinate: CLLocationCoordinate2D(latitude: last.latitude, longitude: last.longitude)) {
                        Image(systemName: "flag.checkered")
                            .padding(5)
                            .background(.red)
                            .foregroundStyle(.white)
                            .clipShape(Circle())
                    }
                }
            }
            .mapStyle(.standard)
            .ignoresSafeArea(edges: .bottom)
        }
    }
}

// MARK: - 取得間隔単位の行ビュー

struct HistoryRowView: View {
    let record: LocationRecord
    var previousRecord: LocationRecord? = nil

    private var calculatedSpeedMps: Double {
        guard record.distanceFromPrevious > 0 else { return 0 }
        let seconds: Double
        if let prev = previousRecord {
            let elapsed = record.timestamp.timeIntervalSince(prev.timestamp)
            guard elapsed > 0 else { return 0 }
            seconds = elapsed
        } else if let minutes = record.intervalMinutes, minutes > 0 {
            seconds = Double(minutes * 60)
        } else {
            return 0
        }
        return record.distanceFromPrevious / seconds
    }

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
                HStack(spacing: 4) {
                    Text(record.timestamp.formatted(date: .omitted, time: .standard))
                    if let minutes = record.intervalMinutes {
                        Text("(\(minutes))")
                    }
                }
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
                Label(formatSpeed(calculatedSpeedMps), systemImage: "speedometer")
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
        .environment(LanguageManager())
}
