import Foundation
import SwiftData

@Model
class ClassDiaryEntry {
    var date: Date
    var startTime: Date?
    var endTime: Date?
    var plan: String
    var objectives: String
    var materials: String
    var notes: String

    var schoolClass: SchoolClass?
    var subject: Subject?
    var unit: Unit?

    init(
        date: Date,
        startTime: Date? = nil,
        endTime: Date? = nil,
        plan: String = "",
        objectives: String = "",
        materials: String = "",
        notes: String = "",
        schoolClass: SchoolClass? = nil,
        subject: Subject? = nil,
        unit: Unit? = nil
    ) {
        self.date = date
        self.startTime = startTime
        self.endTime = endTime
        self.plan = plan
        self.objectives = objectives
        self.materials = materials
        self.notes = notes
        self.schoolClass = schoolClass
        self.subject = subject
        self.unit = unit
    }
}
