import Foundation
import SwiftData

@Model
class SeatingChart {
    var id: UUID
    var title: String
    var rows: Int
    var columns: Int
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
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        placements: [SeatingPlacement] = []
    ) {
        self.id = id
        self.title = title
        self.rows = rows
        self.columns = columns
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.placements = placements
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
