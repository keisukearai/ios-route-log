//
//  DayNote.swift
//  ios-route-log (MoveLog)
//
//  1日分のメモを保持する SwiftData モデル。
//  date は startOfDay で保存し、DaySummary の date と直接比較できる。
//

import Foundation
import SwiftData

@Model
final class DayNote {
    /// その日の開始時刻（00:00:00）
    var date: Date
    /// ユーザーが入力した1行メモ
    var note: String

    init(date: Date, note: String) {
        self.date = date
        self.note = note
    }
}
