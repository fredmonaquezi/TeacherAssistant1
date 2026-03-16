import Foundation
import SwiftData

enum SeatingLayoutStyle: String, CaseIterable, Codable, Identifiable {
    case rows
    case duos
    case uShape
    case centers

    var id: String { rawValue }
}

@Model
class SeatingChart {
    var id: UUID
    var title: String
    var rows: Int
    var columns: Int
    var layoutStyleRaw: String
    var centerGroupSize: Int
    var createdAt: Date
    var updatedAt: Date

    var schoolClass: SchoolClass?

    @Relationship(deleteRule: .cascade, inverse: \SeatingPlacement.chart)
    var placements: [SeatingPlacement] = []

    init(
        id: UUID = UUID(),
        title: String = "Main Layout",
        rows: Int = 4,
        columns: Int = 5,
        layoutStyleRaw: String = SeatingLayoutStyle.rows.rawValue,
        centerGroupSize: Int = 4,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        placements: [SeatingPlacement] = []
    ) {
        self.id = id
        self.title = title
        self.rows = rows
        self.columns = columns
        self.layoutStyleRaw = layoutStyleRaw
        self.centerGroupSize = centerGroupSize
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.placements = placements
    }
}

extension SeatingChart {
    var layoutStyle: SeatingLayoutStyle {
        get { SeatingLayoutStyle(rawValue: layoutStyleRaw) ?? .rows }
        set { layoutStyleRaw = newValue.rawValue }
    }

    var validatedCenterGroupSize: Int {
        min(max(centerGroupSize, 3), 4)
    }

    var activeSeatCount: Int {
        switch layoutStyle {
        case .rows, .duos, .centers:
            return max(rows, 1) * max(columns, 1)
        case .uShape:
            let safeRows = max(rows, 1)
            let safeColumns = max(columns, 1)
            if safeRows == 1 || safeColumns == 1 {
                return safeRows * safeColumns
            }
            return (safeRows * 2) + (safeColumns * 2) - 4
        }
    }

    func isActiveSeat(row: Int, column: Int) -> Bool {
        guard row >= 0, column >= 0, row < rows, column < columns else { return false }

        switch layoutStyle {
        case .rows, .duos, .centers:
            return true
        case .uShape:
            if rows == 1 || columns == 1 {
                return true
            }
            return row == 0 || row == rows - 1 || column == 0 || column == columns - 1
        }
    }
}

@Model
class SeatingPlacement {
    var id: UUID
    var row: Int
    var column: Int
    var studentUUID: UUID
    var studentNameSnapshot: String

    var chart: SeatingChart?

    init(
        id: UUID = UUID(),
        row: Int,
        column: Int,
        studentUUID: UUID,
        studentNameSnapshot: String,
        chart: SeatingChart? = nil
    ) {
        self.id = id
        self.row = row
        self.column = column
        self.studentUUID = studentUUID
        self.studentNameSnapshot = studentNameSnapshot
        self.chart = chart
    }
}
