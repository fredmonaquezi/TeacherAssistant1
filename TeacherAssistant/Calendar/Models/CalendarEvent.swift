import Foundation
import SwiftData

@Model
class CalendarEvent {
    var title: String
    var date: Date
    var startTime: Date?
    var endTime: Date?
    var details: String
    var isAllDay: Bool
    var schoolClass: SchoolClass?

    init(
        title: String,
        date: Date,
        startTime: Date? = nil,
        endTime: Date? = nil,
        details: String = "",
        isAllDay: Bool = true,
        schoolClass: SchoolClass? = nil
    ) {
        self.title = title
        self.date = date
        self.startTime = startTime
        self.endTime = endTime
        self.details = details
        self.isAllDay = isAllDay
        self.schoolClass = schoolClass
    }
}
